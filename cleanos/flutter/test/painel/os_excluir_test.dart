/// os_excluir_test.dart — Excluir OS pelo detalhe do Painel.
///
/// A exclusão é definitiva e o estorno financeiro é do SERVIDOR
/// (os_delete.pb.js); aqui provamos o contrato do cliente:
///   - o botão "Excluir OS" existe em qualquer status (inclusive concluída);
///   - o dialog de OS concluída AVISA do estorno de receita/comissão antes
///     de o admin confirmar;
///   - confirmar dispara exatamente 1 delete no repositório e fecha o detalhe;
///   - "Voltar" não deleta nada.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/painel/ordens/ordens_screen.dart';
import 'package:cleanos/painel/ordens/os_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'ordens_screen_test.dart' show overridesFor;
import 'painel_test_helpers.dart';

OrdemServico _os(OSStatus status) => OrdemServico(
  id: 'os1',
  cliente: 'c1',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  servico: 's1',
  tipoServicoNome: 'Higienização',
  dataHora: '2026-07-10 13:00:00Z',
  status: status,
  valorServico: 200,
  valorPago: status == OSStatus.concluida ? 200 : null,
);

Future<FakeOrdens> _abrirDetalhe(WidgetTester tester, OSStatus status) async {
  final ordens = FakeOrdens(seed: [_os(status)]);
  await pumpPainel(
    tester,
    const OrdensScreen(),
    overrides: overridesFor(ordens: ordens),
  );
  await tester.pump();
  await tester.pump();

  await tester.tap(find.text('Carlos S.').first);
  await tester.pumpAndSettle();
  expect(find.byType(OSDetail), findsOneWidget);
  return ordens;
}

void main() {
  group('Excluir OS pelo detalhe', () {
    testWidgets('concluída: dialog avisa do estorno e confirmar deleta 1x', (
      tester,
    ) async {
      final ordens = await _abrirDetalhe(tester, OSStatus.concluida);

      // Concluída não tem "Cancelar OS", mas TEM "Excluir OS".
      expect(find.text('Cancelar OS'), findsNothing);
      await tester.tap(find.text('Excluir OS'));
      await tester.pumpAndSettle();

      // O aviso de OS concluída nomeia as consequências financeiras.
      expect(
        find.textContaining('estorno do saldo'),
        findsOneWidget,
        reason: 'admin precisa saber que o caixa muda antes de confirmar',
      );
      expect(find.textContaining('comissão'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir OS'));
      await tester.pumpAndSettle();

      expect(ordens.deleteCount, 1, reason: 'confirmar = exatamente 1 delete');
      expect(ordens.lastDeleted, 'os1');
      expect(find.byType(OSDetail), findsNothing, reason: 'detalhe fecha');
    });

    testWidgets('agendada: aviso genérico (sem estorno) e delete funciona', (
      tester,
    ) async {
      final ordens = await _abrirDetalhe(tester, OSStatus.agendada);

      await tester.tap(find.text('Excluir OS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('estorno do saldo'), findsNothing);
      expect(find.textContaining('não pode ser desfeita'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir OS'));
      await tester.pumpAndSettle();

      expect(ordens.deleteCount, 1);
    });

    testWidgets('"Voltar" no dialog não deleta nada e mantém o detalhe', (
      tester,
    ) async {
      final ordens = await _abrirDetalhe(tester, OSStatus.concluida);

      await tester.tap(find.text('Excluir OS'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(ordens.deleteCount, 0);
      expect(find.byType(OSDetail), findsOneWidget);
    });
  });
}
