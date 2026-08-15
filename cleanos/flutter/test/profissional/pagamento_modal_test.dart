/// Modal de pagamento: orçamento só leitura + um campo Valor pago.
library;

import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/profissional/meus_servicos/pagamento_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrdemServico _os() => const OrdemServico(
  id: 'os1',
  status: OSStatus.emAndamento,
  tipoServicoNome: 'Higienização de bancos frente e trás',
  valorServico: 130,
  adicionais: [
    ServicoAdicionalOS(id: 'e1', nome: 'Tapete', valor: 20),
  ],
);

void main() {
  testWidgets('mostra orçamento só leitura e um campo Valor pago', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFintechLightTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showPagamentoModal(
                ctx,
                os: _os(),
                onSubmit: (_) async {},
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Orçamento total'), findsOneWidget);
    expect(find.text(formatCurrency(150)), findsOneWidget);
    expect(find.text('Valor pago'), findsOneWidget);
    expect(find.text('Usar preços de tabela'), findsNothing);
    expect(find.textContaining('Tabela:'), findsNothing);
    expect(find.byKey(const ValueKey('pag-valor-pago')), findsOneWidget);
    expect(find.textContaining('Higienização de bancos'), findsNothing);
  });
}
