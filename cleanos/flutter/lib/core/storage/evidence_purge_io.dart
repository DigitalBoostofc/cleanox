/// evidence_purge_io.dart — Purga do diretório de evidências (plataformas IO).
///
/// Implementação real (Android/iOS/desktop) selecionada por import condicional
/// em `evidence_purge.dart`. Apaga recursivamente o diretório app-private onde
/// a execução copia as fotos de evidência (interior da casa do cliente = PII;
/// auditoria A-01). Best-effort: quem chama (`AuthService`) engole falhas.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_store_keys.dart';

/// Remove `<documents>/cleanos_evidencias` inteiro (fotos já enviadas têm o
/// registro no PocketBase como fonte; pendentes de OUTRA sessão são resíduo).
Future<void> purgeEvidenceDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/$kEvidenceDirName');
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
