import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/profissional/resumo/resumo_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

OrdemServico os(String id, OSStatus status) =>
    OrdemServico(id: id, status: status, valorServico: 200);

void main() {
  group('buildResumo', () {
    test('agendados = realizados + canceladas + pendentes', () {
      final r = buildResumo(
        ordens: [
          os('1', OSStatus.agendada),
          os('2', OSStatus.atribuida),
          os('3', OSStatus.emAndamento),
          os('4', OSStatus.concluida),
          os('5', OSStatus.concluida),
          os('6', OSStatus.cancelada),
          os('7', OSStatus.cancelada),
        ],
        kmDeslocamento: 12.34,
      );
      expect(r.pendentes, 3);
      expect(r.realizados, 2);
      expect(r.canceladas, 2);
      expect(r.agendados, 7);
      expect(r.agendados, r.realizados + r.canceladas + r.pendentes);
      expect(r.kmDeslocamento, 12.3);
    });

    test('vazio → zeros', () {
      final r = buildResumo(ordens: const []);
      expect(r.agendados, 0);
      expect(r.pendentes, 0);
      expect(r.realizados, 0);
      expect(r.canceladas, 0);
      expect(r.kmDeslocamento, 0);
    });
  });

  group('ResumoPeriodo', () {
    test('labels', () {
      expect(ResumoPeriodo.hoje.label, 'Hoje');
      expect(ResumoPeriodo.semana.label, 'Semana');
      expect(ResumoPeriodo.mes.label, 'Mês');
    });

    test('bounds de hoje é half-open de 1 dia', () {
      final now = DateTime.utc(2026, 7, 18, 15, 0);
      final keys = ResumoPeriodo.hoje.diaKeys(now: now);
      expect(keys.startDia, '2026-07-18');
      expect(keys.endDiaExcl, '2026-07-19');
    });
  });
}
