/// Auth do admin da vitrine (admin|gerente only; profissional bloqueado).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_service.dart';
import '../../core/env/env.dart';
import '../../core/models/user.dart';
import '../vitrine_api.dart';

/// PocketBase dedicado à sessão do admin da vitrine (não mistura com painel).
final vitrineAdminPbProvider = Provider<PocketBase>((ref) {
  return PocketBase(Env.pbUrl);
});

final vitrineAdminAuthProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(vitrineAdminPbProvider));
});

final vitrineAdminApiProvider = Provider<VitrineApi>((ref) {
  return VitrineApi(pb: ref.watch(vitrineAdminPbProvider));
});

final vitrineAdminUserProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(vitrineAdminAuthProvider);
  yield* auth.watch().map((s) {
    final u = s.user;
    if (u == null) return null;
    if (!u.role.isPainel) {
      // profissional ou papel inválido
      auth.logout();
      return null;
    }
    return u;
  });
});

extension RolePainelX on Role {
  bool get isPainelAdminVitrine => this == Role.admin || this == Role.gerente;
}
