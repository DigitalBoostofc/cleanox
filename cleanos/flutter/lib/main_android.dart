/// main_android.dart — Entrypoint UNIFICADO do APK Android (CleanOS).
///
/// Um único APK serve admin, gerente e profissional: o roteamento por papel
/// mora no go_router (`app_router.dart` → `homeForRole`). Este entrypoint
/// apenas inicializa o SDK e passa `AppSurface.android`; não há
/// inicializações divergentes entre papéis no Android.
///
/// Rode com (dev local):
///   flutter run -d DEVICE_ID --dart-define=PB_URL=http://10.0.2.2:8090 \
///     -t lib/main_android.dart
/// Produção:
///   flutter build apk --release --split-per-abi -t lib/main_android.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/pb/pb_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PbClient.init();
  runApp(
    const ProviderScope(child: CleanosApp(surface: AppSurface.android)),
  );
}
