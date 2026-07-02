/// location_tracking_service.dart — Tracking GPS ao vivo (Slice B4, doc 09).
///
/// ⚠️ TUDO atrás de `Env.trackingEnabled` (gate G-5). Com a flag OFF nada aqui é
/// exercitado e o app compila/roda normalmente. Implementa:
///   - foreground service Android + notificação persistente (flutter_foreground_task),
///   - stream de posição do geolocator com THROTTLE ~25s,
///   - envio via `TrackingRepository` do core (rotas /posicao, /cheguei).
/// O backend das rotas está sendo feito em paralelo (migration 17 do doc 09) — esta
/// classe NÃO depende dele para compilar (fala só com a interface do core).
///
/// Degradação: permissão negada → [start] devolve false; a UI esconde o tracking
/// automático e mantém só o "Cheguei" manual.
library;

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/repositories/whatsapp_repository.dart';

/// Resultado da tentativa de iniciar o tracking.
enum TrackingStartResult {
  /// Tracking iniciado (foreground service + stream ligados).
  iniciado,

  /// Permissão de localização negada — a UI cai para o "Cheguei" manual.
  permissaoNegada,

  /// Serviço de localização (GPS) desligado no aparelho.
  gpsDesligado,
}

class LocationTrackingService {
  LocationTrackingService(this._tracking);

  final TrackingRepository _tracking;

  StreamSubscription<Position>? _sub;
  DateTime? _lastSent;
  String? _osId;

  /// Throttle mínimo entre POSTs de posição (~25s, faixa 20-30s do doc 09).
  static const Duration _throttle = Duration(seconds: 25);

  bool get isTracking => _osId != null;
  String? get trackingOsId => _osId;

  /// Garante a permissão de localização (fluxo: serviço ligado → checkPermission
  /// → requestPermission se negada).
  Future<LocationPermission> ensurePermission() async {
    final servicoOn = await Geolocator.isLocationServiceEnabled();
    if (!servicoOn) return LocationPermission.deniedForever;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm;
  }

  /// Inicia o tracking de uma OS. Devolve o resultado (para a UI degradar).
  Future<TrackingStartResult> start(String osId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return TrackingStartResult.gpsDesligado;
    }
    final perm = await ensurePermission();
    final ok =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (!ok) return TrackingStartResult.permissaoNegada;

    _osId = osId;
    _lastSent = null;
    _initForegroundTask();
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        serviceTypes: const [ForegroundServiceTypes.location],
        notificationTitle: 'Cleanox — a caminho',
        notificationText: 'Compartilhando sua localização com o cliente.',
      );
    }
    await _sub?.cancel();
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
        ).listen(
          _onPosition,
          onError: (_) {
            /* erro de GPS transitório — ignora */
          },
        );
    return TrackingStartResult.iniciado;
  }

  void _onPosition(Position p) {
    final id = _osId;
    if (id == null) return;
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < _throttle) return;
    _lastSent = now;
    unawaited(
      _tracking.enviarPosicao(id, lat: p.latitude, lng: p.longitude).catchError(
        (_) {
          /* offline/transitório — próximo tick tenta */
        },
      ),
    );
  }

  /// "Cheguei ao local": encerra o tracking e notifica o backend.
  Future<void> chegou() async {
    final id = _osId;
    await stop();
    if (id != null) {
      try {
        await _tracking.cheguei(id);
      } catch (_) {
        /* best-effort: o servidor também encerra por timeout */
      }
    }
  }

  /// Encerra o tracking (para stream + foreground service).
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _osId = null;
    _lastSent = null;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cleanos_tracking',
        channelName: 'Localização em serviço',
        channelDescription:
            'Ativa enquanto você compartilha a localização a caminho da OS.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
  }
}
