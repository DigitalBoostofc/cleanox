import 'package:cleanos/core/models/agenda_compromisso.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inicio = DateTime.utc(2026, 8, 17, 12, 0); // 09:00 BRT

  test('pontual gera só a data informada', () {
    expect(
      ocorrenciasCompromisso(
        inicioUtc: inicio,
        recorrencia: RecorrenciaCompromisso.nenhuma,
      ),
      [inicio],
    );
  });

  test('semanal gera 12 semanas', () {
    final list = ocorrenciasCompromisso(
      inicioUtc: inicio,
      recorrencia: RecorrenciaCompromisso.semanal,
    );
    expect(list, hasLength(12));
    expect(list.first, inicio);
    expect(list[1], DateTime.utc(2026, 8, 24, 12));
    expect(list.last.difference(inicio).inDays, 7 * 11);
  });

  test('mensal gera 6 meses e segura dia 31', () {
    final list = ocorrenciasCompromisso(
      inicioUtc: DateTime.utc(2026, 1, 31, 12),
      recorrencia: RecorrenciaCompromisso.mensal,
    );
    expect(list, hasLength(6));
    expect(list[0].day, 31);
    expect(list[1].month, 2);
    expect(list[1].day, 28);
    expect(list[1].hour, 12);
  });

  test('fromRecord aceita 1 id ou lista de profissionais', () {
    final um = AgendaCompromisso(
      id: 'a',
      titulo: 'T',
      profissionais: const ['p1'],
      dataHora: '2026-08-19 12:00:00.000Z',
    );
    expect(um.profissional, 'p1');
    expect(um.incluiProfissional('p1'), isTrue);
    expect(um.incluiProfissional('p2'), isFalse);
    expect(
      um.copyWith(profissionais: const ['p1', 'p2']).incluiProfissional('p2'),
      isTrue,
    );
  });

  test('toBody grava lista de profissionais', () {
    final t = AgendaCompromisso(
      id: 'a',
      titulo: 'Reunião',
      profissionais: const ['p1', 'p2'],
      dataHora: '2026-08-19 12:00:00.000Z',
      duracaoMin: 90,
    );
    expect(t.toBody()['profissional'], ['p1', 'p2']);
    expect(t.toBody()['duracao_min'], 90);
  });
}
