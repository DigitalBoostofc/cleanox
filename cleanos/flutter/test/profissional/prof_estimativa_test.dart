import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/financeiro/prof_estimativa.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comissão CONGELADA em `prof_comissoes` — o que o hook gravou quando a OS
/// fechou. É o valor que o profissional vai receber, independente do que o
/// admin configurar depois.
ProfComissao congelada({
  required String os,
  required double valor,
  ComissaoStatus status = ComissaoStatus.pendente,
}) => ProfComissao(
  id: 'c-$os',
  profissional: 'p1',
  os: os,
  valorComissao: valor,
  valorOs: 300,
  status: status,
);

void main() {
  const mePct = User(
    id: 'p1',
    role: Role.profissional,
    comissaoTipo: ComissaoTipo.percentual,
    comissaoValor: 10,
  );
  const meFixo = User(
    id: 'p1',
    role: Role.profissional,
    comissaoTipo: ComissaoTipo.fixo,
    comissaoValor: 30,
  );

  group('estimarComissaoOs', () {
    test('percentual sobre valor_servico', () {
      final os = OrdemServico(
        id: '1',
        status: OSStatus.atribuida,
        valorServico: 150,
      );
      expect(estimarComissaoOs(mePct, os), 15);
    });

    test('percentual prefere valor_pago quando > 0', () {
      final os = OrdemServico(
        id: '1',
        status: OSStatus.concluida,
        valorServico: 150,
        valorPago: 200,
      );
      expect(estimarComissaoOs(mePct, os), 20);
    });

    test('fixo por OS', () {
      final os = OrdemServico(
        id: '1',
        status: OSStatus.atribuida,
        valorServico: 150,
      );
      expect(estimarComissaoOs(meFixo, os), 30);
    });

    test('cancelada = 0', () {
      final os = OrdemServico(
        id: '1',
        status: OSStatus.cancelada,
        valorServico: 150,
      );
      expect(estimarComissaoOs(mePct, os), 0);
    });
  });

  group('buildEstimativa', () {
    test('separa previsto (aberta) e realizado (concluída congelada)', () {
      final ordens = [
        OrdemServico(
          id: 'a',
          status: OSStatus.atribuida,
          valorServico: 100,
        ),
        OrdemServico(
          id: 'b',
          status: OSStatus.concluida,
          valorServico: 100,
          valorPago: 100,
        ),
        OrdemServico(
          id: 'c',
          status: OSStatus.cancelada,
          valorServico: 100,
        ),
      ];
      final est = buildEstimativa(
        me: mePct,
        ordens: ordens,
        comissoes: [congelada(os: 'b', valor: 10)],
        periodo: EstimativaPeriodo.semana,
      );
      expect(est.qtdOs, 2);
      expect(est.totalPrevisto, 10); // OS 'a' — ainda aberta
      expect(est.totalRealizado, 10); // OS 'b' — valor congelado
      expect(est.totalGeral, 20);
    });

    test('totalPago = subconjunto do garantido já marcado como pago', () {
      final ordens = [
        OrdemServico(id: 'paga', status: OSStatus.concluida, valorPago: 300),
        OrdemServico(id: 'aberta', status: OSStatus.concluida, valorPago: 300),
      ];
      final est = buildEstimativa(
        me: mePct,
        ordens: ordens,
        comissoes: [
          congelada(os: 'paga', valor: 30, status: ComissaoStatus.paga),
          congelada(os: 'aberta', valor: 30), // pendente
        ],
        periodo: EstimativaPeriodo.mes,
      );
      expect(est.totalRealizado, 60, reason: 'as duas comissões congeladas');
      expect(est.totalPago, 30, reason: 'só a que o admin quitou');
    });

    test('nada pago → totalPago = 0', () {
      final est = buildEstimativa(
        me: mePct,
        ordens: [
          OrdemServico(id: 'b', status: OSStatus.concluida, valorPago: 300),
        ],
        comissoes: [congelada(os: 'b', valor: 30)], // pendente
        periodo: EstimativaPeriodo.mes,
      );
      expect(est.totalPago, 0);
    });
  });

  // ===========================================================================
  // F-226 — o contrato que trava o bug: OS concluída NUNCA é recalculada.
  //
  // Cenário provado no banco de dev (14/07/2026):
  //   prof_comissoes.valor_comissao = 60  (percentual 20% sobre R$300, congelado
  //                                        quando a OS fechou — o hook grava certo)
  //   users.comissao_*  = fixo R$50       (o admin trocou DEPOIS)
  // A Carteira exibia R$50 para a OS já concluída E PAGA. Banco: 60. Tela: 50.
  // ===========================================================================
  group('F-226 — OS concluída exibe o valor CONGELADO', () {
    const meAgoraFixo50 = User(
      id: 'p1',
      role: Role.profissional,
      comissaoTipo: ComissaoTipo.fixo,
      comissaoValor: 50,
    );
    final osConcluidaPaga = OrdemServico(
      id: 'os1',
      status: OSStatus.concluida,
      valorServico: 300,
      valorPago: 300,
    );

    test('config atual mudou → exibe 60 (congelado), nunca 50 (recálculo)', () {
      final est = buildEstimativa(
        me: meAgoraFixo50,
        ordens: [osConcluidaPaga],
        comissoes: [congelada(os: 'os1', valor: 60)],
        periodo: EstimativaPeriodo.mes,
      );

      final linha = est.linhas.single;
      expect(linha.valorComissao, 60, reason: 'valor do banco, não recálculo');
      expect(linha.origem, ComissaoOrigem.congelada);
      expect(linha.isCongelada, isTrue);
      expect(est.totalRealizado, 60);
      expect(est.totalPrevisto, 0, reason: 'nada a estimar: a OS já fechou');
    });

    test('valor congelado é imune a QUALQUER config atual', () {
      // Mesma OS, mesma comissão congelada, três configs diferentes do admin.
      for (final me in [
        meAgoraFixo50,
        mePct, // percentual 10% → recálculo daria 30
        const User(id: 'p1', role: Role.profissional), // nenhuma comissão
      ]) {
        final est = buildEstimativa(
          me: me,
          ordens: [osConcluidaPaga],
          comissoes: [congelada(os: 'os1', valor: 60)],
          periodo: EstimativaPeriodo.mes,
        );
        expect(est.linhas.single.valorComissao, 60);
        expect(est.totalRealizado, 60);
      }
    });

    test('OS ABERTA continua sendo estimativa pela config atual', () {
      final osAberta = OrdemServico(
        id: 'os2',
        status: OSStatus.atribuida,
        valorServico: 300,
      );
      final est = buildEstimativa(
        me: meAgoraFixo50,
        ordens: [osAberta],
        comissoes: const [],
        periodo: EstimativaPeriodo.mes,
      );

      final linha = est.linhas.single;
      expect(linha.valorComissao, 50, reason: 'ganho futuro: recalcular é certo');
      expect(linha.origem, ComissaoOrigem.estimativa);
      expect(est.totalPrevisto, 50);
      expect(est.totalRealizado, 0);
    });

    test('concluída SEM comissão gerada não vira "valor final"', () {
      // Concluída sem valor_pago: o hook não gera comissão. Não há valor
      // congelado — então o que se mostra é estimativa, e a UI diz isso.
      final osSemPagamento = OrdemServico(
        id: 'os3',
        status: OSStatus.concluida,
        valorServico: 300,
      );
      final est = buildEstimativa(
        me: meAgoraFixo50,
        ordens: [osSemPagamento],
        comissoes: const [],
        periodo: EstimativaPeriodo.mes,
      );

      final linha = est.linhas.single;
      expect(linha.isCongelada, isFalse);
      expect(linha.isConcluidaSemComissao, isTrue);
      expect(est.totalRealizado, 0, reason: 'nada garantido: não há comissão');
      expect(est.totalPrevisto, 50);
    });

    test('comissão de OUTRA OS não contamina a linha', () {
      final est = buildEstimativa(
        me: meAgoraFixo50,
        ordens: [osConcluidaPaga],
        comissoes: [congelada(os: 'os-outra', valor: 999)],
        periodo: EstimativaPeriodo.mes,
      );
      expect(est.linhas.single.valorComissao, isNot(999));
      expect(est.totalRealizado, 0);
    });
  });

  group('periodo ranges', () {
    test('dia = 1 dia BRT', () {
      final now = DateTime.utc(2026, 7, 9, 15); // 12:00 BRT
      final r = EstimativaPeriodo.dia.toRange(now: now);
      final day = getBrtDayBounds(now: now);
      expect(r.start, day.todayStart);
      expect(r.end, day.tomorrowStart);
    });

    test('semana = semana civil BRT (seg → próxima seg)', () {
      // 2026-07-18 sábado 12:00 BRT → semana começa na seg 13/07
      final now = DateTime.utc(2026, 7, 18, 15);
      final r = EstimativaPeriodo.semana.toRange(now: now);
      final week = getBrtWeekBounds(now: now);
      expect(r.start, week.start);
      expect(r.end, week.end);
      // Passado da semana (ex.: 16/07) entra — não é só "a partir de hoje".
      expect(r.start, isNot(getBrtDayBounds(now: now).todayStart));
    });

    test('15 dias = span com passado e futuro em torno de hoje', () {
      final now = DateTime.utc(2026, 7, 18, 15);
      final r = EstimativaPeriodo.dias15.toRange(now: now);
      final span = getBrtSpanDaysRange(15, now: now);
      expect(r.start, span.start);
      expect(r.end, span.end);
      // Começa antes de hoje (inclui concluídas recentes).
      expect(
        r.start.compareTo(getBrtDayBounds(now: now).todayStart),
        lessThan(0),
      );
    });

    test('mês = mês civil BRT', () {
      final now = DateTime.utc(2026, 7, 18, 15);
      final r = EstimativaPeriodo.mes.toRange(now: now);
      final m = getBrtCurrentMonthRange(now: now);
      expect(r.start, m.start);
      expect(r.end, m.end);
    });
  });
}
