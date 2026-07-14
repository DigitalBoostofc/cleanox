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
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final VoidCallback onNovaReceita;
  final VoidCallback onNovaDespesa;
  final VoidCallback onTransferencia;

  /// Layout de celular: reduz o padding e recebe o cabeçalho rolável.
  final bool mobile;

  /// APK "Fintech Clean" (doc 12): saldo geral vira [FintechBalanceHero] em
  /// vez de um card de KPI a mais na grade. A Web (`fintech=false`) preserva
  /// 100% do layout de 4 KPIs de hoje.
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
    final saldoTotal = saldoGeral(contas);
    final hoje = todayLocalDate();
    final receber = contasAReceber(pendentes, hoje).take(5).toList();
    final pagar = contasAPagar(pendentes, hoje).take(5).toList();

    final entradasCard = FinKpiCard(
      label: 'Entradas do mês',
      value: formatCurrency(resumo.entradas),
      color: clx.finIncome,
      icon: Icons.north_east_rounded,
      hint: 'Receitas realizadas',
    );
    final saidasCard = FinKpiCard(
      label: 'Saídas do mês',
      value: formatCurrency(resumo.saidas),
      color: clx.finExpense,
      icon: Icons.south_west_rounded,
      hint: 'Despesas realizadas',
    );
    final saldoMesCard = FinKpiCard(
      label: 'Saldo do mês',
      value: formatCurrency(resumo.saldoMes),
      color: resumo.saldoMes < 0 ? clx.finExpense : clx.primary,
      icon: Icons.equalizer_rounded,
      hint: 'Entradas − saídas',
    );

    // Easypay (APK): hero + mini KPIs + gráfico de fluxo animado.
    final chartGroups = _fluxoUltimosMeses(lancs);
    final kpiSection = fintech
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FintechBalanceHero(
                label: 'Saldo geral',
                value: formatCurrency(saldoTotal),
                hint: 'Disponível em contas',
              ),
              const SizedBox(height: ClxSpace.x4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClxFadeSlide(
                      delay: const Duration(milliseconds: 40),
                      child: entradasCard,
                    ),
                  ),
                  const SizedBox(width: ClxSpace.x3),
                  Expanded(
                    child: ClxFadeSlide(
                      delay: const Duration(milliseconds: 80),
                      child: saidasCard,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ClxSpace.x3),
              ClxFadeSlide(
                delay: const Duration(milliseconds: 120),
                child: FinKpiCard(
                  label: 'Saldo do mês',
                  value: formatCurrency(resumo.saldoMes),
                  color: resumo.saldoMes < 0 ? clx.finExpense : clx.primary,
                  icon: Icons.equalizer_rounded,
                  hint: 'Entradas − saídas',
                  wide: true,
                ),
              ),
              if (chartGroups.isNotEmpty) ...[
                const SizedBox(height: ClxSpace.x4),
                ClxFadeSlide(
                  delay: const Duration(milliseconds: 160),
                  child: ClxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fluxo do período',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: clx.ink,
                              ),
                        ),
                        const SizedBox(height: ClxSpace.x3),
                        FinGroupedBarChart(groups: chartGroups, height: 180),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          )
        : FinKpiGrid(
            cards: [
              entradasCard,
              saidasCard,
              saldoMesCard,
              FinKpiCard(
                label: 'Saldo geral',
                value: formatCurrency(saldoTotal),
                color: saldoTotal < 0 ? clx.finExpense : clx.ink,
                icon: Icons.account_balance_outlined,
                hint: 'Disponível em contas',
              ),
            ],
          );

    // Desktop: grid denso em largura total (sem faixas vazias laterais).
    // Mobile: coluna simples.
    return ListView(
      padding: EdgeInsets.all(mobile ? ClxSpace.x4 : ClxSpace.x5),
      children: [
        ...leadingChildren,
        kpiSection,
        const SizedBox(height: ClxSpace.x4),
        ClxCard(
          child: _QuickActions(
            onNovaReceita: onNovaReceita,
            onNovaDespesa: onNovaDespesa,
            onTransferencia: onTransferencia,
            onImportar: () => showClxToast(
              context,
              'Importação — em breve.',
              type: ToastType.info,
            ),
          ),
        ),
        if (lancs.isEmpty) ...[
          const SizedBox(height: ClxSpace.x4),
          const ClxCard(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: 'Sem movimentações neste mês',
              message:
                  'Os gráficos do período aparecem vazios. As contas a pagar/'
                  'receber abaixo consideram todos os períodos.',
            ),
          ),
        ],
        const SizedBox(height: ClxSpace.x4),
        // Linha 1: a receber | a pagar | maiores gastos (3 colunas em desktop).
        _ResponsiveRow(
          minColWidth: 260,
          children: [
            _PreviewCard(
              title: 'Contas a receber',
              badge: '${receber.length} próximas',
              badgeColor: clx.finIncome,
              items: receber,
              kind: TipoLancamento.receita,
              cat: _cat,
            ),
            _PreviewCard(
              title: 'Contas a pagar',
              badge: '${pagar.length} próximas',
              badgeColor: clx.finExpense,
              items: pagar,
              kind: TipoLancamento.despesa,
              cat: _cat,
            ),
            _GastosCard(lancs: lancs, cat: _cat),
          ],
        ),
        const SizedBox(height: ClxSpace.x4),
        // Linha 2: receitas por origem | limites | fluxo (preenche a largura).
        _ResponsiveRow(
          minColWidth: 280,
          children: [
            _OrigemCard(lancs: lancs),
            _LimitesCard(lancs: lancs, limites: limites, cat: _cat),
            if (!mobile && !fintech && chartGroups.isNotEmpty)
              ClxCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fluxo do período',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.ink,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    FinGroupedBarChart(groups: chartGroups, height: 200),
                  ],
                ),
              ),
          ],
        ),
        // Mobile/fintech: fluxo já está no hero; desktop sem 3ª col acima ok.
        if ((mobile || fintech) && chartGroups.isNotEmpty) ...[
          const SizedBox(height: ClxSpace.x4),
          ClxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fluxo do período',
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
        // Respiro final menor — evita “mar” de branco sob o conteúdo.
        const SizedBox(height: ClxSpace.x4),
      ],
    );
  }
}

/// Agrupa lançamentos do período em até 5 buckets por dia (label dd/MM)
/// para o gráfico de barras Easypay. Se houver poucos dias, mostra o que tiver.
List<FinBarGroup> _fluxoUltimosMeses(List<FinLancamento> lancs) {
  if (lancs.isEmpty) return const [];
  final byDay = <String, ({double rec, double desp})>{};
  for (final l in lancs) {
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

/* ─────────────────────── layout responsivo ─────────────────────── */

/// Linha que vira coluna em telas estreitas (mantém cada filho >= [minColWidth]).
/// Em desktop, filhos [Expanded] ocupam a **largura total** (sem sobras laterais).
class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children, required this.minColWidth});

  final List<Widget> children;
  final double minColWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = children.length;
        final cabe = n > 0 && c.maxWidth >= minColWidth * n;
        if (!cabe) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: ClxSpace.x4),
                children[i],
              ],
            ],
          );
        }
        // Colunas de mesma altura SEM IntrinsicHeight: os cards contêm
        // LayoutBuilder (donut responsivo em fin_charts.dart), e o Flutter
        // proíbe consultar intrínsecos de um LayoutBuilder (crash em debug,
        // altura 0 em release). O layout custom mede as colunas e estica
        // todas para a mais alta, sem intrínsecos.
        return _EqualHeightRow(gap: ClxSpace.x4, children: children);
      },
    );
  }
}

/// Linha de colunas de LARGURA igual esticadas para a altura da mais alta.
/// Substitui `IntrinsicHeight(Row(stretch))`, que não suporta filhos com
/// `LayoutBuilder`. Dois passes: mede a altura natural de cada coluna na
/// largura final e relayouta com a altura máxima (tight).
class _EqualHeightRow extends MultiChildRenderObjectWidget {
  const _EqualHeightRow({required this.gap, required super.children});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class _EqualHeightRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualHeightRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualHeightRowParentData> {
  _RenderEqualHeightRow(this._gap);

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualHeightRowParentData) {
      child.parentData = _EqualHeightRowParentData();
    }
  }

  @override
  void performLayout() {
    final n = childCount;
    if (n == 0) {
      size = constraints.smallest;
      return;
    }
    final colW = (constraints.maxWidth - _gap * (n - 1)) / n;
    final colConstraints = BoxConstraints(minWidth: colW, maxWidth: colW);

    // 1º passe: altura natural de cada coluna na largura final.
    var maxH = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(colConstraints, parentUsesSize: true);
      if (child.size.height > maxH) maxH = child.size.height;
      child = (child.parentData! as _EqualHeightRowParentData).nextSibling;
    }
    maxH = constraints.constrainHeight(maxH);

    // 2º passe: estica todas para a altura da mais alta e posiciona.
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: colW, height: maxH),
        parentUsesSize: true,
      );
      (child.parentData! as _EqualHeightRowParentData).offset = Offset(x, 0);
      x += colW + _gap;
      child = (child.parentData! as _EqualHeightRowParentData).nextSibling;
    }
    size = Size(constraints.maxWidth, maxH);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/* ─────────────────────── ações rápidas ─────────────────────── */

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNovaReceita,
    required this.onNovaDespesa,
    required this.onTransferencia,
    required this.onImportar,
  });

  final VoidCallback onNovaReceita;
  final VoidCallback onNovaDespesa;
  final VoidCallback onTransferencia;
  final VoidCallback onImportar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final novaReceita = _QuickAction(
      icon: Icons.add_rounded,
      label: 'Nova receita',
      fg: clx.success,
      bg: clx.successBg,
      onTap: onNovaReceita,
    );
    final novaDespesa = _QuickAction(
      icon: Icons.remove_rounded,
      label: 'Nova despesa',
      fg: clx.error,
      bg: clx.errorBg,
      onTap: onNovaDespesa,
    );
    final transferencia = _QuickAction(
      icon: Icons.swap_horiz_rounded,
      label: 'Transferência',
      fg: clx.info,
      bg: clx.infoBg,
      onTap: onTransferencia,
    );
    final importar = _QuickAction(
      icon: Icons.file_download_outlined,
      label: 'Importar',
      fg: clx.primary,
      bg: clx.primary.withValues(alpha: 0.14),
      onTap: onImportar,
    );

    // Mobile / Easypay: grade fixa 2x2.
    if (finIsMobile(context)) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [novaReceita, novaDespesa],
          ),
          const SizedBox(height: ClxSpace.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [transferencia, importar],
          ),
        ],
      );
    }

    return Wrap(
      spacing: ClxSpace.x3,
      runSpacing: ClxSpace.x3,
      alignment: WrapAlignment.spaceAround,
      children: [novaReceita, novaDespesa, transferencia, importar],
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
            for (final p in items)
              Padding(
                padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                child: _PreviewRow(pendente: p, kind: kind, cat: cat),
              ),
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
      children: [
        FinCategoriaAvatar(categoria: cat(l.categoriaId), size: 32),
        const SizedBox(width: ClxSpace.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(color: clx.ink),
              ),
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
  const _GastosCard({required this.lancs, required this.cat});

  final List<FinLancamento> lancs;
  final FinCategoria? Function(String) cat;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final gastos = gastoPorCategoria(lancs);
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Maiores gastos do mês'),
          const SizedBox(height: ClxSpace.x4),
          if (gastos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  'Nenhuma despesa paga no período.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                ),
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
    final top = entries.take(5).toList();
    final resto = entries.skip(5).fold<double>(0, (a, e) => a + e.value);
    final cores = finSeriesColors(context, top.length + 1);
    final slices = <FinSlice>[
      for (var i = 0; i < top.length; i++)
        FinSlice(
          label: cat(top[i].key)?.nome ?? 'Categoria',
          value: top[i].value,
          color: cores[i],
        ),
      if (resto > 0)
        FinSlice(label: 'Outros', value: resto, color: cores.last),
    ];
    return FinDonutChart(slices: slices, centerLabel: 'Gastos');
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Receitas por origem'),
          const SizedBox(height: ClxSpace.x4),
          if (total <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  'Nenhuma receita recebida no período.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else
            FinDonutChart(
              centerLabel: 'Receitas',
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
              '${formatCurrency(progresso.gasto)} / '
              '${formatCurrency(progresso.limite)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: estourou ? clx.error : clx.ink3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: ClxSpace.x1),
        FinProgressBar(value: progresso.pct),
      ],
    );
  }
}
