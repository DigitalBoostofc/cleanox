/// os_estado_impossivel_test.dart — F-234: o Painel não pode GRAVAR uma OS
/// `atribuida` sem profissional.
///
/// O QA E2E achou no banco de dev a OS `g6y2409up2zudtt` com
/// `status="atribuida"` + `profissional=""` — um estado que o domínio não
/// admite (quem está "atribuída" está atribuída A ALGUÉM).
///
/// O caminho: atribuir pelo DETALHE (o registro no servidor vira
/// atribuida+prof) → clicar em "Editar" sem F5 → o form reabre com o registro
/// VELHO do closure ("— Não atribuído (Agendada) —") → Salvar manda
/// `profissional: null` mas, como o registro velho diz "agendada/sem prof",
/// nenhum ramo de transição dispara e `status` NÃO entra no payload.
///
/// [FakeOrdensPatch] é o coração deste teste: modela a semântica REAL de PATCH
/// do PocketBase — campo ausente do payload é PRESERVADO no banco. Um fake que
/// devolvesse o payload como se fosse o registro inteiro esconderia o bug, que
/// é exatamente o que passou despercebido até o QA olhar o banco.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/ordens/ordens_screen.dart';
import 'package:cleanos/painel/ordens/os_detail.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'ordens_screen_test.dart' show overridesFor;
import 'painel_test_helpers.dart';

/// Data no FUTURO: OS de teste precisa de data estável (evita flaky com "hoje");
/// passar pela validação para chegar ao `update` (que é o que queremos medir).
const String _dataFutura = '2030-01-15 13:00:00Z';

OrdemServico _osAgendada() => const OrdemServico(
  id: 'os1',
  cliente: 'c1',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  servico: 's1',
  tipoServicoNome: 'Higienização',
  dataHora: _dataFutura,
  status: OSStatus.agendada,
  valorServico: 200,
);

void main() {
  const usuarios = [User(id: 'p1', name: 'Pedro', role: Role.profissional)];

  /// Executa o repro do F-234 até o ponto de reabrir o form de Edição:
  /// abre o detalhe → atribui o Pedro → clica em "Editar" SEM F5.
  Future<FakeOrdensPatch> atribuirEEditar(WidgetTester tester) async {
    final ordens = FakeOrdensPatch(seed: [_osAgendada()]);

    await pumpPainel(
      tester,
      const OrdensScreen(),
      overrides: overridesFor(
        ordens: ordens,
        usuarios: FakeUsuarios(profissionais: usuarios),
        servicos: FakeServicos(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // A atribuição muda agendada→atribuida; na aba "Todas" a OS continua
    // visível durante todo o fluxo (o default novo é "Em agendamento").
    await tester.tap(find.text('Todas'));
    await tester.pump();
    await tester.pump();

    // 1) Abre a OS pelo DETALHE (clicando na linha) — aba "Todas".
    await tester.tap(find.text('Carlos S.').first);
    await tester.pumpAndSettle();
    expect(find.byType(OSDetail), findsOneWidget);

    // 2) Atribui o Pedro. O servidor passa a ter atribuida + p1.
    await tester.tap(
      find.descendant(
        of: find.byType(OSDetail),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atribuir'));
    await tester.pumpAndSettle();

    expect(
      ordens.registro.status,
      OSStatus.atribuida,
      reason: 'a atribuição em si tem que funcionar',
    );
    expect(ordens.registro.profissional, 'p1');

    // 3) SEM F5: clica em "Editar" no detalhe já aberto.
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.byType(OSForm), findsOneWidget);

    return ordens;
  }

  group('F-234 — OS não pode ficar num estado impossível', () {
    testWidgets(
      'salvar o form reaberto NÃO grava status=atribuida sem profissional',
      (tester) async {
        final ordens = await atribuirEEditar(tester);

        // Salva sem tocar em nada.
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        // A PROVA — o invariante do domínio, medido no "banco":
        expect(
          ordens.estadoImpossivel,
          isFalse,
          reason:
              'gravou status=${ordens.registro.status.wire} com '
              'profissional="${ordens.registro.profissional ?? ''}" — '
              'estado impossível (F-234). Payloads: ${ordens.payloads}',
        );
      },
    );

    testWidgets('o form de Edição reabre com a OS ATUAL, não com a stale', (
      tester,
    ) async {
      final ordens = await atribuirEEditar(tester);

      // O form tem que refletir a OS COMO ELA ESTÁ AGORA (atribuída ao Pedro),
      // não o registro velho do closure.
      expect(
        find.descendant(
          of: find.byType(OSForm),
          matching: find.text('— Não atribuído (Agendada) —'),
        ),
        findsNothing,
        reason:
            'o form reabriu com o registro STALE: mostra "não atribuído" '
            'mesmo com a OS já atribuída ao ${ordens.registro.profissional} '
            'no servidor',
      );
      expect(
        find.descendant(
          of: find.byType(OSForm),
          matching: find.text('Pedro'),
        ),
        findsWidgets,
      );
    });
  });
}
