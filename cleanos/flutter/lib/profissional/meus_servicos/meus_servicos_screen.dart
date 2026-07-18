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
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/repositories/whatsapp_repository.dart';
import '../data/prof_providers.dart';
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
  final Map<String, bool> _contatoLoading = {};

  MeusServicosController get _ctrl => ref.read(meusServicosProvider.notifier);

  void _setLoading(String id, bool v) => setState(() => _actionLoading[id] = v);
  void _setError(String id, String? v) => setState(() => _actionError[id] = v);

  Future<void> _iniciar(OrdemServico os) async {
    _setLoading(os.id, true);
    _setError(os.id, null);
    try {
      await _ctrl.iniciar(os);
      if (!mounted) return;
      _toast(
        'Serviço iniciado! Preencha o checklist e o pagamento.',
        ToastType.success,
      );
      // Fluxo pedido pelo dono: Iniciar → tela de execução (checklist/pagamento).
      _abrirExecucao(os);
    } catch (err) {
      final msg = describeOSError(err).message;
      _setError(os.id, msg);
      _toast(msg, ToastType.error);
    } finally {
      _setLoading(os.id, false);
    }
  }

  Future<void> _whatsAppCliente(OrdemServico os) async {
    setState(() => _contatoLoading[os.id] = true);
    try {
      final WhatsAppRepository wa = ref.read(whatsappRepositoryProvider);
      final res = await wa.contatoCliente(os.id);
      final uri = Uri.tryParse(res.waUrl);
      if (uri == null) {
        _toast('Link de WhatsApp inválido.', ToastType.error);
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _toast('Não foi possível abrir o WhatsApp.', ToastType.error);
      }
    } catch (err) {
      _toast(describeOSError(err).message, ToastType.error);
    } finally {
      if (mounted) setState(() => _contatoLoading[os.id] = false);
    }
  }

  Future<void> _avisar(OrdemServico os) async {
    setState(() => _avisoLoading[os.id] = true);
    try {
      final res = await _ctrl.avisarACaminho(os);
      if (res.ok) {
        _toast(
          'Cliente avisado: você está a caminho ✓',
          ToastType.success,
        );
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
      onSubmit: (valor, forma, outro) async {
        await _ctrl.registrarPagamento(
          os,
          valor: valor,
          forma: forma,
          outro: outro,
        );
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

  Widget _card(OrdemServico os, {int index = 0}) => ClxFadeSlide(
    delay: Duration(milliseconds: (index % 6) * 40),
    child: OSCard(
      os: os,
      onIniciar: () => _iniciar(os),
      onAvisar: () => _avisar(os),
      onPagar: () => _pagar(os),
      onConcluir: () => _concluir(os),
      onChecklist: () => _abrirExecucao(os),
      onWhatsAppCliente: () => _whatsAppCliente(os),
      actionLoading: _actionLoading[os.id] ?? false,
      actionError: _actionError[os.id],
      avisoLoading: _avisoLoading[os.id] ?? false,
      contatoLoading: _contatoLoading[os.id] ?? false,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final state = ref.watch(meusServicosProvider);
    final hoje = DateTime.now();
    final diaLabel = _capitalize(_weekdayLabel(hoje));
    final countHoje = state.today.length;

    // Cabeçalho global (saudação + avatar) fica no [ProfShell].
    // Aqui só o resumo do dia + refresh.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: clx.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  countHoje == 1
                      ? '1 serviço hoje'
                      : '$countHoje serviços hoje',
                  style: TextStyle(
                    color: clx.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: state.loading ? null : _ctrl.refresh,
                icon: state.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: clx.primary,
                        ),
                      )
                    : Icon(Icons.refresh_rounded, color: clx.ink2),
              ),
            ],
          ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: clx.ink3),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
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
          for (var i = 0; i < state.pastOpen.length; i++)
            _card(state.pastOpen[i], index: i),
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
                  color: clx.primary2,
                )
              : null,
        ),
        const SizedBox(height: ClxSpace.x3),
        if (state.today.isEmpty)
          const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nenhum serviço hoje',
            message: 'Você não tem serviços agendados para hoje.',
          )
        else
          for (var i = 0; i < state.today.length; i++)
            _card(state.today[i], index: i),

        // Próximos — agrupados por dia BRT (mais próximo → mais distante).
        if (state.upcoming.isNotEmpty) ...[
          const SizedBox(height: ClxSpace.x5),
          Divider(color: clx.line),
          const SizedBox(height: ClxSpace.x3),
          _SectionHeader(
            title: 'Próximos agendamentos',
            titleColor: clx.ink,
            trailing: ClxChip(
              label:
                  '${state.upcoming.length} serviço${state.upcoming.length != 1 ? 's' : ''}',
              color: clx.ink3,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          ..._buildUpcomingByDay(state.upcoming),
        ],
        const SizedBox(height: ClxSpace.x8),
      ],
    );
  }

  /// Cards de "próximos" com separador de dia (lista já vem por `data_hora`).
  List<Widget> _buildUpcomingByDay(List<OrdemServico> upcoming) {
    final groups = groupOrdensByDayBrt(upcoming);
    final out = <Widget>[];
    var cardIndex = 0;
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      out.add(
        _DayGroupHeader(
          label: group.header,
          count: group.items.length,
          first: g == 0,
        ),
      );
      for (final os in group.items) {
        out.add(_card(os, index: cardIndex++));
      }
    }
    return out;
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

/// Agrupa OS já ordenadas por `data_hora` em blocos por dia civil BRT
/// (mais próximo → mais distante). Função pura para teste.
List<({String header, List<OrdemServico> items})> groupOrdensByDayBrt(
  List<OrdemServico> ordens, {
  DateTime? now,
}) {
  final out = <({String header, List<OrdemServico> items})>[];
  String? lastDayKey;
  for (final os in ordens) {
    final key = formatDate(os.dataHora); // dd/MM/yyyy BRT
    if (key != lastDayKey) {
      out.add((
        header: formatDayHeaderBrt(os.dataHora, now: now),
        items: <OrdemServico>[os],
      ));
      lastDayKey = key;
    } else {
      out.last.items.add(os);
    }
  }
  return out;
}

/// Separador de dia nos próximos (ex.: "Amanhã · 19/07").
class _DayGroupHeader extends StatelessWidget {
  const _DayGroupHeader({
    required this.label,
    required this.count,
    this.first = false,
  });

  final String label;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : ClxSpace.x4,
        bottom: ClxSpace.x2,
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 15, color: clx.ink3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: clx.ink2,
              ),
            ),
          ),
          Text(
            count == 1 ? '1 serviço' : '$count serviços',
            style: tt.labelSmall?.copyWith(color: clx.ink3),
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
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleSmall?.copyWith(
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: tt.bodySmall?.copyWith(color: clx.ink3),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
