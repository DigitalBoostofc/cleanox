/// fin_principal_screen.dart — Home do Financeiro v2 (Principal).
///
/// UX inspirada nas refs Mobills: hero de saldo, receitas/despesas, pendências,
/// donut por categoria, contas, balanço, favoritas, economia, frequência de
/// gastos. Cores Cleanox; dados via [finPeriodLancamentosProvider] + derivations.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surface_provider.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'carteiras/conta_form.dart';
import 'charts/fin_charts.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_providers.dart';
import 'fintech/fintech_balance_hero.dart';
import 'lancamentos/lancamento_form.dart';
import 'ui/fin_ui.dart';

class FinPrincipalScreen extends ConsumerStatefulWidget {
  const FinPrincipalScreen({super.key});

  @override
  ConsumerState<FinPrincipalScreen> createState() => _FinPrincipalScreenState();
}

class _FinPrincipalScreenState extends ConsumerState<FinPrincipalScreen> {
  bool _saldoVisivel = true;

  Future<void> _novo(
    TipoLancamento tipo,
  ) async {
    final saved = await showLancamentoForm(context, initialTipo: tipo);
    if (saved == true && mounted) {
      ref
        ..invalidate(finPeriodLancamentosProvider)
        ..invalidate(finContasProvider)
        ..invalidate(finPendentesProvider);
      showClxToast(context, 'Lançamento criado.', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final mobile = finIsMobile(context);
    final fintech = ref.watch(isFintechCleanProvider) ||
        ref.watch(isNarrowWebProvider);
    final period = ref.watch(finPeriodProvider);
    final lancAsync = ref.watch(finPeriodLancamentosProvider);
    final contas = ref.watch(finContasProvider).valueOrNull ?? const <FinConta>[];
    final categorias =
        ref.watch(finCategoriasProvider).valueOrNull ?? const <FinCategoria>[];
    final pendentes =
        ref.watch(finPendentesProvider).valueOrNull ?? const <FinLancamento>[];
    final objetivos =
        ref.watch(finObjetivosProvider).valueOrNull ?? const <FinObjetivo>[];

    return ColoredBox(
      color: clx.bg2,
      child: FinAsync<List<FinLancamento>>(
        value: lancAsync,
        onRetry: () => ref.invalidate(finPeriodLancamentosProvider),
        data: (lancs) {
          final resumo = resumoPeriodo(lancs);
          final saldo = saldoGeral(contas.where((c) => c.ativo).toList());
          final catMap = {for (final c in categorias) c.id: c};
          final gasto = gastoPorCategoria(lancs);
          final receitaCat =
              totalPagoPorCategoria(lancs, TipoLancamento.receita);
          final despPend = totalDespesasEmAberto(pendentes);
          final recPend = totalReceitasPrevistas(pendentes);
          final nDespPend = pendentes
              .where(
                (l) =>
                    l.tipo == TipoLancamento.despesa && emAberto(l),
              )
              .length;
          final economiaPct = resumo.entradas > 0
              ? ((resumo.saldoMes / resumo.entradas) * 100).clamp(0.0, 100.0)
              : 0.0;

          final freq = _frequenciaGastos(lancs, days: 7);

          final body = mobile
              ? _MobileBody(
                  fintech: fintech,
                  periodLabel: period.label,
                  onPrev: () => ref.read(finPeriodProvider.notifier).state =
                      period.shift(-1),
                  onNext: () => ref.read(finPeriodProvider.notifier).state =
                      period.shift(1),
                  saldo: saldo,
                  saldoVisivel: _saldoVisivel,
                  onToggleSaldo: () =>
                      setState(() => _saldoVisivel = !_saldoVisivel),
                  resumo: resumo,
                  despPend: despPend,
                  recPend: recPend,
                  nDespPend: nDespPend,
                  gasto: gasto,
                  receitaCat: receitaCat,
                  catMap: catMap,
                  contas: contas.where((c) => c.ativo).toList(),
                  favoritos: lancs.where((l) => l.favorito).take(5).toList(),
                  objetivos: objetivos.where((o) => o.ativo).take(3).toList(),
                  economiaPct: economiaPct,
                  freq: freq,
                  onNovaReceita: () => _novo(TipoLancamento.receita),
                  onNovaDespesa: () => _novo(TipoLancamento.despesa),
                  onGoTransacoes: () =>
                      context.go('/painel/financeiro/transacoes'),
                  onGoPlanejamento: () =>
                      context.go('/painel/financeiro/planejamento'),
                  onGoContas: () => context.go('/painel/financeiro/carteiras'),
                  onGoObjetivos: () =>
                      context.go('/painel/financeiro/objetivos'),
                  onNovaConta: () async {
                    final ok = await showContaForm(context);
                    if (ok == true) ref.invalidate(finContasProvider);
                  },
                )
              : _DesktopBody(
                  periodLabel: period.label,
                  periodYear: period.year,
                  periodMonth: period.month,
                  onPrev: () => ref.read(finPeriodProvider.notifier).state =
                      period.shift(-1),
                  onNext: () => ref.read(finPeriodProvider.notifier).state =
                      period.shift(1),
                  saldo: saldo,
                  resumo: resumo,
                  despPend: despPend,
                  recPend: recPend,
                  nDespPend: nDespPend,
                  gasto: gasto,
                  receitaCat: receitaCat,
                  catMap: catMap,
                  contas: contas.where((c) => c.ativo).toList(),
                  objetivos:
                      objetivos.where((o) => o.ativo).take(3).toList(),
                  economiaPct: economiaPct,
                  freq: freq,
                  lancs: lancs,
                  onGoTransacoes: () =>
                      context.go('/painel/financeiro/transacoes'),
                  onGoPlanejamento: () =>
                      context.go('/painel/financeiro/planejamento'),
                  onGoContas: () => context.go('/painel/financeiro/carteiras'),
                  onGoObjetivos: () =>
                      context.go('/painel/financeiro/objetivos'),
                );

          return RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(finPeriodLancamentosProvider)
                ..invalidate(finContasProvider)
                ..invalidate(finPendentesProvider);
              await ref.read(finPeriodLancamentosProvider.future);
            },
            child: body,
          );
        },
      ),
    );
  }
}

/* ─────────────────────── mobile ─────────────────────── */

class _MobileBody extends StatelessWidget {
  const _MobileBody({
    required this.fintech,
    required this.periodLabel,
    required this.onPrev,
    required this.onNext,
    required this.saldo,
    required this.saldoVisivel,
    required this.onToggleSaldo,
    required this.resumo,
    required this.despPend,
    required this.recPend,
    required this.nDespPend,
    required this.gasto,
    required this.receitaCat,
    required this.catMap,
    required this.contas,
    required this.favoritos,
    required this.objetivos,
    required this.economiaPct,
    required this.freq,
    required this.onNovaReceita,
    required this.onNovaDespesa,
    required this.onGoTransacoes,
    required this.onGoPlanejamento,
    required this.onGoContas,
    required this.onGoObjetivos,
    required this.onNovaConta,
  });

  final bool fintech;
  final String periodLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double saldo;
  final bool saldoVisivel;
  final VoidCallback onToggleSaldo;
  final ResumoPeriodo resumo;
  final double despPend;
  final double recPend;
  final int nDespPend;
  final Map<String, double> gasto;
  final Map<String, double> receitaCat;
  final Map<String, FinCategoria> catMap;
  final List<FinConta> contas;
  final List<FinLancamento> favoritos;
  final List<FinObjetivo> objetivos;
  final double economiaPct;
  final List<_FreqPoint> freq;
  final VoidCallback onNovaReceita;
  final VoidCallback onNovaDespesa;
  final VoidCallback onGoTransacoes;
  final VoidCallback onGoPlanejamento;
  final VoidCallback onGoContas;
  final VoidCallback onGoObjetivos;
  final VoidCallback onNovaConta;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    // Fintech (APK): padding inferior só pro bottom bar Easypay (~72+safe).
    final bottomPad = fintech ? 108.0 : 100.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
      physics: const BouncingScrollPhysics(),
      children: [
        FinMonthBar(
          label: periodLabel,
          onPrev: onPrev,
          onNext: onNext,
          pill: fintech,
        ),
        const SizedBox(height: ClxSpace.x4),
        if (fintech) ...[
          FintechBalanceHero(
            label: 'Saldo em contas',
            value: saldoVisivel ? formatCurrency(saldo) : '••••••',
            hint: saldoVisivel
                ? (saldo < 0
                    ? 'Atenção: saldo negativo'
                    : 'Disponível agora · $periodLabel')
                : 'Saldo oculto',
            trailing: Material(
              color: Colors.white.withValues(alpha: 0.16),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggleSaldo,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    saldoVisivel
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            footer: Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Receitas',
                    value: formatCurrency(resumo.entradas),
                    onTap: onNovaReceita,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'Despesas',
                    value: formatCurrency(resumo.saidas),
                    onTap: onNovaDespesa,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'Saldo atual em contas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: clx.ink3,
                ),
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            saldoVisivel ? formatCurrency(saldo) : '••••••',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: saldo < 0 ? clx.finExpense : clx.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          IconButton(
            onPressed: onToggleSaldo,
            icon: Icon(
              saldoVisivel
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: clx.ink3,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _MiniInOut(
                  label: 'Receitas',
                  value: resumo.entradas,
                  income: true,
                  onTap: onNovaReceita,
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: _MiniInOut(
                  label: 'Despesas',
                  value: resumo.saidas,
                  income: false,
                  onTap: onNovaDespesa,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: ClxSpace.x5),
        // Atalhos rápidos no APK
        if (fintech) ...[
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_rounded,
                  label: 'Receita',
                  color: clx.finIncome,
                  onTap: onNovaReceita,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.remove_rounded,
                  label: 'Despesa',
                  color: clx.finExpense,
                  onTap: onNovaDespesa,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Extrato',
                  color: clx.primary,
                  onTap: onGoTransacoes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Contas',
                  color: clx.accent,
                  onTap: onGoContas,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x5),
        ],
        FinDashSectionHeader(title: 'Pendências e alertas'),
        FinCard(
          elevated: fintech,
          onTap: onGoTransacoes,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: clx.finExpense.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: clx.finExpense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Despesas pendentes',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (nDespPend > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: clx.finExpense,
                              borderRadius: ClxRadii.rPill,
                            ),
                            child: Text(
                              '$nDespPend',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    FinMoneyText(-despPend.abs()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: clx.ink3),
            ],
          ),
        ),
        if (recPend > 0) ...[
          const SizedBox(height: ClxSpace.x2),
          FinCard(
            child: Row(
              children: [
                Icon(Icons.arrow_upward_rounded, color: clx.finIncome, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Receitas a receber',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                FinMoneyText(recPend),
              ],
            ),
          ),
        ],
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(
          title: 'Despesas por categoria',
          trailing: const Text('Detalhes'),
          onTrailing: onGoTransacoes,
        ),
        _DonutBlock(
          map: gasto,
          catMap: catMap,
          totalLabel: formatCurrency(resumo.saidas),
          emptyLabel: 'Sem despesas pagas neste mês.',
        ),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(
          title: 'Planejamento mensal',
          trailing: const Text('Ver'),
          onTrailing: onGoPlanejamento,
        ),
        FinEmptyCta(
          icon: Icons.receipt_long_outlined,
          message:
              'Opa! Você ainda não possui um planejamento definido para este mês.',
          hint: 'Melhore o controle do caixa da operação.',
          ctaLabel: 'Definir novo planejamento',
          onCta: onGoPlanejamento,
        ),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(
          title: 'Contas',
          trailing: Icon(Icons.add, color: context.clx.primary, size: 22),
          onTrailing: onNovaConta,
        ),
        FinCard(
          elevated: fintech,
          child: Column(
            children: [
              for (var i = 0; i < contas.length; i++) ...[
                if (i > 0) Divider(height: 20, color: clx.line),
                InkWell(
                  onTap: onGoContas,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: clx.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: clx.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            contas[i].nome,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FinMoneyText(contas[i].saldoAtual),
                      ],
                    ),
                  ),
                ),
              ],
              if (contas.isEmpty)
                Text(
                  'Nenhuma conta ativa.',
                  style: TextStyle(color: clx.ink3),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  FinMoneyText(saldoGeral(contas)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(
          title: 'Balanço mensal',
          trailing: const Text('Detalhes'),
          onTrailing: onGoTransacoes,
        ),
        _BalancoMensalCard(resumo: resumo, elevated: fintech),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(
          title: 'Transações favoritas',
          trailing: const Text('Ver'),
          onTrailing: onGoTransacoes,
        ),
        _FavoritosBlock(
          lancs: favoritos,
          catMap: catMap,
          onGo: onGoTransacoes,
        ),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(title: 'Economia mensal'),
        _EconomiaCard(pct: economiaPct, resumo: resumo),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(
          title: 'Objetivos',
          trailing: const Text('Ver'),
          onTrailing: onGoObjetivos,
        ),
        if (objetivos.isEmpty)
          FinEmptyCta(
            icon: Icons.track_changes_outlined,
            message: 'Opa! Você ainda não possui objetivos definidos.',
            hint: 'Melhore o controle financeiro da operação!',
            ctaLabel: 'Definir meus objetivos',
            onCta: onGoObjetivos,
          )
        else
          FinCard(
            child: Column(
              children: [
                for (var i = 0; i < objetivos.length; i++) ...[
                  if (i > 0) Divider(color: clx.line),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: onGoObjetivos,
                    title: Text(objetivos[i].nome),
                    subtitle: Text(
                      '${formatCurrency(objetivos[i].valorAtual)} de ${formatCurrency(objetivos[i].metaValor)}',
                      style: TextStyle(color: clx.ink3, fontSize: 12),
                    ),
                    trailing: Text(
                      '${(objetivos[i].progresso * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: clx.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: ClxSpace.x6),
        FinDashSectionHeader(title: 'Frequência de gastos'),
        _FreqChart(points: freq),
      ],
    );
  }
}


/* ─────────────────────── desktop ─────────────────────── */

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({
    required this.periodLabel,
    required this.periodYear,
    required this.periodMonth,
    required this.onPrev,
    required this.onNext,
    required this.saldo,
    required this.resumo,
    required this.despPend,
    required this.recPend,
    required this.nDespPend,
    required this.gasto,
    required this.receitaCat,
    required this.catMap,
    required this.contas,
    required this.objetivos,
    required this.economiaPct,
    required this.freq,
    required this.lancs,
    required this.onGoTransacoes,
    required this.onGoPlanejamento,
    required this.onGoContas,
    required this.onGoObjetivos,
  });

  final String periodLabel;
  final int periodYear;
  final int periodMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double saldo;
  final ResumoPeriodo resumo;
  final double despPend;
  final double recPend;
  final int nDespPend;
  final Map<String, double> gasto;
  final Map<String, double> receitaCat;
  final Map<String, FinCategoria> catMap;
  final List<FinConta> contas;
  final List<FinObjetivo> objetivos;
  final double economiaPct;
  final List<_FreqPoint> freq;
  final List<FinLancamento> lancs;
  final VoidCallback onGoTransacoes;
  final VoidCallback onGoPlanejamento;
  final VoidCallback onGoContas;
  final VoidCallback onGoObjetivos;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: clx.bg3,
                borderRadius: ClxRadii.rPill,
                border: Border.all(color: clx.line),
              ),
              child: FinMonthBar(
                label: periodLabel,
                onPrev: onPrev,
                onNext: onNext,
                center: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: ClxSpace.x5),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w > 1100 ? 4 : (w > 720 ? 2 : 1);
            final tileW = (w - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: tileW,
                  child: FinKpiTile(
                    label: 'Saldo atual',
                    value: formatCurrency(saldo),
                    icon: Icons.account_balance_rounded,
                    iconBg: clx.primary,
                    valueColor: saldo < 0 ? clx.finExpense : clx.ink,
                    onTap: onGoContas,
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: FinKpiTile(
                    label: 'Receitas',
                    value: formatCurrency(resumo.entradas),
                    icon: Icons.arrow_upward_rounded,
                    iconBg: clx.finIncome,
                    valueColor: clx.finIncome,
                    onTap: onGoTransacoes,
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: FinKpiTile(
                    label: 'Despesas',
                    value: formatCurrency(resumo.saidas),
                    icon: Icons.arrow_downward_rounded,
                    iconBg: clx.finExpense,
                    valueColor: clx.finExpense,
                    onTap: onGoTransacoes,
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: FinKpiTile(
                    label: 'Balanço mensal',
                    value: formatCurrency(resumo.saldoMes),
                    icon: Icons.balance_rounded,
                    iconBg: clx.accent,
                    valueColor:
                        resumo.saldoMes < 0 ? clx.finExpense : clx.finIncome,
                    onTap: onGoTransacoes,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: ClxSpace.x5),
        LayoutBuilder(
          builder: (context, c) {
            final two = c.maxWidth >= 900;
            if (!two) {
              return Column(
                children: [
                  _DonutBlock(
                    title: 'Receitas por categoria',
                    map: receitaCat,
                    catMap: catMap,
                    totalLabel: formatCurrency(resumo.entradas),
                    emptyLabel: 'Sem receitas pagas neste mês.',
                  ),
                  const SizedBox(height: 16),
                  _DonutBlock(
                    title: 'Despesas por categoria',
                    map: gasto,
                    catMap: catMap,
                    totalLabel: formatCurrency(resumo.saidas),
                    emptyLabel: 'Sem despesas pagas neste mês.',
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DonutBlock(
                    title: 'Receitas por categoria',
                    map: receitaCat,
                    catMap: catMap,
                    totalLabel: formatCurrency(resumo.entradas),
                    emptyLabel: 'Sem receitas pagas neste mês.',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DonutBlock(
                    title: 'Despesas por categoria',
                    map: gasto,
                    catMap: catMap,
                    totalLabel: formatCurrency(resumo.saidas),
                    emptyLabel: 'Sem despesas pagas neste mês.',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: ClxSpace.x5),
        LayoutBuilder(
          builder: (context, c) {
            final two = c.maxWidth >= 900;
            final left = Column(
              children: [
                FinDashSectionHeader(title: 'Frequência de gastos'),
                _FreqChart(points: freq),
                const SizedBox(height: 16),
                FinDashSectionHeader(title: 'Balanço mensal'),
                _BalancoMensalCard(resumo: resumo),
                const SizedBox(height: 16),
                FinDashSectionHeader(
                  title: 'Pendências e alertas',
                  trailing: const Text('VER MAIS'),
                  onTrailing: onGoTransacoes,
                ),
                FinCard(
                  child: Column(
                    children: [
                      _PendRow(
                        label: 'Total de despesas pendentes',
                        amount: -despPend.abs(),
                      ),
                      const SizedBox(height: 10),
                      _PendRow(
                        label: 'Total de receitas pendentes',
                        amount: recPend,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FinDashSectionHeader(title: 'Planejamento mensal'),
                FinEmptyCta(
                  icon: Icons.flag_outlined,
                  message:
                      'Opa! Você ainda não possui um planejamento definido para este mês.',
                  ctaLabel: 'DEFINIR MEU PLANEJAMENTO',
                  onCta: onGoPlanejamento,
                ),
              ],
            );
            final right = Column(
              children: [
                FinDashSectionHeader(
                  title: 'Objetivos',
                  trailing: const Text('VER MAIS'),
                  onTrailing: onGoObjetivos,
                ),
                if (objetivos.isEmpty)
                  FinEmptyCta(
                    icon: Icons.track_changes_outlined,
                    message:
                        'Opa! Você ainda não possui objetivos definidos.',
                    ctaLabel: 'DEFINIR MEUS OBJETIVOS',
                    onCta: onGoObjetivos,
                  )
                else
                  FinCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < objetivos.length; i++) ...[
                          if (i > 0) Divider(color: clx.line),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: onGoObjetivos,
                            title: Text(objetivos[i].nome),
                            subtitle: Text(
                              '${formatCurrency(objetivos[i].valorAtual)} de ${formatCurrency(objetivos[i].metaValor)}',
                            ),
                            trailing: Text(
                              '${(objetivos[i].progresso * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: clx.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                FinDashSectionHeader(title: 'Economia mensal'),
                _EconomiaCard(pct: economiaPct, resumo: resumo),
                const SizedBox(height: 16),
                FinDashSectionHeader(
                  title: 'Minhas contas',
                  trailing: const Text('VER MAIS'),
                  onTrailing: onGoContas,
                ),
                FinCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < contas.length; i++) ...[
                        if (i > 0) Divider(color: clx.line),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.account_balance_wallet_outlined,
                              color: clx.primary),
                          title: Text(contas[i].nome),
                          subtitle: Text(
                            'Saldo atual',
                            style: TextStyle(color: clx.ink3, fontSize: 12),
                          ),
                          trailing: FinMoneyText(contas[i].saldoAtual),
                          onTap: onGoContas,
                        ),
                      ],
                      if (contas.isEmpty)
                        Text('Nenhuma conta.', style: TextStyle(color: clx.ink3)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FinDashSectionHeader(
                  title: 'Transações favoritas',
                  trailing: const Text('VER MAIS'),
                  onTrailing: onGoTransacoes,
                ),
                FinEmptyCta(
                  message: 'Você não possui transações favoritas.',
                  hint:
                      'Que tal começar adicionando despesas e receitas pelo botão +?',
                ),
              ],
            );
            if (!two) {
              return Column(children: [left, const SizedBox(height: 16), right]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ],
            );
          },
        ),
        const SizedBox(height: ClxSpace.x5),
        FinDashSectionHeader(title: 'Calendário do mês'),
        _MiniCalendar(
          year: periodYear,
          month: periodMonth,
          lancs: lancs,
        ),
      ],
    );
  }
}

/* ─────────────────────── widgets auxiliares ─────────────────────── */

class _FavoritosBlock extends StatelessWidget {
  const _FavoritosBlock({
    required this.lancs,
    required this.catMap,
    required this.onGo,
  });

  final List<FinLancamento> lancs;
  final Map<String, FinCategoria> catMap;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    if (lancs.isEmpty) {
      return FinEmptyCta(
        message: 'Não existem transações favoritas ainda ;)',
        hint: 'Toque no pin em um lançamento para marcar.',
      );
    }
    final clx = context.clx;
    return FinCard(
      child: Column(
        children: [
          for (var i = 0; i < lancs.length; i++) ...[
            if (i > 0) Divider(color: clx.line),
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: onGo,
              title: Text(
                lancs[i].descricao,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                catMap[lancs[i].categoriaId]?.nome ?? '',
                style: TextStyle(color: clx.ink3, fontSize: 12),
              ),
              trailing: FinMoneyText(
                lancs[i].tipo == TipoLancamento.receita
                    ? lancs[i].valor
                    : -lancs[i].valor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: clx.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: clx.line),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: clx.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInOut extends StatelessWidget {
  const _MiniInOut({
    required this.label,
    required this.value,
    required this.income,
    this.onTap,
  });
  final String label;
  final double value;
  final bool income;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = income ? clx.finIncome : clx.finExpense;
    return FinCard(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              income
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: clx.ink3, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutBlock extends StatelessWidget {
  const _DonutBlock({
    this.title,
    required this.map,
    required this.catMap,
    required this.totalLabel,
    required this.emptyLabel,
  });

  final String? title;
  final Map<String, double> map;
  final Map<String, FinCategoria> catMap;
  final String totalLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = finSeriesColors(context, entries.length);
    final slices = [
      for (var i = 0; i < entries.length; i++)
        FinSlice(
          id: entries[i].key,
          label: catMap[entries[i].key]?.nome ?? 'Outros',
          value: entries[i].value,
          color: colors[i],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) FinDashSectionHeader(title: title!),
        FinCard(
          child: slices.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    emptyLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: clx.ink3),
                  ),
                )
              : FinDonutChart(
                  slices: slices,
                  centerLabel: totalLabel,
                  size: 160,
                  showLegend: true,
                ),
        ),
      ],
    );
  }
}

class _BalancoMensalCard extends StatelessWidget {
  const _BalancoMensalCard({required this.resumo, this.elevated = false});
  final ResumoPeriodo resumo;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final maxV = [
      resumo.entradas,
      resumo.saidas,
      resumo.saldoMes.abs(),
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    return FinCard(
      elevated: elevated,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Bar(
                  h: 96 * (resumo.entradas / maxV).clamp(0.08, 1),
                  color: clx.finIncome,
                ),
                const SizedBox(width: 8),
                _Bar(
                  h: 96 * (resumo.saidas / maxV).clamp(0.08, 1),
                  color: clx.finExpense,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _BalRow('Receitas', resumo.entradas, clx.finIncome),
                const SizedBox(height: 10),
                _BalRow('Despesas', resumo.saidas, clx.finExpense),
                const Divider(height: 20),
                _BalRow('Balanço', resumo.saldoMes, null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.h, required this.color});
  final double h;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _BalRow extends StatelessWidget {
  const _BalRow(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        color == null
            ? FinMoneyText(value)
            : Text(
                formatCurrency(value),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
      ],
    );
  }
}

class _PendRow extends StatelessWidget {
  const _PendRow({required this.label, required this.amount});
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        FinMoneyText(amount),
      ],
    );
  }
}

class _EconomiaCard extends StatelessWidget {
  const _EconomiaCard({required this.pct, required this.resumo});
  final double pct;
  final ResumoPeriodo resumo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ok = resumo.saldoMes > 0 && resumo.entradas > 0;
    return FinCard(
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: clx.line2,
                  color: ok ? clx.finIncome : clx.ink3,
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              ok
                  ? 'Você economizou ${pct.toStringAsFixed(0)}% dos ganhos (${formatCurrency(resumo.saldoMes)}).'
                  : resumo.entradas <= 0
                      ? 'Você ainda não tem registro de receitas pagas neste mês.'
                      : 'As despesas superaram as receitas neste mês. Revise o planejamento.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: clx.ink2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreqPoint {
  const _FreqPoint(this.label, this.value);
  final String label;
  final double value;
}

List<_FreqPoint> _frequenciaGastos(List<FinLancamento> lancs, {int days = 7}) {
  final hoje = todayLocalDate();
  final end = DateTime.parse(hoje);
  final start = end.subtract(Duration(days: days - 1));
  final map = <String, int>{};
  for (var i = 0; i < days; i++) {
    final d = start.add(Duration(days: i));
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    map[key] = 0;
  }
  for (final l in lancs) {
    if (l.tipo != TipoLancamento.despesa || !isLancamentoRealizado(l)) continue;
    final d = dateOnly(l.data);
    if (map.containsKey(d)) {
      map[d] = map[d]! + (l.valor * 100).round();
    }
  }
  final keys = map.keys.toList()..sort();
  return [
    for (final k in keys)
      _FreqPoint('${k.substring(8, 10)}/${k.substring(5, 7)}', map[k]! / 100.0),
  ];
}

class _FreqChart extends StatelessWidget {
  const _FreqChart({required this.points});
  final List<_FreqPoint> points;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    if (points.every((p) => p.value == 0)) {
      return FinCard(
        child: SizedBox(
          height: 140,
          child: Center(
            child: Text(
              'Sem gastos no período.',
              style: TextStyle(color: clx.ink3),
            ),
          ),
        ),
      );
    }
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return FinCard(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (maxY * 1.2).clamp(10, double.infinity),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: clx.line, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (v, _) => Text(
                    v == 0 ? '0' : v.toStringAsFixed(0),
                    style: TextStyle(color: clx.ink3, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final i = v.round();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    if (i != 0 && i != points.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      points[i].label,
                      style: TextStyle(color: clx.ink3, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].value),
                ],
                isCurved: true,
                color: clx.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: clx.primary.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({
    required this.year,
    required this.month,
    required this.lancs,
  });
  final int year;
  final int month;
  final List<FinLancamento> lancs;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final y = year;
    final m = month;
    final byDay = <int, double>{};
    for (final l in lancs) {
      final d = dateOnly(l.data);
      if (!d.startsWith(
        '$y-${m.toString().padLeft(2, '0')}',
      )) {
        continue;
      }
      if (!isLancamentoRealizado(l)) continue;
      final day = int.parse(d.substring(8, 10));
      final signed =
          l.tipo == TipoLancamento.receita ? l.valor : -l.valor;
      byDay[day] = (byDay[day] ?? 0) + signed;
    }
    final firstWeekday = DateTime(y, m, 1).weekday % 7; // 0=Sun
    final daysInMonth = DateTime(y, m + 1, 0).day;

    return FinCard(
      child: Column(
        children: [
          Row(
            children: [
              for (final w in ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(color: clx.ink3, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < 6; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          final idx = row * 7 + col;
                          final day = idx - firstWeekday + 1;
                          if (day < 1 || day > daysInMonth) {
                            return const SizedBox(height: 36);
                          }
                          final v = byDay[day];
                          final bg = v == null
                              ? Colors.transparent
                              : v >= 0
                                  ? clx.finIncome.withValues(alpha: 0.25)
                                  : clx.finExpense.withValues(alpha: 0.3);
                          return Container(
                            height: 40,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: clx.ink2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (v != null)
                                  Text(
                                    v.abs() >= 1000
                                        ? '${(v.abs() / 1000).toStringAsFixed(1)}k'
                                        : v.abs().toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: v >= 0
                                          ? clx.finIncome
                                          : clx.finExpense,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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
