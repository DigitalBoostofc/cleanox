/// Layout Organizze da linha de lançamento: conta central, comentário, fixo, mãozinha.
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';

void main() {
  Future<void> pumpRow(WidgetTester tester, FinLancamento l) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SizedBox(width: 900, child: debugLancamentoRow(l)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mostra comentário com tooltip quando há observação', (tester) async {
    await pumpRow(
      tester,
      fakeLanc(
        id: '1',
        descricao: 'Compra',
        observacao: 'compra no cartão da mãe',
      ),
    );
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(
      find.byTooltip('compra no cartão da mãe'),
      findsOneWidget,
    );
  });

  testWidgets('mostra sync com tooltip em lançamento fixo', (tester) async {
    await pumpRow(
      tester,
      fakeLanc(
        id: '1',
        descricao: 'Aluguel',
        recorrencia: RecorrenciaTipo.fixa,
      ),
    );
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(
      find.byTooltip('Este é um lançamento fixo'),
      findsOneWidget,
    );
  });

  testWidgets('mãozinha 👍 se pago e 👎 se pendente', (tester) async {
    await pumpRow(
      tester,
      fakeLanc(id: '1', status: LancamentoStatus.pago),
    );
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);

    await pumpRow(
      tester,
      fakeLanc(id: '2', status: LancamentoStatus.pendente),
    );
    expect(find.byIcon(Icons.thumb_down_alt_rounded), findsOneWidget);
  });
}
