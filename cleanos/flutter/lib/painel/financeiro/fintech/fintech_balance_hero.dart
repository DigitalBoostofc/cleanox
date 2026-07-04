/// fintech_balance_hero.dart — Hero de saldo do Financeiro (Opção B, doc 12
/// §2.5, Onda 3): único elemento das telas do Financeiro que a troca de
/// `ThemeData` sozinha não cobre — o mock inverte a superfície (fundo `ink`,
/// texto `bg`) mesmo no tema claro, o que não é um papel padrão do
/// `ColorScheme`/`CleanoxColors` (nenhum dos dois define "card com cores
/// trocadas"). Usado só quando `isFintechCleanProvider` é true; a Web nunca
/// importa este arquivo.
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Card escuro (claro no tema escuro — inversão proposital, ver doc 12 §2.5)
/// com o saldo em destaque. `label`/`hint` usam `clx.bg`/`clx.bg2` com opacidade
/// reduzida para contraste AA sobre `clx.ink`.
class FintechBalanceHero extends StatelessWidget {
  const FintechBalanceHero({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon = Icons.account_balance_wallet_outlined,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    // Texto sobre o fundo invertido: `clx.bg` é o par de contraste de `clx.ink`
    // nos dois temas (ink claro → bg escuro vira o texto; ink escuro → bg claro
    // vira o texto), preservando AA sem precisar de um token novo.
    final onInk = clx.bg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x5,
        vertical: ClxSpace.x5,
      ),
      decoration: BoxDecoration(color: clx.ink, borderRadius: ClxRadii.rXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: onInk.withValues(alpha: 0.65)),
              const SizedBox(width: ClxSpace.x1),
              Text(
                label.toUpperCase(),
                style: tt.labelMedium?.copyWith(
                  color: onInk.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.displayLarge?.copyWith(color: onInk, letterSpacing: -1),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: onInk.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
