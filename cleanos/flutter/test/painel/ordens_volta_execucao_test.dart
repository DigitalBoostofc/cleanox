/// ordens_volta_execucao_test.dart — F-233: voltar da tela de Execução (visão
/// admin) tem que recarregar a lista e os contadores.
///
/// Lá dentro dá para mudar valor, serviço e status da OS. Enquanto a volta não
/// recarregava, o painel continuava mostrando os valores VELHOS — o admin via um
/// número que já não era verdade.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

/// Avança o tempo o bastante para rotas/futuros resolverem, SEM esperar a árvore
/// ficar parada — os spinners do app real animam para sempre.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('F-233: voltar da Execução recarrega a lista de OS', (
    tester,
  ) async {
    final ordens = FakeOrdensPatch(
      seed: const [
        OrdemServico(
          id: 'os1',
          cliente: 'c1',
          nomeCurto: 'Carlos S.',
          bairro: 'Centro',
          tipoServicoNome: 'Higienização',
          dataHora: '2030-01-15 13:00:00Z',
          status: OSStatus.atribuida,
          profissional: 'p1',
          valorServico: 200,
        ),
      ],
    );

    final router = await pumpPainelApp(
      tester,
      user: painelUser(),
      repo: ordens,
      location: '/painel/ordens',
    );
    // Sem `pumpAndSettle`: o app real tem spinners que nunca param de animar
    // (os outros repositórios batem num PocketBase de descarte). Mesma
    // convenção dos demais testes de rota do Painel.
    await settle(tester);
    expect(find.text('Carlos S.'), findsWidgets);

    final antes = ordens.listCount;
    expect(antes, greaterThan(0), reason: 'a lista carregou ao abrir a tela');

    // Abre a Execução (visão admin) pela linha.
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await settle(tester);
    expect(router.state.uri.toString(), '/painel/ordens/os1/execucao');

    // Volta.
    router.pop();
    await settle(tester);

    expect(
      ordens.listCount,
      greaterThan(antes),
      reason:
          'voltou da Execução e a lista NÃO foi recarregada — o painel segue '
          'mostrando valor/serviço velhos (F-233)',
    );
  });
}
