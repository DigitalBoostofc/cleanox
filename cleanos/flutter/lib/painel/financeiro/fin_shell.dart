/// fin_shell.dart — Casco do módulo Financeiro (Onda 4 · Painel).
///
/// Espelha `FinanceiroLayout.tsx`: sub-navegação horizontal por ABAS + corpo. O
/// título "Financeiro" já é exibido pela topbar do PainelShell; aqui vive só a
/// sub-nav e a tela ativa. Cada aba é uma URL deep-linkável
/// (`/painel/financeiro/:tab`): a aba ativa vem do slug da rota ([tabSlug]) e a
/// sub-nav navega com `context.go(...)`.
///
/// Só a ABA ATIVA é construída (switch, não IndexedStack): evita disparar os
/// controllers/fetches das 7 telas de uma vez. O chunk inteiro (fl_chart incluso)
/// já é deferred pela rota — as telas podem ser importadas eager aqui.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import 'carteiras/fin_carteiras_screen.dart';
import 'categorias/fin_categorias_screen.dart';
import 'fin_contas_pagar_receber_screen.dart';
import 'fin_limites_screen.dart';
import 'fin_relatorios_screen.dart';
import 'fin_comissoes_screen.dart';
import 'fin_visao_geral_screen.dart';
import 'lancamentos/fin_lancamentos_screen.dart';

/// Abas do Financeiro (ordem/rótulos idênticos ao `FinanceiroLayout` + Comissões).
/// O [slug] é o segmento de URL da aba (`/painel/financeiro/<slug>`).
enum FinTab {
  visaoGeral('Visão geral', 'visao-geral'),
  lancamentos('Lançamentos', 'lancamentos'),
  contas('Contas a pagar/receber', 'contas'),
  comissoes('Comissões', 'comissoes'),
  categorias('Categorias', 'categorias'),
  relatorios('Relatórios', 'relatorios'),
  limites('Limites', 'limites'),
  carteiras('Carteiras', 'carteiras');

  const FinTab(this.label, this.slug);
  final String label;
  final String slug;

  /// Resolve o slug de URL para a aba (fallback: [FinTab.visaoGeral]).
  static FinTab fromSlug(String? slug) => FinTab.values.firstWhere(
    (t) => t.slug == slug,
    orElse: () => FinTab.visaoGeral,
  );

  /// `true` se [slug] casa uma aba real. Usado pela rota para canonicalizar
  /// slugs desconhecidos (`/painel/financeiro/lixo`) → `visao-geral`, em vez de
  /// só cair no fallback mantendo a URL suja na barra de endereços.
  static bool isKnownSlug(String? slug) =>
      FinTab.values.any((t) => t.slug == slug);
}

class FinanceiroShell extends StatefulWidget {
  const FinanceiroShell({super.key, this.tabSlug});

  /// Slug da aba ativa (vem do path param `/painel/financeiro/:tab`).
  final String? tabSlug;

  @override
  State<FinanceiroShell> createState() => _FinanceiroShellState();
}

class _FinanceiroShellState extends State<FinanceiroShell> {
  @override
  void initState() {
    super.initState();
    _canonicalizeSlug();
  }

  @override
  void didUpdateWidget(FinanceiroShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabSlug != widget.tabSlug) _canonicalizeSlug();
  }

  /// Slug desconhecido (`/painel/financeiro/lixo`, bookmark velho) → reescreve a
  /// URL para a aba default. Renderizamos a Visão geral (fallback do [fromSlug])
  /// enquanto o `context.go` corrige o endereço no próximo frame — assim a barra
  /// de endereços nunca fica presa num slug sujo.
  void _canonicalizeSlug() {
    if (FinTab.isKnownSlug(widget.tabSlug)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/painel/financeiro/${FinTab.visaoGeral.slug}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final active = FinTab.fromSlug(widget.tabSlug);
    // Ocupa o card flutuante inteiro (borda completa até embaixo).
    return ColoredBox(
      color: clx.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SubNav(active: active),
          Expanded(child: _body(active)),
        ],
      ),
    );
  }

  Widget _body(FinTab tab) => switch (tab) {
    FinTab.visaoGeral => const FinVisaoGeralScreen(),
    FinTab.lancamentos => const FinLancamentosScreen(),
    FinTab.contas => const FinContasPagarReceberScreen(),
    FinTab.comissoes => const FinComissoesScreen(),
    FinTab.categorias => const FinCategoriasScreen(),
    FinTab.relatorios => const FinRelatoriosScreen(),
    FinTab.limites => const FinLimitesScreen(),
    FinTab.carteiras => const FinCarteirasScreen(),
  };
}

/// Sub-nav horizontal rolável (chips-aba com sublinhado no ativo).
class _SubNav extends StatelessWidget {
  const _SubNav({required this.active});

  final FinTab active;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      decoration: BoxDecoration(
        color: clx.bg,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x4),
        child: Row(
          children: [
            for (final tab in FinTab.values)
              _SubNavItem(
                label: tab.label,
                active: tab == active,
                onTap: () => context.go('/painel/financeiro/${tab.slug}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubNavItem extends StatelessWidget {
  const _SubNavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: ClxLayout.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x3),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? clx.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: active ? clx.ink : clx.ink3,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
