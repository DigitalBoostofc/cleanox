/// fin_mais_screen.dart — Hub "Mais" do Financeiro v2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/models/financeiro.dart';
import 'fin_export.dart';
import 'fin_providers.dart';
import 'ui/fin_ui.dart';

class FinMaisScreen extends ConsumerWidget {
  const FinMaisScreen({super.key});

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final period = ref.read(finPeriodProvider);
    final lancs = await ref.read(finPeriodLancamentosProvider.future);
    if (!context.mounted) return;
    final cats = ref.read(finCategoriasProvider).valueOrNull ??
        const <FinCategoria>[];
    final contas =
        ref.read(finContasProvider).valueOrNull ?? const <FinConta>[];
    await finExportLancamentosCsv(
      context,
      lancs: lancs,
      catById: {for (final c in cats) c.id: c},
      contaById: {for (final c in contas) c.id: c},
      filename:
          'cleanox-financeiro-${period.year}-${period.month.toString().padLeft(2, '0')}.csv',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    return ColoredBox(
      color: clx.bg2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Mais opções',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            'Gerenciar o caixa da operação',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: clx.ink3,
                ),
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Gerenciar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: clx.ink3,
                ),
          ),
          const SizedBox(height: ClxSpace.x2),
          FinCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Item(
                  icon: Icons.account_balance_outlined,
                  label: 'Contas',
                  onTap: () => context.go('/painel/financeiro/carteiras'),
                ),
                _Item(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Categorias',
                  onTap: () => context.go('/painel/financeiro/categorias'),
                ),
                _Item(
                  icon: Icons.sell_outlined,
                  label: 'Tags',
                  onTap: () => context.go('/painel/financeiro/tags'),
                ),
                _Item(
                  icon: Icons.track_changes_outlined,
                  label: 'Objetivos',
                  onTap: () => context.go('/painel/financeiro/objetivos'),
                ),
                _Item(
                  icon: Icons.flag_outlined,
                  label: 'Planejamento / limites',
                  onTap: () => context.go('/painel/financeiro/planejamento'),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Acompanhar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: clx.ink3,
                ),
          ),
          const SizedBox(height: ClxSpace.x2),
          FinCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Item(
                  icon: Icons.groups_outlined,
                  label: 'Equipe / comissões',
                  onTap: () => context.go('/painel/financeiro/comissoes'),
                ),
                _Item(
                  icon: Icons.receipt_long_outlined,
                  label: 'A receber / A pagar',
                  onTap: () => context.go('/painel/financeiro/contas'),
                ),
                _Item(
                  icon: Icons.bar_chart_rounded,
                  label: 'Relatórios',
                  onTap: () => context.go('/painel/financeiro/relatorios'),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Exportar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: clx.ink3,
                ),
          ),
          const SizedBox(height: ClxSpace.x2),
          FinCard(
            padding: EdgeInsets.zero,
            child: _Item(
              icon: Icons.download_outlined,
              label: 'Exportar CSV do mês',
              onTap: () => _exportCsv(context, ref),
              last: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: clx.ink2),
          title: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: clx.ink3),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x4,
            vertical: 2,
          ),
        ),
        if (!last)
          Divider(height: 1, indent: 56, color: clx.line),
      ],
    );
  }
}
