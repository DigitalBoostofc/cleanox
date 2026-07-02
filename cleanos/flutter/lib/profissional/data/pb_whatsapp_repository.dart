/// pb_whatsapp_repository.dart — Impl PB das rotas custom de WhatsApp (via pb.send).
///
/// Implementa a INTERFACE congelada do core (`WhatsAppRepository`) sem tocar no
/// core. Porte do Apêndice B do blueprint. O profissional só usa
/// [avisarACaminho] (em_andamento, dono da OS); as rotas admin (status/connect/
/// disconnect) existem para o Painel reusar a mesma impl.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/repositories/whatsapp_repository.dart';

/// Prefixo das rotas custom do CleanOS (espelha o web: `/api/cleanos/...`).
const String _base = '/api/cleanos';

class PbWhatsAppRepository implements WhatsAppRepository {
  PbWhatsAppRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<AvisoResult> avisarACaminho(String osId) async {
    final res = await _pb.send<Map<String, dynamic>>(
      '$_base/os/$osId/a-caminho',
      method: 'POST',
    );
    return AvisoResult(ok: res['ok'] == true, sentAt: res['sentAt'] as String?);
  }

  @override
  Future<void> enviarRelatorio(String osId) async {
    await _pb.send<dynamic>('$_base/os/$osId/relatorio', method: 'POST');
  }

  @override
  Future<WhatsAppStatus> status() async {
    final res = await _pb.send<Map<String, dynamic>>('$_base/whatsapp/status');
    return _statusFrom(res);
  }

  @override
  Future<WhatsAppStatus> connect() async {
    final res = await _pb.send<Map<String, dynamic>>(
      '$_base/whatsapp/connect',
      method: 'POST',
    );
    return _statusFrom(res);
  }

  @override
  Future<void> disconnect() async {
    await _pb.send<dynamic>('$_base/whatsapp/disconnect', method: 'POST');
  }

  // O backend (ratings_routes/whatsapp_routes) responde com o shape
  // `{ status, qrcode, paircode? }` (connect) e `{ configured, status, ... }`
  // (status) — NÃO envia `connected`/`qr`. Mapeamos a partir do shape real.
  WhatsAppStatus _statusFrom(Map<String, dynamic> res) => WhatsAppStatus(
    connected: res['status'] == 'connected',
    qr: res['qrcode'] as String?,
    paircode: res['paircode'] as String?,
  );
}
