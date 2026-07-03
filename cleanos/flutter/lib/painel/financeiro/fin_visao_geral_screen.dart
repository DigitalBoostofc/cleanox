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

    return ListView(
      padding: EdgeInsets.all(mobile ? ClxSpace.x4 : ClxSpace.x6),
      children: [
        ...leadingChildren,
        FinKpiGrid(
          cards: [
            FinKpiCard(
              label: 'Entradas do mês',
              value: formatCurrency(resumo.entradas),
              color: clx.finIncome,
              icon: Icons.north_east_rounded,
              hint: 'Receitas realizadas',
            ),
            FinKpiCard(
              label: 'Saídas do mês',
              value: formatCurrency(resumo.saidas),
              color: clx.finExpense,
              icon: Icons.south_west_rounded,
              hint: 'Despesas realizadas',
            ),
            FinKpiCard(
              label: 'Saldo do mês',
              value: formatCurrency(resumo.saldoMes),
              color: resumo.saldoMes < 0 ? clx.finExpense : clx.primary,
              icon: Icons.equalizer_rounded,
              hint: 'Entradas − saídas',
            ),
            FinKpiCard(
              label: 'Saldo geral',
              value: formatCurrency(saldoTotal),
              color: saldoTotal < 0 ? clx.finExpense : clx.ink,
              icon: Icons.account_balance_outlined,
              hint: 'Disponível em contas',
            ),
          ],
        ),
        const SizedBox(height: ClxSpace.x5),
        // Ações rápidas.
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
          const SizedBox(height: ClxSpace.x5),
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
        const SizedBox(height: ClxSpace.x5),
        // Bloco 1: a receber | a pagar | maiores gastos.
        _ResponsiveRow(
          minColWidth: 300,
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
        // Bloco 2: receitas por origem | limites.
        _ResponsiveRow(
          minColWidth: 360,
          children: [
            _OrigemCard(lancs: lancs),
            _LimitesCard(lancs: lancs, limites: limites, cat: _cat),
          ],
        ),
      ],
    );
  }
}

/* ─────────────────────── layout responsivo ─────────────────────── */

/// Linha que vira coluna em telas estreitas (mantém cada filho >= [minColWidth]).
class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children, required this.minColWidth});

  final List<Widget> children;
  final double minColWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cabe = c.maxWidth >= minColWidth * children.length;
        if (!cabe) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: ClxSpace.x4),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: ClxSpace.x4),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
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

    // Mobile: grade fixa 2x2 (em vez do Wrap 3+1 que sobra "Importar" sozinho).
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
