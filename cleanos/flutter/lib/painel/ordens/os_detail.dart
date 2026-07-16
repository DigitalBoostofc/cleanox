/// os_detail.dart — Detalhe (visualização) de uma Ordem de Serviço no Painel.
///
/// Espelha o modal "view" de `OrdensServico.tsx`: identificação, endereço liberado
/// (só em_andamento), profissional com REATRIBUIÇÃO (admin/gerente), financeiro e
/// avaliação. Ações: abrir Execução (admin), Editar, Cancelar OS, Excluir OS.
///
/// Mostrado via [showOSDetail]. Resolve um [OSDetailResult] dizendo ao caller se
/// algo mudou (recarregar a lista) e/ou se o usuário pediu para editar/executar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import 'ordens_controller.dart';
import 'os_rebaixar_confirm.dart';

enum OSDetailIntent { editar, execucao }

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

Future<OSDetailResult?> showOSDetail(BuildContext context, OrdemServico os) {
  return showDialog<OSDetailResult>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: OSDetail(os: os),
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
  bool _reatribuindo = false;
  String? _reatribuirError;

  @override
  void initState() {
    super.initState();
    _os = widget.os;
    _selectedProf = _os.profissional ?? '';
  }

  bool get _aberta =>
      _os.status != OSStatus.concluida && _os.status != OSStatus.cancelada;

  Future<void> _reatribuir() async {
    // Mexer no profissional de uma OS EM ANDAMENTO rebaixa o status, e o hook do
    // servidor apaga endereço liberado + GPS ao ver o status sair de
    // `em_andamento` (são efêmeros por design). Consequência legítima, mas o
    // admin tem que saber antes de confirmar (F-228).
    if (_os.status == OSStatus.emAndamento) {
      final ok = await confirmarRebaixarEmAndamento(
        context,
        removendo: _selectedProf.isEmpty,
      );
      if (ok != true) return;
      if (!mounted) return;
    }
    setState(() {
      _reatribuindo = true;
      _reatribuirError = null;
    });
    final OrdemServico novo;
    try {
      // `cliente` no expand junto do `profissional`: o registro que volta daqui
      // substitui `_os`, e sem o cofre expandido o título do detalhe cairia de
      // "Carlos Silva" pra "Carlos S." logo depois de reatribuir.
      novo = await ref.read(ordensRepositoryProvider).update(_os.id, {
        'profissional': _selectedProf.isEmpty ? null : _selectedProf,
        'status': _selectedProf.isEmpty
            ? OSStatus.agendada.wire
            : OSStatus.atribuida.wire,
      }, expand: 'profissional,cliente');
    } catch (_) {
      if (mounted) {
        setState(() {
          _reatribuindo = false;
          _reatribuirError = 'Não foi possível reatribuir. Tente novamente.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _os = novo;
      _selectedProf = novo.profissional ?? '';
      _reatribuindo = false;
      _changed = true;
    });
    // Atualiza lista/contadores AQUI, no sucesso da ação — o refresh não pode
    // depender do resultado do dialog, porque fechar pelo barrier devolve null.
    ref.invalidate(ordensCountsProvider);
    showClxToast(
      context,
      novo.profissional == null
          ? 'Profissional removido — OS voltou para Agendada.'
          : 'Profissional atribuído.',
      type: ToastType.success,
    );
    final notifier = ref.read(ordensControllerProvider.notifier);
    final filtroAtivo = ref.read(ordensControllerProvider).filter.status;
    if (filtroAtivo != null && filtroAtivo != novo.status) {
      // A OS saiu da aba ativa (ex.: Agendada → Atribuída): leva a lista para
      // a aba onde ela está agora e fecha o detalhe.
      await notifier.setStatus(novo.status);
      if (!mounted) return;
      Navigator.of(context).pop(OSDetailResult(os: novo));
    } else {
      await notifier.refresh();
      _changed = false; // lista já recarregada; sem refresh duplicado no fechar
    }
  }

  Future<void> _cancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar OS'),
        content: const Text('Deseja cancelar esta ordem de serviço?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar OS'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ordensControllerProvider.notifier).cancelar(_os.id);
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

  Future<void> _excluir() async {
    // O aviso muda para OS concluída: ela tem dinheiro atrelado, e o hook do
    // servidor vai estornar receita (saldo) e apagar a comissão junto.
    final concluida = _os.status == OSStatus.concluida;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir OS'),
        content: Text(
          concluida
              ? 'Esta OS está concluída: a receita dela será removida do '
                    'financeiro (com estorno do saldo da conta) e a comissão '
                    'do profissional será apagada. As fotos de evidência '
                    'também serão excluídas.\n\n'
                    'Esta ação não pode ser desfeita.'
              : 'A OS e suas fotos de evidência serão excluídas.\n\n'
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
      mainAxisSize: MainAxisSize.min,
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
              StatusBadge(status: _os.status, dense: true),
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
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(clx, 'Identificação', [
                  _row(clx, 'Cliente', _os.clienteNomeExibicao),
                  _row(clx, 'Bairro', _os.bairro),
                  _row(clx, 'Serviço', _os.tipoServicoNome ?? '—'),
                  _row(clx, 'Data / Hora', formatDateTime(_os.dataHora)),
                  if ((_os.observacoes ?? '').isNotEmpty)
                    _row(clx, 'Observações', _os.observacoes!),
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
                    'Valor do serviço',
                    _os.valorServico == null
                        ? '—'
                        : formatCurrency(_os.valorServico!),
                  ),
                  _row(
                    clx,
                    'Valor pago',
                    _os.valorPago == null
                        ? '—'
                        : formatCurrency(_os.valorPago!),
                  ),
                  _row(
                    clx,
                    'Forma de pagamento',
                    _os.formaPagamento?.label ?? '—',
                  ),
                  _row(
                    clx,
                    'Repasse',
                    _repasseTexto(),
                  ),
                ]),
                if (_os.status == OSStatus.concluida) _avaliacaoSection(clx),
              ],
            ),
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
              if (_aberta)
                ClxButton(
                  label: 'Editar',
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

  Widget _profissionalSection(CleanoxColors clx, List<User> profs) {
    final prof = _os.expand?.profissional;
    return _section(clx, 'Profissional', [
      _row(clx, 'Atribuído', prof?.displayName ?? '—'),
      if (_aberta) ...[
        const SizedBox(height: ClxSpace.x2),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
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
                    : (v) => setState(() => _selectedProf = v ?? ''),
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            ClxButton(
              label: 'Atribuir',
              icon: Icons.check_rounded,
              loading: _reatribuindo,
              onPressed: _reatribuindo ? null : _reatribuir,
            ),
          ],
        ),
        if (_reatribuirError != null) ...[
          const SizedBox(height: ClxSpace.x2),
          ErrorBanner(message: _reatribuirError!),
        ],
      ],
    ]);
  }

  /// "Pendente · R$ x" / "Repassado · R$ x" / "—". Espelha o React (status + valor).
  String _repasseTexto() {
    final status = _os.repasseStatus?.label;
    final valor = _os.repasseValor;
    if (status == null) return '—';
    if (valor != null && valor > 0) {
      return '$status · ${formatCurrency(valor)}';
    }
    return status;
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
