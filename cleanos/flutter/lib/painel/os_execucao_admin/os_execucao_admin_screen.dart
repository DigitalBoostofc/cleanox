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

import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/cliente.dart';
import '../../core/models/ordem_servico.dart';
import '../../shared_widgets_os/shared_widgets_os.dart';
import '../data/painel_providers.dart';
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
                child: StatusBadge(status: d.os.status, dense: true),
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

  OrdemServico get _os => widget.data.os;

  /// Monta o laudo pronto p/ pré-visualizar/PDF (admin inclui dados do cliente).
  RelatorioOS? _montarLaudo() {
    final snap = _os.serviceSnapshot;
    if (snap == null) return null;
    final cliente = _os.expand?.cliente;
    final clienteNome = cliente == null
        ? (_os.nomeCurto.isEmpty ? 'Cliente' : _os.nomeCurto)
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

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final os = _os;
    final semSnapshot = os.serviceSnapshot == null;

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        _headerCard(clx),
        const SizedBox(height: ClxSpace.x3),

        // Snapshot do serviço.
        if (os.serviceSnapshot != null)
          SnapshotResumo(snapshot: os.serviceSnapshot!)
        else
          _placeholder(
            clx,
            'Serviço não definido',
            'A OS ainda não tem um serviço/snapshot capturado.',
          ),
        const SizedBox(height: ClxSpace.x3),

        // Checklist (LEITURA — o Painel não edita a execução do profissional).
        AbsorbPointer(
          child: ChecklistExecucao(
            items: os.checklistExec,
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

        // Evidências (LEITURA).
        ClxCard(
          child: AbsorbPointer(
            child: EvidenciasSection(
              fotos: widget.data.evidencias,
              onPick: (_) {},
              onRemove: (_) {},
              onLegenda: (_, __) {},
              disabled: true,
            ),
          ),
        ),
        const SizedBox(height: ClxSpace.x3),

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
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ClxSpace.x1),
              Text(
                semSnapshot
                    ? 'Defina o serviço da OS para habilitar o laudo.'
                    : 'Pré-visualize/gere o PDF ou envie o relatório ao cliente.',
                style: TextStyle(color: clx.ink3, fontSize: 13),
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
                ? (os.nomeCurto.isEmpty ? 'Cliente' : os.nomeCurto)
                : [
                    cliente.nome,
                    cliente.sobrenome,
                  ].where((s) => (s ?? '').isNotEmpty).join(' '),
            style: TextStyle(
              color: clx.ink,
              fontSize: 16,
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
    final adicionais = _os.adicionais;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Serviços adicionais',
            style: TextStyle(
              color: clx.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          if (adicionais.isEmpty)
            Text(
              'Nenhum adicional registrado.',
              style: TextStyle(color: clx.ink3, fontSize: 13),
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
                            style: TextStyle(color: clx.ink, fontSize: 14),
                          ),
                          Text(
                            aprovacaoLabel(a.aprovacao),
                            style: TextStyle(color: clx.ink3, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(a.valor * a.quantidade),
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 14,
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
    final obs = _os.observacoesProf;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Observações do profissional',
            style: TextStyle(
              color: clx.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          if (obs.isEmpty)
            Text(
              'Nenhuma observação registrada.',
              style: TextStyle(color: clx.ink3, fontSize: 13),
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
                        style: TextStyle(color: clx.ink2, fontSize: 13.5),
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
    final os = _os;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resumo financeiro',
            style: TextStyle(
              color: clx.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          _linha(clx, 'Valor do serviço', formatCurrency(os.valorServico ?? 0)),
          if (os.descontos > 0)
            _linha(clx, 'Descontos', '- ${formatCurrency(os.descontos)}'),
          if (os.valorPago != null)
            _linha(clx, 'Valor pago', formatCurrency(os.valorPago!)),
          Divider(height: ClxSpace.x5, color: clx.line),
          _linha(clx, 'Total', formatCurrency(os.valorTotal), strong: true),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? clx.ink : clx.ink2,
                fontSize: strong ? 15 : 14,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: clx.ink,
              fontSize: strong ? 16 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(CleanoxColors clx, String title, String msg) {
    return ClxCard(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: clx.ink2,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: clx.ink3, fontSize: 13),
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
        Text(text, style: TextStyle(color: clx.ink2, fontSize: 13)),
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
          child: Text(text, style: TextStyle(color: clx.ink2, fontSize: 13)),
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
