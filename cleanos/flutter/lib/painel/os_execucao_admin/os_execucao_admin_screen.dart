/// os_execucao_admin_screen.dart — Visão admin da EXECUÇÃO de uma OS.
///
/// Espelha `OSExecucaoPage.tsx` no que interessa ao Painel: mostra (LEITURA) o
/// snapshot, o checklist executado, as evidências, os adicionais, as observações e
/// o resumo financeiro; e permite GERAR o laudo (PDF via `RelatorioOSModal`) e
/// ENVIAR o relatório ao cliente (rota WhatsApp). CONSOME os widgets compartilhados
/// de `lib/shared_widgets_os/` (SnapshotResumo, ChecklistExecucao, EvidenciasSection,
/// RelatorioOSModal) — sem alterá-los. Admin/gerente PODEM ver os dados do cliente
/// aqui (≠ profissional).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_providers.dart' show ordensRepositoryProvider;
import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/cliente.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/os_execucao.dart';
import '../../core/models/servico.dart';
import '../../shared_widgets_os/shared_widgets_os.dart';
import '../data/painel_providers.dart';
import '../servicos/servicos_labels.dart';
import 'os_execucao_admin_controller.dart';

class OSExecucaoAdminScreen extends ConsumerWidget {
  const OSExecucaoAdminScreen({super.key, required this.osId});

  final String osId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final async = ref.watch(osExecucaoAdminProvider(osId));
    return Scaffold(
      backgroundColor: clx.bg2,
      appBar: AppBar(
        title: Text(
          async.maybeWhen(
            data: (d) => 'Execução ${numeroFromId(d.os.id)}',
            orElse: () => 'Execução da OS',
          ),
        ),
        actions: [
          async.maybeWhen(
            data: (d) => Padding(
              padding: const EdgeInsets.only(right: ClxSpace.x3),
              child: Center(
                child: StatusBadge(status: d.os.status, dense: true, refazer: d.os.refazer, vitrine: d.os.isVitrine),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: Spinner(size: 26)),
          error: (_, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(ClxSpace.x5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ErrorBanner(
                  message: 'Não foi possível carregar a execução desta OS.',
                  onRetry: () => ref.invalidate(osExecucaoAdminProvider(osId)),
                ),
              ),
            ),
          ),
          data: (d) => _Body(data: d),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.data});

  final OSExecucaoAdminData data;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _enviando = false;
  bool _salvandoServico = false;
  bool _salvandoDesc = false;

  /// OS local (mutável): reflete os saves de serviço/descontos sem sair da tela.
  late OrdemServico _os;

  @override
  void initState() {
    super.initState();
    _os = widget.data.os;
  }

  /// Monta o laudo pronto p/ pré-visualizar/PDF (admin inclui dados do cliente).
  RelatorioOS? _montarLaudo() {
    final snap = _os.serviceSnapshot;
    if (snap == null) return null;
    final cliente = _os.expand?.cliente;
    final clienteNome = cliente == null
        ? (_os.clienteNomeExibicao.isEmpty ? 'Cliente' : _os.clienteNomeExibicao)
        : [
            cliente.nome,
            cliente.sobrenome,
          ].where((s) => (s ?? '').isNotEmpty).join(' ');
    return buildRelatorioOS(
      BuildRelatorioOSInput(
        osId: _os.id,
        numeroOS: numeroFromId(_os.id),
        clienteNome: clienteNome.isEmpty ? 'Cliente' : clienteNome,
        clienteTelefone: cliente?.telefone,
        enderecoCompleto: _enderecoCompleto(cliente),
        bairro: _os.bairro.isEmpty ? cliente?.enderecoBairro : _os.bairro,
        profissionalNome: _os.expand?.profissional?.displayName,
        dataHora: _os.dataHora,
        snapshot: snap,
        adicionais: _os.adicionais,
        checklist: _os.checklistExec,
        evidencias: widget.data.evidencias,
        observacoes: _os.observacoesProf,
        descontos: _os.descontos > 0 ? _os.descontos : null,
        avaliacaoNota: _os.avaliacaoNota,
        geradoEm: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  String? _enderecoCompleto(Cliente? cliente) {
    final liberado = _os.enderecoLiberado;
    if (liberado != null && liberado.isNotEmpty) return liberado;
    if (cliente == null) return null;
    final rua = [
      cliente.enderecoRua,
      cliente.enderecoNumero,
    ].where((s) => (s ?? '').isNotEmpty).join(', ');
    final full = [
      if (rua.isNotEmpty) rua,
      if ((cliente.enderecoComplemento ?? '').isNotEmpty)
        cliente.enderecoComplemento,
      if (cliente.enderecoBairro.isNotEmpty) cliente.enderecoBairro,
      if ((cliente.enderecoCidade ?? '').isNotEmpty) cliente.enderecoCidade,
    ].join(' — ');
    return full.isEmpty ? null : full;
  }

  Future<void> _gerarLaudo() async {
    final rel = _montarLaudo();
    if (rel == null) {
      showClxToast(
        context,
        'OS sem serviço definido — laudo indisponível.',
        type: ToastType.error,
      );
      return;
    }
    await showRelatorioOSModal(context, relatorio: rel);
  }

  Future<void> _enviarRelatorio() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      await ref.read(painelWhatsappRepositoryProvider).enviarRelatorio(_os.id);
      if (mounted) {
        showClxToast(
          context,
          'Relatório enviado ao cliente pelo WhatsApp.',
          type: ToastType.success,
        );
      }
    } catch (err) {
      if (mounted) {
        showClxToast(context, _whatsError(err), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Define o serviço de uma OS que ainda não tem serviço/snapshot. Grava só o
  /// relation `servico` (+ nome/valor denormalizados) e deixa o hook do servidor
  /// congelar o snapshot e materializar o checklist (fillServiceSnapshot). O
  /// snapshot é IMUTÁVEL depois disso — por isso só habilitamos a seleção quando
  /// ainda não há snapshot (troca posterior exige reabrir a OS no funil de edição).
  Future<void> _selecionarServico(ServicoPB svc) async {
    if (_salvandoServico) return;
    setState(() => _salvandoServico = true);
    try {
      final novo = await ref.read(ordensRepositoryProvider).update(_os.id, {
        'servico': svc.id,
        'tipo_servico_nome': svc.nome,
        'valor_servico': svc.valorBase,
      }, expand: kAdminExecExpand);
      if (!mounted) return;
      setState(() {
        _os = novo;
        _salvandoServico = false;
      });
      showClxToast(
        context,
        'Serviço "${svc.nome}" definido na OS.',
        type: ToastType.success,
      );
    } catch (err) {
      if (mounted) {
        setState(() => _salvandoServico = false);
        showClxToast(context, _whatsError(err), type: ToastType.error);
      }
    }
  }

  /// Persiste o desconto (R$) — campo liberado ao Painel; abatido no total.
  Future<void> _salvarDescontos(double valor) async {
    if (_salvandoDesc || valor == _os.descontos) return;
    setState(() => _salvandoDesc = true);
    try {
      final novo = await ref.read(ordensRepositoryProvider).update(_os.id, {
        'descontos': valor,
      }, expand: kAdminExecExpand);
      if (!mounted) return;
      setState(() {
        _os = novo;
        _salvandoDesc = false;
      });
      showClxToast(context, 'Desconto atualizado.', type: ToastType.success);
    } catch (err) {
      if (mounted) {
        setState(() => _salvandoDesc = false);
        showClxToast(context, _whatsError(err), type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final os = _os;
    final semSnapshot = os.serviceSnapshot == null;

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        _headerCard(clx),
        const SizedBox(height: ClxSpace.x3),

        // Snapshot do serviço — ou seletor quando a OS ainda não tem serviço.
        if (os.serviceSnapshot != null)
          SnapshotResumo(snapshot: os.serviceSnapshot!)
        else
          _seletorServico(clx),
        const SizedBox(height: ClxSpace.x3),

        // Checklist (LEITURA — o Painel não edita a execução do profissional).
        if (os.checklistExec.isNotEmpty) ...[
          _checklistProgresso(clx),
          const SizedBox(height: ClxSpace.x2),
        ],
        AbsorbPointer(
          child: ChecklistExecucao(
            items: os.checklistExec,
            adicionais: os.adicionais,
            fotos: const [], // painel admin: thumbs via seção de evidências
            onChange: (_) {},
            concluidoPor:
                os.expand?.profissional?.displayName ?? 'Profissional',
          ),
        ),
        const SizedBox(height: ClxSpace.x3),

        // Adicionais.
        _adicionaisCard(clx),
        const SizedBox(height: ClxSpace.x3),

        // Observações do profissional.
        _observacoesCard(clx),
        const SizedBox(height: ClxSpace.x3),

        // Evidências (LEITURA) — sem Durante; se o checklist cobre antes/depois
        // e não há fotos soltas, a seção some (thumbs ficam no checklist).
        Builder(
          builder: (context) {
            final fasesEv = fasesEvidenciaSemChecklist(os.checklistExec);
            // Em leitura, ainda mostra fase se houver foto legada nela.
            final fases = <FaseFoto>[
              for (final f in [FaseFoto.antes, FaseFoto.depois])
                if (fasesEv.contains(f) ||
                    widget.data.evidencias.any((e) => e.fase == f))
                  f,
            ];
            if (fases.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                ClxCard(
                  child: AbsorbPointer(
                    child: EvidenciasSection(
                      fotos: widget.data.evidencias,
                      fases: fases,
                      onPick: (_) {},
                      onRemove: (_) {},
                      onLegenda: (_, __) {},
                      disabled: true,
                    ),
                  ),
                ),
                const SizedBox(height: ClxSpace.x3),
              ],
            );
          },
        ),

        // Resumo financeiro.
        _financeiroCard(clx),
        const SizedBox(height: ClxSpace.x3),

        // Ações do laudo.
        ClxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Laudo do serviço',
                style: tt.titleSmall?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ClxSpace.x1),
              Text(
                semSnapshot
                    ? 'Defina o serviço da OS para habilitar o laudo.'
                    : 'Pré-visualize/gere o PDF ou envie o relatório ao cliente.',
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
              ),
              const SizedBox(height: ClxSpace.x3),
              Wrap(
                spacing: ClxSpace.x3,
                runSpacing: ClxSpace.x2,
                children: [
                  ClxButton(
                    label: 'Gerar laudo (PDF)',
                    icon: Icons.picture_as_pdf_outlined,
                    variant: ClxButtonVariant.ghost,
                    onPressed: semSnapshot ? null : _gerarLaudo,
                  ),
                  ClxButton(
                    label: 'Enviar ao cliente',
                    icon: Icons.send_rounded,
                    loading: _enviando,
                    onPressed: semSnapshot || _enviando
                        ? null
                        : _enviarRelatorio,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x8),
      ],
    );
  }

  Widget _headerCard(CleanoxColors clx) {
    final os = _os;
    final cliente = os.expand?.cliente;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cliente == null
                ? (os.clienteNomeExibicao.isEmpty ? 'Cliente' : os.clienteNomeExibicao)
                : [
                    cliente.nome,
                    cliente.sobrenome,
                  ].where((s) => (s ?? '').isNotEmpty).join(' '),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          Wrap(
            spacing: ClxSpace.x4,
            runSpacing: ClxSpace.x1,
            children: [
              _meta(clx, Icons.event_outlined, formatDateTime(os.dataHora)),
              if (os.tipoServicoNome != null)
                _meta(
                  clx,
                  Icons.cleaning_services_outlined,
                  os.tipoServicoNome!,
                ),
              if (os.expand?.profissional != null)
                _meta(
                  clx,
                  Icons.badge_outlined,
                  os.expand!.profissional!.displayName,
                ),
            ],
          ),
          // PII do cliente — só o Painel (admin/gerente) vê.
          if (cliente != null) ...[
            const SizedBox(height: ClxSpace.x3),
            Container(
              padding: const EdgeInsets.all(ClxSpace.x3),
              decoration: BoxDecoration(
                color: clx.bg2,
                borderRadius: ClxRadii.rMd,
                border: Border.all(color: clx.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cliente.telefone.isNotEmpty)
                    _infoRow(
                      clx,
                      Icons.phone_outlined,
                      maskPhoneBR(cliente.telefone),
                    ),
                  if ((_enderecoCompleto(cliente) ?? '').isNotEmpty) ...[
                    const SizedBox(height: ClxSpace.x1),
                    _infoRow(
                      clx,
                      Icons.place_outlined,
                      _enderecoCompleto(cliente)!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _adicionaisCard(CleanoxColors clx) {
    final tt = Theme.of(context).textTheme;
    final adicionais = _os.adicionais;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Serviços adicionais',
            style: tt.titleSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          if (adicionais.isEmpty)
            Text(
              'Nenhum adicional registrado.',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            )
          else
            for (final a in adicionais)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.nome}${a.quantidade > 1 ? ' ×${a.quantidade}' : ''}',
                            style: tt.bodyLarge?.copyWith(color: clx.ink),
                          ),
                          Text(
                            aprovacaoLabel(a.aprovacao),
                            style: tt.bodySmall?.copyWith(color: clx.ink3),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(a.valor * a.quantidade),
                      style: tt.bodyLarge?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _observacoesCard(CleanoxColors clx) {
    final tt = Theme.of(context).textTheme;
    final obs = _os.observacoesProf;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Observações do profissional',
            style: tt.titleSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          if (obs.isEmpty)
            Text(
              'Nenhuma observação registrada.',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            )
          else
            for (final o in obs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      o.visivelCliente
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color: o.visivelCliente ? clx.primary : clx.ink3,
                    ),
                    const SizedBox(width: ClxSpace.x2),
                    Expanded(
                      child: Text(
                        o.texto,
                        style: tt.bodyLarge?.copyWith(color: clx.ink2),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _financeiroCard(CleanoxColors clx) {
    final tt = Theme.of(context).textTheme;
    final os = _os;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resumo financeiro',
            style: tt.titleSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          _linha(
            clx,
            (os.tipoServicoNome ?? '').trim().isEmpty
                ? 'Serviço principal'
                : os.tipoServicoNome!,
            formatCurrency(os.valorServico ?? 0),
          ),
          for (final a in adicionaisCobraveis(os))
            _linha(
              clx,
              a.nome.isEmpty
                  ? 'Serviço extra'
                  : 'Extra: ${a.nome}${a.quantidade > 1 ? ' ×${a.quantidade}' : ''}',
              formatCurrency(a.valor * a.quantidade),
            ),
          // Desconto EDITÁVEL (campo liberado ao Painel) — espelha o input do React.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '− Descontos (R\$)',
                    style: tt.bodyLarge?.copyWith(color: clx.ink2),
                  ),
                ),
                if (_salvandoDesc) ...[
                  const Spinner(size: 14),
                  const SizedBox(width: ClxSpace.x2),
                ],
                _DescontosField(
                  key: ValueKey(os.id),
                  valor: os.descontos,
                  enabled: !_salvandoDesc,
                  onSubmit: _salvarDescontos,
                ),
              ],
            ),
          ),
          Divider(height: ClxSpace.x5, color: clx.line),
          _linha(clx, 'Valor total da OS', formatCurrency(os.valorTotal), strong: true),
          if (os.valorPago != null)
            _linha(
              clx,
              'Valor pago (movimentação)',
              formatCurrency(os.valorPago!),
              strong: true,
            ),
        ],
      ),
    );
  }

  Widget _linha(
    CleanoxColors clx,
    String label,
    String value, {
    bool strong = false,
  }) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: (strong ? tt.titleSmall : tt.bodyLarge)?.copyWith(
                color: strong ? clx.ink : clx.ink2,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: (strong ? tt.titleMedium : tt.bodyLarge)?.copyWith(
              color: clx.ink,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Progresso do checklist de execução (X de Y itens concluídos + barra).
  Widget _checklistProgresso(CleanoxColors clx) {
    final total = _os.checklistExec.length;
    final feitos = _os.checklistExec
        .where((i) => i.status == ChecklistExecStatus.concluido)
        .length;
    final frac = total == 0 ? 0.0 : feitos / total;
    return Row(
      children: [
        Icon(Icons.checklist_rounded, size: 16, color: clx.ink3),
        const SizedBox(width: ClxSpace.x2),
        Text(
          '$feitos de $total itens concluídos',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: clx.ink2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ClxSpace.x3),
        Expanded(
          child: ClipRRect(
            borderRadius: ClxRadii.rPill,
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: clx.line,
              color: clx.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Seletor de serviço para OS SEM serviço definido. Ao escolher, grava o
  /// relation e o servidor congela o snapshot + checklist (fillServiceSnapshot).
  Widget _seletorServico(CleanoxColors clx) {
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(execServicosProvider);
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Serviço principal',
            style: tt.titleSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          Text(
            'Esta OS ainda não tem serviço. Selecione o serviço do catálogo '
            'para capturar o snapshot e gerar o checklist.',
            style: tt.bodyMedium?.copyWith(color: clx.ink3, height: 1.4),
          ),
          const SizedBox(height: ClxSpace.x3),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: ClxSpace.x2),
              child: Spinner(size: 20),
            ),
            error: (_, __) => ErrorBanner(
              message: 'Não foi possível carregar o catálogo de serviços.',
              onRetry: () => ref.invalidate(execServicosProvider),
            ),
            data: (servicos) {
              if (servicos.isEmpty) {
                return Text(
                  'Nenhum serviço ativo no catálogo.',
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                );
              }
              final ordenados = [...servicos]
                ..sort((a, b) => a.nome.toLowerCase().compareTo(
                      b.nome.toLowerCase(),
                    ));
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ServicoPB>(
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      hint: const Text('Selecione o serviço…'),
                      items: [
                        for (final s in ordenados)
                          DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.nome} — ${formatValorServico(s)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _salvandoServico
                          ? null
                          : (s) => s == null ? null : _selecionarServico(s),
                    ),
                  ),
                  if (_salvandoServico) ...[
                    const SizedBox(width: ClxSpace.x3),
                    const Spinner(size: 18),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Item curto p/ Wrap (largura não-limitada): sem Flexible.
  Widget _meta(CleanoxColors clx, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: clx.ink3),
        const SizedBox(width: ClxSpace.x1),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: clx.ink2),
        ),
      ],
    );
  }

  /// Linha de info em contexto de largura limitada (Column): pode quebrar/elipsar.
  Widget _infoRow(CleanoxColors clx, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: clx.ink3),
        const SizedBox(width: ClxSpace.x2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: clx.ink2),
          ),
        ),
      ],
    );
  }
}

/// Mensagem do erro da rota de relatório: prioriza o `error` do corpo (409 das
/// rotas custom), caindo em `describeOSError`. Local ao Painel (não importa a
/// camada do profissional).
String _whatsError(Object? err) {
  if (err is ClientException) {
    final e = err.response['error'];
    if (e is String && e.isNotEmpty) return e;
  }
  return describeOSError(err).message;
}

/// Campo compacto de desconto (R$) — persiste ao concluir a edição (submit/blur),
/// espelhando o input de descontos do resumo financeiro do `OSExecucaoPage.tsx`.
class _DescontosField extends StatefulWidget {
  const _DescontosField({
    super.key,
    required this.valor,
    required this.onSubmit,
    this.enabled = true,
  });

  final double valor;
  final ValueChanged<double> onSubmit;
  final bool enabled;

  @override
  State<_DescontosField> createState() => _DescontosFieldState();
}

class _DescontosFieldState extends State<_DescontosField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.valor));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  static String _fmt(double v) => v <= 0 ? '' : v.toStringAsFixed(2);

  double _parse() {
    final raw = _ctrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(raw) ?? 0;
    return v < 0 ? 0 : v;
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _submit();
  }

  void _submit() {
    widget.onSubmit(_parse());
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return SizedBox(
      width: 120,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink),
        decoration: const InputDecoration(
          isDense: true,
          prefixText: r'R$ ',
          hintText: '0,00',
        ),
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
