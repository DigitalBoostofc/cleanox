/// Teste REAL do PbOrdensRepository sobre o SDK PocketBase com o transporte HTTP
/// mockado (MockClient). Não há PB local, então injetamos respostas HTTP e
/// verificamos: (1) o filtro do profissional, (2) o parse de OrdemServico +
/// expand, (3) o body de updateStatus. Prova que o repo lê `ordens_servico`.
library;

import 'dart:convert';

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

Map<String, dynamic> _osRecord({String status = 'em_andamento'}) => {
  'id': 'os123',
  'collectionId': 'col',
  'collectionName': 'ordens_servico',
  'created': '2026-07-01 10:00:00.000Z',
  'updated': '2026-07-01 11:00:00.000Z',
  'cliente': 'cli1',
  'nome_curto': 'Carlos S.',
  'bairro': 'Centro',
  'servico': 'svc1',
  'tipo_servico_nome': 'Higienização',
  'data_hora': '2026-07-01 17:00:00.000Z',
  'profissional': 'prof1',
  'status': status,
  'valor_servico': 150,
  'checklist_exec': const [],
  'adicionais': const [],
  'observacoes_prof': const [],
  'expand': {
    'profissional': {'id': 'prof1', 'nome': 'Pedro', 'role': 'profissional'},
    'servico': {'id': 'svc1', 'nome': 'Higienização', 'slug': 'svc1'},
  },
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'listDoProfissional filtra por profissional e janela e parseia',
    () async {
      final requests = <http.Request>[];
      final pb = PocketBase(
        'http://pb.test',
        httpClientFactory: () => MockClient((req) async {
          requests.add(req);
          return _json({
            'page': 1,
            'perPage': 200,
            'totalItems': 1,
            'totalPages': 1,
            'items': [_osRecord()],
          });
        }),
      );
      final repo = PbOrdensRepository(pb);

      final list = await repo.listDoProfissional(
        'prof1',
        janela: const DateRange('2026-07-01 03:00:00', '2026-07-02 03:00:00'),
      );

      expect(list, hasLength(1));
      final os = list.first;
      expect(os.id, 'os123');
      expect(os.nomeCurto, 'Carlos S.');
      expect(os.status, OSStatus.emAndamento);
      expect(os.expand?.profissional?.displayName, 'Pedro');

      // O filtro precisa amarrar o profissional (anti-desvio: só as suas OS).
      final filter = requests.single.url.queryParameters['filter'] ?? '';
      expect(filter, contains("profissional = 'prof1'"));
      expect(filter, contains('data_hora >='));
      // Expand da execução (nunca inclui cliente).
      expect(requests.single.url.queryParameters['expand'], kExecExpand);
    },
  );

  test('getExec busca por id com expand', () async {
    late Uri calledUri;
    final pb = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((req) async {
        calledUri = req.url;
        return _json(_osRecord());
      }),
    );
    final os = await PbOrdensRepository(pb).getExec('os123');
    expect(os.id, 'os123');
    expect(calledUri.path, contains('/ordens_servico/records/os123'));
    expect(calledUri.queryParameters['expand'], kExecExpand);
  });

  test('updateStatus envia PATCH com status wire correto', () async {
    http.Request? patch;
    final pb = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((req) async {
        if (req.method == 'PATCH') patch = req;
        return _json(_osRecord(status: 'concluida'));
      }),
    );
    final os = await PbOrdensRepository(
      pb,
    ).updateStatus('os123', OSStatus.concluida);

    expect(os.status, OSStatus.concluida);
    expect(patch, isNotNull);
    expect(patch!.method, 'PATCH');
    final body = jsonDecode(patch!.body) as Map<String, dynamic>;
    expect(body['status'], 'concluida');
    // Não envia campos travados no update de status.
    expect(body.containsKey('valor_servico'), isFalse);
  });

  test(
    'OSExecPatch.toBody serializa SÓ campos liberados (com pagamento, sem snapshot)',
    () {
      const patch = OSExecPatch(
        status: OSStatus.concluida,
        valorPago: 150.5,
        formaPagamento: FormaPagamento.pixMaquininha,
        checklistExec: [
          {'id': 'c1', 'status': 'concluido'},
        ],
        adicionais: [
          {'id': 'a1', 'nome': 'Extra'},
        ],
        observacoesProf: [
          {'id': 'o1', 'texto': 'ok'},
        ],
        descontos: 10,
      );
      final body = patch.toBody();

      // Pagamento presente (senão updateStatus→concluida sempre falha no hook).
      expect(body['status'], 'concluida');
      expect(body['valor_pago'], 150.5);
      expect(body['forma_pagamento'], 'pix_maquininha');
      expect(body['checklist_exec'], isA<List>());
      expect(body['adicionais'], isA<List>());
      expect(body['observacoes_prof'], isA<List>());
      expect(body['descontos'], 10);

      // A denylist do hook trava `service_snapshot` — o patch NUNCA pode enviá-lo.
      expect(body.containsKey('service_snapshot'), isFalse);
      // Só as 7 chaves liberadas ao profissional.
      expect(body.keys.toSet(), {
        'status',
        'valor_pago',
        'forma_pagamento',
        'checklist_exec',
        'adicionais',
        'observacoes_prof',
        'descontos',
      });
    },
  );

  test('OSExecPatch vazio não serializa nada (isEmpty)', () {
    const patch = OSExecPatch();
    expect(patch.toBody(), isEmpty);
    expect(patch.isEmpty, isTrue);
  });

  test(
    'patchExec envia PATCH com o body do patch e expand de execução',
    () async {
      http.Request? patch;
      final pb = PocketBase(
        'http://pb.test',
        httpClientFactory: () => MockClient((req) async {
          if (req.method == 'PATCH') patch = req;
          return _json(_osRecord(status: 'concluida'));
        }),
      );

      final os = await PbOrdensRepository(pb).patchExec(
        'os123',
        const OSExecPatch(
          status: OSStatus.concluida,
          valorPago: 200,
          formaPagamento: FormaPagamento.debito,
        ),
      );

      expect(os.status, OSStatus.concluida);
      expect(patch, isNotNull);
      final body = jsonDecode(patch!.body) as Map<String, dynamic>;
      expect(body['status'], 'concluida');
      expect(body['valor_pago'], 200);
      expect(body['forma_pagamento'], 'debito');
      expect(body.containsKey('service_snapshot'), isFalse);
      // Expand da execução (nunca inclui cliente).
      expect(patch!.url.queryParameters['expand'], kExecExpand);
    },
  );
}
