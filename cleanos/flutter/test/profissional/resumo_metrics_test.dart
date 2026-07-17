import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/profissional/resumo/resumo_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

OrdemServico os(String id, OSStatus status, {double? nota}) =>
    OrdemServico(id: id, status: status, valorServico: 200, avaliacaoNota: nota);

ProfComissao com(String id, double valor, ComissaoStatus status) =>
    ProfComissao(
      id: id,
      profissional: 'p1',
      os: 'os-$id',
      valorComissao: valor,
      valorOs: 200,
      status: status,
    );

void main() {
  group('buildResumo', () {
    test('conta agendados (em aberto) e realizados; cancelada não conta', () {
      final r = buildResumo(
        ordens: [
          os('1', OSStatus.agendada),
          os('2', OSStatus.atribuida),
          os('3', OSStatus.emAndamento),
          os('4', OSStatus.concluida),
          os('5', OSStatus.concluida),
          os('6', OSStatus.cancelada), // ignorada
        ],
        comissoes: const [],
      );
      expect(r.agendados, 3);
      expect(r.realizados, 2);
    });

    test('separa comissões a receber (pendente) e recebidas (paga)', () {
      final r = buildResumo(
        ordens: const [],
        comissoes: [
          com('a', 30, ComissaoStatus.pendente),
          com('b', 20, ComissaoStatus.pendente),
          com('c', 50, ComissaoStatus.paga),
        ],
      );
      expect(r.aReceber, 50);
      expect(r.recebidos, 50);
    });

    test('avaliação média só considera notas >= 1', () {
      final r = buildResumo(
        ordens: [
          os('1', OSStatus.concluida, nota: 5),
          os('2', OSStatus.concluida, nota: 4),
          os('3', OSStatus.concluida, nota: 0), // não avaliada
          os('4', OSStatus.concluida), // sem nota
        ],
        comissoes: const [],
      );
      expect(r.avaliacaoMedia, 4.5);
      expect(r.totalAvaliacoes, 2);
    });

    test('sem avaliações → média null', () {
      final r = buildResumo(
        ordens: [os('1', OSStatus.agendada)],
        comissoes: const [],
      );
      expect(r.avaliacaoMedia, isNull);
      expect(r.totalAvaliacoes, 0);
    });

    test('vazio → tudo zero', () {
      final r = buildResumo(ordens: const [], comissoes: const []);
      expect(r.agendados, 0);
      expect(r.realizados, 0);
      expect(r.aReceber, 0);
      expect(r.recebidos, 0);
      expect(r.avaliacaoMedia, isNull);
    });
  });
}
