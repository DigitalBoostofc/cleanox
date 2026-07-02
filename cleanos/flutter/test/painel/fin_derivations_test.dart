/// fin_derivations_test.dart — Testa as derivações PURAS do Financeiro (resumo,
/// saldo, agrupamento por data, contas a pagar/receber, gasto/limite) e os
/// filtros PB. Cobre dinheiro (centavos) e datas de parede (sem fuso).
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:cleanos/painel/financeiro/fin_filters.dart';
import 'package:cleanos/painel/financeiro/fin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';

void main() {
  group('mesPeriodo', () {
    test('janela half-open do mês (vira o ano em dezembro)', () {
      expect(mesPeriodo(2026, 7).start, '2026-07-01');
      expect(mesPeriodo(2026, 7).end, '2026-08-01');
      expect(mesPeriodo(2026, 12).end, '2027-01-01');
    });
  });

  group('bordas de mês BRT (dentroDoPeriodo — data de PAREDE, sem fuso)', () {
    final julho = mesPeriodo(2026, 7); // [2026-07-01, 2026-08-01)

    test('dia 01 conta (limite inferior INCLUSIVO)', () {
      expect(
        dentroDoPeriodo(fakeLanc(id: '1', data: '2026-07-01'), julho),
        isTrue,
      );
    });

    test(
      'último dia do mês conta, mas o 1º dia do mês seguinte NÃO (superior EXCLUSIVO)',
      () {
        expect(
          dentroDoPeriodo(fakeLanc(id: '1', data: '2026-07-31'), julho),
          isTrue,
        );
        // 2026-08-01 == end → fora (não vaza pro mês seguinte).
        expect(
          dentroDoPeriodo(fakeLanc(id: '2', data: '2026-08-01'), julho),
          isFalse,
        );
      },
    );

    test('data de parede "2026-07-01 01:00" NÃO cai em junho por −3h', () {
      // Se aplicasse fuso BRT (−3h), 01:00Z viraria 2026-06-30 22:00 e cairia em
      // JUNHO. Como a comparação é por dateOnly (parede), permanece em JULHO.
      final l = fakeLanc(id: '1', data: '2026-07-01 01:00:00');
      expect(dentroDoPeriodo(l, julho), isTrue);
      expect(dentroDoPeriodo(l, mesPeriodo(2026, 6)), isFalse);
    });

    test('último instante do mês "2026-07-31 23:59" fica em julho', () {
      final l = fakeLanc(id: '1', data: '2026-07-31 23:59:59');
      expect(dentroDoPeriodo(l, julho), isTrue);
    });
  });

  group('resumoPeriodo', () {
    test('soma só os pagos e não acumula erro de float', () {
      final lancs = [
        fakeLanc(id: '1', tipo: TipoLancamento.receita, valor: 0.1),
        fakeLanc(id: '2', tipo: TipoLancamento.receita, valor: 0.2),
        fakeLanc(id: '3', tipo: TipoLancamento.despesa, valor: 0.3),
        fakeLanc(
          id: '4',
          tipo: TipoLancamento.receita,
          valor: 999,
          status: LancamentoStatus.pendente, // ignorado
        ),
      ];
      final r = resumoPeriodo(lancs);
      expect(r.entradas, closeTo(0.30, 1e-9));
      expect(r.saidas, closeTo(0.30, 1e-9));
      expect(r.saldoMes, closeTo(0.0, 1e-9)); // 0.1+0.2-0.3 == 0 exato
    });
  });

  group('saldoGeral', () {
    test('soma saldoAtual das contas em centavos', () {
      final contas = [
        fakeConta(id: 'a', saldoAtual: 100.10),
        fakeConta(id: 'b', saldoAtual: 50.05),
      ];
      expect(saldoGeral(contas), closeTo(150.15, 1e-9));
    });
  });

  group('agruparPorData', () {
    test('agrupa por dia desc com total com sinal', () {
      final lancs = [
        fakeLanc(
          id: '1',
          data: '2026-07-10',
          tipo: TipoLancamento.receita,
          valor: 300,
        ),
        fakeLanc(
          id: '2',
          data: '2026-07-10',
          tipo: TipoLancamento.despesa,
          valor: 100,
        ),
        fakeLanc(
          id: '3',
          data: '2026-07-08',
          tipo: TipoLancamento.despesa,
          valor: 50,
        ),
      ];
      final grupos = agruparPorData(lancs);
      expect(grupos.length, 2);
      expect(grupos.first.data, '2026-07-10'); // mais recente primeiro
      expect(grupos.first.totalDia, closeTo(200, 1e-9)); // 300 - 100
      expect(grupos.last.totalDia, closeTo(-50, 1e-9));
    });
  });

  group('contasAPagar / contasAReceber', () {
    test('separa por tipo, marca atraso/vencendo-hoje e ordena por venc', () {
      const hoje = '2026-07-15';
      final lancs = [
        fakeLanc(
          id: 'atrasada',
          tipo: TipoLancamento.despesa,
          status: LancamentoStatus.pendente,
          vencimento: '2026-07-10',
        ),
        fakeLanc(
          id: 'hoje',
          tipo: TipoLancamento.despesa,
          status: LancamentoStatus.pendente,
          vencimento: '2026-07-15',
        ),
        fakeLanc(
          id: 'receber',
          tipo: TipoLancamento.receita,
          status: LancamentoStatus.previsto,
          vencimento: '2026-07-20',
        ),
        fakeLanc(id: 'paga', status: LancamentoStatus.pago), // fora
      ];
      final pagar = contasAPagar(lancs, hoje);
      expect(pagar.map((p) => p.lancamento.id), ['atrasada', 'hoje']);
      expect(pagar.first.emAtraso, isTrue);
      expect(pagar[1].vencendoHoje, isTrue);

      final receber = contasAReceber(lancs, hoje);
      expect(receber.length, 1);
      expect(receber.first.lancamento.id, 'receber');
    });
  });

  group('progressoLimite', () {
    test('soma despesas pagas da categoria (mãe ou sub) e clampa pct', () {
      final limite = fakeLimite(id: 'l', categoriaId: 'cat', limite: 200);
      final lancs = [
        fakeLanc(id: '1', categoriaId: 'cat', valor: 150),
        fakeLanc(id: '2', categoriaId: 'outra', valor: 100),
        fakeLanc(
          id: '3',
          tipo: TipoLancamento.receita,
          categoriaId: 'cat',
          valor: 999,
        ), // receita ignorada
      ];
      final p = progressoLimite(limite, lancs);
      expect(p.gasto, closeTo(150, 1e-9));
      expect(p.pct, closeTo(0.75, 1e-9));

      // estouro → pct clampa em 1.
      final estourado = progressoLimite(
        fakeLimite(id: 'l', categoriaId: 'cat', limite: 100),
        lancs,
      );
      expect(estourado.pct, 1.0);
    });
  });

  group('formatDateOnlyBr', () {
    test('reordena YYYY-MM-DD → dd/MM/yyyy sem tocar no fuso', () {
      expect(formatDateOnlyBr('2026-07-01'), '01/07/2026');
      expect(formatDateOnlyBr('2026-07-01 03:00:00'), '01/07/2026');
    });
  });

  group('filtros PB', () {
    test('finPeriodoFilter usa o campo data', () {
      final f = finPeriodoFilter(mesPeriodo(2026, 7));
      expect(f, "data >= '2026-07-01' && data < '2026-08-01'");
    });

    test('finLancamentosFilter escapa a busca (anti-injeção)', () {
      final f = finLancamentosFilter(search: "a' || 1=1");
      expect(f, contains(r"a\' || 1=1"));
    });

    test('finContasPendentesFilter filtra tipo + não pago', () {
      final f = finContasPendentesFilter(TipoLancamento.despesa);
      expect(f, "tipo = 'despesa' && status != 'pago'");
    });
  });

  group('FinTab.isKnownSlug (canonicalização de slug de aba)', () {
    test('slugs reais das 7 abas são conhecidos', () {
      for (final tab in FinTab.values) {
        expect(FinTab.isKnownSlug(tab.slug), isTrue, reason: tab.slug);
      }
    });

    test('slug desconhecido/null/vazio NÃO é conhecido (vira visao-geral)', () {
      expect(FinTab.isKnownSlug('lixo'), isFalse);
      expect(FinTab.isKnownSlug(null), isFalse);
      expect(FinTab.isKnownSlug(''), isFalse);
      // fromSlug segue caindo no fallback defensivo enquanto a URL é corrigida.
      expect(FinTab.fromSlug('lixo'), FinTab.visaoGeral);
    });
  });
}
