/// fin_mais_screen.dart — Hub "Mais" do Financeiro v2.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import 'ui/fin_ui.dart';

class FinMaisScreen extends StatelessWidget {
  const FinMaisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ColoredBox(
      color: clx.bg2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
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
                  icon: Icons.track_changes_outlined,
                  label: 'Objetivos',
                  onTap: () => context.go('/painel/financeiro/objetivos'),
                ),
                _Item(
                  icon: Icons.flag_outlined,
                  label: 'Planejamento / limites',
                  onTap: () => context.go('/painel/financeiro/planejamento'),
                ),
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
