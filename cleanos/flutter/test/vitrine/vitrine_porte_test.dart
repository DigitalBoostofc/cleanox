import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:cleanos/vitrine/vitrine_porte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VitrineServico _s({
  required String id,
  required String nome,
  required double valor,
  String grupo = 'lavagens_essenciais',
}) =>
    VitrineServico.fromJson({
      'id': id,
      'nome': nome,
      'grupo': grupo,
      'valor_base': valor,
    });

void main() {
  final primePop = _s(id: 'pp', nome: 'Lavagem Prime — Popular', valor: 60);
  final primeSuv = _s(id: 'ps', nome: 'Lavagem Prime — SUV', valor: 70);
  final primeCam = _s(id: 'pc', nome: 'Lavagem Prime — Caminhonete', valor: 80);
  final detailPop = _s(id: 'dp', nome: 'Lavagem Detail — Popular', valor: 120);
  final detailSuv = _s(id: 'ds', nome: 'Lavagem Detail — SUV', valor: 130);
  final detailCam = _s(id: 'dc', nome: 'Lavagem Detail — Caminhonete', valor: 140);
  final moto = _s(id: 'm', nome: 'Lavagem Prime — Moto', valor: 30, grupo: 'lavagens_moto');
  final basic = _s(id: 'b', nome: 'Cleanox Basic', valor: 170, grupo: 'higienizacao_interna');

  test('parse porte Popular/SUV/Caminhonete', () {
    expect(parsePorteLavagem('Lavagem Prime — Popular')?.familia, 'Lavagem Prime');
    expect(parsePorteLavagem('Lavagem Prime — Popular')?.porte, 'Popular');
    expect(parsePorteLavagem('Lavagem Detail - SUV')?.porte, 'SUV');
    expect(parsePorteLavagem('Lavagem Prime — Moto'), isNull);
    expect(parsePorteLavagem('Cleanox Basic'), isNull);
  });

  test('6 lavagens viram 2 cards; moto e basic ficam', () {
    final out = catalogoAgrupadoPorPorte([
      primePop,
      primeSuv,
      primeCam,
      detailPop,
      detailSuv,
      detailCam,
      moto,
      basic,
    ]);
    expect(out.map((s) => s.nome), [
      'Lavagem Prime',
      'Lavagem Detail',
      'Lavagem Prime — Moto',
      'Cleanox Basic',
    ]);
    expect(out.first.valorBase, 60);
    expect(out.first.precoModo, VitrinePrecoModo.aPartirDe);
  });

  test('seleção do SUV marca o card Prime', () {
    final cards = catalogoAgrupadoPorPorte([primePop, primeSuv, primeCam]);
    final ids = idsSelecaoComPorte(
      exibidos: cards,
      catalogo: [primePop, primeSuv, primeCam],
      selecionados: {'ps'},
    );
    expect(ids, {cards.first.id});
  });

  testWidgets('sheet mostra + ao lado de cada porte', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showVitrinePorteSheet(
              ctx,
              titulo: 'Lavagem Prime',
              variantes: [primePop, primeSuv, primeCam],
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsNWidgets(3));
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('SUV'), findsOneWidget);
  });
}
