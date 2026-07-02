/// auth_logout_purge_test.dart — Purga LGPD do logout (auditoria A-01/A-05):
///  - apaga as chaves por-OS do secure storage (fila de upload + buffer de
///    checklist), preservando as demais,
///  - dispara a purga do diretório de evidências (fotos da casa do cliente),
///  - limpa o token (authStore) como antes.
library;

import 'package:cleanos/core/auth/auth_service.dart';
import 'package:cleanos/core/storage/local_store_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import '../profissional/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout purga chaves prefixadas + diretório de evidências', () async {
    final storage = FakeSecureStorage({
      '${kUploadQueueKeyPrefix}os1': '[]',
      '${kUploadQueueKeyPrefix}os2': '[{"localId":"l1"}]',
      '${kChecklistBufKeyPrefix}os1': '[{"id":"c1"}]',
      // Não-sensíveis/foram de escopo: devem SOBREVIVER à purga.
      'cleanos_theme_mode': 'dark',
    });
    var evidenciasPurgadas = false;

    var cacheImagensPurgado = false;
    final pb = PocketBase('http://127.0.0.1:9');
    final auth = AuthService(
      pb,
      storage: storage,
      purgeEvidenceFiles: () async => evidenciasPurgadas = true,
      purgeImageDiskCache: () async => cacheImagensPurgado = true,
    );

    auth.logout();
    await pumpEventQueue(); // a purga é fire-and-forget (não bloqueia o logout)

    expect(pb.authStore.isValid, isFalse);
    expect(evidenciasPurgadas, isTrue);
    expect(cacheImagensPurgado, isTrue);
    expect(
      storage.store.keys.toList(),
      ['cleanos_theme_mode'],
      reason: 'só as chaves de execução por OS são varridas',
    );
  });

  test('falha na purga de evidências NÃO derruba o logout', () async {
    final storage = FakeSecureStorage({'${kChecklistBufKeyPrefix}os9': 'x'});
    final pb = PocketBase('http://127.0.0.1:9');
    final auth = AuthService(
      pb,
      storage: storage,
      purgeEvidenceFiles: () async => throw Exception('disco indisponível'),
      purgeImageDiskCache: () async {},
    );

    expect(auth.logout, returnsNormally);
    await pumpEventQueue();

    expect(pb.authStore.isValid, isFalse);
    expect(storage.store, isEmpty, reason: 'a varredura de chaves ainda roda');
  });
}
