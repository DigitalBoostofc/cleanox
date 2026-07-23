/// painel_filters_test.dart — Construtores puros de filtro do Painel: escaping
/// seguro (espelha pb.filter) e composição.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/data/painel_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pbStringLiteral', () {
    test('envolve em aspas simples', () {
      expect(pbStringLiteral('Ana'), "'Ana'");
    });
    test('escapa aspas simples (anti-injeção)', () {
      expect(pbStringLiteral("O'Brien"), r"'O\'Brien'");
    });
  });

  group('clienteSearchFilter', () {
    test('vazio → null (lista tudo)', () {
      expect(clienteSearchFilter(''), isNull);
      expect(clienteSearchFilter('   '), isNull);
    });
    test('casa nos campos esperados com ~', () {
      final f = clienteSearchFilter('centro')!;
      expect(f.contains("nome ~ 'centro'"), isTrue);
      expect(f.contains("endereco_bairro ~ 'centro'"), isTrue);
      expect(f.contains('||'), isTrue);
    });
  });

  group('ordensFilter', () {
    test('sem filtros → null', () {
      expect(ordensFilter(), isNull);
    });
    test('status + profissional compõem com &&', () {
      final f = ordensFilter(status: OSStatus.concluida, profissionalId: 'p1')!;
      expect(f.contains("status = 'concluida'"), isTrue);
      expect(f.contains("profissional = 'p1'"), isTrue);
      expect(f.contains('&&'), isTrue);
    });
    test('janela de datas', () {
      final f = ordensFilter(
        dataInicio: '2026-07-01 03:00:00',
        dataFim: '2026-07-02 03:00:00',
      )!;
      expect(f.contains('data_hora >='), isTrue);
      expect(f.contains('data_hora <'), isTrue);
    });
    test('busca por nome casa em nome_curto / serviço / bairro', () {
      final f = ordensFilter(search: 'Lucas')!;
      expect(f.contains("nome_curto ~ 'Lucas'"), isTrue);
      expect(f.contains("tipo_servico_nome ~ 'Lucas'"), isTrue);
      expect(f.contains("bairro ~ 'Lucas'"), isTrue);
      expect(f.contains('||'), isTrue);
    });
    test('busca vazia não entra no filtro', () {
      expect(ordensFilter(search: ''), isNull);
      expect(ordensFilter(search: '   '), isNull);
    });
    test('busca escapa aspas (anti-injeção)', () {
      final f = ordensFilter(search: "O'Brien")!;
      expect(f.contains(r"nome_curto ~ 'O\'Brien'"), isTrue);
    });
  });

  group('ordensOcupamAgendaFilter', () {
    test('cruza profissional + janela do dia e exclui canceladas', () {
      final f = ordensOcupamAgendaFilter(
        profissionalId: 'p1',
        dataInicio: '2026-07-06 03:00:00',
        dataFim: '2026-07-07 03:00:00',
      );
      expect(f.contains("profissional = 'p1'"), isTrue);
      expect(f.contains("data_hora >= '2026-07-06 03:00:00'"), isTrue);
      expect(f.contains("data_hora < '2026-07-07 03:00:00'"), isTrue);
      expect(f.contains("status != 'cancelada'"), isTrue);
      expect(f.contains('&&'), isTrue);
    });
    test('escapa o id (anti-injeção)', () {
      final f = ordensOcupamAgendaFilter(
        profissionalId: "p'1",
        dataInicio: 'a',
        dataFim: 'b',
      );
      expect(f.contains(r"profissional = 'p\'1'"), isTrue);
    });
  });

  group('profissionaisFilter', () {
    test('fixa o papel profissional', () {
      expect(profissionaisFilter(), "role = 'profissional'");
    });
  });

  group('avaliacoesFilter', () {
    test('base: só OS avaliadas', () {
      expect(avaliacoesFilter(), 'avaliacao_nota >= 1');
    });
    test('nota exata entra como literal numérico e é limitada a 1..5', () {
      final f = avaliacoesFilter(nota: 4);
      expect(f.contains('avaliacao_nota = 4'), isTrue);
      expect(f.contains('avaliacao_nota >= 1'), isTrue);
      // Fora da faixa é grampeado (defesa; a UI só oferece 1..5).
      expect(avaliacoesFilter(nota: 9).contains('avaliacao_nota = 5'), isTrue);
    });
    test('desde: filtro por data de avaliação (string escapada)', () {
      final f = avaliacoesFilter(desde: '2026-06-01 03:00:00.000Z');
      expect(f.contains("avaliacao_em >= '2026-06-01 03:00:00.000Z'"), isTrue);
      expect(f.contains('&&'), isTrue);
    });
  });
}
