/// ordens_screen_test.dart — Lista + fluxo de Nova OS.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/ordens_screen.dart';
import 'package:cleanos/painel/ordens/os_detail.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('OrdensScreen — ordenação (feedback do dono 16/07)', () {
    setUp(() async {
      // Prefs limpas: cada teste começa sem sort por aba.
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'padrão é data mais próxima primeiro (data_hora asc); trocar reordena',
      (tester) async {
        final ordens = _FakeOrdensSortSpy(seed: [_os('a')]);
        await pumpPainel(
          tester,
          const OrdensScreen(),
          overrides: overridesFor(ordens: ordens),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Default: mais próximo primeiro → ascendente, NÃO '-data_hora'.
        expect(ordens.lastSort, 'data_hora');
        expect(find.text('Data — mais próxima primeiro'), findsOneWidget);

        // Troca para Cliente A→Z e confirma que o servidor recebe o sort novo.
        await tester.tap(find.text('Data — mais próxima primeiro'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente — A a Z').last);
        await tester.pumpAndSettle();
        expect(ordens.lastSort, 'nome_curto');
      },
    );

    testWidgets(
      'ordenação é por ABA: Agendada ≠ Concluída (e volta ao voltar de aba)',
      (tester) async {
        final ordens = _FakeOrdensSortSpy(seed: [_os('a')]);
        await pumpPainel(
          tester,
          const OrdensScreen(),
          overrides: overridesFor(ordens: ordens),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Em Agendada: Cliente A→Z.
        await tester.tap(find.text('Data — mais próxima primeiro'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente — A a Z').last);
        await tester.pumpAndSettle();
        expect(ordens.lastSort, 'nome_curto');

        // Vai pra Concluída → FIXO: conclusão mais recente (não herda A→Z).
        await tester.tap(find.text('Concluída').first);
        await tester.pumpAndSettle();
        expect(ordens.lastSort, '-concluida_em,-updated');
        expect(
          find.text('Conclusão — mais recente primeiro'),
          findsOneWidget,
        );

        // Volta pra Agendada → ainda A→Z (salva por aba).
        await tester.tap(find.text('Agendada').first);
        await tester.pumpAndSettle();
        expect(ordens.lastSort, 'nome_curto');
        expect(find.text('Cliente — A a Z'), findsOneWidget);
      },
    );

    testWidgets('período virou dropdown: padrão "Esta semana", troca p/ "Tudo"', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(ordens: FakeOrdens(seed: [_os('a')])),
      );
      await tester.pump();
      await tester.pump();

      // Default do dono (16/07): semana corrente.
      expect(find.text('Esta semana'), findsOneWidget);

      // Abre o dropdown e escolhe "Tudo".
      await tester.tap(find.text('Esta semana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tudo').last);
      await tester.pumpAndSettle();
      expect(find.text('Tudo'), findsOneWidget);
      expect(find.text('Esta semana'), findsNothing);
    });
  });

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

      // Default novo (16/07): a tela abre filtrando "Agendada" na semana
      // corrente — o vazio informa o status e sugere trocar o período.
      expect(find.text('Nenhuma OS com status "Agendada"'), findsOneWidget);
      expect(find.textContaining('Nada no período'), findsOneWidget);
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

      // Valor (índice 3: picker=0, tipo=1, hora=2, valor=3). A Hora virou entrada
      // LIVRE 'HH:MM' (agenda estilo Google) e entrou na frente do Valor.
      await tester.enterText(osFormFieldAt(3), '150');
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

    testWidgets('Atribuir na aba Agendada: lista recarrega e vai pra Atribuída', (
      tester,
    ) async {
      final ordens = _FakeOrdensStatusFilter(seed: [_os('a')]);
      final usuarios = FakeUsuarios(
        profissionais: const [
          User(id: 'p1', name: 'Pedro', role: Role.profissional),
        ],
      );
      await pumpPainel(
        tester,
        const OrdensScreen(),
        overrides: overridesFor(ordens: ordens, usuarios: usuarios),
      );
      await tester.pump();
      await tester.pump();

      // Vai pra aba Agendada (tabs vêm antes da lista na árvore).
      await tester.tap(find.text('Agendada').first);
      await tester.pump();
      await tester.pump();
      expect(find.text('Higienização'), findsWidgets);

      // Abre o detalhe pela linha e atribui o Pedro.
      await tester.tap(find.text('Carlos S.').first);
      await tester.pumpAndSettle();
      expect(find.byType(OSDetail), findsOneWidget);
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
      await tester.pump();
      await tester.pump();
      // Anima o fechamento do dialog (pump sem duração não avança a rota).
      await tester.pump(const Duration(milliseconds: 400));

      // Modal fechou sozinho e a lista mudou pra aba Atribuída, onde a OS
      // aparece (o fake honra o filtro de status: se ainda estivesse na aba
      // Agendada, a lista estaria vazia).
      expect(find.byType(OSDetail), findsNothing);
      expect(ordens.updateCount, 1);
      expect(find.text('Nenhuma ordem de serviço'), findsNothing);
      expect(find.text('Higienização'), findsWidgets);
    });
  });
}

/// FakeOrdens que CAPTURA o `sort` enviado ao servidor — prova o padrão de
/// ordenação e a troca pelo dropdown.
class _FakeOrdensSortSpy extends FakeOrdens {
  _FakeOrdensSortSpy({super.seed});

  String? lastSort;

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    // Só a busca da LISTA (perPage grande) importa; as contagens das abas
    // usam perPage:1 com sort fixo e não devem sujar o que estamos medindo.
    if (perPage > 1) lastSort = sort;
    return PageResult<OrdemServico>(
      items: seed,
      page: 1,
      perPage: perPage,
      totalItems: seed.length,
      totalPages: 1,
    );
  }
}

/// FakeOrdens que HONRA o filtro de status do servidor — necessário pra provar
/// que a lista trocou de aba após a reatribuição (agendada → atribuida).
class _FakeOrdensStatusFilter extends FakeOrdens {
  _FakeOrdensStatusFilter({super.seed});

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    // Só aplica o recorte por STATUS; a janela de data (período) é ignorada
    // pelo fake — as OS de teste usam datas placeholder distantes.
    final items = seed
        .where(
          (o) =>
              filter == null ||
              !filter.contains('status =') ||
              filter.contains(o.status.wire),
        )
        .toList();
    return PageResult<OrdemServico>(
      items: items,
      page: 1,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) async {
    updateCount++;
    final atualizado = seed
        .firstWhere((o) => o.id == osId)
        .copyWith(
          status: OSStatus.atribuida,
          profissional: data['profissional'] as String?,
        );
    seed = [
      for (final o in seed)
        if (o.id == osId) atualizado else o,
    ];
    return atualizado;
  }
}
