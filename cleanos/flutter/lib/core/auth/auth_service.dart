/// auth_service.dart — login/logout/refresh/role. Espelha `AuthContext.tsx`.
///
/// Fonte única de auth das DUAS superfícies. Ninguém reimplementa auth (§3.1).
library;

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show DefaultCacheManager;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/collections.dart';
import '../models/user.dart';
import '../storage/evidence_purge.dart' as evidence_purge;
import '../storage/local_store_keys.dart';

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

/// Purga default do cache em disco do cached_network_image. O construtor do
/// `DefaultCacheManager` já dispara IO assíncrono (path_provider/sqflite) —
/// numa VM de teste isso vira erro assíncrono fora de try/catch, por isso a
/// função inteira é injetável e o default só roda no app real.
Future<void> _defaultImageDiskCachePurge() =>
    DefaultCacheManager().emptyCache();

class AuthService {
  /// [storage], [purgeEvidenceFiles] e [purgeImageDiskCache] são injetáveis
  /// para teste; os defaults são o secure storage real, a purga de plataforma
  /// (`evidence_purge.dart`) e o `DefaultCacheManager().emptyCache()`.
  AuthService(
    this._pb, {
    FlutterSecureStorage? storage,
    Future<void> Function()? purgeEvidenceFiles,
    Future<void> Function()? purgeImageDiskCache,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _purgeEvidenceFiles =
           purgeEvidenceFiles ?? evidence_purge.purgeEvidenceDir,
       _purgeImageDiskCache = purgeImageDiskCache ?? _defaultImageDiskCachePurge;

  final PocketBase _pb;
  final FlutterSecureStorage _storage;
  final Future<void> Function() _purgeEvidenceFiles;
  final Future<void> Function() _purgeImageDiskCache;

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
    // Fotos de evidência copiadas para o app-private dir (A-01): o registro no
    // PocketBase é a fonte — a cópia local é resíduo LGPD após o logout.
    try {
      _purgeEvidenceFiles().catchError((_) {});
    } catch (_) {
      /* plataforma sem suporte — ignora */
    }
    // Buffers por-OS no secure storage (A-05): fila de upload + checklist
    // offline não podem sobreviver à troca de usuário no mesmo aparelho.
    _purgeSecureKeys().catchError((_) {});
    // Cache de imagens EM DISCO do cached_network_image (fotos do cliente).
    try {
      _purgeImageDiskCache().catchError((_) {});
    } catch (_) {
      /* plugin indisponível (ex.: teste) — ignora */
    }
  }

  /// Apaga as chaves de execução por OS ([kLgpdPurgeKeyPrefixes]) do secure
  /// storage. O token de auth já foi limpo pelo `authStore.clear()`.
  Future<void> _purgeSecureKeys() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (kLgpdPurgeKeyPrefixes.any(key.startsWith)) {
        await _storage.delete(key: key);
      }
    }
  }
}
