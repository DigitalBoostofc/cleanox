/// pb_tracking_repository.dart — Impl PB do tracking/push do doc 09 (via pb.send).
///
/// Implementa a INTERFACE congelada do core (`TrackingRepository`) sem tocar no
/// core. ⚠️ Só é injetada quando `Env.trackingEnabled == true` (gate G-5) — com a
/// flag OFF, o provider entrega o `UnimplementedTrackingRepository` do core e nada
/// aqui é exercitado. O backend destas rotas está sendo feito em paralelo; esta
/// impl NÃO é necessária para o app compilar/rodar com a flag OFF.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/repositories/whatsapp_repository.dart';

const String _base = '/api/cleanos';

class PbTrackingRepository implements TrackingRepository {
  PbTrackingRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<void> enviarPosicao(
    String osId, {
    required double lat,
    required double lng,
  }) async {
    await _pb.send<dynamic>(
      '$_base/os/$osId/posicao',
      method: 'POST',
      body: {'lat': lat, 'lng': lng},
    );
  }

  @override
  Future<void> cheguei(String osId) async {
    await _pb.send<dynamic>('$_base/os/$osId/cheguei', method: 'POST');
  }

  @override
  Future<void> registrarPush(String token, {required String plataforma}) async {
    await _pb.send<dynamic>(
      '$_base/push/register',
      method: 'POST',
      body: {'token': token, 'plataforma': plataforma},
    );
  }
}
