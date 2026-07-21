/// fin_shell.dart — Casco do módulo Financeiro v2.
///
/// Mobile / web estreita: bottom nav Principal · Transações · FAB · Planejamento · Mais.
/// Desktop: rail interno de ícones + corpo.
///
/// Slugs legados (`visao-geral`, `lancamentos`, …) redirecionam para os novos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import 'carteiras/fin_carteiras_screen.dart';
import 'categorias/fin_categorias_screen.dart';
import 'fin_comissoes_screen.dart';
import 'fin_common.dart';
import 'fin_contas_pagar_receber_screen.dart';
import 'fin_limites_screen.dart';
import 'fin_mais_screen.dart';
import 'fin_objetivos_screen.dart';
import 'fin_principal_screen.dart';
import 'fin_relatorios_screen.dart';
import 'lancamentos/fin_transacoes_screen.dart';
import 'lancamentos/lancamento_form.dart';

/// Abas / deep-links do Financeiro v2.
enum FinTab {
  principal('Principal', 'principal'),
  transacoes('Transações', 'transacoes'),
  planejamento('Planejamento', 'planejamento'),
  mais('Mais', 'mais'),
  // Deep links do hub Mais / legado
  carteiras('Carteiras', 'carteiras'),
  categorias('Categorias', 'categorias'),
  comissoes('Equipe', 'comissoes'),
  relatorios('Relatórios', 'relatorios'),
  contas('A receber / A pagar', 'contas'),
  limites('Limites', 'limites'),
  objetivos('Objetivos', 'objetivos');

  const FinTab(this.label, this.slug);
  final String label;
  final String slug;

  /// Resolve slug (inclui aliases legados).
  static FinTab fromSlug(String? slug) {
    switch (slug) {
      case null:
      case '':
      case 'principal':
      case 'visao-geral':
        return FinTab.principal;
      case 'transacoes':
      case 'lancamentos':
        return FinTab.transacoes;
      case 'planejamento':
      case 'limites':
        return FinTab.planejamento;
      case 'mais':
        return FinTab.mais;
      case 'carteiras':
        return FinTab.carteiras;
      case 'categorias':
        return FinTab.categorias;
      case 'comissoes':
        return FinTab.comissoes;
      case 'relatorios':
        return FinTab.relatorios;
      case 'contas':
        return FinTab.contas;
      case 'objetivos':
        return FinTab.objetivos;
      default:
        return FinTab.principal;
    }
  }

  static bool isKnownSlug(String? slug) {
    if (slug == null || slug.isEmpty) return false;
    const known = {
      'principal',
      'visao-geral',
      'transacoes',
      'lancamentos',
      'planejamento',
      'limites',
      'mais',
      'carteiras',
      'categorias',
      'comissoes',
      'relatorios',
      'contas',
      'objetivos',
    };
    return known.contains(slug);
  }

  /// Aba do bottom nav (4 itens). Deep links caem em Mais.
  FinTab get navRoot => switch (this) {
        FinTab.principal => FinTab.principal,
        FinTab.transacoes => FinTab.transacoes,
        FinTab.planejamento || FinTab.limites => FinTab.planejamento,
        _ => FinTab.mais,
      };
}

class FinanceiroShell extends ConsumerStatefulWidget {
  const FinanceiroShell({super.key, this.tabSlug});

  final String? tabSlug;

  @override
  ConsumerState<FinanceiroShell> createState() => _FinanceiroShellState();
}

class _FinanceiroShellState extends ConsumerState<FinanceiroShell> {
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

  void _canonicalizeSlug() {
    final slug = widget.tabSlug;
    if (FinTab.isKnownSlug(slug)) {
      // Normaliza aliases legados para slug canônico.
      final tab = FinTab.fromSlug(slug);
      final canonical = switch (slug) {
        'visao-geral' => 'principal',
        'lancamentos' => 'transacoes',
        'limites' => 'planejamento',
        _ => null,
      };
      if (canonical != null && slug != canonical) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/painel/financeiro/$canonical');
        });
      }
      // silencia analyzer se tab unused
      assert(tab.slug.isNotEmpty);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/painel/financeiro/${FinTab.principal.slug}');
      }
    });
  }

  Future<void> _fabAdd() async {
    final saved = await showLancamentoForm(context);
    if (saved == true && mounted) {
      showClxToast(context, 'Lançamento criado.', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final active = FinTab.fromSlug(widget.tabSlug);
    final mobile = finIsMobile(context);
    final body = _body(active);

    if (mobile) {
      return ColoredBox(
        color: clx.bg2,
        child: Scaffold(
          backgroundColor: clx.bg2,
          body: body,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: _fabAdd,
            tooltip: 'Novo lançamento',
            child: const Icon(Icons.add_rounded),
          ),
          bottomNavigationBar: _MobileNav(
            active: active.navRoot,
            onSelect: (t) => context.go('/painel/financeiro/${t.slug}'),
          ),
        ),
      );
    }

    return ColoredBox(
      color: clx.bg2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopRail(
            active: active,
            onSelect: (t) => context.go('/painel/financeiro/${t.slug}'),
            onAdd: _fabAdd,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _body(FinTab tab) => switch (tab) {
        FinTab.principal => const FinPrincipalScreen(),
        FinTab.transacoes => const FinTransacoesScreen(),
        FinTab.planejamento || FinTab.limites => const FinLimitesScreen(),
        FinTab.mais => const FinMaisScreen(),
        FinTab.carteiras => const FinCarteirasScreen(),
        FinTab.categorias => const FinCategoriasScreen(),
        FinTab.comissoes => const FinComissoesScreen(),
        FinTab.relatorios => const FinRelatoriosScreen(),
        FinTab.contas => const FinContasPagarReceberScreen(),
        FinTab.objetivos => const FinObjetivosScreen(),
      };
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.active, required this.onSelect});

  final FinTab active;
  final ValueChanged<FinTab> onSelect;

  static const _items = [
    (FinTab.principal, Icons.home_outlined, Icons.home_rounded),
    (FinTab.transacoes, Icons.swap_horiz_outlined, Icons.swap_horiz_rounded),
    (FinTab.planejamento, Icons.flag_outlined, Icons.flag_rounded),
    (FinTab.mais, Icons.more_horiz_rounded, Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return BottomAppBar(
      color: clx.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      padding: EdgeInsets.zero,
      height: 64,
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: _NavBtn(
                label: _items[i].$1.label,
                icon: active == _items[i].$1
                    ? _items[i].$3
                    : _items[i].$2,
                selected: active == _items[i].$1,
                onTap: () => onSelect(_items[i].$1),
              ),
            ),
          const SizedBox(width: 56), // FAB central
          for (var i = 2; i < 4; i++)
            Expanded(
              child: _NavBtn(
                label: _items[i].$1.label,
                icon: active == _items[i].$1
                    ? _items[i].$3
                    : _items[i].$2,
                selected: active == _items[i].$1,
                onTap: () => onSelect(_items[i].$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = selected ? clx.primary : clx.ink3;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.active,
    required this.onSelect,
    required this.onAdd,
  });

  final FinTab active;
  final ValueChanged<FinTab> onSelect;
  final VoidCallback onAdd;

  static const _main = [
    (FinTab.principal, Icons.home_rounded),
    (FinTab.transacoes, Icons.swap_horiz_rounded),
    (FinTab.planejamento, Icons.flag_rounded),
    (FinTab.carteiras, Icons.account_balance_wallet_rounded),
    (FinTab.mais, Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final root = active.navRoot;
    // Destaca deep link de carteiras no ícone carteiras
    FinTab highlight = root;
    if (active == FinTab.carteiras) highlight = FinTab.carteiras;

    return Container(
      width: 72,
      color: clx.bg,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Material(
              color: clx.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAdd,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final item in _main)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Tooltip(
                  message: item.$1.label,
                  child: InkWell(
                    borderRadius: ClxRadii.rMd,
                    onTap: () => onSelect(item.$1),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: highlight == item.$1
                            ? clx.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: ClxRadii.rMd,
                      ),
                      child: Icon(
                        item.$2,
                        color: highlight == item.$1 ? clx.primary : clx.ink3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
