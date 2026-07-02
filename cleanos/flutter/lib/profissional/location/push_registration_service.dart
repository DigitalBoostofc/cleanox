/// push_registration_service.dart — Registro de push FCM (STUB — gate G-2).
///
/// O Firebase fica COMENTADO até o dono liberar a conta/keys (gate G-2). Este
/// serviço existe para a fiação (registrar/limpar token) ficar pronta: quando o
/// Firebase entrar, basta descomentar a obtenção do token e chamar
/// `TrackingRepository.registrarPush`. Enquanto isso, [register] é no-op.
library;

import '../../core/env/env.dart';
import '../../core/repositories/whatsapp_repository.dart';

/// Gancho de deep-link do push: recebe o id da OS a abrir. O [ProfShell] liga
/// com `(osId) => context.go('/app/os/$osId')` — a rota `/app/os/:osId` é
/// deep-linkável (StatefulShellRoute), então o toque na notificação "Nova OS"
/// abre direto a execução.
typedef PushOpenOs = void Function(String osId);

class PushRegistrationService {
  PushRegistrationService(this._tracking);

  final TrackingRepository _tracking;

  /// Callback de navegação (deep-link). Ligado pelo [ProfShell] via
  /// [bindDeepLink]; null enquanto ninguém ligou.
  PushOpenOs? _openOs;

  /// Liga o gancho de navegação do deep-link. Idempotente (a última ligação
  /// vence). Chamado pelo `ProfShell` com o `context.go` da superfície.
  void bindDeepLink(PushOpenOs openOs) => _openOs = openOs;

  /// Handler do toque na notificação "Nova OS": abre a execução deep-linkada.
  /// No-op se o gancho ainda não foi ligado. Fecha o finding G-8/#8 do doc 09
  /// quando o Firebase (gate G-2) entregar `onMessageOpenedApp`.
  void openOsFromNotification(String osId) => _openOs?.call(osId);

  /// Registra o token de push do aparelho. STUB: só age quando
  /// `Env.pushEnabled` e o Firebase estiver conectado (gate G-2).
  Future<void> register() async {
    if (!Env.pushEnabled) return; // Firebase ainda não liberado — no-op.

    // ── TODO (gate G-2): descomentar quando firebase_messaging entrar. ──
    // await Firebase.initializeApp();
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission();
    // final token = await messaging.getToken();
    // if (token != null) {
    //   await _tracking.registrarPush(token, plataforma: 'android');
    // }
    // messaging.onTokenRefresh.listen((t) =>
    //   _tracking.registrarPush(t, plataforma: 'android'));
    //
    // // Deep-link (finding G-8/#8): notificação "Nova OS" abre a execução.
    // FirebaseMessaging.onMessageOpenedApp.listen((m) {
    //   final osId = m.data['osId'] as String?;
    //   if (osId != null && osId.isNotEmpty) openOsFromNotification(osId);
    // });
    // final initial = await messaging.getInitialMessage();
    // final coldOsId = initial?.data['osId'] as String?;
    // if (coldOsId != null && coldOsId.isNotEmpty) openOsFromNotification(coldOsId);

    // Mantém a referência viva para quando o corpo real (gate G-2) entrar.
    final _ = _tracking;
  }
}
