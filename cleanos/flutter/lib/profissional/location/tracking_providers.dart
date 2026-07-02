/// tracking_providers.dart — Providers dos serviços de localização/push (B4).
///
/// Só fazem sentido com `Env.trackingEnabled`/`Env.pushEnabled`. Os serviços
/// consomem o `TrackingRepository` do core (que, com a flag OFF, é o Unimplemented
/// do core) — então os providers existem sempre, mas os serviços só são usados
/// atrás da flag pela UI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prof_providers.dart';
import 'location_tracking_service.dart';
import 'push_registration_service.dart';

/// Serviço de tracking GPS (foreground service + throttle). Singleton por sessão.
final locationTrackingServiceProvider = Provider<LocationTrackingService>(
  (ref) => LocationTrackingService(ref.watch(trackingRepositoryProvider)),
);

/// Serviço de registro de push (STUB até gate G-2).
final pushRegistrationServiceProvider = Provider<PushRegistrationService>(
  (ref) => PushRegistrationService(ref.watch(trackingRepositoryProvider)),
);
