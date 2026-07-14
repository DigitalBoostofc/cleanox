/// painel_test_helpers.dart — Utilitários comuns dos testes do Painel (Fase 3).
///
/// Sobrescreve os providers do core (auth/tema/repositório) por fakes sem rede,
/// reaproveitando os fakes já existentes do time do profissional.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/auth/auth_service.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../profissional/fakes.dart';

/// Usuário de teste com o [role] desejado.
User painelUser({Role role = Role.admin, String nome = 'Ana Admin'}) => User(
  id: 'u_${role.wire}',
  name: nome,
  email: '${role.wire}@cleanos.app',
  role: role,
);

/// AuthService fake: usuário fixo (sempre logado), stream que emite 1 snapshot.
/// Alimenta o `redirect` por papel do `routerProvider` nos testes de rota.
class FakeAuthService implements AuthService {
  FakeAuthService(this._user);
  final User? _user;

  @override
  User? get currentUser => _user;
  @override
  Role? get currentRole => _user?.role;
  @override
  bool get isSignedIn => _user != null;
  @override
  AuthSnapshot get snapshot => AuthSnapshot(user: _user);
  @override
  Stream<AuthSnapshot> watch() async* {
    yield snapshot;
  }

  @override
  Future<User> login(String email, String password) =>
      throw UnimplementedError();
  @override
  Future<User?> refresh() async => _user;
  @override
  void logout() {}
}

/// Sobe o APP REAL (router incluso) autenticado como [user] e navega até
/// [location]. Diferente de [pumpPainel], exercita as ROTAS ANINHADAS de verdade
/// (deep-link + guard por papel). Devolve o [GoRouter] pra inspeção da URL atual.
///
/// `pocketBaseProvider` é sobrescrito por um PB de descarte (nenhuma rede real);
/// as telas pesadas que o `indexedStack` construir caem em loading/erro sem
/// crashar por falta de `PbClient.init`.
Future<GoRouter> pumpPainelApp(
  WidgetTester tester, {
  required User user,
  OrdensRepository? repo,
  String location = '/painel/dashboard',
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(FakeAuthService(user)),
      pocketBaseProvider.overrideWithValue(PocketBase('http://127.0.0.1:9')),
      themeStorageProvider.overrideWithValue(FakeSecureStorage()),
      if (repo != null) ordensRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, theme: buildLightTheme()),
    ),
  );
  await tester.pump(); // redirect: /login → /painel → /painel/dashboard

  if (location != '/painel/dashboard') router.go(location);
  // Deixa o `loadLibrary()` das seções `deferred` (LazySection) completar antes
  // das asserções. `loadLibrary()` roda na zona ASSÍNCRONA REAL (não avança com
  // `pump`, que é fake-async); então intercala `runAsync` (avança a zona real,
  // completa o Future e agenda o setState do FutureBuilder) com `pump` (rebuild).
  // Intercalar cobre chunks grandes (Financeiro) de forma determinística.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 12));
  }
  return router;
}

/// URL atualmente ativa no [router] (após redirects).
String currentLocation(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Overrides padrão: usuário/papel fixos, secure storage em memória e (opcional)
/// um repositório de ordens fake.
List<Override> painelOverrides({required User user, OrdensRepository? repo}) =>
    [
      currentUserProvider.overrideWithValue(user),
      currentRoleProvider.overrideWithValue(user.role),
      themeStorageProvider.overrideWithValue(FakeSecureStorage()),
      if (repo != null) ordensRepositoryProvider.overrideWithValue(repo),
    ];

/// Monta [child] num app real (tema claro) com os [overrides], numa viewport de
/// [size] (default desktop, p/ ver a sidebar fixa). Faz apenas `pump()` (não
/// `pumpAndSettle`, que travaria no spinner de loading).
Future<void> pumpPainel(
  WidgetTester tester,
  Widget child, {
  required List<Override> overrides,
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      // Scaffold garante um ancestral Material p/ as telas testadas isoladas
      // (no app real elas vivem dentro do Scaffold do PainelShell).
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}
