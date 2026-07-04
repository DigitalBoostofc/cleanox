/// app.dart — Raiz compartilhada (MaterialApp.router) das duas superfícies.
///
/// Locale fixo pt_BR (blueprint §2). Tema claro/escuro via ThemeMode persistido.
/// O `surface` (painel vs profissional) é decidido pelo go_router + redirect por
/// papel — o mesmo binário serve as duas, o entrypoint só muda o alvo/plataforma.
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
    // Bifurcação de tema (Nível 1, doc 12 §1): só a Web (`painel`) mantém o
    // ThemeData clássico — os dois APKs (unificado e o legado profissional,
    // decisão do dono P-1) recebem o tema "Fintech Clean".
    final isWeb = surface == AppSurface.painel;

    return MaterialApp.router(
      title: surface == AppSurface.painel ? 'CleanOS · Painel' : 'CleanOS',
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
    );
  }
}
