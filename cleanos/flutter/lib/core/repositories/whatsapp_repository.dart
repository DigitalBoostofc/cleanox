/// whatsapp_repository.dart — Contrato das rotas custom (via `pb.send`).
///
/// Apêndice B do blueprint: /a-caminho, /relatorio, /whatsapp/{status,connect,
/// disconnect}. As rotas de tracking (doc 09, /posicao /cheguei /push/register)
/// ficam em [TrackingRepository], atrás de feature flag (Env.trackingEnabled).
library;

/// Resultado do aviso "a caminho".
class AvisoResult {
  const AvisoResult({required this.ok, this.sentAt});
  final bool ok;
  final String? sentAt;
}

/// Status da conexão WhatsApp (UAZAPI).
class WhatsAppStatus {
  const WhatsAppStatus({required this.connected, this.qr, this.paircode});
  final bool connected;
  final String? qr;
  final String? paircode;
}

abstract class WhatsAppRepository {
  /// POST /os/{id}/a-caminho — profissional dono, em_andamento. 409 se desconectado.
  Future<AvisoResult> avisarACaminho(String osId);

  /// POST /os/{id}/relatorio — admin/gerente ou prof dono.
  Future<void> enviarRelatorio(String osId);

  /// GET /whatsapp/status — admin/gerente.
  Future<WhatsAppStatus> status();

  /// POST /whatsapp/connect — admin/gerente (retorna QR/paircode).
  Future<WhatsAppStatus> connect();

  /// POST /whatsapp/disconnect — admin/gerente.
  Future<void> disconnect();
}

/// Contrato de tracking/push do doc 09 (Fase 2 / gate G-5). Impl fica atrás de
/// `Env.trackingEnabled`/`Env.pushEnabled` — o app compila e roda sem o backend.
abstract class TrackingRepository {
  /// POST /os/{id}/posicao {lat,lng} — throttle no cliente.
  Future<void> enviarPosicao(
    String osId, {
    required double lat,
    required double lng,
  });

  /// POST /os/{id}/cheguei — encerra o tracking.
  Future<void> cheguei(String osId);

  /// POST /push/register {token, plataforma}.
  Future<void> registrarPush(String token, {required String plataforma});
}

/// Stub congelado (Fase 1). Impl real na Fase 2 (Painel WhatsApp + Prof a-caminho).
class UnimplementedWhatsAppRepository implements WhatsAppRepository {
  const UnimplementedWhatsAppRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2: WhatsAppRepository (pb.send)');

  @override
  Future<AvisoResult> avisarACaminho(String osId) => _todo();
  @override
  Future<void> enviarRelatorio(String osId) => _todo();
  @override
  Future<WhatsAppStatus> status() => _todo();
  @override
  Future<WhatsAppStatus> connect() => _todo();
  @override
  Future<void> disconnect() => _todo();
}

/// Stub congelado do tracking (doc 09). Só liga quando o backend existir.
class UnimplementedTrackingRepository implements TrackingRepository {
  const UnimplementedTrackingRepository();

  Never _todo() => throw UnimplementedError(
    'TODO doc 09 (Fase 2, gate G-5): TrackingRepository',
  );

  @override
  Future<void> enviarPosicao(
    String osId, {
    required double lat,
    required double lng,
  }) => _todo();
  @override
  Future<void> cheguei(String osId) => _todo();
  @override
  Future<void> registrarPush(String token, {required String plataforma}) =>
      _todo();
}
