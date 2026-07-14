/// app_router.dart — go_router base com redirect por papel + as duas superfícies
/// como `StatefulShellRoute.indexedStack` (URL por seção/aba + estado preservado).
///
/// Espelha `App.tsx` (RootRedirect + RoleGuard): `profissional → /app`, senão
/// `→ /painel`. Deep-linking nativo habilitado (necessário p/ push "Nova OS"
/// abrir a OS — doc 09 §6.3).
///
/// ── COMO AS FEATURES REGISTRAM ROTAS (sem dependência circular) ───────────────
/// Cada superfície expõe um builder do seu `StatefulShellRoute`:
///   • `painel/painel_routes.dart` → [painelShellRoute]
///   • `profissional/prof_routes.dart` → [profShellRoute]
/// Este arquivo apenas os importa e pendura. Os arquivos de rota importam o
/// go_router + suas telas, NUNCA o `app_router` — a dependência é one-way
/// (router → feature), então não há ciclo. Rotas de tela cheia (execução da OS,
/// editor de serviço) sobem no [rootNavigatorKey] (cobrem o casco).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../auth/auth_service.dart';
import '../design/design.dart';
import '../models/collections.dart';
import '../../features/login/login_screen.dart';
import '../../painel/painel_routes.dart';
import '../../profissional/prof_routes.dart';

/// Caminhos canônicos.
class Routes {
  const Routes._();
  static const String login = '/login';
  static const String painel = '/painel';
  static const String app = '/app';

  /// Home real do Painel (o `/painel` "puro" redireciona pra cá).
  static const String painelHome = '/painel/dashboard';

  /// Seção admin-only (guard por papel no redirect global).
  static const String painelWhatsapp = '/painel/whatsapp';
}

/// Navigator RAIZ (acima das duas superfícies). As rotas de tela cheia sobem
/// nele; o push do deep-link também navega por aqui.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Home de cada papel.
String homeForRole(Role? role) =>
    role != null && role.isProfissional ? Routes.app : Routes.painel;

/// Re-avalia o redirect a cada mudança do authStore.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = GoRouterRefreshStream(auth.watch());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.login,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    // URL inexistente/quebrada (bookmarks agora são deep-linkáveis) → tela 404
    // com a marca e atalho para a home do papel, em vez do erro cru do go_router.
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final AuthSnapshot snap = auth.snapshot;
      final loggedIn = snap.isSignedIn;
      final role = snap.role;
      final loc = state.matchedLocation;
      final atLogin = loc == Routes.login;

      // Não autenticado → só /login.
      if (!loggedIn) return atLogin ? null : Routes.login;

      // Autenticado no /login (ou na raiz) → manda para a home do papel.
      if (atLogin || loc == '/') return homeForRole(role);

      // Guard por superfície (anti-desvio de navegação).
      final inPainel = loc.startsWith(Routes.painel);
      final inApp = loc.startsWith(Routes.app);
      if (role != null && role.isProfissional && inPainel) return Routes.app;
      if (role != null && role.isPainel && inApp) return Routes.painel;

      // `/painel` "puro" não tem branch próprio → vai pra home (Dashboard).
      if (loc == Routes.painel) return Routes.painelHome;

      // WhatsApp é admin-only: gerente é barrado de volta ao Dashboard.
      if (loc.startsWith(Routes.painelWhatsapp) && role != Role.admin) {
        return Routes.painelHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // `/painel` "puro" não tem branch próprio → manda pra home (Dashboard).
      // Rota explícita (o `StatefulShellRoute` começa em `/painel/dashboard`).
      GoRoute(
        path: Routes.painel,
        redirect: (context, state) => Routes.painelHome,
      ),
      // ── Painel (admin/gerente) — Flutter Web. Uma seção por branch. ──
      painelShellRoute(rootNavigatorKey),
      // ── Profissional (Android) — bottom nav. Uma aba por branch. ──
      profShellRoute(rootNavigatorKey),
    ],
  );
});

/// Tela 404 com a marca CleanOS. Aparece quando a URL não casa nenhuma rota
/// (bookmark quebrado, link antigo). Oferece voltar para a home do papel logado
/// — ou o login, se não houver sessão.
class NotFoundScreen extends ConsumerWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final snap = ref.watch(authServiceProvider).snapshot;
    final home = snap.isSignedIn ? homeForRole(snap.role) : Routes.login;

    return Scaffold(
      backgroundColor: clx.bg2,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ClxCard(
              elevated: true,
              padding: const EdgeInsets.all(ClxSpace.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    kAppDisplayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: clx.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x4),
                  Icon(Icons.explore_off_outlined, size: 48, color: clx.ink3),
                  const SizedBox(height: ClxSpace.x4),
                  Text(
                    'Página não encontrada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                  Text(
                    'O endereço que você abriu não existe ou foi movido.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: clx.ink3),
                  ),
                  const SizedBox(height: ClxSpace.x6),
                  ClxButton(
                    label: 'Voltar ao início',
                    icon: Icons.home_rounded,
                    expand: true,
                    onPressed: () => context.go(home),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
