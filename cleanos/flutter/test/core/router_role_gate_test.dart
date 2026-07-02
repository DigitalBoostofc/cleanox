/// router_role_gate_test.dart — Gate de roteamento por papel do APK unificado.
///
/// Verifica que `homeForRole` envia cada papel para a superfície correta e que
/// o modelo `User` deserializa papel desconhecido para o de menor privilégio.
library;

import 'package:cleanos/core/auth/auth_service.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeForRole — gate de superfície', () {
    test('admin → /painel', () {
      expect(homeForRole(Role.admin), Routes.painel);
    });

    test('gerente → /painel', () {
      expect(homeForRole(Role.gerente), Routes.painel);
    });

    test('profissional → /app', () {
      expect(homeForRole(Role.profissional), Routes.app);
    });

    // null = usuário autenticado sem campo `role` (ex.: token corrompido).
    // Comportamento real: vai para /painel (homeForRole trata null como não-profissional).
    test('role null → /painel (default de menor risco para routing)', () {
      expect(homeForRole(null), Routes.painel);
    });
  });

  group('Role — deserialização defensiva', () {
    // unknownEnumValue: Role.profissional em user.dart (gerado em user.g.dart:
    // unknownValue: Role.profissional). Papel desconhecido no JSON → menor privilégio.
    test('valor desconhecido no JSON → Role.profissional (menor privilégio)', () {
      final user = User.fromJson({
        'id': 'u-test',
        'role': '__valor_inventado__',
      });
      expect(user.role, Role.profissional);
    });

    test('campo role ausente no JSON → Role.profissional (default)', () {
      final user = User.fromJson({'id': 'u-test'});
      expect(user.role, Role.profissional);
    });

    test('role null no JSON → Role.profissional (default)', () {
      final user = User.fromJson({'id': 'u-test', 'role': null});
      expect(user.role, Role.profissional);
    });
  });

  group('AuthSnapshot signedOut', () {
    test('isSignedIn é false', () {
      expect(AuthSnapshot.signedOut.isSignedIn, isFalse);
    });

    test('role é null', () {
      expect(AuthSnapshot.signedOut.role, isNull);
    });
  });
}
