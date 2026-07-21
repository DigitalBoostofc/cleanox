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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/pb/pb_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Evita "tela branca" silenciosa: erros de layout/runtime ficam visíveis.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint(details.exceptionAsString());
      debugPrint(details.stack?.toString());
    }
  };
  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFF0B1D34),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Algo falhou ao abrir o painel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFFFD0D0), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    await PbClient.init();
  } catch (e, st) {
    debugPrint('PbClient.init falhou: $e\n$st');
    // Ainda sobe o app — login pode funcionar com sessão limpa.
    try {
      await PbClient.init(autoRefresh: false);
    } catch (_) {
      /* último recurso: deixa o runApp mostrar a UI de login */
    }
  }

  runApp(const ProviderScope(child: CleanosApp(surface: AppSurface.painel)));
}
