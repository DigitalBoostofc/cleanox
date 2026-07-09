/// painel_shell.dart — Casco do PAINEL admin (Flutter Web + APK).
///
/// Layouts:
///   • APK (`isFintechClean`) → [FintechPainelScaffold] (bottom nav 5 itens);
///   • Web &lt; 600dp → mesmo casco fintech + tema Fintech Clean;
///   • Web ≥ 1024px → sidebar fixa; 600–1023dp → NavigationRail;
/// Conteúdo limitado a ~1200px (`ClxLayout.contentMaxW`).
///
/// ── ROTAS ANINHADAS (StatefulShellRoute) ────────────────────────────────────
/// Cada seção é um branch do `StatefulShellRoute.indexedStack` do `/painel`
/// (definido em `painel/painel_routes.dart`). Este casco recebe o
/// [StatefulNavigationShell] (o IndexedStack que preserva o estado das seções) e
/// só desenha a moldura (sidebar + topbar). A SEÇÃO ATIVA é derivada da ROTA
/// atual ([painelSectionForLocation]) — a sidebar navega com `context.go(...)`,
/// dando URL deep-linkável por seção (`/painel/financeiro`, `/painel/clientes`…)
/// com botão voltar/refresh do navegador funcionando.
///
/// ── LAZY ROUTES ──────────────────────────────────────────────────────────────
/// O carregamento `deferred as` + [LazySection] das seções PESADAS
/// (Financeiro/Agenda/Clientes/…) vive agora nos builders das rotas
/// (`painel_routes.dart`); o `indexedStack` só constrói o branch na primeira
/// visita, então o chunk só baixa quando a seção é aberta.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/app_surface_provider.dart';
import '../../core/design/design.dart';
import '../../core/design/theme_fintech.dart';
import '../../core/models/collections.dart';
import 'fintech/fintech_painel_shell.dart';
import 'painel_nav.dart';

class PainelShell extends ConsumerWidget {
  const PainelShell({super.key, required this.navigationShell});

  /// IndexedStack dos branches (uma seção por branch), entregue pelo
  /// `StatefulShellRoute.indexedStack`. Preserva o estado de cada seção entre
  /// trocas — o que o `IndexedStack` interno fazia antes.
  final StatefulNavigationShell navigationShell;

  static const double _desktopBreakpoint = 1024;
  // Janela "narrow/compact" (<600dp): usa [ClxLayout.narrowBreakpoint] — valor
  // canônico definido em tokens.dart para não duplicar a constante 600.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final role = ref.watch(currentRoleProvider);
    final section = painelSectionForLocation(
      GoRouterState.of(context).matchedLocation,
    );

    // Fintech Clean (doc 12): bottom nav de 5 itens em TODO Android — celular
    // E tablet, sem NavigationRail no APK (decisão do dono P-2). Só a Web
    // segue com sidebar/rail/drawer responsivo abaixo.
    if (ref.watch(isFintechCleanProvider)) {
      return FintechPainelScaffold(
        navigationShell: navigationShell,
        section: section,
        role: role,
      );
    }

    // Lido aqui (fora do LayoutBuilder) para que a assinatura seja registrada
    // em build() — não durante o callback de layout.
    final themeMode = ref.watch(themeModeControllerProvider);

    final items = navItemsForRole(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // ── NARROW WEB ────────────────────────────────────────────────────────
        // kIsWeb é uma const de compilação: em testes (VM) sempre false, então
        // este branch é código morto nos testes — o layout clássico abaixo é
        // o único exercitado. Em produção web + largura < 600dp mostra o mesmo
        // visual fintech do APK, com o tema aplicado via Theme() wrapper.
        if (kIsWeb && width < ClxLayout.narrowBreakpoint) {
          return ProviderScope(
            overrides: [isNarrowWebProvider.overrideWithValue(true)],
            child: Theme(
              data: themeMode == ThemeMode.dark
                  ? buildFintechDarkTheme()
                  : buildFintechLightTheme(),
              child: FintechPainelScaffold(
                navigationShell: navigationShell,
                section: section,
                role: role,
              ),
            ),
          );
        }

        final isDesktop = width >= _desktopBreakpoint;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: clx.bg2,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: ClxLayout.sidebarW,
                  child: _Sidebar(
                    items: items,
                    active: section,
                    role: role,
                    showClose: false,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(section: section, showMenu: false),
                      Expanded(child: _Content(child: navigationShell)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Tablet/janela média (600–1023dp): NavigationRail fixo (MD3).
        if (width >= ClxLayout.narrowBreakpoint) {
          return Scaffold(
            backgroundColor: clx.bg2,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavRail(items: items, active: section),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(section: section, showMenu: false),
                      Expanded(child: _Content(child: navigationShell)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Compact (<600dp): sidebar em Drawer, hambúrguer na AppBar.
        return Scaffold(
          backgroundColor: clx.bg2,
          drawer: Drawer(
            backgroundColor: clx.bgSidebar,
            child: _Sidebar(
              items: items,
              active: section,
              role: role,
              showClose: true,
            ),
          ),
          appBar: _TopBar(
            section: section,
            showMenu: true,
            statusBarHeight: MediaQuery.paddingOf(context).top,
          ).asAppBar(),
          body: _Content(child: navigationShell),
        );
      },
    );
  }
}

/// Área de conteúdo: limita a ~1200px e alinha ao topo. O [child] é o
/// `StatefulNavigationShell` (IndexedStack das seções).
class _Content extends StatelessWidget {
  const _Content({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ClxLayout.contentMaxW),
        child: child,
      ),
    );
  }
}

/// Topbar reutilizada em desktop (linha própria) e mobile (como `AppBar`).
class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.section,
    required this.showMenu,
    this.statusBarHeight = 0,
  });

  final PainelSection section;
  final bool showMenu;

  /// Altura da status bar do SO (MediaQuery.paddingOf.top).
  /// Zero no Web e no desktop (body já abaixo da status bar).
  final double statusBarHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(ClxLayout.topbarH + statusBarHeight);

  /// Adapta a topbar para o slot `appBar:` do Scaffold (mobile).
  PreferredSizeWidget asAppBar() => this;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final user = ref.watch(currentUserProvider);
    final mode = ref.watch(themeModeControllerProvider);

    return Container(
      height: ClxLayout.topbarH + statusBarHeight,
      decoration: BoxDecoration(
        color: clx.bg,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      padding: EdgeInsets.only(
        top: statusBarHeight,
        left: ClxSpace.x4,
        right: ClxSpace.x4,
      ),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Abrir menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              painelTitle(section),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Alternar tema',
            icon: Icon(
              mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () =>
                ref.read(themeModeControllerProvider.notifier).toggle(),
          ),
          if (user != null && (user.email).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: ClxSpace.x2),
              child: Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: clx.ink3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// NavigationRail da janela média: mesmas seções da sidebar, com "Minha
/// Conta" e logout no rodapé. Rolável para não estourar em janelas baixas.
class _NavRail extends ConsumerWidget {
  const _NavRail({required this.items, required this.active});

  final List<PainelNavItem> items;
  final PainelSection active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final selected = items.indexWhere((i) => i.section == active);

    return Container(
      decoration: BoxDecoration(
        color: clx.bgSidebar,
        border: Border(right: BorderSide(color: clx.line)),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: selected >= 0 ? selected : null,
                  onDestinationSelected: (i) =>
                      context.go(painelPath(items[i].section)),
                  leading: Padding(
                    padding: const EdgeInsets.only(
                      top: ClxSpace.x2,
                      bottom: ClxSpace.x3,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: clx.primary,
                        borderRadius: ClxRadii.rMd,
                      ),
                      child: const Icon(
                        Icons.cleaning_services_rounded,
                        size: 18,
                        color: ClxBrand.onPrimary,
                      ),
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: ClxSpace.x2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Minha Conta',
                              icon: Icon(
                                Icons.person_outline_rounded,
                                color: active == PainelSection.conta
                                    ? clx.primary
                                    : clx.ink2,
                              ),
                              onPressed: () =>
                                  context.go(painelPath(PainelSection.conta)),
                            ),
                            IconButton(
                              tooltip: 'Sair',
                              icon: Icon(Icons.logout_rounded, color: clx.ink2),
                              onPressed: () =>
                                  ref.read(authServiceProvider).logout(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final item in items)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar: marca + navegação por papel + rodapé (usuário/conta + logout).
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.items,
    required this.active,
    required this.role,
    required this.showClose,
  });

  final List<PainelNavItem> items;
  final PainelSection active;
  final Role? role;

  /// Mostra o botão de fechar (só no Drawer mobile).
  final bool showClose;

  void _navigate(BuildContext context, PainelSection section) {
    // No mobile a sidebar está num Drawer: fecha antes de navegar.
    if (showClose) Navigator.of(context).maybePop();
    context.go(painelPath(section));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final user = ref.watch(currentUserProvider);
    final dn = user?.displayName ?? '—';
    final avatarInitial = dn != '—' ? dn[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: clx.bgSidebar,
        border: Border(right: BorderSide(color: clx.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header / marca.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x4,
                ClxSpace.x4,
                ClxSpace.x2,
                ClxSpace.x4,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: clx.primary,
                      borderRadius: ClxRadii.rMd,
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      size: 18,
                      color: ClxBrand.onPrimary,
                    ),
                  ),
                  const SizedBox(width: ClxSpace.x2),
                  Expanded(
                    child: Text(
                      'CleanOS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (showClose)
                    IconButton(
                      tooltip: 'Fechar menu',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
            ),

            // Navegação (rolável se não couber).
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x2),
                children: [
                  for (final item in items)
                    _NavTile(
                      item: item,
                      active: item.section == active,
                      onTap: () => _navigate(context, item.section),
                    ),
                ],
              ),
            ),

            Divider(height: 1, color: clx.line),

            // Rodapé: usuário (→ Minha Conta) + logout.
            Padding(
              padding: const EdgeInsets.all(ClxSpace.x3),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: ClxRadii.rMd,
                      onTap: () => _navigate(context, PainelSection.conta),
                      child: Padding(
                        padding: const EdgeInsets.all(ClxSpace.x1),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: clx.accent,
                              child: Text(
                                avatarInitial,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: ClxSpace.x2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dn != '—' ? dn : 'Usuário',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: clx.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    role?.wire ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: clx.ink3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sair',
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    onPressed: () => ref.read(authServiceProvider).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de navegação da sidebar (ativo = realce petrol/cyan).
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final PainelNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final fg = active ? clx.primary : clx.ink2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active
            ? clx.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: ClxRadii.rMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: ClxRadii.rMd,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: ClxLayout.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x3),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: ClxSpace.x3),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: active ? clx.ink : clx.ink2,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
