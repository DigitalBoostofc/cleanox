/// main_vitrine.dart — Entrypoint da VITRINE pública (Flutter Web · cliente).
///
/// Superfície **sem login**. Consome só `/api/cleanos/vitrine/*`.
///
/// Dev:
///   flutter run -d chrome --dart-define=PB_URL=http://127.0.0.1:8090 \
///     -t lib/main_vitrine.dart
/// Prod:
///   flutter build web --release -t lib/main_vitrine.dart
///   # deploy em host do subdomínio (ex. vitrine.cleanox.com.br)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'vitrine/vitrine_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path-based URLs (/admin, /admin/login) — sem isso o browser em
  // agendar.cleanox.com.br/admin carrega a home e ignora o path.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint(details.exceptionAsString());
    }
  };
  runApp(const ProviderScope(child: VitrineApp()));
}
