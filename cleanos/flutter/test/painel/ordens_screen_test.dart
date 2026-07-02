/// ordens_screen_test.dart — Lista + fluxo de Nova OS.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/ordens_screen.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

OrdemServico _os(String id, {OSStatus status = OSStatus.agendada}) =>
    OrdemServico(
      id: id,
      nomeCurto: 'Carlos S.',
      bairro: 'Centro',
      tipoServicoNome: 'Higienização',
      dataHora: '2026-07-10 13:00:00Z',
      status: status,
      valorServico: 200,
    );

List<Override> overridesFor({
  required FakeOrdens ordens,
  FakeClientes? clientes,
  FakeServicos? servicos,
  FakeUsuarios? usuarios,
}) => [
  ...painelOverrides(user: painelUser()),
  ordensRepositoryProvider.overrideWithValue(ordens),
  clientesRepositoryProvider.overrideWithValue(clientes ?? FakeClientes()),
  servicosRepositoryProvider.overrideWithValue(servicos ?? FakeServicos()),
  usuariosRepositoryProvider.overrideWithValue(usuarios ?? FakeUsuarios()),
];

void main() {
  Finder osFormFieldAt(int i) => find
      .descendant(of: find.byType(OSForm), matching: find.byType(TextField))
      .at(i);

  group('OrdensScreen', () {
    testWidgets('lista: renderiza OS + abas de status', (tester) async {
      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(ordens: FakeOrdens(seed: [_os('a'), _os('b')])),
      );
      await tester.pump();
      await tester.pump();

      // Aba "Todas" + cada status.
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Agendada'), findsWidgets);
      // Serviço da OS aparece.
      expect(find.text('Higienização'), findsWidgets);
    });

    testWidgets('vazio: estado sem OS', (tester) async {
      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(ordens: FakeOrdens()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhuma ordem de serviço'), findsOneWidget);
    });

    testWidgets('Nova OS: abre o formulário e valida obrigatórios', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(ordens: FakeOrdens(seed: [_os('a')])),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Nova OS').first);
      await tester.pumpAndSettle();
      expect(find.byType(OSForm), findsOneWidget);

      // Salvar sem cliente/data/valor → erros.
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(find.text('Selecione um cliente'), findsOneWidget);
    });

    testWidgets('Nova OS: fluxo completo cria a OS', (tester) async {
      final ordens = FakeOrdens(seed: [_os('a')]);
      final clientes = FakeClientes(
        seed: [fakeCliente(id: 'c1', nome: 'Carlos', sobrenome: 'Silva')],
      );
      final servicos = FakeServicos(
        ativos: const [
          ServicoPB(id: 's1', nome: 'Higienização', valorBase: 200),
        ],
      );
      final usuarios = FakeUsuarios(
        profissionais: const [
          User(id: 'p1', name: 'Pedro', role: Role.profissional),
        ],
      );

      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(
          ordens: ordens,
          clientes: clientes,
          servicos: servicos,
          usuarios: usuarios,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Nova OS').first);
      await tester.pumpAndSettle();

      // Cliente: busca no servidor → seleciona resultado.
      await tester.enterText(osFormFieldAt(0), 'Car');
      await tester.pump(const Duration(milliseconds: 400)); // debounce
      await tester.pump();
      await tester.tap(find.text('Carlos Silva').last);
      await tester.pumpAndSettle();

      // Valor (índice 2: picker=0, tipo=1, valor=2).
      await tester.enterText(osFormFieldAt(2), '150');
      await tester.pump();

      // Data: abre o date picker e confirma (hoje).
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(ordens.createCount, 1);
      expect(ordens.lastCreate?['cliente'], 'c1');
    });
  });
}
