/// painel_shell.dart — Casco do PAINEL admin (Flutter Web · Onda 1 da Fase 3).
///
/// Espelha `PainelLayout.tsx`: sidebar com o menu por papel, topbar (título +
/// tema + usuário + logout), overlay/drawer no mobile. Desktop-first:
///   • largura ≥ 1024px → sidebar FIXA ao lado do conteúdo;
///   • largura  < 1024px → sidebar vira Drawer (hambúrguer na topbar).
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/collections.dart';
import 'painel_nav.dart';

class PainelShell extends ConsumerWidget {
  const PainelShell({super.key, required this.navigationShell});

  /// IndexedStack dos branches (uma seção por branch), entregue pelo
  /// `StatefulShellRoute.indexedStack`. Preserva o estado de cada seção entre
  /// trocas — o que o `IndexedStack` interno fazia antes.
  final StatefulNavigationShell navigationShell;

  static const double _desktopBreakpoint = 1024;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final role = ref.watch(currentRoleProvider);
    final section = painelSectionForLocation(
      GoRouterState.of(context).matchedLocation,
    );
    final items = navItemsForRole(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

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

        // Mobile/tablet: sidebar em Drawer, hambúrguer na AppBar.
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
          appBar: _TopBar(section: section, showMenu: true).asAppBar(),
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
  const _TopBar({required this.section, required this.showMenu});

  final PainelSection section;
  final bool showMenu;

  @override
  Size get preferredSize => const Size.fromHeight(ClxLayout.topbarH);

  /// Adapta a topbar para o slot `appBar:` do Scaffold (mobile).
  PreferredSizeWidget asAppBar() => this;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final user = ref.watch(currentUserProvider);
    final mode = ref.watch(themeModeControllerProvider);

    return Container(
      height: ClxLayout.topbarH,
      decoration: BoxDecoration(
        color: clx.bg,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x4),
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
              style: TextStyle(
                color: clx.ink,
                fontSize: 18,
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
                style: TextStyle(
                  color: clx.ink3,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
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
                      color: Color(0xFF04201E),
                    ),
                  ),
                  const SizedBox(width: ClxSpace.x2),
                  Expanded(
                    child: Text(
                      'CleanOS',
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 18,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
                                    style: TextStyle(
                                      color: clx.ink,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    role?.wire ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: clx.ink3,
                                      fontSize: 11.5,
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
                    style: TextStyle(
                      color: active ? clx.ink : clx.ink2,
                      fontSize: 14,
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
