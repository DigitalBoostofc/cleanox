/// Testes de helpers de série (fin_series body + chave).
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_recorrencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bodySerieFromLancamento / bodyOcorrenciaDaSerie', () {
    test('série nasce ativa com data_inicio do lançamento', () {
      final l = FinLancamento(
        id: 'l1',
        tipo: TipoLancamento.despesa,
        descricao: 'Aluguel',
        categoriaId: 'cat',
        valor: 2000,
        contaId: 'c1',
        data: '2026-08-01',
        recorrencia: RecorrenciaTipo.fixa,
        frequencia: FrequenciaRecorrencia.mensal,
      );
      final body = bodySerieFromLancamento(l);
      expect(body['status'], 'ativa');
      expect(body['data_inicio'], '2026-08-01');
      expect(body['recorrencia'], 'fixa');
      expect(body['frequencia'], 'mensal');
      expect(body['valor'], 2000);
    });

    test('ocorrência da série carrega serie_id e status previsto', () {
      const serie = FinSerie(
        id: 's1',
        tipo: TipoLancamento.despesa,
        descricao: 'Internet',
        categoriaId: 'cat',
        valor: 120,
        contaId: 'c1',
        recorrencia: RecorrenciaTipo.fixa,
        frequencia: FrequenciaRecorrencia.mensal,
        status: FinSerieStatus.ativa,
        dataInicio: '2026-01-10',
      );
      final body = bodyOcorrenciaDaSerie(serie, '2026-09-10');
      expect(body['serie_id'], 's1');
      expect(body['status'], 'previsto');
      expect(body['data'], '2026-09-10');
      expect(body['recorrencia'], 'fixa');
      expect(body['descricao'], 'Internet');
    });

    test('bodyOcorrenciaPrevista propaga serie_id do template', () {
      final t = FinLancamento(
        id: 't1',
        descricao: 'Net',
        categoriaId: 'c',
        valor: 99,
        contaId: 'x',
        data: '2026-01-01',
        recorrencia: RecorrenciaTipo.fixa,
        serieId: 'serieABC',
      );
      final body = bodyOcorrenciaPrevista(t, '2026-02-01');
      expect(body['serie_id'], 'serieABC');
    });
  });

  group('FinSerieStatus', () {
    test('labels e wire', () {
      expect(FinSerieStatus.ativa.wire, 'ativa');
      expect(FinSerieStatus.pausada.label, 'Pausada');
      expect(FinSerieStatus.encerrada.label, 'Encerrada');
    });
  });

  group('isDaSerie', () {
    test('true com serieId ou recorrencia fixa', () {
      expect(
        const FinLancamento(
          id: 'a',
          serieId: 's1',
        ).isDaSerie,
        isTrue,
      );
      expect(
        const FinLancamento(
          id: 'b',
          recorrencia: RecorrenciaTipo.fixa,
        ).isDaSerie,
        isTrue,
      );
      expect(
        const FinLancamento(id: 'c').isDaSerie,
        isFalse,
      );
    });

    test('parcelada é da série e mostra 1/10', () {
      const l = FinLancamento(
        id: 'p1',
        descricao: 'Máquina Geradora de Ozônio',
        valor: 279,
        recorrencia: RecorrenciaTipo.parcelada,
        parcelaAtual: 1,
        parcelasTotal: 10,
      );
      expect(l.isDaSerie, isTrue);
      expect(l.isCiclico, isTrue);
      expect(l.parcelaRotulo, '1/10');
      final body = bodySerieFromLancamento(l);
      expect(body['recorrencia'], 'parcelada');
      expect(body['parcelas_total'], 10);
      expect(serieRecorrenciaKey(l), contains('parcelada|10'));
    });

    test('SerieParcelasProgresso rotulo pagas/total', () {
      const p = SerieParcelasProgresso(pagas: 2, ocorrencias: 10);
      expect(p.rotulo(10), '2/10');
      expect(p.rotulo(null), '2/10');
      expect(p.totalEfetivo(12), 12);
      expect(const SerieParcelasProgresso(pagas: 0, ocorrencias: 0).rotulo(10),
          '0/10');
    });
  });

  group('cutoff data_fim', () {
    test('dia após fim é exclusivo (último dia válido fica)', () {
      // Espelha a regra: data_fim=2026-08-04 → poda a partir de 2026-08-05.
      final fim = DateTime(2026, 8, 4);
      final diaApos = DateTime(fim.year, fim.month, fim.day + 1);
      expect(
        '${diaApos.year.toString().padLeft(4, '0')}-'
        '${diaApos.month.toString().padLeft(2, '0')}-'
        '${diaApos.day.toString().padLeft(2, '0')}',
        '2026-08-05',
      );
    });
  });
}
