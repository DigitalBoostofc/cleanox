/// Agrupamento de próximos agendamentos por dia BRT (mais próximo → longe).
library;

import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/profissional/meus_servicos/meus_servicos_screen.dart';
import 'package:flutter_test/flutter_test.dart';

OrdemServico _os(String id, String dataHora) => OrdemServico(
  id: id,
  nomeCurto: id,
  dataHora: dataHora,
);

void main() {
  // Fixo: 2026-07-18 15:00 UTC = 12:00 BRT (sábado).
  final now = DateTime.utc(2026, 7, 18, 15);

  test('vazio → sem grupos', () {
    expect(groupOrdensByDayBrt(const [], now: now), isEmpty);
  });

  test('mesmo dia → um grupo com N itens', () {
    final list = [
      _os('a', '2026-07-19 11:00:00.000Z'), // 08:00 BRT domingo
      _os('b', '2026-07-19 14:30:00.000Z'), // 11:30 BRT
    ];
    final g = groupOrdensByDayBrt(list, now: now);
    expect(g, hasLength(1));
    expect(g.first.header, startsWith('Amanhã'));
    expect(g.first.items.map((o) => o.id), ['a', 'b']);
  });

  test('dias distintos → grupos do mais próximo ao mais distante', () {
    // Lista já ordenada por data_hora (como o controller entrega).
    final list = [
      _os('dom', '2026-07-19 11:00:00.000Z'), // amanhã
      _os('seg1', '2026-07-20 11:00:00.000Z'),
      _os('seg2', '2026-07-20 15:00:00.000Z'),
      _os('qua', '2026-07-22 12:00:00.000Z'),
    ];
    final g = groupOrdensByDayBrt(list, now: now);
    expect(g, hasLength(3));
    expect(g[0].header, startsWith('Amanhã'));
    expect(g[0].items.map((o) => o.id), ['dom']);
    expect(g[1].items.map((o) => o.id), ['seg1', 'seg2']);
    expect(g[2].items.map((o) => o.id), ['qua']);
    // Headers distintos.
    expect(g[0].header, isNot(equals(g[1].header)));
    expect(g[1].header, isNot(equals(g[2].header)));
  });
}
