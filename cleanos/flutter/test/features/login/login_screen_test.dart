/// login_screen_test.dart — Reskin "Fintech Clean" (doc 12, Onda 2) do login.
///
/// Cobre a ÚNICA bifurcação estrutural desta onda: `isFintechCleanProvider`
/// troca o layout clássico (`ClxCard` elevado, ainda usado pela Web) pelo novo
/// (sem card, logo + campos + CTA no polegar), preservando 100% da lógica de
/// auth/estados (loading/erro) nos dois ramos.
library;

import 'dart:async';

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/auth/auth_service.dart';
import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/features/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

/// Fake de [AuthService] que resolve/rejeita o login sob controle do teste
/// (via [gate]), sem tocar rede/PocketBase de verdade.
class _GatedAuthService extends AuthService {
  _GatedAuthService(this.gate) : super(PocketBase('http://localhost'));

  final Completer<void> gate;
  Object? failWith;

  @override
  Future<User> login(String email, String password) async {
    await gate.future;
    final err = failWith;
    if (err != null) throw err;
    return const User(id: 'u1', name: 'Carlos', role: Role.profissional);
  }
}

Widget _wrap({required bool isFintechClean, AuthService? authService}) {
  return ProviderScope(
    overrides: [
      isFintechCleanProvider.overrideWithValue(isFintechClean),
      if (authService != null) authServiceProvider.overrideWithValue(authService),
    ],
    child: MaterialApp(
      theme: isFintechClean ? buildFintechLightTheme() : buildLightTheme(),
      home: const LoginScreen(),
    ),
  );
}

Future<void> _preencherEsubmeter(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'carlos@cleanox.com');
  await tester.enterText(fields.at(1), 'segredo123');
  await tester.tap(find.text('Entrar'));
  await tester.pump();
}

void main() {
  testWidgets('surface Web (não-fintech): login em card flutuante', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(isFintechClean: false));

    // Card visual próprio (não ClxCard) + logo Cleanox + CTA.
    expect(find.byType(CleanoxLogo), findsOneWidget);
    expect(find.text(kAppTagline), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets(
    'surface Android fintech: sem card, logo + CTA no polegar, 360x800',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(isFintechClean: true));

      expect(find.byType(ClxCard), findsNothing);
      expect(find.byType(CleanoxLogo), findsOneWidget);
      expect(find.text(kAppTagline), findsOneWidget);
      final entrar = tester.widget<ClxButton>(
        find.widgetWithText(ClxButton, 'Entrar'),
      );
      expect(entrar.expand, isTrue, reason: 'CTA pill full-width');
      expect(
        find.text('Esqueceu a senha? Fale com o administrador.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('surface Android fintech em 320x800: sem overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(isFintechClean: true));

    expect(tester.takeException(), isNull);
  });

  testWidgets('loading: CTA mostra spinner enquanto o login está em voo', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      _wrap(isFintechClean: true, authService: _GatedAuthService(gate)),
    );

    await _preencherEsubmeter(tester);

    final entrar = tester
        .widgetList<ClxButton>(find.byType(ClxButton))
        .firstWhere((b) => b.label == 'Entrar');
    expect(entrar.loading, isTrue);

    gate.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('erro: credenciais inválidas mostram o ErrorBanner', (
    tester,
  ) async {
    final gate = Completer<void>()..complete();
    final auth = _GatedAuthService(gate)
      ..failWith = const AuthException('E-mail ou senha inválidos.');
    await tester.pumpWidget(_wrap(isFintechClean: true, authService: auth));

    await _preencherEsubmeter(tester);
    await tester.pump();

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
  });
}
