/// fin_objetivos_screen.dart — Objetivos (placeholder até migração fin_objetivos).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import 'ui/fin_ui.dart';

class FinObjetivosScreen extends StatelessWidget {
  const FinObjetivosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ColoredBox(
      color: clx.bg2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          Text(
            'Objetivos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: ClxSpace.x4),
          FinEmptyCta(
            icon: Icons.track_changes_outlined,
            message: 'Opa! Você ainda não possui objetivos definidos.',
            hint:
                'Em breve você poderá cadastrar metas de caixa (coleção fin_objetivos). Por enquanto use o planejamento por limites.',
            ctaLabel: 'Ir ao planejamento',
            onCta: () => context.go('/painel/financeiro/planejamento'),
          ),
        ],
      ),
    );
  }
}
