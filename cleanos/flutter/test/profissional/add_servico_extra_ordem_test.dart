import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_models.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_providers.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_repository.dart';
import 'package:cleanos/profissional/os_execucao/add_servico_extra_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import '../painel/fakes_onda3.dart';
import '../painel/painel_test_helpers.dart';

class _TaxonomiaOrdenada extends TaxonomiaRepository {
  _TaxonomiaOrdenada() : super(PocketBase('http://127.0.0.1:9'));

  @override
  Future<TaxonomiaArvore> load() async => TaxonomiaArvore(const [
        TaxonomiaNo(id: 'cz', tipo: TaxonomiaTipo.categoria, slug: 'z-cat', nome: 'Z categoria', parent: '', ordem: 10, ativo: true),
        TaxonomiaNo(id: 'ca', tipo: TaxonomiaTipo.categoria, slug: 'a-cat', nome: 'A categoria', parent: '', ordem: 20, ativo: true),
        TaxonomiaNo(id: 'gz', tipo: TaxonomiaTipo.grupo, slug: 'z-grupo', nome: 'Z grupo', parent: 'cz', ordem: 10, ativo: true),
        TaxonomiaNo(id: 'ga', tipo: TaxonomiaTipo.grupo, slug: 'a-grupo', nome: 'A grupo', parent: 'cz', ordem: 20, ativo: true),
      ]);
}

void main() {
  testWidgets('serviço extra preserva ordem de categoria, grupo e serviço',
      (tester) async {
    final repo = FakeServicosFull(seed: [
      fakeServico(id: 'cat-a', nome: 'Categoria A', categoria: 'a-cat', grupo: 'unico', ordem: 10),
      fakeServico(id: 'svc-z', nome: 'Serviço Z', categoria: 'z-cat', grupo: 'z-grupo', ordem: 10),
      fakeServico(id: 'svc-a', nome: 'Serviço A', categoria: 'z-cat', grupo: 'z-grupo', ordem: 20),
      fakeServico(id: 'grupo-a', nome: 'Grupo A', categoria: 'z-cat', grupo: 'a-grupo', ordem: 10),
    ]);
    final taxonomia = _TaxonomiaOrdenada();

    await pumpPainel(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAddServicoExtraSheet(context),
          child: const Text('Abrir'),
        ),
      ),
      overrides: [
        ...painelOverrides(user: painelUser()),
        servicosRepositoryProvider.overrideWithValue(repo),
        taxonomiaRepositoryProvider.overrideWithValue(taxonomia),
      ],
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    var fields = find.byType(DropdownButton<String>);
    final categoria = tester.widget<DropdownButton<String>>(fields.at(0));
    expect(categoria.items!.map((item) => item.value), ['z-cat', 'a-cat']);

    categoria.onChanged!('z-cat');
    await tester.pump();
    fields = find.byType(DropdownButton<String>);
    final grupo = tester.widget<DropdownButton<String>>(fields.at(1));
    expect(grupo.items!.map((item) => item.value), ['z-grupo', 'a-grupo']);

    grupo.onChanged!('z-grupo');
    await tester.pump();
    final servico = tester.widget<DropdownButton<ServicoPB>>(
      find.byType(DropdownButton<ServicoPB>),
    );
    expect(servico.items!.map((item) => item.value!.id), ['svc-z', 'svc-a']);
  });
}
