/// Configuração de ambiente resolvida em tempo de compilação via `--dart-define`.
///
/// Espelha `web/src/lib/pb.ts` (`import.meta.env.VITE_PB_URL`). O default aponta
/// para produção (`https://cleanox.wenox.com.br`, ver memória de deploy). Para dev
/// local contra o PocketBase da máquina, rode com:
///   --dart-define=PB_URL=http://127.0.0.1:8090
///
/// Chaves de GPS/Push (doc 09) ficam STUB até o gate do dono (G-2). O app compila
/// e roda sem elas; `trackingEnabled`/`pushEnabled` só ligam quando o backend do
/// doc 09 existir e as chaves chegarem.
class Env {
  const Env._();

  /// URL base do PocketBase. Produção por default; dev via --dart-define.
  static const String pbUrl = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'https://cleanox.wenox.com.br',
  );

  /// STUB (doc 09 / gate G-2) — chave do Google Maps para GPS/ETA. Vazia = desligado.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Feature flag de tracking GPS (doc 09). Falso até o backend existir (gate G-5).
  static const bool trackingEnabled = bool.fromEnvironment(
    'TRACKING_ENABLED',
    defaultValue: false,
  );

  /// Feature flag de push FCM (doc 09). Falso até Firebase liberado (gate G-2).
  static const bool pushEnabled = bool.fromEnvironment(
    'PUSH_ENABLED',
    defaultValue: false,
  );
}
