/// app.dart — Raiz compartilhada (MaterialApp.router) das duas superfícies.
///
/// Locale fixo pt_BR (blueprint §2). Tema claro/escuro via ThemeMode persistido.
/// O `surface` (painel vs profissional) é decidido pelo go_router + redirect por
/// papel — o mesmo binário serve as duas, o entrypoint só muda o alvo/plataforma.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme.dart';
import 'core/router/app_router.dart';

/// Superfície-alvo do entrypoint (só afeta o título; o roteamento é por papel).
enum AppSurface { painel, profissional }

class CleanosApp extends ConsumerWidget {
  const CleanosApp({super.key, required this.surface});

  final AppSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: surface == AppSurface.painel ? 'CleanOS · Painel' : 'CleanOS',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
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
