/// auth_service.dart — login/logout/refresh/role. Espelha `AuthContext.tsx`.
///
/// Fonte única de auth das DUAS superfícies. Ninguém reimplementa auth (§3.1).
library;

import 'package:pocketbase/pocketbase.dart';

import '../models/collections.dart';
import '../models/user.dart';

/// Erro de login já traduzido para PT-BR (espelha as mensagens do AuthContext).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Snapshot do estado de autenticação.
class AuthSnapshot {
  const AuthSnapshot({this.user});
  final User? user;
  Role? get role => user?.role;
  bool get isSignedIn => user != null;

  static const AuthSnapshot signedOut = AuthSnapshot();
}

class AuthService {
  AuthService(this._pb);

  final PocketBase _pb;

  User? get currentUser {
    final rec = _pb.authStore.record;
    if (!_pb.authStore.isValid || rec == null) return null;
    return User.fromRecord(rec);
  }

  Role? get currentRole => currentUser?.role;
  bool get isSignedIn => _pb.authStore.isValid;

  AuthSnapshot get snapshot => AuthSnapshot(user: currentUser);

  /// Emite o estado atual e cada mudança do authStore (refresh, login, logout).
  Stream<AuthSnapshot> watch() async* {
    yield snapshot;
    yield* _pb.authStore.onChange.map((_) => snapshot);
  }

  /// authWithPassword('users') → roteia por role no chamador.
  /// Traduz erros como o AuthContext (400/401 → credencial, 0 → offline).
  Future<User> login(String email, String password) async {
    try {
      final auth = await _pb
          .collection(Collections.users)
          .authWithPassword(email, password);
      return User.fromRecord(auth.record);
    } on ClientException catch (err) {
      if (err.statusCode == 400 || err.statusCode == 401) {
        throw const AuthException('E-mail ou senha inválidos.');
      }
      if (err.statusCode == 0) {
        throw const AuthException(
          'Não foi possível conectar ao servidor. Verifique sua internet.',
        );
      }
      throw const AuthException('Ocorreu um erro inesperado. Tente novamente.');
    } catch (_) {
      throw const AuthException('Ocorreu um erro inesperado. Tente novamente.');
    }
  }

  void logout() => _pb.authStore.clear();
}
