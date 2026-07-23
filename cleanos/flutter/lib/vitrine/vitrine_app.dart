/// Shell da vitrine pública + admin `/admin` — identidade Cleanox.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/tokens.dart';
import '../core/design/widgets/cleanox_logo.dart';
import 'admin/vitrine_admin_auth.dart';
import 'admin/vitrine_admin_screens.dart';
import 'admin/vitrine_admin_shell.dart';
import 'screens/vitrine_home_screen.dart';

class VitrineApp extends ConsumerWidget {
  const VitrineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_vitrineRouterProvider);
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: kFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ClxBrand.cyan,
        primary: ClxBrand.cyan,
        onPrimary: ClxBrand.onPrimary,
        secondary: ClxBrand.navy,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: ClxBrand.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: ClxBrand.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ClxRadii.rLg,
          side: const BorderSide(color: Color(0x140B1D34)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClxBrand.cyan,
          foregroundColor: ClxBrand.onPrimary,
          textStyle: const TextStyle(
            fontFamily: kFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: const BorderSide(color: Color(0x1A0B1D34)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: const BorderSide(color: Color(0x1A0B1D34)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: BorderSide(color: ClxBrand.cyan, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );

    return MaterialApp.router(
      title: '$kAppDisplayName — Agendar',
      debugShowCheckedModeBanner: false,
      theme: base,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

final _vitrineRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthRefresh(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const VitrineHomeScreen(),
      ),
      // Login fora do shell (sem sidebar).
      GoRoute(
        path: '/admin/login',
        builder: (_, __) => const VitrineAdminLoginScreen(),
      ),
      // Área logada: /admin e sub-rotas.
      ShellRoute(
        builder: (context, state, child) => VitrineAdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, __) => const VitrineAdminDashboardScreen(),
            routes: [
              GoRoute(
                path: 'personalizar',
                builder: (_, __) => const VitrineAdminPersonalizarScreen(),
              ),
              GoRoute(
                path: 'midia',
                builder: (_, __) => const VitrineAdminMidiaScreen(),
              ),
              GoRoute(
                path: 'servicos',
                builder: (_, __) => const VitrineAdminServicosScreen(),
              ),
              GoRoute(
                path: 'order-bumps',
                builder: (_, __) => const VitrineAdminBumpsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      // Usar path do browser (não só matchedLocation) — crítico no deep-link /admin.
      final loc = state.uri.path;
      final isAdmin = loc == '/admin' || loc.startsWith('/admin/');
      final isLogin = loc == '/admin/login';
      if (!isAdmin) return null;

      final auth = ref.read(vitrineAdminAuthProvider);
      final user = auth.currentUser;
      final signedIn = user != null && user.role.isPainel;

      if (!signedIn && !isLogin) return '/admin/login';
      if (signedIn && isLogin) return '/admin';
      if (user != null && user.role.isProfissional) {
        auth.logout();
        return '/admin/login';
      }
      return null;
    },
  );
});

/// Notifica o GoRouter quando o authStore do admin muda.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    final pb = ref.read(vitrineAdminPbProvider);
    _sub = pb.authStore.onChange.listen((_) => notifyListeners());
  }

  final Ref ref;
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Atalhos de cor usados nas telas da vitrine (= APK / board Cleanox).
abstract final class VitrineColors {
  static const petrol = ClxBrand.navy;
  static const cyan = ClxBrand.cyan;
  static const cyanLight = ClxBrand.cyanLight;
  static const bg = ClxBrand.canvas;
  static const ink = ClxBrand.navy;
  static const ink2 = ClxBrand.muted;
  static const onPrimary = ClxBrand.onPrimary;
}

/// App bar com logo oficial (mesmo do login APK).
class VitrineBrandBar extends StatelessWidget implements PreferredSizeWidget {
  const VitrineBrandBar({
    super.key,
    this.bottom,
    this.showBack = false,
  });

  final PreferredSizeWidget? bottom;
  final bool showBack;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: ClxBrand.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: showBack,
      titleSpacing: ClxSpace.x4,
      toolbarHeight: 80,
      title: const Align(
        alignment: Alignment.centerLeft,
        child: CleanoxLogo(
          height: 64,
          variant: CleanoxLogoVariant.primary,
        ),
      ),
      bottom: bottom,
    );
  }
}
