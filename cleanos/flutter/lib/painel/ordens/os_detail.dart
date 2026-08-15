/// os_detail.dart — Detalhe (visualização) de uma Ordem de Serviço no Painel.
///
/// Espelha o modal "view" de `OrdensServico.tsx`: identificação, endereço liberado
/// (só em_andamento), profissional com REATRIBUIÇÃO (admin/gerente), financeiro e
/// avaliação. Ações: Execução, Editar, Cancelar; Excluir só se cancelada.
///
/// Mostrado via [showOSDetail]. Resolve um [OSDetailResult] dizendo ao caller se
/// algo mudou (recarregar a lista) e/ou se o usuário pediu para editar/executar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException;

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/cliente.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import '../../shared_widgets_os/cancelar_os_dialog.dart';
import '../../shared_widgets_os/os_financeiro_resumo.dart';
import 'ordens_controller.dart';
import 'os_atividade_panel.dart';
import 'os_rebaixar_confirm.dart';
import '../agenda/agenda_controller.dart';

enum OSDetailIntent { editar, execucao }

/// Rua + número do cliente para o detalhe da OS (Painel / expand cliente).
///
/// Público e puro para unit test — a UI só repassa `os.expand?.cliente`.
String formatOsRuaExibicao(Cliente? c) {
  if (c == null) return '—';
  final parts = <String>[
    if ((c.enderecoRua ?? '').trim().isNotEmpty) c.enderecoRua!.trim(),
    if ((c.enderecoNumero ?? '').trim().isNotEmpty) c.enderecoNumero!.trim(),
  ];
  if (parts.isEmpty) return '—';
  return parts.join(', ');
}

/// Cidade (+ UF) do cliente para o detalhe da OS.
String formatOsCidadeExibicao(Cliente? c) {
  if (c == null) return '—';
  final cidade = (c.enderecoCidade ?? '').trim();
  final uf = (c.enderecoEstado ?? '').trim();
  if (cidade.isEmpty && uf.isEmpty) return '—';
  if (cidade.isEmpty) return uf;
  if (uf.isEmpty) return cidade;
  return '$cidade — $uf';
}

/// Rua/cidade no detalhe respeitando ponto físico (se selecionado na OS).
String formatOsRuaDaOs(OrdemServico os) {
  if (os.isLocalPontoFisico) {
    final p = os.expand?.pontoFisico;
    if (p == null) return '—';
    final parts = <String>[
      if (p.enderecoRua.trim().isNotEmpty) p.enderecoRua.trim(),
      if (p.enderecoNumero.trim().isNotEmpty) p.enderecoNumero.trim(),
    ];
    if (parts.isEmpty) return p.nome.isEmpty ? '—' : p.nome;
    final rua = parts.join(', ');
    return p.nome.isEmpty ? rua : '${p.nome} · $rua';
  }
  return formatOsRuaExibicao(os.expand?.cliente);
}

String formatOsCidadeDaOs(OrdemServico os) {
  if (os.isLocalPontoFisico) {
    final p = os.expand?.pontoFisico;
    if (p == null) return '—';
    final cidade = p.enderecoCidade.trim();
    final uf = p.enderecoEstado.trim();
    if (cidade.isEmpty && uf.isEmpty) return '—';
    if (cidade.isEmpty) return uf;
    if (uf.isEmpty) return cidade;
    return '$cidade — $uf';
  }
  return formatOsCidadeExibicao(os.expand?.cliente);
}

String formatOsBairroDaOs(OrdemServico os) {
  if (os.isLocalPontoFisico) {
    final p = os.expand?.pontoFisico;
    final b = (p?.enderecoBairro ?? os.bairro).trim();
    return b.isEmpty ? '—' : b;
  }
  final b = os.bairro.trim();
  if (b.isNotEmpty) return b;
  final cb = (os.expand?.cliente?.enderecoBairro ?? '').trim();
  return cb.isEmpty ? '—' : cb;
}

class OSDetailResult {
  const OSDetailResult({this.changed = false, this.intent, this.os});
  final bool changed;
  final OSDetailIntent? intent;

  /// A OS COMO ELA ESTÁ AGORA — inclusive se o detalhe a reatribuiu enquanto
  /// estava aberto. O caller PRECISA usar esta e não o registro que ele passou
  /// para `showOSDetail`: aquele já pode estar velho, e abrir o form de edição
  /// com um registro velho foi o que gravou `status=atribuida` +
  /// `profissional=""` no banco (F-234).
  final OrdemServico? os;
}

/// Payload de reatribuição no detalhe da OS (solo | dupla).
///
/// Pure — unit-tested. `null` em relações = limpar no PB (hook normaliza solo).
@visibleForTesting
Map<String, dynamic> bodyReatribuicaoOs({
  required String profissionalId,
  required String profissional2Id,
  required ExecucaoModo modo,
}) {
  final isDupla = modo == ExecucaoModo.dupla &&
      profissionalId.isNotEmpty &&
      profissional2Id.isNotEmpty &&
      profissional2Id != profissionalId;
  return {
    'profissional': profissionalId.isEmpty ? null : profissionalId,
    'profissional2': isDupla ? profissional2Id : null,
    'execucao_modo':
        isDupla ? ExecucaoModo.dupla.wire : ExecucaoModo.solo.wire,
    'status': profissionalId.isEmpty
        ? OSStatus.agendada.wire
        : OSStatus.atribuida.wire,
  };
}

Future<OSDetailResult?> showOSDetail(BuildContext context, OrdemServico os) {
  final size = MediaQuery.sizeOf(context);
  // Desktop/tablet: modal largo estilo Trello (detalhes | comentários).
  // Mobile/estreito: coluna única (max ~560).
  final wide = size.width >= 720;
  final maxW = wide
      ? (size.width * 0.92).clamp(720.0, 960.0)
      : 560.0;
  final maxH = (size.height * 0.88).clamp(480.0, 820.0);
  return showDialog<OSDetailResult>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: wide ? ClxSpace.x6 : ClxSpace.x4,
        vertical: ClxSpace.x4,
      ),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: SizedBox(
          width: maxW,
          height: maxH,
          child: OSDetail(os: os),
        ),
      ),
    ),
  );
}

class OSDetail extends ConsumerStatefulWidget {
  const OSDetail({super.key, required this.os});

  final OrdemServico os;

  @override
  ConsumerState<OSDetail> createState() => _OSDetailState();
}

class _OSDetailState extends ConsumerState<OSDetail> {
  late OrdemServico _os;
  bool _changed = false;

  String _selectedProf = '';
  String _selectedProf2 = '';
  ExecucaoModo _execucaoModo = ExecucaoModo.solo;
  bool _reatribuindo = false;
  String? _reatribuirError;

  @override
  void initState() {
    super.initState();
    _os = widget.os;
    _selectedProf = _os.profissional ?? '';
    _selectedProf2 = _os.profissional2 ?? '';
    _execucaoModo = _os.isDupla || _selectedProf2.isNotEmpty
        ? ExecucaoModo.dupla
        : ExecucaoModo.solo;
  }

  void _syncSelecaoFromOs(OrdemServico os) {
    _selectedProf = os.profissional ?? '';
    _selectedProf2 = os.profissional2 ?? '';
    _execucaoModo = os.isDupla || _selectedProf2.isNotEmpty
        ? ExecucaoModo.dupla
        : ExecucaoModo.solo;
  }

  /// OS ainda em curso (não finalizada). Reatribuição e cancelamento só nestas.
  bool get _aberta =>
      _os.status != OSStatus.concluida && _os.status != OSStatus.cancelada;

  /// Edição do formulário (serviço, valor, obs…): permitida também em
  /// **concluída** — correção pós-fechamento. Cancelada permanece bloqueada.
  /// Data/hora/duração de concluída ficam congeladas no form/servidor.
  bool get _editavel => _os.status != OSStatus.cancelada;

  /// Rua + número do cliente (cofre expandido). Painel only.
  String get _ruaExibicao => formatOsRuaDaOs(_os);

  /// Cidade (+ UF se houver) do cliente ou ponto.
  String get _cidadeExibicao => formatOsCidadeDaOs(_os);

  Future<void> _reatribuir() async {
    // Mexer no profissional de uma OS EM ANDAMENTO rebaixa o status, e o hook do
    // servidor apaga endereço liberado + GPS ao ver o status sair de
    // `em_andamento` (são efêmeros por design). Consequência legítima, mas o
    // admin tem que saber antes de confirmar (F-228).
    final removendo = _selectedProf.isEmpty &&
        (_execucaoModo != ExecucaoModo.dupla || _selectedProf2.isEmpty);
    if (_os.status == OSStatus.emAndamento) {
      final ok = await confirmarRebaixarEmAndamento(
        context,
        removendo: removendo,
      );
      if (ok != true) return;
      if (!mounted) return;
    }

    // Valida dupla antes do request.
    if (_execucaoModo == ExecucaoModo.dupla) {
      if (_selectedProf.isEmpty) {
        setState(() => _reatribuirError = 'Escolha o profissional principal.');
        return;
      }
      if (_selectedProf2.isEmpty) {
        setState(() => _reatribuirError = 'Escolha o 2º profissional da dupla.');
        return;
      }
      if (_selectedProf2 == _selectedProf) {
        setState(
          () => _reatribuirError =
              'A dupla precisa de dois profissionais diferentes.',
        );
        return;
      }
    }

    setState(() {
      _reatribuindo = true;
      _reatribuirError = null;
    });
    final OrdemServico novo;
    try {
      // expand: cofre cliente + os dois profissionais (título / nomes).
      novo = await ref.read(ordensRepositoryProvider).update(
            _os.id,
            bodyReatribuicaoOs(
              profissionalId: _selectedProf,
              profissional2Id: _selectedProf2,
              modo: _execucaoModo,
            ),
            expand: 'profissional,profissional2,cliente,ponto_fisico',
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _reatribuindo = false;
          _reatribuirError = e is ClientException
              ? _msgClientException(e) ??
                  'Não foi possível reatribuir. Tente novamente.'
              : 'Não foi possível reatribuir. Tente novamente.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _os = novo;
      _syncSelecaoFromOs(novo);
      _reatribuindo = false;
      _changed = true;
    });
    // Atualiza lista/contadores AQUI, no sucesso da ação — o refresh não pode
    // depender só do resultado do dialog (fechar pelo barrier devolve null).
    ref.invalidate(ordensCountsProvider);
    final toast = novo.profissional == null
        ? 'Profissional removido — OS voltou para Em agendamento.'
        : (novo.isDupla
            ? 'Dupla atribuída.'
            : 'Profissional atribuído.');
    showClxToast(context, toast, type: ToastType.success);
    // Agenda: recarrega a grade no lugar (mesmo dia/semana/mês aberto).
    await _refreshAgendaAposMutacao();

    final notifier = ref.read(ordensControllerProvider.notifier);
    final filtroAtivo = ref.read(ordensControllerProvider).filter.status;
    if (filtroAtivo != null && filtroAtivo != novo.status) {
      // A OS saiu da aba ativa (ex.: Agendada → Atribuída): leva a lista para
      // a aba onde ela está agora e fecha o detalhe.
      await notifier.setStatus(novo.status);
      if (!mounted) return;
      Navigator.of(context).pop(OSDetailResult(changed: true, os: novo));
    } else {
      await notifier.refresh();
      // Mantém `_changed = true` para se o usuário fechar o modal a Agenda
      // (e outros callers) ainda revalidem — barato e evita stale.
    }
  }

  String? _msgClientException(ClientException e) {
    final data = e.response;
    final details = data['data'];
    if (details is Map && details.isNotEmpty) {
      final parts = <String>[];
      details.forEach((_, v) {
        if (v is Map && v['message'] != null) parts.add('${v['message']}');
      });
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    final msg = (data['message'] as String?)?.trim();
    if (msg != null &&
        msg.isNotEmpty &&
        msg != 'Failed to update record.') {
      return msg;
    }
    return null;
  }

  /// Recarrega a agenda se o provider estiver ativo (usuário na tela Agenda).
  Future<void> _refreshAgendaAposMutacao() async {
    try {
      if (!ref.exists(agendaControllerProvider)) return;
      await ref.read(agendaControllerProvider.notifier).load();
    } catch (_) {
      /* agenda pode não estar montada / falha de rede — UI de Ordens ok */
    }
  }

  Future<void> _cancelar() async {
    final motivo = await showCancelarOsDialog(context, os: _os);
    if (motivo == null || motivo.isEmpty) return;
    try {
      await ref
          .read(ordensControllerProvider.notifier)
          .cancelar(_os.id, motivo: motivo);
      if (mounted) {
        Navigator.of(context).pop(const OSDetailResult(changed: true));
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível cancelar a OS.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _reabrir() async {
    if (_os.status != OSStatus.concluida) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir OS (Refazer)'),
        content: const Text(
          'Será criada uma NOVA OS em Em agendamento com a etiqueta Refazer, '
          'copiando cliente, serviço, data e observações. '
          'Valor e pagamento da cópia ficam zerados e sem profissional.\n\n'
          'A OS concluída original permanece intacta (histórico e financeiro).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Duplicar e reabrir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ordensControllerProvider.notifier).reabrir(_os.id);
      if (!mounted) return;
      ref.invalidate(ordensCountsProvider);
      showClxToast(
        context,
        'Nova OS criada em Em agendamento (Refazer). '
        'A concluída original foi mantida.',
        type: ToastType.success,
      );
      Navigator.of(context).pop(const OSDetailResult(changed: true));
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível reabrir a OS.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _excluir() async {
    // Só OS cancelada pode ser excluída (UI + hook server-side).
    if (_os.status != OSStatus.cancelada) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir OS'),
        content: const Text(
          'A OS cancelada e suas fotos de evidência serão excluídas '
          'definitivamente.\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir OS'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ordensControllerProvider.notifier).excluir(_os.id);
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível excluir a OS.',
          type: ToastType.error,
        );
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(ordensCountsProvider);
    showClxToast(context, 'OS excluída.', type: ToastType.success);
    Navigator.of(context).pop(const OSDetailResult(changed: true));
  }

  void _close([OSDetailIntent? intent]) {
    // Devolve `_os` — o registro ATUAL, já com a reatribuição feita aqui dentro.
    // Sem isso o caller reabria o form de edição com o registro velho (F-234).
    Navigator.of(
      context,
    ).pop(OSDetailResult(changed: _changed, intent: intent, os: _os));
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final lookups = ref.watch(ordensLookupsProvider);
    final profs = lookups.maybeWhen(
      data: (lk) => lk.profissionais,
      orElse: () => const <User>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x5,
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'OS — ${_os.clienteNomeExibicao.isEmpty ? "Cliente" : _os.clienteNomeExibicao}',
                  style: tt.titleMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusBadge(
                status: _os.status,
                dense: true,
                refazer: _os.refazer,
                vitrine: _os.isVitrine,
              ),
              const SizedBox(width: ClxSpace.x2),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: _close,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        // Corpo: desktop ≥720 → split Trello (detalhes | atividade);
        // estreito → coluna única com atividade no fim do scroll.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= 700;
              final details = _buildDetailsBody(clx, tt, profs);
              if (split) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(ClxSpace.x5),
                        child: details,
                      ),
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: clx.line),
                    Expanded(
                      flex: 4,
                      child: ColoredBox(
                        color: clx.bg2.withValues(alpha: 0.35),
                        child: OsAtividadePanel(
                          osId: _os.id,
                          sidePanel: true,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(ClxSpace.x5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: ClxSpace.x2),
                    OsAtividadePanel(osId: _os.id),
                  ],
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: clx.line),
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: ClxSpace.x2,
            runSpacing: ClxSpace.x2,
            children: [
              ClxButton(
                label: 'Execução',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => _close(OSDetailIntent.execucao),
              ),
              if (_editavel)
                ClxButton(
                  label: 'Editar OS',
                  variant: ClxButtonVariant.ghost,
                  icon: Icons.edit_outlined,
                  onPressed: () => _close(OSDetailIntent.editar),
                ),
              if (_aberta)
                ClxButton(
                  label: 'Cancelar OS',
                  variant: ClxButtonVariant.danger,
                  icon: Icons.cancel_outlined,
                  onPressed: _cancelar,
                ),
              if (_os.status == OSStatus.concluida)
                ClxButton(
                  label: 'Reabrir OS',
                  variant: ClxButtonVariant.secondary,
                  icon: Icons.replay_rounded,
                  onPressed: _reabrir,
                ),
              // Exclusão definitiva só em OS já cancelada (servidor também bloqueia).
              if (_os.status == OSStatus.cancelada)
                ClxButton(
                  label: 'Excluir OS',
                  variant: ClxButtonVariant.danger,
                  icon: Icons.delete_outline_rounded,
                  onPressed: _excluir,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Coluna esquerda (ou corpo único no mobile): seções da OS sem o feed.
  Widget _buildDetailsBody(
    CleanoxColors clx,
    TextTheme tt,
    List<User> profs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(clx, 'Identificação', [
          _row(clx, 'Cliente', _os.clienteNomeExibicao),
          _row(
            clx,
            'Local',
            _os.isLocalPontoFisico ? 'Ponto físico' : 'Endereço do cliente',
          ),
          // Rua/cidade: cofre do cliente OU ponto expandido (Painel).
          _row(clx, 'Rua', _ruaExibicao),
          _row(clx, 'Bairro', formatOsBairroDaOs(_os)),
          _row(clx, 'Cidade', _cidadeExibicao),
          _row(clx, 'Serviço', _os.tipoServicoNome ?? '—'),
          _row(clx, 'Data / Hora', formatDateTime(_os.dataHora)),
          if ((_os.observacoes ?? '').isNotEmpty)
            _row(clx, 'Observações', _os.observacoes!),
        ]),
        if (_os.status == OSStatus.cancelada)
          _section(clx, 'Cancelamento', [
            _row(
              clx,
              'Motivo',
              (_os.motivoCancelamento ?? '').trim().isEmpty
                  ? '—'
                  : _os.motivoCancelamento!,
            ),
            _row(
              clx,
              'Cancelado por',
              (_os.canceladoPorNome ?? '').trim().isEmpty
                  ? '—'
                  : _os.canceladoPorNome!,
            ),
            _row(
              clx,
              'Quando',
              (_os.canceladoEm ?? '').trim().isEmpty
                  ? '—'
                  : formatDateTime(_os.canceladoEm!),
            ),
          ]),
        if (_os.status == OSStatus.emAndamento &&
            (_os.enderecoLiberado ?? '').isNotEmpty)
          _section(clx, 'Endereço (liberado)', [
            Text(
              _os.enderecoLiberado!,
              style: tt.bodyLarge?.copyWith(color: clx.ink),
            ),
          ]),
        _profissionalSection(clx, profs),
        _section(clx, 'Financeiro', [
          _row(
            clx,
            'Orçamento inicial',
            _os.valorServico == null
                ? '—'
                : formatCurrency(_os.valorServico!),
          ),
          for (final a in adicionaisCobraveis(_os))
            _row(
              clx,
              a.nome.isEmpty
                  ? 'Serviço extra'
                  : 'Extra: ${a.nome}${a.quantidade > 1 ? ' ×${a.quantidade}' : ''}',
              formatCurrency(a.valor * a.quantidade),
            ),
          if (_os.descontos > 0)
            _row(clx, 'Descontos', '− ${formatCurrency(_os.descontos)}'),
          if (osMostraValorTotal(_os))
            _row(
              clx,
              'Valor total da OS',
              formatCurrency(_os.valorTotal),
            ),
          _row(
            clx,
            'Valor pago',
            _os.valorPago == null ? '—' : formatCurrency(_os.valorPago!),
          ),
          _row(
            clx,
            'Forma de pagamento',
            _os.formaPagamento?.label ?? '—',
          ),
        ]),
        if (_os.status == OSStatus.concluida) _avaliacaoSection(clx),
      ],
    );
  }

  Widget _profissionalSection(CleanoxColors clx, List<User> profs) {
    final prof = _os.expand?.profissional;
    final prof2 = _os.expand?.profissional2;
    final modoLabel = _os.isDupla ? 'Dupla' : 'Individual';
    final nomes = <String>[
      if (prof != null) prof.displayName,
      if (_os.isDupla && prof2 != null) prof2.displayName,
    ];
    return _section(clx, 'Profissional', [
      _row(clx, 'Forma', modoLabel),
      _row(
        clx,
        _os.isDupla ? 'Equipe' : 'Atribuído',
        nomes.isEmpty ? '—' : nomes.join(' + '),
      ),
      if (_aberta) ...[
        const SizedBox(height: ClxSpace.x2),
        Text(
          'Forma de prestação',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: clx.ink3,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<ExecucaoModo>(
          key: ValueKey('detail-execucao-$_execucaoModo'),
          initialValue: _execucaoModo,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final m in ExecucaoModo.all)
              DropdownMenuItem(value: m, child: Text(m.label)),
          ],
          onChanged: _reatribuindo
              ? null
              : (v) {
                  if (v == null) return;
                  setState(() {
                    _execucaoModo = v;
                    if (v == ExecucaoModo.solo) {
                      _selectedProf2 = '';
                    }
                    _reatribuirError = null;
                  });
                },
        ),
        if (_execucaoModo == ExecucaoModo.dupla)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Em dupla, a comissão de cada um é a metade '
              '(ex.: 30% → 15% para cada).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: clx.ink3,
                  ),
            ),
          ),
        const SizedBox(height: ClxSpace.x2),
        Text(
          _execucaoModo == ExecucaoModo.dupla
              ? 'Profissional principal'
              : 'Profissional',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: clx.ink3,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('detail-prof1-$_selectedProf'),
          initialValue: _selectedProf.isEmpty ? '' : _selectedProf,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('— Remover atribuição —'),
            ),
            for (final p in profs)
              DropdownMenuItem(
                value: p.id,
                child: Text(
                  p.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _reatribuindo
              ? null
              : (v) => setState(() {
                    _selectedProf = v ?? '';
                    if (_selectedProf2.isNotEmpty &&
                        _selectedProf2 == _selectedProf) {
                      _selectedProf2 = '';
                    }
                    _reatribuirError = null;
                  }),
        ),
        if (_execucaoModo == ExecucaoModo.dupla) ...[
          const SizedBox(height: ClxSpace.x2),
          Text(
            '2º profissional',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: clx.ink3,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('detail-prof2-$_selectedProf2'),
            initialValue: _selectedProf2.isEmpty ? null : _selectedProf2,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text('— Escolher parceiro —'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('— Escolher parceiro —'),
              ),
              for (final p in profs)
                if (p.id != _selectedProf)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: _reatribuindo
                ? null
                : (v) => setState(() {
                      _selectedProf2 = v ?? '';
                      _reatribuirError = null;
                    }),
          ),
        ],
        const SizedBox(height: ClxSpace.x2),
        Align(
          alignment: Alignment.centerLeft,
          child: ClxButton(
            label: 'Atribuir',
            icon: Icons.check_rounded,
            loading: _reatribuindo,
            onPressed: _reatribuindo ? null : _reatribuir,
          ),
        ),
        if (_reatribuirError != null) ...[
          const SizedBox(height: ClxSpace.x2),
          ErrorBanner(message: _reatribuirError!),
        ],
      ],
    ]);
  }

  /// Avaliação da OS concluída (estrelas + motivo + data). Espelha o bloco
  /// "Avaliação" do detalhe no React.
  Widget _avaliacaoSection(CleanoxColors clx) {
    final tt = Theme.of(context).textTheme;
    final nota = _os.avaliacaoNota;
    if (nota == null) {
      return _section(clx, 'Avaliação', [
        Text(
          'Avaliação pendente',
          style: tt.bodyLarge?.copyWith(color: clx.ink3),
        ),
      ]);
    }
    return _section(clx, 'Avaliação', [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                'Nota',
                style: tt.bodyMedium?.copyWith(
                  color: clx.ink3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: StarRating(value: nota, size: 18)),
          ],
        ),
      ),
      if ((_os.avaliacaoMotivo ?? '').isNotEmpty)
        _row(clx, 'Motivo', _os.avaliacaoMotivo!),
      if ((_os.avaliacaoEm ?? '').isNotEmpty)
        _row(clx, 'Data', formatDateTime(_os.avaliacaoEm!)),
    ]);
  }

  Widget _section(CleanoxColors clx, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: clx.ink3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          ...children,
        ],
      ),
    );
  }

  Widget _row(CleanoxColors clx, String label, String value) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: clx.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: tt.bodyLarge?.copyWith(color: clx.ink),
            ),
          ),
        ],
      ),
    );
  }
}
