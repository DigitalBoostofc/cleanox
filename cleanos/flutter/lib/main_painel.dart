/// main_painel.dart — Entrypoint do PAINEL (Flutter Web · admin/gerente).
///
/// Rode com (dev local contra o PB da máquina):
///   flutter run -d chrome --dart-define=PB_URL=http://127.0.0.1:8090 \
///     -t lib/main_painel.dart
/// Produção (default de PB_URL já é https://app.cleanox.com.br):
///   flutter build web --release -t lib/main_painel.dart
///
/// O binário compartilha o core; o roteamento por papel garante que só
/// admin/gerente cheguem em /painel (profissional é redirecionado a /app).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/pb/pb_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PbClient.init();
  runApp(const ProviderScope(child: CleanosApp(surface: AppSurface.painel)));
}
