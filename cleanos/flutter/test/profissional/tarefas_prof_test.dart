import 'package:cleanos/core/models/agenda_compromisso.dart';
import 'package:cleanos/profissional/meus_servicos/tarefas_prof.dart';
import 'package:flutter_test/flutter_test.dart';

AgendaCompromisso _t(
  String id, {
  required String dataHora,
  StatusCompromisso status = StatusCompromisso.pendente,
}) => AgendaCompromisso(
  id: id,
  titulo: id,
  profissional: 'p1',
  dataHora: dataHora,
  status: status,
);

void main() {
  final hoje = DateTime(2026, 8, 14, 12);

  test('mostra pendente de qualquer dia e concluída só de hoje', () {
    final list = tarefasParaMeusServicos(
      [
        _t('hoje', dataHora: '2026-08-14 12:00:00Z'),
        _t(
          'feita-hoje',
          dataHora: '2026-08-14 11:00:00Z',
          status: StatusCompromisso.concluida,
        ),
        _t(
          'feita-ontem',
          dataHora: '2026-08-13 12:00:00Z',
          status: StatusCompromisso.concluida,
        ),
        _t('amanha', dataHora: '2026-08-15 12:00:00Z'),
      ],
      hojeBrt: hoje,
    );
    expect(list.map((t) => t.id), ['hoje', 'amanha', 'feita-hoje']);
  });

  test('horarioTarefa formata BRT', () {
    expect(horarioTarefa(_t('x', dataHora: '2026-08-14 12:00:00Z')), '09:00');
  });
}
