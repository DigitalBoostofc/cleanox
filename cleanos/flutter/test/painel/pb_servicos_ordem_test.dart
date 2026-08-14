import 'dart:convert';

import 'package:cleanos/painel/data/pb_servicos_repository.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

Map<String, dynamic> _record({
  required String id,
  required String categoria,
  required String grupo,
  required int ordem,
}) => <String, dynamic>{
  'id': id,
  'collectionId': 'servicos_collection',
  'collectionName': 'servicos',
  'created': '2026-08-14 00:00:00.000Z',
  'updated': '2026-08-14 00:00:00.000Z',
  'nome': 'Serviço',
  'categoria': categoria,
  'grupo': grupo,
  'ordem': ordem,
  'ativo': true,
};

void main() {
  test('reordenação envia a sequência inteira para a rota atômica', () async {
    Map<String, dynamic>? requestBody;
    final pb = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'updated': 2}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await TaxonomiaRepository(pb).reorderCatalog(
      kind: 'servicos',
      ids: ['segundo', 'primeiro'],
    );

    expect(requestBody, {
      'kind': 'servicos',
      'ids': ['segundo', 'primeiro'],
    });
  });

  test('mover serviço de grupo o posiciona no fim do destino', () async {
    Map<String, dynamic>? patchBody;
    final pb = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/svc-old')) {
          return http.Response(
            jsonEncode(
              _record(
                id: 'svc-old',
                categoria: 'residencial',
                grupo: 'sofa',
                ordem: 10,
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/api/collections/servicos/records')) {
          return http.Response(
            jsonEncode({
              'page': 1,
              'perPage': 1,
              'totalItems': 1,
              'totalPages': 1,
              'items': [
                _record(
                  id: 'svc-destino',
                  categoria: 'residencial',
                  grupo: 'colchao',
                  ordem: 30,
                ),
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/svc-old')) {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              _record(
                id: 'svc-old',
                categoria: 'residencial',
                grupo: 'colchao',
                ordem: (patchBody!['ordem'] as num).toInt(),
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await PbServicosRepository(pb).update('svc-old', {
      'categoria': 'residencial',
      'grupo': 'colchao',
      'nome': 'Serviço',
    });

    expect(patchBody?['ordem'], 40);
  });
}
