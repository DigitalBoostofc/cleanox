import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/financeiro/prof_estimativa.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('separa aberto e concluído', () {
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
        periodo: EstimativaPeriodo.semana,
      );
      expect(est.qtdOs, 2);
      expect(est.totalAberto, 10);
      expect(est.totalConcluido, 10);
      expect(est.totalEstimado, 20);
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

    test('semana = 7 dias a partir de hoje', () {
      final now = DateTime.utc(2026, 7, 9, 15);
      final r = EstimativaPeriodo.semana.toRange(now: now);
      final f = getBrtForwardDaysRange(7, now: now);
      expect(r.start, f.start);
      expect(r.end, f.end);
    });
  });
}
