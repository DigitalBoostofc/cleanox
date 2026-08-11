/// Contratos de autenticação e destino do cliente administrativo da vitrine.
library;

import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('VitrineApi usa backend e token do PocketBase autenticado', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{}', 200);
    });
    final pb = PocketBase('https://workspace.cleanox.test');
    pb.authStore.save('token-do-painel', null);

    await VitrineApi(client: client, pb: pb).adminGetConfig();

    expect(captured.url.origin, 'https://workspace.cleanox.test');
    expect(captured.url.path, '/api/cleanos/vitrine/admin/config');
    expect(captured.headers['Authorization'], 'token-do-painel');
  });
}
