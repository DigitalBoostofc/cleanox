/// Testes de (de)serialização dos modelos contra fixtures JSON reais do PB
/// (derivadas das migrations + collections.ts). Cobre snake_case do topo,
/// camelCase dos campos JSON ricos, enums, e o mapeamento de expand em fromRecord.
library;

import 'package:cleanos/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('User', () {
    test('fromJson mapeia role e displayName', () {
      final u = User.fromJson({
        'id': 'u1',
        'name': 'joao',
        'email': 'joao@cleanox.com',
        'role': 'gerente',
        'nome': 'João Silva',
        'verified': true,
        'emailVisibility': true,
      });
      expect(u.role, Role.gerente);
      expect(u.role.isPainel, isTrue);
      expect(u.displayName, 'João Silva');
    });

    test('role desconhecido cai em profissional (menor privilégio)', () {
      final u = User.fromJson({'id': 'u2', 'role': 'root'});
      expect(u.role, Role.profissional);
    });

    test('displayName cai para name quando nome vazio', () {
      final u = User.fromJson({'id': 'u3', 'name': 'ana', 'role': 'admin'});
      expect(u.displayName, 'ana');
    });
  });

  group('Cliente', () {
    test('fromJson mapeia endereco_* e nomeCurto', () {
      final c = Cliente.fromJson({
        'id': 'c1',
        'nome': 'Carlos',
        'sobrenome': 'Silva',
        'telefone': '11999990001',
        'endereco_bairro': 'Centro',
        'endereco_rua': 'Rua X',
        'ativo': true,
      });
      expect(c.enderecoBairro, 'Centro');
      expect(c.enderecoRua, 'Rua X');
      expect(c.nomeCurto, 'Carlos S.');
    });
  });

  group('ServicoPB', () {
    test('placeholder com selects vazios vira enums null', () {
      final s = ServicoPB.fromJson({
        'id': 's1',
        'slug': 'svc_x',
        'categoria': '',
        'grupo': '',
        'tipo_valor': '',
        'status': '',
        'nome': 'Serviço legado',
        'valor_base': 0,
        'preco_base': 0,
        'ativo': false,
      });
      expect(s.categoria, isNull);
      expect(s.grupo, isNull);
      expect(s.tipoValor, isNull);
      expect(s.status, isNull);
    });

    test('serviço rico mapeia checklist_padrao e taxonomia', () {
      final s = ServicoPB.fromJson({
        'id': 's2',
        'slug': 'svc_veic_essencial',
        'categoria': 'veicular',
        'grupo': 'plano',
        'tipo_valor': 'fixo',
        'status': 'ativo',
        'nome': 'Higienização',
        'valor_base': 150.0,
        'valor_base_max': 0,
        'preco_base': 150.0,
        'ativo': true,
        'checklist_padrao': [
          {'id': 'c1', 'titulo': 'Aspirar', 'ordem': 1, 'obrigatorio': true},
          {'id': 'c2', 'titulo': 'Enxaguar', 'ordem': 2},
        ],
      });
      expect(s.categoria, Categoria.veicular);
      expect(s.grupo, Grupo.plano);
      expect(s.tipoValor, TipoValor.fixo);
      expect(s.status, ServicoStatus.ativo);
      expect(s.checklistPadrao, hasLength(2));
      expect(s.checklistPadrao.first.obrigatorio, isTrue);
      expect(s.checklistPadrao[1].obrigatorio, isFalse);
    });
  });

  group('OrdemServico', () {
    Map<String, dynamic> osFixture() => {
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
      'status': 'em_andamento',
      'valor_servico': 150,
      'endereco_liberado': 'Rua X, 10 - Centro',
      'valor_pago': 0,
      'forma_pagamento': '',
      'descontos': 20,
      'checklist_exec': [
        {
          'id': 'cke1',
          'titulo': 'Aspirar',
          'status': 'pendente',
          'obrigatorio': true,
        },
        {'id': 'cke2', 'titulo': 'Enxaguar', 'status': 'concluido'},
      ],
      'adicionais': [
        {
          'id': 'ad1',
          'nome': 'Cera extra',
          'valor': 30,
          'quantidade': 2,
          'aprovacao': 'aprovado',
        },
      ],
      'observacoes_prof': [],
      'service_snapshot': {
        'serviceId': 'svc1',
        'nome': 'Higienização',
        'categoria': 'veicular',
        'grupo': 'plano',
        'valorBase': 150,
        'tipoValor': 'fixo',
        'tempoMedioLabel': '1h',
        'checklistPadrao': [
          {'id': 'c1', 'titulo': 'Aspirar', 'ordem': 1, 'obrigatorio': true},
        ],
        'capturedAt': '2026-07-01T10:00:00.000Z',
      },
    };

    test('fromJson: snake_case topo + camelCase JSON ricos + enums', () {
      final os = OrdemServico.fromJson(osFixture());
      expect(os.status, OSStatus.emAndamento);
      expect(os.nomeCurto, 'Carlos S.');
      expect(os.valorServico, 150.0);
      expect(os.formaPagamento, isNull); // '' → null
      expect(os.checklistExec, hasLength(2));
      expect(os.checklistExec.first.obrigatorio, isTrue);
      expect(os.checklistExec[1].concluido, isTrue);
      expect(os.adicionais.first.aprovacao, AprovacaoStatus.aprovado);
      expect(os.serviceSnapshot!.categoria, Categoria.veicular);
      expect(os.serviceSnapshot!.tipoValor, TipoValor.fixo);
    });

    test('valorTotal = serviço + adicionais − descontos', () {
      final os = OrdemServico.fromJson(osFixture());
      // 150 + (30 * 2) - 20 = 190
      expect(os.valorTotal, 190.0);
    });

    test('temItensObrigatoriosPendentes detecta obrigatório pendente', () {
      final os = OrdemServico.fromJson(osFixture());
      expect(os.temItensObrigatoriosPendentes, isTrue);
    });

    test('fromRecord resolve expand profissional/servico (sem cliente)', () {
      final data = osFixture()
        ..['expand'] = {
          'profissional': {
            'id': 'prof1',
            'nome': 'Pedro',
            'role': 'profissional',
          },
          'servico': {'id': 'svc1', 'nome': 'Higienização', 'slug': 'svc1'},
        };
      final rec = RecordModel.fromJson(data);
      final os = OrdemServico.fromRecord(rec);
      expect(os.expand?.profissional?.displayName, 'Pedro');
      expect(os.expand?.servico?.nome, 'Higienização');
      // anti-desvio: profissional NUNCA recebe o expand de cliente.
      expect(os.expand?.cliente, isNull);
    });

    test('toJson faz round-trip dos campos-chave', () {
      final os = OrdemServico.fromJson(osFixture());
      final back = OrdemServico.fromJson(os.toJson());
      expect(back.status, os.status);
      expect(back.checklistExec.length, os.checklistExec.length);
      expect(back.serviceSnapshot!.serviceId, 'svc1');
      expect(back.descontos, 20.0);
    });
  });

  group('OSEvidenciaPB', () {
    test('mapeia vínculos snake_case e fase', () {
      final e = OSEvidenciaPB.fromJson({
        'id': 'ev1',
        'os': 'os123',
        'foto': 'foto.jpg',
        'fase': 'depois',
        'checklist_item_id': 'cke1',
        'enviado_por': 'prof1',
      });
      expect(e.fase, FaseFoto.depois);
      expect(e.checklistItemId, 'cke1');
      expect(e.enviadoPor, 'prof1');
    });
  });

  group('Financeiro', () {
    test('FinLancamento: enums + valorComSinal', () {
      final rec = FinLancamento.fromJson({
        'id': 'l1',
        'tipo': 'despesa',
        'descricao': 'Combustível',
        'categoria_id': 'cat1',
        'valor': 100,
        'conta_id': 'conta1',
        'data': '2026-07-01 12:00:00.000Z',
        'status': 'pago',
        'recorrencia': 'unica',
        'origem': 'via_os',
        'os_id': 'os123',
      });
      expect(rec.tipo, TipoLancamento.despesa);
      expect(rec.origem, OrigemLancamento.viaOs);
      expect(rec.status, LancamentoStatus.pago);
      expect(rec.valorComSinal, -100.0);
    });

    test('FinConta mapeia saldo_inicial/saldo_atual', () {
      final c = FinConta.fromJson({
        'id': 'conta1',
        'nome': 'Caixa',
        'tipo': 'caixa',
        'saldo_inicial': 500,
        'saldo_atual': 320.5,
        'ativo': true,
      });
      expect(c.tipo, ContaTipo.caixa);
      expect(c.saldoInicial, 500.0);
      expect(c.saldoAtual, 320.5);
    });

    // Bug de produção (dono, 04/07): categoria criada não aparecia na tela de
    // Categorias mesmo com o fix de defaultTipo (540321f) já embarcado.
    // Causa raiz: `parent_id` é um TextField (não RelationField, migration 14)
    // — o PocketBase grava vazio como `""`, nunca `null` — mas TODA a árvore de
    // Categorias/Relatórios/Contas a pagar/formulários decide "é raiz?" com
    // `c.parentId == null`. Sem normalizar no `fromRecord`, NENHUMA categoria
    // raiz (a esmagadora maioria) nunca batia nesse teste: a lista de
    // Categorias ficava permanentemente vazia, com ou sem o fix de tipo.
    test(
      'FinCategoria.fromRecord normaliza parent_id "" (PocketBase) para null',
      () {
        final rec = RecordModel.fromJson({
          'id': 'c1',
          'nome': 'Marketing',
          'tipo': 'despesa',
          'parent_id': '',
        });
        final cat = FinCategoria.fromRecord(rec);
        expect(
          cat.parentId,
          isNull,
          reason:
              'categoria-raiz do PocketBase vem com parent_id="", '
              'precisa virar null pro filtro `parentId == null` funcionar',
        );
      },
    );

    test('FinCategoria.fromRecord preserva parent_id de subcategoria', () {
      final rec = RecordModel.fromJson({
        'id': 'c2',
        'nome': 'Google Ads',
        'tipo': 'despesa',
        'parent_id': 'c1',
      });
      final cat = FinCategoria.fromRecord(rec);
      expect(cat.parentId, 'c1');
    });
  });
}
