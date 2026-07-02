/// pb_client.dart — Singleton PocketBase + AsyncAuthStore em armazenamento seguro.
///
/// Espelha `web/src/lib/pb.ts` (client + baseURL) e o boot do `AuthContext`
/// (`authRefresh().catch(clear)`). Diferença mobile (blueprint §2):
///   - o token NÃO vai para SharedPreferences (anti-pattern de segurança). Usa
///     `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) via
///     `AsyncAuthStore`.
///   - refresh proativo no boot; se expirado → limpa a sessão (redirect ao login).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';

import '../env/env.dart';
import '../models/collections.dart';

/// Chave do blob de auth no secure storage.
const String kAuthStorageKey = 'cleanos_pb_auth';

/// Fachada do cliente PocketBase compartilhado pelas duas superfícies.
///
/// [PbClient.init] deve ser chamado UMA vez no boot (nas mains), pois a leitura
/// inicial do token no secure storage é assíncrona (o `AsyncAuthStore` recebe o
/// valor já resolvido). Depois, `PbClient.instance` expõe o `PocketBase`.
class PbClient {
  PbClient._(this.pb);

  final PocketBase pb;

  static PbClient? _instance;

  /// Instância única. Lança se [init] ainda não rodou.
  static PbClient get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('PbClient.init() precisa ser chamado antes de usar.');
    }
    return i;
  }

  static bool get isReady => _instance != null;

  /// Inicializa o singleton: carrega o token persistido e liga o auto-refresh.
  /// [storage] é injetável para testes. [autoRefresh] pode ser desligado em teste.
  static Future<PbClient> init({
    FlutterSecureStorage? storage,
    bool autoRefresh = true,
  }) async {
    if (_instance != null) return _instance!;

    final secure = storage ?? const FlutterSecureStorage();
    String? initial;
    try {
      initial = await secure.read(key: kAuthStorageKey);
    } catch (_) {
      initial = null; // storage indisponível — degrada para sessão nova
    }

    final authStore = AsyncAuthStore(
      initial: initial,
      save: (data) async {
        try {
          await secure.write(key: kAuthStorageKey, value: data);
        } catch (_) {
          /* best-effort: não derruba a sessão em memória por falha de disco */
        }
      },
      clear: () async {
        try {
          await secure.delete(key: kAuthStorageKey);
        } catch (_) {
          /* best-effort */
        }
      },
    );

    final pb = PocketBase(Env.pbUrl, authStore: authStore);
    final client = PbClient._(pb);
    _instance = client;

    if (autoRefresh) {
      await client.refreshSessionOnBoot();
    }
    return client;
  }

  /// Renova o token proativamente. Se inválido/expirado, limpa a sessão.
  /// Espelha `authRefresh().catch(() => authStore.clear())` do AuthContext.
  Future<void> refreshSessionOnBoot() async {
    if (!pb.authStore.isValid) return;
    try {
      await pb.collection(Collections.users).authRefresh();
    } catch (_) {
      pb.authStore.clear();
    }
  }

  /// Apenas para testes: descarta o singleton entre casos.
  static void resetForTest() => _instance = null;
}
