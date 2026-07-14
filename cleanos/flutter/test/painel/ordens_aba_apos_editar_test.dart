/// ordens_aba_apos_editar_test.dart — F-232 e F-228.
///
/// F-232: o fix de ontem (865f2bf) só cobriu a atribuição pelo DETALHE. Pelo
/// LÁPIS da lista o `os_form` muda o status na surdina (agendada + profissional
/// → atribuída) e a OS deixava de casar com o filtro ativo: sumia da tela num
/// empty-state, sem aviso.
///
/// F-228: mexer no profissional de uma OS EM ANDAMENTO rebaixa o status, e o
/// hook do servidor apaga endereço liberado + GPS ao ver o status sair de
/// `em_andamento`. Tem que perguntar antes.
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

const String _dataFutura = '2030-01-15 13:00:00Z';

OrdemServico _os({required OSStatus status, String? profissional}) =>
    OrdemServico(
      id: 'os1',
      cliente: 'c1',
      nomeCurto: 'Carlos S.',
      bairro: 'Centro',
      tipoServicoNome: 'Higienização',
      dataHora: _dataFutura,
      status: status,
      profissional: profissional,
      valorServico: 200,
    );

void main() {
  // `p0` é quem já está na OS em andamento — precisa existir na lista, senão o
  // dropdown do detalhe fica com um `initialValue` sem item correspondente.
  const profs = [
    User(id: 'p0', name: 'Paulo', role: Role.profissional),
    User(id: 'p1', name: 'Pedro', role: Role.profissional),
  ];

  testWidgets(
    'F-232: atribuir pelo LÁPIS da lista leva a lista pra aba do novo status',
    (tester) async {
      final ordens = FakeOrdensPatch(seed: [_os(status: OSStatus.agendada)]);

      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(
          ordens: ordens,
          usuarios: FakeUsuarios(profissionais: profs),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Fica na aba Agendada (o filtro ativo é o que faz a OS sumir).
      await tester.tap(find.text('Agendada').first);
      await tester.pump();
      await tester.pump();
      expect(find.text('Higienização'), findsWidgets);

      // Lápis da lista → form de edição.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byType(OSForm), findsOneWidget);

      // Atribui o Pedro pelo dropdown de Profissional do form.
      await tester.tap(find.byKey(const ValueKey('os-profissional')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedro').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // O form mudou o status na surdina — a OS agora é "atribuida".
      expect(ordens.registro.status, OSStatus.atribuida);
      expect(ordens.registro.profissional, 'p1');

      // E a lista NÃO pode ter deixado a OS sumir: seguiu pra aba do novo
      // status, onde ela aparece.
      expect(
        find.text('Nenhuma OS com status "Agendada"'),
        findsNothing,
        reason: 'a OS sumiu da tela sem aviso (empty-state) — F-232',
      );
      expect(find.text('Higienização'), findsWidgets);
    },
  );

  group('F-228 — reatribuir OS em andamento', () {
    testWidgets('avisa que endereço e GPS serão apagados, e respeita o Voltar', (
      tester,
    ) async {
      final ordens = FakeOrdensPatch(
        seed: [_os(status: OSStatus.emAndamento, profissional: 'p0')],
      );

      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(
          ordens: ordens,
          usuarios: FakeUsuarios(profissionais: profs),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Carlos S.').first);
      await tester.pumpAndSettle();
      expect(find.byType(OSDetail), findsOneWidget);

      // Troca o profissional e manda atribuir.
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

      // Em vez de rebaixar em silêncio, avisa a consequência.
      expect(find.text('Esta OS está em andamento'), findsOneWidget);
      expect(find.textContaining('endereço'), findsWidgets);
      expect(find.textContaining('GPS'), findsWidgets);

      // "Voltar" NÃO grava nada.
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(ordens.updateCount, 0, reason: 'desistir não pode gravar');
      expect(ordens.registro.status, OSStatus.emAndamento);
      expect(ordens.registro.profissional, 'p0');
    });

    testWidgets('confirmando, a reatribuição acontece', (tester) async {
      final ordens = FakeOrdensPatch(
        seed: [_os(status: OSStatus.emAndamento, profissional: 'p0')],
      );

      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(
          ordens: ordens,
          usuarios: FakeUsuarios(profissionais: profs),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Carlos S.').first);
      await tester.pumpAndSettle();
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

      await tester.tap(find.text('Trocar mesmo assim'));
      await tester.pumpAndSettle();

      expect(ordens.updateCount, 1);
      expect(ordens.registro.profissional, 'p1');
      expect(ordens.registro.status, OSStatus.atribuida);
    });
  });
}
