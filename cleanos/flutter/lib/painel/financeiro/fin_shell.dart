/// fin_shell.dart — Casco do módulo Financeiro v2.
///
/// Mobile / web estreita: bottom nav Principal · Extrato · Equipe · Mais.
/// Desktop: rail Principal · Extrato · Equipe · A pagar · Relatórios · Mais.
///
/// Slugs legados (`visao-geral`, `lancamentos`, `planejamento`, …) redirecionam.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surface_provider.dart';
import '../../core/design/design.dart';
import 'carteiras/fin_carteiras_screen.dart';
import 'categorias/fin_categorias_screen.dart';
import 'fin_comissoes_screen.dart';
import 'fin_common.dart';
import 'fin_contas_pagar_receber_screen.dart';
import 'fin_mais_screen.dart';
import 'fin_objetivos_screen.dart';
import 'fin_planejamento_screen.dart';
import 'fin_principal_screen.dart';
import 'fin_relatorios_screen.dart';
import 'fin_tags_screen.dart';
import 'lancamentos/fin_transacoes_screen.dart';
import 'lancamentos/lancamento_form.dart';

/// Abas / deep-links do Financeiro v2.
enum FinTab {
  principal('Principal', 'principal'),
  transacoes('Transações', 'transacoes'),
  comissoes('Equipe / comissões', 'comissoes'),
  contas('A receber / A pagar', 'contas'),
  relatorios('Relatórios', 'relatorios'),
  mais('Mais', 'mais'),
  // Deep links do hub Mais / legado (fora do menu lateral)
  categorias('Categorias', 'categorias'),
  objetivos('Objetivos', 'objetivos'),
  tags('Tags', 'tags'),
  carteiras('Carteiras', 'carteiras'),
  planejamento('Planejamento', 'planejamento'),
  limites('Limites', 'limites');

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
      case 'comissoes':
        return FinTab.comissoes;
      case 'contas':
        return FinTab.contas;
      case 'relatorios':
        return FinTab.relatorios;
      case 'mais':
        return FinTab.mais;
      case 'categorias':
        return FinTab.categorias;
      case 'objetivos':
        return FinTab.objetivos;
      case 'tags':
        return FinTab.tags;
      case 'carteiras':
        return FinTab.carteiras;
      case 'planejamento':
        return FinTab.planejamento;
      case 'limites':
        return FinTab.limites;
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
      'comissoes',
      'contas',
      'relatorios',
      'mais',
      'categorias',
      'objetivos',
      'tags',
      'carteiras',
      'planejamento',
      'limites',
    };
    return known.contains(slug);
  }

  /// Abas primárias do rail / bottom nav (destaque quando abertas).
  FinTab get navRoot => switch (this) {
        FinTab.principal => FinTab.principal,
        FinTab.transacoes => FinTab.transacoes,
        FinTab.comissoes => FinTab.comissoes,
        FinTab.contas => FinTab.contas,
        FinTab.relatorios => FinTab.relatorios,
        // Legado / secundário → Mais
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
        'limites' => 'planejamento', // alias; fora do menu, deep link ainda abre
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
    // APK + web estreita já têm bottom nav Easypay (Início/OS/Carteira).
    // NÃO empilhar segundo bottom nav + FAB — vira UX quebrada no celular.
    final embeddedInFintech = ref.watch(isFintechCleanProvider) ||
        ref.watch(isNarrowWebProvider);
    final body = _body(active);

    void goTab(FinTab t) => context.go('/painel/financeiro/${t.slug}');

    if (mobile && embeddedInFintech) {
      return ColoredBox(
        color: clx.bg2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FintechSubNav(
              active: active.navRoot,
              onSelect: goTab,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

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
            onSelect: goTab,
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
            onSelect: goTab,
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
        FinTab.planejamento || FinTab.limites =>
          const FinPlanejamentoScreen(),
        FinTab.mais => const FinMaisScreen(),
        FinTab.carteiras => const FinCarteirasScreen(),
        FinTab.categorias => const FinCategoriasScreen(),
        FinTab.comissoes => const FinComissoesScreen(),
        FinTab.relatorios => const FinRelatoriosScreen(),
        FinTab.contas => const FinContasPagarReceberScreen(),
        FinTab.objetivos => const FinObjetivosScreen(),
        FinTab.tags => const FinTagsScreen(),
      };
}

/// Sub-nav embutida no casco fintech — segmento premium (sem 2º bottom bar).
class _FintechSubNav extends StatelessWidget {
  const _FintechSubNav({required this.active, required this.onSelect});

  final FinTab active;
  final ValueChanged<FinTab> onSelect;

  static const _items = [
    (FinTab.principal, Icons.home_rounded, 'Principal'),
    (FinTab.transacoes, Icons.swap_horiz_rounded, 'Extrato'),
    (FinTab.comissoes, Icons.groups_outlined, 'Equipe'),
    (FinTab.mais, Icons.grid_view_rounded, 'Mais'),
  ];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final r = context.clxR;
    // Contas / relatórios caem em "Mais" no chip (sem espaço para 6 abas).
    final selected = switch (active) {
      FinTab.principal => FinTab.principal,
      FinTab.transacoes => FinTab.transacoes,
      FinTab.comissoes => FinTab.comissoes,
      _ => FinTab.mais,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(r.pagePadH, r.s(4), r.pagePadH, r.s(10)),
      child: Container(
        padding: EdgeInsets.all(r.s(4)),
        decoration: BoxDecoration(
          color: clx.bg,
          borderRadius: BorderRadius.circular(r.r(16)),
          border: Border.all(color: clx.line),
          boxShadow: [
            BoxShadow(
              color: clx.ink.withValues(alpha: 0.04),
              blurRadius: r.s(12),
              offset: Offset(0, r.s(4)),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in _items)
              Expanded(
                child: _SegTab(
                  icon: item.$2,
                  label: item.$3,
                  selected: item.$1 == selected,
                  onTap: () => onSelect(item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final r = context.clxR;
    final radius = BorderRadius.circular(r.r(12));
    return Material(
      color: selected ? clx.primary : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: ClxMotion.shortDuration,
          padding: EdgeInsets.symmetric(vertical: r.s(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: r.s(18),
                color: selected ? clx.onPrimary : clx.ink3,
              ),
              SizedBox(height: r.s(2)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: r.sp(10),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? clx.onPrimary : clx.ink3,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.active, required this.onSelect});

  final FinTab active;
  final ValueChanged<FinTab> onSelect;

  static const _items = [
    (FinTab.principal, Icons.home_outlined, Icons.home_rounded, 'Principal'),
    (
      FinTab.transacoes,
      Icons.swap_horiz_outlined,
      Icons.swap_horiz_rounded,
      'Extrato',
    ),
    (FinTab.comissoes, Icons.groups_outlined, Icons.groups_rounded, 'Equipe'),
    (
      FinTab.mais,
      Icons.more_horiz_rounded,
      Icons.more_horiz_rounded,
      'Mais',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final selected = switch (active) {
      FinTab.principal => FinTab.principal,
      FinTab.transacoes => FinTab.transacoes,
      FinTab.comissoes => FinTab.comissoes,
      _ => FinTab.mais,
    };
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
                label: _items[i].$4,
                icon: selected == _items[i].$1
                    ? _items[i].$3
                    : _items[i].$2,
                selected: selected == _items[i].$1,
                onTap: () => onSelect(_items[i].$1),
              ),
            ),
          const SizedBox(width: 56), // FAB central
          for (var i = 2; i < 4; i++)
            Expanded(
              child: _NavBtn(
                label: _items[i].$4,
                icon: selected == _items[i].$1
                    ? _items[i].$3
                    : _items[i].$2,
                selected: selected == _items[i].$1,
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

  /// Menu lateral: Principal · Extrato · Equipe · A pagar · Relatórios · Mais.
  /// (Planejamento/limites e Carteiras removidos do nav.)
  static const _main = [
    (FinTab.principal, Icons.home_rounded),
    (FinTab.transacoes, Icons.swap_horiz_rounded),
    (FinTab.comissoes, Icons.groups_outlined),
    (FinTab.contas, Icons.receipt_long_outlined),
    (FinTab.relatorios, Icons.bar_chart_rounded),
    (FinTab.mais, Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final highlight = active.navRoot;

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
