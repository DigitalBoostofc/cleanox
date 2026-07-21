/// Stub non-web: devolve o CSV para o caller copiar/tratar.
Future<void> finDownloadTextFile(String filename, String content) async {
  // Sem download nativo fora da web — o caller usa Clipboard.
  throw UnsupportedError('download_not_web');
}
