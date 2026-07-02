/// auth_service.dart — login/logout/refresh/role. Espelha `AuthContext.tsx`.
///
/// Fonte única de auth das DUAS superfícies. Ninguém reimplementa auth (§3.1).
library;

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show DefaultCacheManager;
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

  /// Encerra a sessão. Além de limpar o token do secure storage (via authStore),
  /// PURGA os caches locais sensíveis do dispositivo — imagens de evidência do
  /// cliente ficam em cache em disco/memória (LGPD). Espelha o React, que apaga
  /// todo o Cache Storage no logout. Best-effort e não bloqueante.
  void logout() {
    _pb.authStore.clear();
    _purgeLocalCaches();
  }

  /// Limpeza best-effort dos caches locais (fire-and-forget). Falhas são
  /// engolidas: não devem impedir/atrasar o logout nem derrubar a navegação.
  void _purgeLocalCaches() {
    try {
      // Cache de imagens EM MEMÓRIA (thumbnails de evidências já decodificadas).
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache
        ..clear()
        ..clearLiveImages();
    } catch (_) {
      /* binding indisponível (ex.: teste) — ignora */
    }
    // Cache de imagens EM DISCO do cached_network_image (fotos do cliente).
    DefaultCacheManager().emptyCache().catchError((_) {});
  }
}
