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
    // E tablet, sem NavigationRail no APK (decisão do dono P-2).
    // Web estreita: mesmo casco (via isNarrowWeb no app builder + largura).
    final fintechApk = ref.watch(isFintechCleanProvider);
    final narrowWebFlag = ref.watch(isNarrowWebProvider);
    if (fintechApk) {
      return FintechPainelScaffold(
        navigationShell: navigationShell,
        section: section,
        role: role,
      );
    }

    final items = navItemsForRole(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // ── NARROW WEB (< 600dp) ───────────────────────────────────────────────
        // Mesmo casco Easypay do APK: top bar + avatar + bottom nav 5 itens.
        // Desktop web (≥ 600dp) NÃO entra aqui — sidebar/rail intactos.
        //
        // [isNarrowWebProvider] costuma vir true do builder do MaterialApp
        // (app.dart). Mantemos também o check de largura (kIsWeb) como rede
        // de segurança se o flag não estiver na árvore.
        final narrowWeb = narrowWebFlag ||
            (kIsWeb && width < ClxLayout.narrowBreakpoint);
        if (narrowWeb) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ProviderScope(
            overrides: [isNarrowWebProvider.overrideWithValue(true)],
            child: Theme(
              data: dark
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

        // ── DESKTOP / TABLET WEB (≥ 600dp) ──────────────────────────────────
        // Casco estilo “dashboard flutuante” (ref. Shakuro): canvas cinza,
        // shell branco arredondado + rail escuro de ícones + conteúdo.
        // APK e web estreita já saíram acima (FintechPainelScaffold).
        if (width >= ClxLayout.narrowBreakpoint) {
          return _DesktopAppShell(
            items: items,
            section: section,
            role: role,
            navigationShell: navigationShell,
            compact: width < _desktopBreakpoint,
          );
        }

        // Compact residual (não-web / edge): drawer clássico.
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

/// Canvas + shell flutuante branco (desktop web) com entrada animada.
class _DesktopAppShell extends ConsumerWidget {
  const _DesktopAppShell({
    required this.items,
    required this.section,
    required this.role,
    required this.navigationShell,
    this.compact = false,
  });

  final List<PainelNavItem> items;
  final PainelSection section;
  final Role? role;
  final StatefulNavigationShell navigationShell;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = compact ? 12.0 : 20.0;
    final radius = compact ? 22.0 : 28.0;

    return Scaffold(
      // Canvas externo (cinza suave / preto no dark).
      backgroundColor: isDark ? const Color(0xFF0A0B0C) : const Color(0xFFE6EAEE),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: ClxScaleFade(
            beginScale: 0.94,
            duration: ClxMotion.emphasizedDuration,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: clx.bg,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: clx.primary.withValues(alpha: 0.06),
                    blurRadius: 60,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _IconRail(
                      items: items,
                      active: section,
                      role: role,
                      compact: compact,
                    ),
                    Expanded(
                      child: ColoredBox(
                        // Fundo suave: o conteúdo “flutua” em cards brancos.
                        color: clx.bg2,
                        child: Column(
                          children: [
                            _DesktopTopBar(section: section),
                            Expanded(
                              // Card da página cola nas bordas úteis (sem “faixa”
                              // incompleta em volta do Financeiro/listas).
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 10 : 14,
                                  0,
                                  compact ? 10 : 14,
                                  compact ? 10 : 14,
                                ),
                                child: _FloatingPage(
                                  child: _Content(child: navigationShell),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Rail escuro: **recolhido** (só ícones) ou **expandido** (ícone + nome).
/// Seta no meio da borda direita alterna o estado.
class _IconRail extends ConsumerStatefulWidget {
  const _IconRail({
    required this.items,
    required this.active,
    required this.role,
    this.compact = false,
  });

  final List<PainelNavItem> items;
  final PainelSection active;
  final Role? role;
  final bool compact;

  @override
  ConsumerState<_IconRail> createState() => _IconRailState();
}

class _IconRailState extends ConsumerState<_IconRail> {
  static const _railBg = Color(0xFF12181C);
  static const double _collapsedW = 76;
  static const double _expandedW = 228;

  /// Começa recolhido (como no mock) — clique na seta abre os nomes.
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final user = ref.watch(currentUserProvider);
    final items = widget.items;
    final active = widget.active;
    final collapsedW = widget.compact ? 64.0 : _collapsedW;
    final width = _expanded ? _expandedW : collapsedW;

    return AnimatedContainer(
          duration: ClxMotion.emphasizedDuration,
          curve: ClxMotion.emphasized,
          width: width,
          color: _railBg,
          child: SafeArea(
            right: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo grande (transparente) — no rail escuro usa card claro.
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _expanded ? 12 : 8,
                  ),
                  child: ClxPulse(
                    minScale: 0.97,
                    maxScale: 1.05,
                    period: const Duration(milliseconds: 1800),
                    child: Tooltip(
                      message: kAppDisplayName,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: _expanded ? 10 : 6,
                          vertical: _expanded ? 12 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            _expanded ? 16 : 14,
                          ),
                        ),
                        child: CleanoxLogo(
                          height: _expanded ? 64 : 40,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          variant: CleanoxLogoVariant.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: _expanded ? 10 : 10,
                    ),
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _RailIcon(
                          icon: items[i].icon,
                          label: items[i].label,
                          selected: items[i].section == active,
                          expanded: _expanded,
                          onTap: () =>
                              context.go(painelPath(items[i].section)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      // Seta logo acima do boneco (Minha Conta).
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Center(
                          child: Material(
                            color: clx.primary,
                            elevation: 3,
                            shadowColor: clx.primary.withValues(alpha: 0.35),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _toggle,
                              child: Tooltip(
                                message: _expanded
                                    ? 'Recolher menu'
                                    : 'Expandir menu',
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Center(
                                    child: AnimatedRotation(
                                      turns: _expanded ? 0.5 : 0,
                                      duration: ClxMotion.standardDuration,
                                      curve: ClxMotion.emphasized,
                                      child: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _RailIcon(
                        icon: Icons.person_outline_rounded,
                        label: 'Minha Conta',
                        selected: active == PainelSection.conta,
                        expanded: _expanded,
                        onTap: () =>
                            context.go(painelPath(PainelSection.conta)),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _expanded ? 12 : 0,
                        ),
                        child: Row(
                          mainAxisAlignment: _expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Tooltip(
                              message: user?.displayName ?? 'Conta',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => context.go(
                                    painelPath(PainelSection.conta),
                                  ),
                                  child: UserAvatar(user: user, radius: 18),
                                ),
                              ),
                            ),
                            if (_expanded) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  user?.displayName ?? 'Usuário',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _RailIcon(
                        icon: Icons.logout_rounded,
                        label: 'Sair',
                        selected: false,
                        expanded: _expanded,
                        onTap: () =>
                            ref.read(authServiceProvider).logout(),
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

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final fg = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.62);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        // Tooltip só no recolhido (quando expandido o nome já aparece).
        message: expanded ? '' : label,
        child: ClxPressScale(
          onTap: onTap,
          scale: 0.94,
          child: AnimatedContainer(
            duration: ClxMotion.standardDuration,
            curve: ClxMotion.emphasized,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 0),
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            decoration: BoxDecoration(
              color: selected ? clx.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: clx.primary.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: ClxMotion.shortDuration,
                  curve: ClxMotion.emphasized,
                  child: Icon(icon, size: 22, color: fg),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: expanded ? 1 : 0,
                      duration: ClxMotion.standardDuration,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top bar limpa dentro do shell (título + tema).
class _DesktopTopBar extends ConsumerWidget {
  const _DesktopTopBar({required this.section});

  final PainelSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final mode = ref.watch(themeModeControllerProvider);
    final user = ref.watch(currentUserProvider);

    // Top bar no fundo suave (fora do card flutuante da página).
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(28, 8, 20, 8),
      color: clx.bg2,
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: ClxMotion.standardDuration,
              switchInCurve: ClxMotion.emphasized,
              switchOutCurve: ClxMotion.emphasizedAccelerate,
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: Text(
                painelTitle(section),
                key: ValueKey(section),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ),
          ClxPressScale(
            onTap: () =>
                ref.read(themeModeControllerProvider.notifier).toggle(),
            child: IconButton(
              tooltip: 'Alternar tema',
              icon: AnimatedSwitcher(
                duration: ClxMotion.shortDuration,
                transitionBuilder: (child, anim) =>
                    RotationTransition(turns: anim, child: child),
                child: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  key: ValueKey(mode),
                  color: clx.ink2,
                ),
              ),
              onPressed: () =>
                  ref.read(themeModeControllerProvider.notifier).toggle(),
            ),
          ),
          if (user != null && user.email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: ClxFadeSlide(
                delay: const Duration(milliseconds: 120),
                offset: const Offset(0.2, 0),
                child: Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: clx.ink3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Superfície flutuante onde as páginas vivem — **preenche 100%** do espaço
/// (largura + altura) para a borda do card fechar em volta do conteúdo.
class _FloatingPage extends StatelessWidget {
  const _FloatingPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClxScaleFade(
      beginScale: 0.985,
      duration: ClxMotion.standardDuration,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: clx.bg,
            borderRadius: ClxRadii.rXl,
            border: Border.all(
              color: clx.line2.withValues(alpha: isDark ? 0.5 : 0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: clx.primary.withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: ClxRadii.rXl,
            child: ColoredBox(
              // Fundo contínuo até a borda (listas curtas não “quebram” o card).
              color: clx.bg,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Conteúdo da seção: ocupa 100% do card flutuante.
class _Content extends StatelessWidget {
  const _Content({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: child);
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

/// Sidebar: marca + navegação por papel + rodapé (usuário/conta + logout).
/// Usada no drawer residual; desktop usa [_IconRail].
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
                  const Expanded(
                    child: CleanoxLogo(
                      height: 52,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      variant: CleanoxLogoVariant.primary,
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
                            // Foto real quando houver; senão iniciais (UserAvatar).
                            UserAvatar(user: user, radius: 16),
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
