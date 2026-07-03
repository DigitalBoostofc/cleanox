/// server_error.dart — Extrai a mensagem útil do corpo de erro do backend.
///
/// As rotas custom (a-caminho / relatorio) devolvem 409 com `{ error: "..." }`
/// explicando o motivo (ex.: "WhatsApp não está conectado…"). O `pb.send` lança
/// `ClientException` e o corpo fica em `response`. Este helper recupera esse
/// `error` para o toast — caindo em `describeOSError` quando não há corpo útil.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/errors/os_error.dart';

/// Mensagem amigável priorizando o `error` do corpo do backend (rotas custom).
String serverErrorMessage(Object? err) {
  if (err is ClientException) {
    final e = err.response['error'];
    if (e is String && e.isNotEmpty) return e;
  }
  return describeOSError(err).message;
}
