/// os_excluir_test.dart — Excluir OS pelo detalhe do Painel.
///
/// Contrato: botão "Excluir OS" só em status cancelada; confirmar deleta 1x.
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
  motivoCancelamento: status == OSStatus.cancelada ? 'Cliente desistiu' : null,
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
    testWidgets('cancelada: botão aparece e confirmar deleta 1x', (
      tester,
    ) async {
      final ordens = await _abrirDetalhe(tester, OSStatus.cancelada);

      expect(find.text('Excluir OS'), findsOneWidget);
      expect(find.text('Cancelar OS'), findsNothing);

      await tester.tap(find.text('Excluir OS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('não pode ser desfeita'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Excluir OS'));
      await tester.pumpAndSettle();

      expect(ordens.deleteCount, 1, reason: 'confirmar = exatamente 1 delete');
      expect(ordens.lastDeleted, 'os1');
      expect(find.byType(OSDetail), findsNothing, reason: 'detalhe fecha');
    });

    testWidgets('concluída: NÃO mostra Excluir OS', (tester) async {
      await _abrirDetalhe(tester, OSStatus.concluida);
      expect(find.text('Excluir OS'), findsNothing);
      expect(find.text('Cancelar OS'), findsNothing);
    });

    testWidgets('agendada: NÃO mostra Excluir OS (só Cancelar)', (
      tester,
    ) async {
      await _abrirDetalhe(tester, OSStatus.agendada);
      expect(find.text('Excluir OS'), findsNothing);
      expect(find.text('Cancelar OS'), findsOneWidget);
    });

    testWidgets('"Voltar" no dialog não deleta nada e mantém o detalhe', (
      tester,
    ) async {
      final ordens = await _abrirDetalhe(tester, OSStatus.cancelada);

      await tester.tap(find.text('Excluir OS'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(ordens.deleteCount, 0);
      expect(find.byType(OSDetail), findsOneWidget);
    });
  });
}
