/// main_profissional.dart — Entrypoint do APP DO PROFISSIONAL (Android).
///
/// Rode com (dev local contra o PB da máquina):
///   flutter run -d ANDROID_DEVICE_ID --dart-define=PB_URL=http://10.0.2.2:8090 \
///     -t lib/main_profissional.dart
///   (10.0.2.2 é o host da máquina visto de dentro do emulador Android.)
/// Produção (default de PB_URL já é https://cleanox.wenox.com.br):
///   flutter build apk --release -t lib/main_profissional.dart
///
/// iOS fica bloqueado pelo gate do dono (G-1: conta Apple + Mac/CI).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/pb/pb_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PbClient.init();
  runApp(
    const ProviderScope(child: CleanosApp(surface: AppSurface.profissional)),
  );
}
