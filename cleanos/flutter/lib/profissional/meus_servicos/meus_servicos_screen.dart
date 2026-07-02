/// meus_servicos_screen.dart — Tela "Meus serviços" (Slice B1).
///
/// Espelha `MeusServicos.tsx`: seções Em aberto (atrasado) / Hoje / Próximos,
/// pull-to-refresh, realtime, toasts e estados vazio/erro/offline (com banner
/// "dados de HH:MM" quando há cache mas a rede caiu). Ações delegadas ao
/// [MeusServicosController]; a navegação/execução abre a [OSExecucaoScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../data/server_error.dart';
import 'meus_servicos_controller.dart';
import 'os_card.dart';
import 'pagamento_modal.dart';

class MeusServicosScreen extends ConsumerStatefulWidget {
  const MeusServicosScreen({super.key});

  @override
  ConsumerState<MeusServicosScreen> createState() => _MeusServicosScreenState();
}

class _MeusServicosScreenState extends ConsumerState<MeusServicosScreen> {
  final Map<String, bool> _actionLoading = {};
  final Map<String, String?> _actionError = {};
  final Map<String, bool> _avisoLoading = {};

  MeusServicosController get _ctrl => ref.read(meusServicosProvider.notifier);

  void _setLoading(String id, bool v) => setState(() => _actionLoading[id] = v);
  void _setError(String id, String? v) => setState(() => _actionError[id] = v);

  Future<void> _iniciar(OrdemServico os) async {
    _setLoading(os.id, true);
    _setError(os.id, null);
    try {
      await _ctrl.iniciar(os);
      _toast('Serviço iniciado! Endereço liberado.', ToastType.success);
    } catch (err) {
      final msg = describeOSError(err).message;
      _setError(os.id, msg);
      _toast(msg, ToastType.error);
    } finally {
      _setLoading(os.id, false);
    }
  }

  Future<void> _avisar(OrdemServico os) async {
    setState(() => _avisoLoading[os.id] = true);
    try {
      final res = await _ctrl.avisarACaminho(os);
      if (res.ok) {
        _toast('Cliente avisado pela Cleanox ✓', ToastType.success);
      } else {
        _toast('Não foi possível avisar o cliente.', ToastType.error);
      }
    } catch (err) {
      final info = describeOSError(err);
      // Espelha o handleAvisar de MeusServicos.tsx: 409 (WhatsApp da empresa não
      // conectado) e 403 (não autorizado) têm mensagens fixas; demais caem no
      // `{error}` do corpo do backend.
      final String msg;
      if (err is ClientException && err.statusCode == 409) {
        msg = 'WhatsApp da empresa não está conectado. Avise o administrador.';
      } else if (info.isPermission) {
        msg = 'Ação não autorizada para este serviço.';
      } else {
        msg = serverErrorMessage(err);
      }
      _toast(msg, ToastType.error);
    } finally {
      if (mounted) setState(() => _avisoLoading[os.id] = false);
    }
  }

  Future<void> _pagar(OrdemServico os) async {
    await showPagamentoModal(
      context,
      os: os,
      onSubmit: (valor, forma) async {
        await _ctrl.registrarPagamento(os, valor: valor, forma: forma);
        if (mounted) {
          _toast(
            'Pagamento registrado. Agora você pode concluir o serviço.',
            ToastType.success,
          );
        }
      },
    );
  }

  Future<void> _concluir(OrdemServico os) async {
    if (!((os.valorPago ?? 0) > 0 && os.formaPagamento != null)) {
      _toast('Registre o pagamento antes de concluir.', ToastType.error);
      return;
    }
    _setLoading(os.id, true);
    _setError(os.id, null);
    try {
      final res = await _ctrl.concluir(os);
      if (res == ConcluirResultado.checklistPendente) {
        _abrirExecucao(os, obrigatoriosPendentes: true);
        return;
      }
      _toast('Serviço concluído!', ToastType.success);
    } catch (err) {
      final msg = describeOSError(err).message;
      _setError(os.id, msg);
      _toast(msg, ToastType.error);
    } finally {
      _setLoading(os.id, false);
    }
  }

  void _abrirExecucao(OrdemServico os, {bool obrigatoriosPendentes = false}) {
    // Rota deep-linkável `/app/os/:osId` (tela cheia no navigator raiz). É a
    // mesma que o push "Nova OS" abre. `?pendentes=1` destaca os obrigatórios.
    final q = obrigatoriosPendentes ? '?pendentes=1' : '';
    context.push('/app/os/${os.id}$q');
  }

  void _toast(String msg, ToastType type) {
    if (mounted) showClxToast(context, msg, type: type);
  }

  OSCard _card(OrdemServico os) => OSCard(
    os: os,
    onIniciar: () => _iniciar(os),
    onAvisar: () => _avisar(os),
    onPagar: () => _pagar(os),
    onConcluir: () => _concluir(os),
    onChecklist: () => _abrirExecucao(os),
    actionLoading: _actionLoading[os.id] ?? false,
    actionError: _actionError[os.id],
    avisoLoading: _avisoLoading[os.id] ?? false,
  );

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final state = ref.watch(meusServicosProvider);
    final hoje = DateTime.now();
    final diaLabel = _capitalize(_weekdayLabel(hoje));

    return Column(
      children: [
        _Header(
          onRefresh: state.loading ? null : _ctrl.refresh,
          loading: state.loading,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _ctrl.refresh,
            color: clx.primary,
            child: _body(context, state, diaLabel),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, MeusServicosState state, String diaLabel) {
    final clx = context.clx;

    if (state.loading && state.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                const Spinner(size: 26),
                const SizedBox(height: ClxSpace.x3),
                Text(
                  'Carregando seus serviços…',
                  style: TextStyle(color: clx.ink3, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        // Banner de erro / offline (com cache "dados de HH:MM").
        if (state.error != null) ...[
          ErrorBanner(message: state.error!, onRetry: _ctrl.refresh),
          const SizedBox(height: ClxSpace.x4),
        ],
        if (state.offline && state.lastLoadedAt != null && !state.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: ClxSpace.x3),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 15, color: clx.ink3),
                const SizedBox(width: ClxSpace.x1),
                Text(
                  'Sem conexão — dados de ${formatHour(state.lastLoadedAt!.toUtc().toIso8601String())}',
                  style: TextStyle(color: clx.ink3, fontSize: 12.5),
                ),
              ],
            ),
          ),

        // Em aberto (atrasado).
        if (state.pastOpen.isNotEmpty) ...[
          _SectionHeader(
            title: 'Em aberto (atrasado)',
            subtitle: 'Serviços de dias anteriores aguardando conclusão',
            titleColor: clx.warning,
            trailing: ClxChip(
              label:
                  '${state.pastOpen.length} pendente${state.pastOpen.length != 1 ? 's' : ''}',
              color: clx.warning,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          for (final os in state.pastOpen) _card(os),
          const SizedBox(height: ClxSpace.x5),
        ],

        // Hoje.
        _SectionHeader(
          title: 'Hoje',
          subtitle: diaLabel,
          titleColor: clx.ink,
          trailing: state.today.isNotEmpty
              ? ClxChip(
                  label:
                      '${state.today.length} serviço${state.today.length != 1 ? 's' : ''}',
                  color: clx.primary,
                )
              : null,
        ),
        const SizedBox(height: ClxSpace.x3),
        if (state.today.isEmpty)
          EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nenhum serviço hoje',
            message: 'Você não tem serviços agendados para hoje.',
          )
        else
          for (final os in state.today) _card(os),

        // Próximos.
        if (state.upcoming.isNotEmpty) ...[
          const SizedBox(height: ClxSpace.x5),
          Divider(color: clx.line),
          const SizedBox(height: ClxSpace.x3),
          _SectionHeader(title: 'Próximos agendamentos', titleColor: clx.ink),
          const SizedBox(height: ClxSpace.x3),
          for (final os in state.upcoming) _card(os),
        ],
        const SizedBox(height: ClxSpace.x8),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _weekdayLabel(DateTime d) {
    const dias = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo',
    ];
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${dias[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, required this.loading});

  final VoidCallback? onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x4,
        ClxSpace.x3,
        ClxSpace.x2,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        color: clx.bg,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Meus serviços',
              style: TextStyle(
                color: clx.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: onRefresh,
            icon: loading
                ? const Spinner(size: 18)
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.titleColor,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Color titleColor;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: clx.ink3, fontSize: 12),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
