/// prof_deeplink_test.dart — ROTAS ANINHADAS do app do profissional.
///
/// Cobre: o deep-link `/app/os/:osId` abre a execução da OS (é o que o push
/// "Nova OS" dispara); e o gancho de deep-link do [PushRegistrationService]
/// navega via o callback ligado pelo `ProfShell` (`context.go('/app/os/:id')`).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/whatsapp_repository.dart';
import 'package:cleanos/core/router/app_router.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/location/push_registration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../painel/painel_test_helpers.dart' show FakeAuthService;
import 'fakes.dart';

const _prof = User(id: 'p1', name: 'Pedro', role: Role.profissional);

OrdemServico _os() => OrdemServico(
  id: 'os1',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  status: OSStatus.emAndamento,
  profissional: 'p1',
  dataHora: '2026-07-01 10:00:00Z',
  valorServico: 150,
  enderecoLiberado: 'Rua Secreta, 123',
  serviceSnapshot: const ServiceSnapshot(
    serviceId: 's1',
    nome: 'Higienização',
    valorBase: 150,
  ),
);

Future<GoRouter> _pumpApp(WidgetTester tester, {String? location}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(FakeAuthService(_prof)),
      pocketBaseProvider.overrideWithValue(PocketBase('http://127.0.0.1:9')),
      ordensRepositoryProvider.overrideWithValue(
        FakeOrdensRepository(execOS: _os()),
      ),
      evidenciasRepositoryProvider.overrideWithValue(
        FakeEvidenciasRepository(),
      ),
      whatsappRepositoryProvider.overrideWithValue(FakeWhatsAppRepository()),
      secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      themeStorageProvider.overrideWithValue(FakeSecureStorage()),
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
  await tester.pump(); // redirect: /login → /app (home do profissional)

  if (location != null) router.go(location);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return router;
}

void main() {
  testWidgets('deep-link /app/os/:id abre a execução da OS', (tester) async {
    final router = await _pumpApp(tester, location: '/app/os/os1');

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/app/os/os1',
    );
    // Visão-de-job da execução: nome_curto aparece (endereço só em andamento).
    expect(find.text('Carlos S.'), findsOneWidget);
  });

  testWidgets('profissional logado cai em /app (serviços)', (tester) async {
    final router = await _pumpApp(tester);
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/app');
  });

  group('PushRegistrationService — gancho de deep-link', () {
    test('bindDeepLink + openOsFromNotification chama o callback', () {
      final svc = PushRegistrationService(
        const UnimplementedTrackingRepository(),
      );
      String? opened;
      svc.bindDeepLink((osId) => opened = osId);

      svc.openOsFromNotification('os42');
      expect(opened, 'os42');
    });

    test('openOsFromNotification é no-op sem callback ligado', () {
      final svc = PushRegistrationService(
        const UnimplementedTrackingRepository(),
      );
      // Não deve lançar quando ninguém ligou o gancho.
      expect(() => svc.openOsFromNotification('os1'), returnsNormally);
    });
  });
}
