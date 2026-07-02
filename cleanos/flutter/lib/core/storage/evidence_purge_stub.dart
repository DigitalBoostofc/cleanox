/// evidence_purge_stub.dart — Stub no-op da purga de evidências (web).
///
/// No Flutter Web (Painel) não existe `dart:io` nem diretório de documentos —
/// as evidências nunca são copiadas para disco local ali (o upload do Painel é
/// direto da memória). Selecionado por import condicional em
/// `evidence_purge.dart`.
library;

Future<void> purgeEvidenceDir() async {}
