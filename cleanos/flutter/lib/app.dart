/// app.dart — Raiz compartilhada (MaterialApp.router) das duas superfícies.
///
/// Locale fixo pt_BR (blueprint §2). Tema claro/escuro via ThemeMode persistido.
/// O `surface` (painel vs profissional) é decidido pelo go_router + redirect por
/// papel — o mesmo binário serve as duas, o entrypoint só muda o alvo/plataforma.
///
/// **Web estreita (&lt; 600dp):** mesmo tema + UX fintech do APK (login, casco,
/// listas em card). Desktop web (≥ 600dp) permanece clássico (sidebar/rail).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_surface_provider.dart';
import 'core/design/theme.dart';
import 'core/design/theme_fintech.dart';
import 'core/design/tokens.dart';
import 'core/router/app_router.dart';

/// Superfície-alvo do entrypoint (afeta o título E o tema — ver
/// `app_surface_provider.dart`; o roteamento continua por papel).
enum AppSurface { painel, profissional, android }

class CleanosApp extends StatelessWidget {
  const CleanosApp({super.key, required this.surface});

  final AppSurface surface;

  @override
  Widget build(BuildContext context) {
    // Bifurcação estrutural (Nível 2, doc 12 §1): expõe `surface` via Riverpod
    // pra quem não pode decidir só com `ThemeData` (nav de 5 itens, tela Mais).
    // ProviderScope aninhado — não afeta nenhum override que os *_main.dart ou
    // os testes já instalam no ProviderScope de fora.
    return ProviderScope(
      overrides: [appSurfaceProvider.overrideWithValue(surface)],
      child: _CleanosAppView(surface: surface),
    );
  }
}

class _CleanosAppView extends ConsumerWidget {
  const _CleanosAppView({required this.surface});

  final AppSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    // Tema base: APKs → Fintech Clean. Web (`painel`) → clássico no
    // MaterialApp; em viewport &lt;600dp o [builder] aplica fintech +
    // [isNarrowWebProvider] (paridade com o APK).
    final isWeb = surface == AppSurface.painel;

    return MaterialApp.router(
      title: surface == AppSurface.painel
          ? '$kAppDisplayName · Painel'
          : kAppDisplayName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: isWeb ? buildLightTheme() : buildFintechLightTheme(),
      darkTheme: isWeb ? buildDarkTheme() : buildFintechDarkTheme(),
      themeMode: themeMode,
      // Troca claro↔escuro animada com os motion tokens MD3.
      themeAnimationDuration: ClxMotion.standardDuration,
      themeAnimationCurve: ClxMotion.standard,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Web mobile: força tema + flag fintech em toda a árvore (login incluso).
      // Desktop web: não toca — layout clássico.
      builder: isWeb
          ? (context, child) {
              final content = child ?? const SizedBox.shrink();
              final width = MediaQuery.sizeOf(context).width;
              if (width >= ClxLayout.narrowBreakpoint) return content;

              final dark = Theme.of(context).brightness == Brightness.dark;
              return ProviderScope(
                overrides: [
                  isNarrowWebProvider.overrideWithValue(true),
                ],
                child: Theme(
                  data: dark
                      ? buildFintechDarkTheme()
                      : buildFintechLightTheme(),
                  child: content,
                ),
              );
            }
          : null,
    );
  }
}
