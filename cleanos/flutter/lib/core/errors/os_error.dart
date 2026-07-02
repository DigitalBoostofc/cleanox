/// os_error.dart — Tradução amigável de erros do PocketBase.
///
/// Porte fiel de `describeOSError` de `web/src/lib/os/osStore.ts`:
///   - status 0   → offline (sem conexão)
///   - status 403 → sem permissão
///   - status 404 → não encontrado
/// O cliente trata 403 GRACIOSAMENTE (nunca esconde o botão e assume que passou —
/// o servidor é a linha de defesa do anti-desvio).
library;

import 'package:pocketbase/pocketbase.dart';

class OSError {
  const OSError({
    required this.message,
    this.isPermission = false,
    this.isOffline = false,
    this.isNotFound = false,
  });

  final String message;

  /// true para HTTP 403 — sem permissão (ex.: profissional sem acesso à OS).
  final bool isPermission;

  /// true para HTTP 0 — sem conexão com o servidor.
  final bool isOffline;

  /// true para HTTP 404 — OS/registro inexistente.
  final bool isNotFound;
}

/// Espelha `describeOSError(err)` do web. Aceita qualquer erro; reconhece
/// `ClientException` do SDK PocketBase (Dart).
OSError describeOSError(Object? err) {
  if (err is ClientException) {
    if (err.statusCode == 0) {
      return const OSError(
        message: 'Sem conexão com o servidor. Verifique sua internet.',
        isOffline: true,
      );
    }
    if (err.statusCode == 403) {
      return const OSError(
        message: 'Você não tem permissão para esta ação.',
        isPermission: true,
      );
    }
    if (err.statusCode == 404) {
      return const OSError(
        message: 'Ordem de serviço não encontrada.',
        isNotFound: true,
      );
    }
    final data = err.response['message'];
    if (data is String && data.isNotEmpty) {
      return OSError(message: data);
    }
    return OSError(message: 'Erro ${err.statusCode}: tente novamente.');
  }
  if (err is Exception || err is Error) {
    return OSError(message: err.toString());
  }
  return const OSError(message: 'Erro inesperado.');
}
