/// pb_painel_whatsapp_repository.dart — Impl PB das rotas de WhatsApp/UAZAPI do
/// Painel (admin/gerente), via `pb.send`.
///
/// Implementa a interface congelada `WhatsAppRepository` do core. Cobre:
///   • [enviarRelatorio] — POST /api/cleanos/os/{id}/relatorio (envio a partir da
///     execução admin; aberto a admin/gerente/prof dono);
///   • [status]/[connect]/[disconnect] — seção WhatsApp da Onda 5 (admin/gerente).
/// A rota [avisarACaminho] é EXCLUSIVA do profissional (em_andamento, dono da OS)
/// — o Painel nunca a chama, então lança aqui em vez de fingir sucesso.
///
/// O mapeamento do shape do backend (`status == 'connected'`, `qrcode`) espelha
/// FIELMENTE o lado do profissional (`profissional/data/pb_whatsapp_repository.dart`):
/// o backend responde `{ configured, status, instanceName, profileName? }` (status)
/// e `{ status, qrcode, paircode? }` (connect) — NUNCA `connected`/`qr`.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/repositories/whatsapp_repository.dart';

/// Prefixo das rotas custom do CleanOS (espelha o web: `/api/cleanos/...`).
const String _base = '/api/cleanos';

class PbPainelWhatsAppRepository implements WhatsAppRepository {
  PbPainelWhatsAppRepository(this._pb);

  final PocketBase _pb;

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

  // Mapeia o shape REAL do backend → `WhatsAppStatus` do core. O backend usa
  // `status`/`qrcode`/`paircode` (não `connected`/`qr`), então traduzimos aqui.
  WhatsAppStatus _statusFrom(Map<String, dynamic> res) => WhatsAppStatus(
    connected: res['status'] == 'connected',
    qr: res['qrcode'] as String?,
    paircode: res['paircode'] as String?,
    profileName: res['profileName'] as String?,
  );

  Never _soDoProfissional() => throw UnimplementedError(
    'Rota exclusiva do app do profissional (dono da OS).',
  );

  @override
  Future<AvisoResult> avisarACaminho(String osId) => _soDoProfissional();

  @override
  Future<ContatoClienteResult> contatoCliente(String osId) =>
      _soDoProfissional();
}
