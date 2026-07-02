/// prof_filters_test.dart — Filtros do app do profissional (auditoria A-04):
/// valores SEMPRE escapados via pbStringLiteral (mesmo escaping do `pb.filter`
/// do SDK), nunca interpolação crua.
library;

import 'package:cleanos/core/formatters/formatters.dart' show PbDayBounds;
import 'package:cleanos/core/pb/pb_filters.dart';
import 'package:cleanos/profissional/data/prof_filters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  const bounds = PbDayBounds('2026-07-02 03:00:00', '2026-07-03 03:00:00');

  test('pbStringLiteral espelha o escaping do pb.filter do SDK', () {
    final pb = PocketBase('http://127.0.0.1:9');
    for (final v in ["p1", "a'b", "x' || role = 'admin", "aspas''duplas"]) {
      expect(pbStringLiteral(v), pb.filter('{:v}', {'v': v}));
    }
  });

  test('filtros das 3 janelas de Meus Serviços', () {
    expect(
      profOrdensHojeFilter('p1', bounds),
      "profissional = 'p1' && data_hora >= '2026-07-02 03:00:00' "
      "&& data_hora < '2026-07-03 03:00:00'",
    );
    expect(
      profOrdensProximasFilter('p1', bounds),
      "profissional = 'p1' && data_hora >= '2026-07-03 03:00:00'",
    );
    expect(
      profOrdensAtrasadasAbertasFilter('p1', bounds),
      "profissional = 'p1' && (status = 'atribuida' "
      "|| status = 'em_andamento') && data_hora < '2026-07-02 03:00:00'",
    );
  });

  test('filtros do Mapa e do Perfil', () {
    expect(
      profOsEmAndamentoFilter('p1'),
      "profissional = 'p1' && status = 'em_andamento'",
    );
    expect(
      profAvaliadasFilter('p1'),
      "profissional = 'p1' && status = 'concluida' && avaliacao_nota >= 1",
    );
  });

  test('id malicioso com aspa NÃO quebra fora do literal (anti-injeção)', () {
    final f = profOsEmAndamentoFilter("p1' || status = 'atribuida");
    expect(f, contains(r"'p1\' || status = \'atribuida'"));
    // O trecho injetado fica DENTRO do literal escapado — não vira operador.
    expect(
      f,
      "profissional = 'p1\\' || status = \\'atribuida' "
      "&& status = 'em_andamento'",
    );
  });
}
