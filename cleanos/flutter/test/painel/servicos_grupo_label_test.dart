library;

import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/painel/servicos/servicos_labels.dart';
import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grupo do painel usa o mesmo nome da vitrine', () {
    const slugs = [
      'lavagens_essenciais',
      'lavagens_moto',
      'higienizacao_interna',
      'promocao',
      'avulsos',
      'adicional',
      'sofa',
      'colchao',
      'poltrona_puff',
      'cadeiras',
      'tapetes',
      'plano',
      'outros',
    ];
    for (final slug in slugs) {
      expect(grupoLabelSlug(slug), vitrineLabelGrupo(slug), reason: slug);
    }
    expect(grupoLabel(Grupo.promocao), 'Promoções');
    expect(grupoLabel(Grupo.plano), 'Planos');
    expect(grupoLabel(Grupo.colchao), 'Colchão e box');
    expect(grupoLabel(Grupo.adicional), 'Adicionais');
  });
}
