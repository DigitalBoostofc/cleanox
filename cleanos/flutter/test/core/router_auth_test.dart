/// Testes da lógica de roteamento por papel (RootRedirect/RoleGuard do App.tsx).
library;

import 'package:cleanos/core/auth/auth_service.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/router/app_router.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeForRole', () {
    test('profissional → /app', () {
      expect(homeForRole(Role.profissional), Routes.app);
    });
    test('admin/gerente → /painel', () {
      expect(homeForRole(Role.admin), Routes.painel);
      expect(homeForRole(Role.gerente), Routes.painel);
    });
    test('sem papel → /painel (default)', () {
      expect(homeForRole(null), Routes.painel);
    });
  });

  group('Role flags', () {
    test('isPainel / isProfissional', () {
      expect(Role.admin.isPainel, isTrue);
      expect(Role.gerente.isPainel, isTrue);
      expect(Role.profissional.isProfissional, isTrue);
      expect(Role.profissional.isPainel, isFalse);
    });
    test('wire', () {
      expect(Role.profissional.wire, 'profissional');
    });
  });

  group('OSStatus', () {
    test('fromWire / label', () {
      expect(OSStatus.fromWire('em_andamento'), OSStatus.emAndamento);
      expect(OSStatus.emAndamento.label, 'Em andamento');
      expect(OSStatus.emAndamento.wire, 'em_andamento');
    });
    test('fromWire desconhecido → agendada', () {
      expect(OSStatus.fromWire('???'), OSStatus.agendada);
    });
  });

  group('AuthSnapshot', () {
    test('deslogado', () {
      expect(AuthSnapshot.signedOut.isSignedIn, isFalse);
      expect(AuthSnapshot.signedOut.role, isNull);
    });
    test('logado expõe papel do user', () {
      final snap = AuthSnapshot(
        user: const User(id: 'u1', role: Role.gerente),
      );
      expect(snap.isSignedIn, isTrue);
      expect(snap.role, Role.gerente);
    });
  });
}
