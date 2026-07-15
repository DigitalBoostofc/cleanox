/// fin_visao_geral_screen.dart — Visão geral do Financeiro.
///
/// Espelha `VisaoGeral.tsx`: KPIs do mês (entradas/saídas/saldo do mês/saldo
/// geral) + AÇÕES RÁPIDAS (nova receita/despesa, transferência, importar) + bloco
/// de 3 colunas (contas a receber, contas a pagar, maiores gastos por categoria) +
/// bloco de 2 colunas (receitas por origem, limites de gasto). Agrega os
/// lançamentos do período (paginados) e os pendentes globais. Estados
/// carregando/erro/vazio/sucesso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/app_surface_provider.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'charts/fin_charts.dart';
import 'carteiras/transferencia_form.dart';
import 'fin_chips.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_labels.dart';
import 'fin_providers.dart';
import 'fintech/fintech_balance_hero.dart';
import 'lancamentos/lancamento_form.dart';

class FinVisaoGeralScreen extends ConsumerWidget {
  const FinVisaoGeralScreen({super.key});

  Future<void> _novoLancamento(
    BuildContext context,
    WidgetRef ref,
    TipoLancamento tipo,
  ) async {
    final saved = await showLancamentoForm(context, initialTipo: tipo);
    if (saved == true) {
      ref
        ..invalidate(finPeriodLancamentosProvider)
        ..invalidate(finContasProvider)
        ..invalidate(finPendentesProvider);
      if (context.mounted) {
        showClxToast(context, 'Lançamento criado.', type: ToastType.success);
      }
    }
  }

  Future<void> _transferir(BuildContext context, WidgetRef ref) async {
    final done = await showTransferenciaForm(context);
    if (done == true) {
      ref.invalidate(finContasProvider);
      if (context.mounted) {
        showClxToast(
          context,
          'Transferência concluída.',
          type: ToastType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lancAsync = ref.watch(finPeriodLancamentosProvider);
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final limites = ref.watch(finLimitesProvider).valueOrNull ?? const [];
    final pendentes = ref.watch(finPendentesProvider).valueOrNull ?? const [];
    final comissoesPendentes =
        ref.watch(finComissoesPendentesTotalProvider).valueOrNull ?? 0.0;
    final user = ref.watch(currentUserProvider);
    final mobile = finIsMobile(context);
    final fintech = ref.watch(isFintechCleanProvider) || ref.watch(isNarrowWebProvider);

    // Mobile (F-741): o cabeçalho (título + seletor de mês) rola junto com o
    // conteúdo, em vez de ser uma faixa fixa acima do Expanded.
    final leadingChildren = mobile
        ? const <Widget>[_MobileHeader(), SizedBox(height: ClxSpace.x4)]
        : const <Widget>[];

    final body = FinAsync<List<FinLancamento>>(
      value: lancAsync,
      onRetry: () => ref.invalidate(finPeriodLancamentosProvider),
      data: (lancs) => _Body(
        lancs: lancs,
        contas: contas,
        categorias: categorias,
        limites: limites,
        pendentes: pendentes,
        comissoesPendentes: comissoesPendentes,
        userName: user?.displayName ?? 'Admin',
        mobile: mobile,
        fintech: fintech,
        leadingChildren: leadingChildren,
        onNovaReceita: () =>
            _novoLancamento(context, ref, TipoLancamento.receita),
        onNovaDespesa: () =>
            _novoLancamento(context, ref, TipoLancamento.despesa),
        onTransferencia: () => _transferir(context, ref),
      ),
    );

    if (mobile) return body;

    return Column(
      children: [
        _Header(),
        Expanded(child: body),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x4,
        ClxSpace.x6,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Visão geral',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: clx.ink),
            ),
          ),
          const FinPeriodSelector(),
        ],
      ),
    );
  }
}

/// Cabeçalho ROLÁVEL do mobile (título + seletor de mês). No mobile o
/// [FinPeriodSelector] usa `Expanded` para dividir a linha sem estourar.
class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visão geral',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: clx.ink),
        ),
        const SizedBox(height: ClxSpace.x2),
        const SizedBox(
          width: double.infinity,
          child: FinPeriodSelector(expand: true),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.lancs,
    required this.contas,
    required this.categorias,
    required this.limites,
    required this.pendentes,
    required this.comissoesPendentes,
    required this.userName,
    required this.onNovaReceita,
    required this.onNovaDespesa,
    required this.onTransferencia,
    this.mobile = false,
    this.fintech = false,
    this.leadingChildren = const [],
  });

  final List<FinLancamento> lancs;
  final List<FinConta> contas;
  final List<FinCategoria> categorias;
  final List<FinLimite> limites;
  final List<FinLancamento> pendentes;
  final double comissoesPendentes;
  final String userName;
  final VoidCallback onNovaReceita;
  final VoidCallback onNovaDespesa;
  final VoidCallback onTransferencia;

  /// Layout de celular: reduz o padding e recebe o cabeçalho rolável.
  final bool mobile;

  /// APK "Fintech Clean" (doc 12): saldo geral vira [FintechBalanceHero] em
  /// vez de um card de KPI a mais na grade. A Web (`fintech=false`) usa o
  /// layout estilo Organizze (saudação + acesso rápido + 2 colunas).
  final bool fintech;

  /// Widgets inseridos ANTES dos KPIs (cabeçalho mobile). Vazio no desktop.
  final List<Widget> leadingChildren;

  FinCategoria? _cat(String id) {
    for (final c in categorias) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final resumo = resumoPeriodo(lancs);
    final comp = compromissosResumo(
      lancsPeriodo: lancs,
      comissoesPendentes: comissoesPendentes,
      realizado: resumo,
    );
    final saldoTotal = saldoGeral(contas);
    final hoje = todayLocalDate();
    final receberAll = contasAReceber(pendentes, hoje);
    final pagarAll = contasAPagar(pendentes, hoje);
    final receber = receberAll.take(5).toList();
    final pagar = pagarAll.take(5).toList();
    final chartGroups = _fluxoUltimosMeses(lancs);

    // APK fintech: hero + mini KPIs (mantém doc 12).
    if (fintech || mobile) {
      return ListView(
        padding: EdgeInsets.all(mobile ? ClxSpace.x4 : ClxSpace.x5),
        children: [
          ...leadingChildren,
          if (fintech)
            FintechBalanceHero(
              label: 'Saldo nas contas',
              value: formatCurrency(saldoTotal),
              hint: 'Dinheiro disponível agora',
            ),
          const SizedBox(height: ClxSpace.x3),
          _BlocoCaixa(resumo: resumo, compact: true),
          const SizedBox(height: ClxSpace.x3),
          _BlocoCompromissos(comp: comp, compact: true),
          const SizedBox(height: ClxSpace.x4),
          ClxCard(
            child: _QuickActions(
              onNovaReceita: onNovaReceita,
              onNovaDespesa: onNovaDespesa,
              onTransferencia: onTransferencia,
            ),
          ),
          // Pendências primeiro (ação do dia), depois análise.
          const SizedBox(height: ClxSpace.x4),
          _PreviewCard(
            title: 'Contas a pagar',
            badge: '${pagarAll.length}',
            badgeColor: clx.finExpense,
            items: pagar,
            kind: TipoLancamento.despesa,
            cat: _cat,
          ),
          const SizedBox(height: ClxSpace.x4),
          _PreviewCard(
            title: 'Contas a receber',
            badge: '${receberAll.length}',
            badgeColor: clx.finIncome,
            items: receber,
            kind: TipoLancamento.receita,
            cat: _cat,
          ),
          if (chartGroups.isNotEmpty) ...[
            const SizedBox(height: ClxSpace.x4),
            ClxCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entradas × Saídas',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: clx.ink,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  FinGroupedBarChart(groups: chartGroups, height: 180),
                ],
              ),
            ),
          ],
          const SizedBox(height: ClxSpace.x4),
          // Mesma ordem do desktop: saldo → maiores gastos → limites.
          _SaldoEContasCard(saldoTotal: saldoTotal, contas: contas),
          const SizedBox(height: ClxSpace.x4),
          _GastosCard(lancs: lancs, cat: _cat),
          const SizedBox(height: ClxSpace.x4),
          _LimitesCard(lancs: lancs, limites: limites, cat: _cat),
          const SizedBox(height: ClxSpace.x4),
        ],
      );
    }

    // Desktop web — hierarquia: resumo → fluxo → saldo/gastos →
    // pendências → limites/origem.
    // [equalHeight]: IntrinsicHeight + stretch (só pares com conteúdo estável;
    // listas de preview ficam em altura natural).
    Widget pair(Widget a, Widget b, {bool equalHeight = false}) =>
        LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: ClxSpace.x4), b],
          );
        }
        if (equalHeight) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: a),
                const SizedBox(width: ClxSpace.x4),
                Expanded(child: b),
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: ClxSpace.x4),
            Expanded(child: b),
          ],
        );
      },
    );

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x5),
      children: [
        _OrganizzeTop(
          userName: userName,
          resumo: resumo,
          compromissos: comp,
          saldoContas: saldoTotal,
          onNovaReceita: onNovaReceita,
          onNovaDespesa: onNovaDespesa,
          onTransferencia: onTransferencia,
        ),
        if (lancs.isEmpty) ...[
          const SizedBox(height: ClxSpace.x4),
          const ClxCard(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: 'Sem movimentações neste mês',
              message:
                  'Cadastre receitas e despesas para ver gráficos e limites. '
                  'Contas a pagar/receber abaixo consideram todos os períodos.',
            ),
          ),
        ],
        if (chartGroups.isNotEmpty) ...[
          const SizedBox(height: ClxSpace.x4),
          ClxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entradas × Saídas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.ink,
                      ),
                ),
                const SizedBox(height: ClxSpace.x1),
                Text(
                  'Visão do mês selecionado',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clx.ink3,
                      ),
                ),
                const SizedBox(height: ClxSpace.x3),
                FinGroupedBarChart(groups: chartGroups, height: 220),
              ],
            ),
          ),
        ],
        const SizedBox(height: ClxSpace.x4),
        // Saldo | Maiores gastos. Sem IntrinsicHeight (FinDonutChart usa
        // LayoutBuilder e quebra a medição). minHeight alinha visualmente.
        pair(
          _SaldoEContasCard(saldoTotal: saldoTotal, contas: contas),
          _GastosCard(lancs: lancs, cat: _cat),
        ),
        const SizedBox(height: ClxSpace.x4),
        pair(
          _PreviewCard(
            title: 'Contas a pagar',
            badge: '${pagarAll.length}',
            badgeColor: clx.finExpense,
            items: pagar,
            kind: TipoLancamento.despesa,
            cat: _cat,
          ),
          _PreviewCard(
            title: 'Contas a receber',
            badge: '${receberAll.length}',
            badgeColor: clx.finIncome,
            items: receber,
            kind: TipoLancamento.receita,
            cat: _cat,
          ),
        ),
        const SizedBox(height: ClxSpace.x4),
        // Limite de gastos no lugar em que ficava o saldo geral.
        pair(
          _LimitesCard(lancs: lancs, limites: limites, cat: _cat),
          _OrigemCard(lancs: lancs),
        ),
        const SizedBox(height: ClxSpace.x4),
      ],
    );
  }
}

/* ─────────────────────── topo: Caixa + Compromissos ─────────────────────── */

class _OrganizzeTop extends StatelessWidget {
  const _OrganizzeTop({
    required this.userName,
    required this.resumo,
    required this.compromissos,
    required this.saldoContas,
    required this.onNovaReceita,
    required this.onNovaDespesa,
    required this.onTransferencia,
  });

  final String userName;
  final ResumoPeriodo resumo;
  final CompromissosResumo compromissos;
  final double saldoContas;
  final VoidCallback onNovaReceita;
  final VoidCallback onNovaDespesa;
  final VoidCallback onTransferencia;

  String get _saudacao {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClxCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_saudacao, $userName!',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.ink,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x1),
                    Text(
                      'Caixa = o que já entrou/saiu. Compromissos = ainda não é dinheiro.',
                      style: tt.bodySmall?.copyWith(color: clx.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClxSpace.x4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Acesso rápido',
                    style: tt.labelLarge?.copyWith(
                      color: clx.ink3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                  _QuickActions(
                    compact: true,
                    onNovaReceita: onNovaReceita,
                    onNovaDespesa: onNovaDespesa,
                    onTransferencia: onTransferencia,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        // Caixa e Compromissos lado a lado (mesma altura).
        LayoutBuilder(
          builder: (context, c) {
            final caixa = _BlocoCaixa(
              resumo: resumo,
              saldoContas: saldoContas,
              fill: true,
            );
            final comp = _BlocoCompromissos(comp: compromissos, fill: true);
            if (c.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  caixa,
                  const SizedBox(height: ClxSpace.x3),
                  comp,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: caixa),
                  const SizedBox(width: ClxSpace.x3),
                  Expanded(child: comp),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Linha 1 — só o que é caixa (realizado).
class _BlocoCaixa extends StatelessWidget {
  const _BlocoCaixa({
    required this.resumo,
    this.saldoContas,
    this.compact = false,
    this.fill = false,
  });

  final ResumoPeriodo resumo;
  final double? saldoContas;
  final bool compact;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cards = <Widget>[
      _MetricTile(
        label: 'Dinheiro que entrou',
        hint: 'OS concluídas + receitas pagas',
        value: formatCurrency(resumo.entradas),
        color: clx.finIncome,
        icon: Icons.north_east_rounded,
      ),
      _MetricTile(
        label: 'Dinheiro que saiu',
        hint: 'Despesas já pagas',
        value: formatCurrency(resumo.saidas),
        color: clx.finExpense,
        icon: Icons.south_west_rounded,
      ),
      _MetricTile(
        label: 'Resultado do mês',
        hint: 'Entradas − saídas (realizado)',
        value: formatCurrency(resumo.saldoMes),
        color: resumo.saldoMes < 0 ? clx.finExpense : clx.primary,
        icon: Icons.equalizer_rounded,
      ),
      if (saldoContas != null)
        _MetricTile(
          label: 'Saldo nas contas',
          hint: 'Disponível agora',
          value: formatCurrency(saldoContas!),
          color: clx.ink,
          icon: Icons.account_balance_wallet_outlined,
        ),
    ];

    return ClxCard(
      fill: fill,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 · Caixa (realizado)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Só o que já mexeu no saldo. Não inclui OS futuras nem comissão a pagar.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x3),
          // Grade 2×2: cada métrica com largura real do card (sem clamp baixo).
          _metricsGrid(cards, dense: compact || fill),
        ],
      ),
    );
  }
}

/// Linha 2 — compromissos (ainda não é caixa).
class _BlocoCompromissos extends StatelessWidget {
  const _BlocoCompromissos({
    required this.comp,
    this.compact = false,
    this.fill = false,
  });

  final CompromissosResumo comp;
  final bool compact;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cards = <Widget>[
      _MetricTile(
        label: 'A receber (agenda)',
        hint: 'OS ainda não concluídas',
        value: formatCurrency(comp.aReceber),
        color: clx.info,
        icon: Icons.schedule_rounded,
      ),
      _MetricTile(
        label: 'Comissões a pagar',
        hint: 'Equipe — ainda não saiu do caixa',
        value: formatCurrency(comp.comissoesAPagar),
        color: clx.warning,
        icon: Icons.groups_outlined,
      ),
      _MetricTile(
        label: 'Contas a pagar',
        hint: 'Despesas em aberto do período',
        value: formatCurrency(comp.contasAPagar),
        color: clx.finExpense,
        icon: Icons.receipt_long_outlined,
      ),
      _MetricTile(
        label: 'Se tudo se confirmar',
        hint: 'Resultado + a receber − obrigações',
        value: formatCurrency(comp.resultadoProjetado),
        color: comp.resultadoProjetado < 0 ? clx.finExpense : clx.success,
        icon: Icons.trending_up_rounded,
      ),
    ];

    return ClxCard(
      fill: fill,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2 · Compromissos (ainda não é caixa)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Promessas e obrigações. Não confunda com o resultado do mês ao lado.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x3),
          _metricsGrid(cards, dense: compact || fill),
        ],
      ),
    );
  }
}

/// Grade responsiva de métricas (1 col no compact/mobile, 2 col no desktop).
Widget _metricsGrid(List<Widget> cards, {required bool dense}) {
  if (dense) {
    // Coluna full-width: labels/valores inteiros legíveis.
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: ClxSpace.x2),
          cards[i],
        ],
      ],
    );
  }
  return LayoutBuilder(
    builder: (context, c) {
      final gap = ClxSpace.x3;
      // 2 colunas sempre que couber; senão 1.
      final cols = c.maxWidth >= 360 ? 2 : 1;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cards) SizedBox(width: w, child: card),
        ],
      );
    },
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.hint,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        border: Border.all(color: clx.line),
        borderRadius: ClxRadii.rLg,
        color: clx.bg2.withValues(alpha: 0.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: ClxRadii.rMd,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: clx.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: clx.ink3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaldoEContasCard extends StatelessWidget {
  const _SaldoEContasCard({
    required this.saldoTotal,
    required this.contas,
  });

  final double saldoTotal;
  final List<FinConta> contas;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final ativas = contas.where((c) => c.ativo).toList();
    return ClxCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: clx.primary,
                  borderRadius: ClxRadii.rSm,
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo geral',
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                    Text(
                      formatCurrency(saldoTotal),
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: saldoTotal < 0 ? clx.finExpense : clx.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x4),
          Text(
            'Minhas contas',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          if (ativas.isEmpty)
            Text(
              'Nenhuma conta ativa.',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            )
          else
            for (final c in ativas)
              Padding(
                padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (finParseHex(c.cor) ?? clx.primary)
                            .withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: finParseHex(c.cor) ?? clx.primary,
                      ),
                    ),
                    const SizedBox(width: ClxSpace.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.nome,
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: clx.ink,
                            ),
                          ),
                          Text(
                            contaTipoLabel(c.tipo),
                            style: tt.labelSmall?.copyWith(color: clx.ink3),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(c.saldoAtual),
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.saldoAtual < 0 ? clx.finExpense : clx.ink,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Agrupa lançamentos do período em até 5 buckets por dia (label dd/MM)
/// para o gráfico de barras Easypay. Se houver poucos dias, mostra o que tiver.
List<FinBarGroup> _fluxoUltimosMeses(List<FinLancamento> lancs) {
  if (lancs.isEmpty) return const [];
  final byDay = <String, ({double rec, double desp})>{};
  for (final l in lancs) {
    // Só realizado (pago): receita do mês = OS concluída + manual.
    // Previsto de OS atribuída não entra no gráfico de fluxo.
    if (!isLancamentoRealizado(l)) continue;
    final raw = l.data.isNotEmpty ? l.data : (l.created ?? '');
    if (raw.length < 10) continue;
    final key = raw.substring(0, 10);
    final cur = byDay[key] ?? (rec: 0.0, desp: 0.0);
    final v = l.valor;
    if (l.tipo == TipoLancamento.receita) {
      byDay[key] = (rec: cur.rec + v, desp: cur.desp);
    } else if (l.tipo == TipoLancamento.despesa) {
      byDay[key] = (rec: cur.rec, desp: cur.desp + v);
    }
  }
  final keys = byDay.keys.toList()..sort();
  final take = keys.length > 6 ? keys.sublist(keys.length - 6) : keys;
  return [
    for (final k in take)
      FinBarGroup(
        label: '${k.substring(8, 10)}/${k.substring(5, 7)}',
        receitas: byDay[k]!.rec,
        despesas: byDay[k]!.desp,
        lucro: byDay[k]!.rec - byDay[k]!.desp,
      ),
  ];
}

/* ─────────────────────── ações rápidas ─────────────────────── */

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNovaReceita,
    required this.onNovaDespesa,
    required this.onTransferencia,
    this.compact = false,
  });

  final VoidCallback onNovaReceita;
  final VoidCallback onNovaDespesa;
  final VoidCallback onTransferencia;

  /// Estilo Organizze: DESPESA / RECEITA / TRANSF.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final novaDespesa = _QuickAction(
      icon: Icons.remove_rounded,
      label: compact ? 'DESPESA' : 'Nova despesa',
      fg: Colors.white,
      bg: clx.error,
      onTap: onNovaDespesa,
    );
    final novaReceita = _QuickAction(
      icon: Icons.add_rounded,
      label: compact ? 'RECEITA' : 'Nova receita',
      fg: Colors.white,
      bg: clx.success,
      onTap: onNovaReceita,
    );
    final transferencia = _QuickAction(
      icon: Icons.swap_horiz_rounded,
      label: compact ? 'TRANSF.' : 'Transferência',
      fg: clx.ink2,
      bg: clx.bg3,
      onTap: onTransferencia,
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          novaDespesa,
          const SizedBox(width: ClxSpace.x2),
          novaReceita,
          const SizedBox(width: ClxSpace.x2),
          transferencia,
        ],
      );
    }

    // Mobile / Easypay: 3 botões em linha.
    if (finIsMobile(context)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [novaReceita, novaDespesa, transferencia],
      );
    }

    return Wrap(
      spacing: ClxSpace.x3,
      runSpacing: ClxSpace.x3,
      alignment: WrapAlignment.spaceAround,
      children: [novaReceita, novaDespesa, transferencia],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rLg,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x2,
          vertical: ClxSpace.x3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(height: ClxSpace.x2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: clx.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── preview a receber/pagar ─────────────────────── */

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.items,
    required this.kind,
    required this.cat,
  });

  final String title;
  final String badge;
  final Color badgeColor;
  final List<ContaPendente> items;
  final TipoLancamento kind;
  final FinCategoria? Function(String) cat;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinSectionHeader(
            title: title,
            trailing: ClxChip(
              label: badge,
              color: badgeColor,
              dense: true,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x4),
              child: Text(
                kind == TipoLancamento.receita
                    ? 'Nenhuma conta a receber.'
                    : 'Nenhuma conta a pagar.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: ClxSpace.x3),
              _PreviewRow(pendente: items[i], kind: kind, cat: cat),
            ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.pendente,
    required this.kind,
    required this.cat,
  });

  final ContaPendente pendente;
  final TipoLancamento kind;
  final FinCategoria? Function(String) cat;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final l = pendente.lancamento;
    final venc = (l.vencimento?.isNotEmpty ?? false) ? l.vencimento! : l.data;
    final sub = l.origem == OrigemLancamento.viaOs &&
            (l.clienteNome?.isNotEmpty ?? false)
        ? 'Cliente: ${l.clienteNome}'
        : formatDateOnlyBr(venc);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinCategoriaAvatar(categoria: cat(l.categoriaId), size: 32),
        const SizedBox(width: ClxSpace.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(
                  color: clx.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  color: pendente.emAtraso ? clx.error : clx.ink3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: ClxSpace.x2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(l.valor),
              style: tt.bodyLarge?.copyWith(
                color: kind == TipoLancamento.receita
                    ? clx.finIncome
                    : clx.finExpense,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            StatusLancamentoChip(status: l.status, dense: true),
          ],
        ),
      ],
    );
  }
}

/* ─────────────────────── maiores gastos (donut) ─────────────────────── */

class _GastosCard extends StatelessWidget {
  const _GastosCard({
    required this.lancs,
    required this.cat,
  });

  final List<FinLancamento> lancs;
  final FinCategoria? Function(String) cat;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final gastos = gastoPorCategoria(lancs);
    return ClxCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Maiores gastos do mês'),
          const SizedBox(height: ClxSpace.x4),
          if (gastos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Text(
                'Nenhuma despesa paga no período.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
              ),
            )
          else
            _donut(context, gastos),
        ],
      ),
    );
  }

  Widget _donut(BuildContext context, Map<String, double> gastos) {
    final entries = gastos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final resto = entries.skip(6).fold<double>(0, (a, e) => a + e.value);
    final cores = finSeriesColors(context, top.length + 1);
    final slices = <FinSlice>[
      for (var i = 0; i < top.length; i++)
        FinSlice(
          label: cat(top[i].key)?.nome ?? 'Categoria',
          value: top[i].value,
          // Prefere cor da categoria; senão série do tema.
          color: finParseHex(cat(top[i].key)?.cor) ?? cores[i],
        ),
      if (resto > 0)
        FinSlice(label: 'Outros', value: resto, color: cores.last),
    ];
    // Só gráfico + legenda ao lado (sem ranking duplicado acima).
    return FinDonutChart(
      slices: slices,
      centerLabel: 'Gastos',
      size: 180,
      showLegend: true,
    );
  }
}

/* ─────────────────────── receitas por origem (donut) ─────────────────────── */

class _OrigemCard extends StatelessWidget {
  const _OrigemCard({required this.lancs});

  final List<FinLancamento> lancs;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    var viaOs = 0.0;
    var manual = 0.0;
    for (final l in lancs) {
      if (l.tipo != TipoLancamento.receita ||
          l.status != LancamentoStatus.pago) {
        continue;
      }
      if (l.origem == OrigemLancamento.viaOs) {
        viaOs += l.valor;
      } else {
        manual += l.valor;
      }
    }
    final total = viaOs + manual;
    return ClxCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Receitas por origem'),
          const SizedBox(height: ClxSpace.x4),
          if (total <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Text(
                'Nenhuma receita recebida no período.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
              ),
            )
          else
            FinDonutChart(
              centerLabel: 'Receitas',
              size: 160,
              slices: [
                FinSlice(
                  label: origemLabel(OrigemLancamento.viaOs),
                  value: viaOs,
                  color: clx.primary,
                ),
                FinSlice(
                  label: origemLabel(OrigemLancamento.manual),
                  value: manual,
                  color: clx.info,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/* ─────────────────────── limites (preview) ─────────────────────── */

class _LimitesCard extends StatelessWidget {
  const _LimitesCard({
    required this.lancs,
    required this.limites,
    required this.cat,
  });

  final List<FinLancamento> lancs;
  final List<FinLimite> limites;
  final FinCategoria? Function(String) cat;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final rows = limites.take(6).toList();
    return ClxCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinSectionHeader(
            title: 'Limite de gastos do mês',
            trailing: Text(
              '${rows.length} categoria${rows.length == 1 ? '' : 's'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: clx.ink3),
            ),
          ),
          const SizedBox(height: ClxSpace.x4),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x4),
              child: Text(
                'Nenhum limite definido.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
              ),
            )
          else
            for (final lim in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                child: _LimiteRow(
                  limite: lim,
                  progresso: progressoLimite(lim, lancs),
                  nome: cat(lim.categoriaId)?.nome ?? 'Categoria',
                ),
              ),
        ],
      ),
    );
  }
}

class _LimiteRow extends StatelessWidget {
  const _LimiteRow({
    required this.limite,
    required this.progresso,
    required this.nome,
  });

  final FinLimite limite;
  final ProgressoLimite progresso;
  final String nome;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final estourou = progresso.gasto > progresso.limite && progresso.limite > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
              ),
            ),
            Text(
              '${(progresso.pct * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: estourou ? clx.error : clx.ink3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Text(
          'Meta: ${formatCurrency(progresso.limite)}  ·  '
          'Gasto: ${formatCurrency(progresso.gasto)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: estourou ? clx.error : clx.ink3,
          ),
        ),
        const SizedBox(height: ClxSpace.x1),
        FinProgressBar(value: progresso.pct),
      ],
    );
  }
}
