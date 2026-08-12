/// Contratos de autenticação e destino do cliente administrativo da vitrine.
library;

import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:convert';

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

  test('salva configuração comercial completa do serviço', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{}', 200);
    });

    await VitrineApi(
      client: client,
      baseUrl: 'https://app.cleanox.test',
    ).adminPatchServico(
      'svc1',
      vitrine: true,
      vitrineDestaque: true,
      layout: VitrineServicoLayout.antesDepois,
      vitrineTitulo: 'Sofá renovado',
      vitrineDescricao: 'Resultado visível.',
      vitrineBadge: 'Mais escolhido',
      vitrineCta: 'Quero este cuidado',
      precoModo: VitrinePrecoModo.sobAvaliacao,
      vitrineOrdem: 7,
    );

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/cleanos/vitrine/admin/servicos/svc1');
    expect(jsonDecode(captured.body), {
      'vitrine': true,
      'vitrine_destaque': true,
      'vitrine_layout': 'antes_depois',
      'vitrine_titulo': 'Sofá renovado',
      'vitrine_descricao': 'Resultado visível.',
      'vitrine_badge': 'Mais escolhido',
      'vitrine_cta': 'Quero este cuidado',
      'vitrine_preco_modo': 'sob_avaliacao',
      'vitrine_ordem': 7,
    });
  });
}
