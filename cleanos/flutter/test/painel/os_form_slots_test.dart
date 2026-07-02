/// os_form_slots_test.dart — Seletor de slot da Nova OS ligado à disponibilidade
/// REAL do profissional (Fase 3, Feature 1).
///
/// Cobre: (a) o cruzamento PURO disponibilidade × ocupação (`computeOSDaySlots`,
/// reuso da lógica de slot da Agenda); (b) a reatividade do formulário — só slots
/// livres, aviso "não atende neste dia", fallback livre sem disponibilidade e
/// reação à troca de profissional.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

/// Fake de disponibilidade que RESPEITA o filtro por profissional
/// (`profissional = 'id'`) — necessário p/ o seletor de slot diferenciar profs.
class FakeDispFiltrada implements DisponibilidadeRepository {
  FakeDispFiltrada(this.seed);
  final List<Disponibilidade> seed;

  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async {
    final items = filter == null
        ? seed
        : seed.where((d) => filter.contains("'${d.profissional}'")).toList();
    return PageResult<Disponibilidade>(
      items: items,
      page: 1,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  Never _unused() => throw UnimplementedError();
  @override
  Future<Disponibilidade> getOne(String id) => _unused();
  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) => _unused();
  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) =>
      _unused();
  @override
  Future<void> delete(String id) => _unused();
}

List<Override> _overrides({
  required DisponibilidadeRepository disp,
  FakeOrdens? ordens,
  FakeUsuarios? usuarios,
}) => [
  ...painelOverrides(user: painelUser()),
  ordensRepositoryProvider.overrideWithValue(ordens ?? FakeOrdens()),
  clientesRepositoryProvider.overrideWithValue(FakeClientes()),
  servicosRepositoryProvider.overrideWithValue(FakeServicos()),
  usuariosRepositoryProvider.overrideWithValue(
    usuarios ??
        FakeUsuarios(
          profissionais: const [
            User(id: 'p1', name: 'Pedro', role: Role.profissional),
            User(id: 'p2', name: 'Marina', role: Role.profissional),
          ],
        ),
  ),
  disponibilidadeRepositoryProvider.overrideWithValue(disp),
];

/// Deixa os lookups + fetches de disponibilidade/ocupação assentarem sem usar
/// `pumpAndSettle` (que travaria no spinner de "Carregando horários…").
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> _selecionarProfissional(WidgetTester tester, String nome) async {
  await tester.tap(find.byKey(const ValueKey('os-profissional')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nome).last);
  await _settle(tester);
}

Future<void> _escolherHoje(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calendar_month_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  group('computeOSDaySlots (puro)', () {
    // 2026-07-06 é uma segunda-feira; com todos os dias ativos o dia da semana
    // é irrelevante (todos atendem).
    const date = '2026-07-06';

    test('gera slots livres da janela (08:00–10:00, 60min, sem ocupação)', () {
      final r = computeOSDaySlots(
        disp: fakeDisponibilidade(
          id: 'd',
          profissional: 'p1',
          inicio: '08:00',
          fim: '10:00',
          duracaoMin: 60,
        ),
        date: date,
        ocupados: const [],
      );
      expect(r.diaAtende, isTrue);
      expect(r.slots.contains('08:00'), isTrue);
      expect(r.slots.contains('09:00'), isTrue);
      expect(r.slots.length, 5); // 08:00,08:15,08:30,08:45,09:00
    });

    test('remove os horários ocupados (09:00 ocupado → sobra 08:00)', () {
      final r = computeOSDaySlots(
        disp: fakeDisponibilidade(
          id: 'd',
          profissional: 'p1',
          inicio: '08:00',
          fim: '10:00',
          duracaoMin: 60,
        ),
        date: date,
        ocupados: const ['09:00'],
      );
      expect(r.slots, ['08:00']);
    });

    test('dia inativo → não atende', () {
      final r = computeOSDaySlots(
        disp: fakeDisponibilidade(
          id: 'd',
          profissional: 'p1',
          diasAtivos: List<bool>.filled(7, false),
        ),
        date: date,
        ocupados: const [],
      );
      expect(r.diaAtende, isFalse);
      expect(r.slots, isEmpty);
    });
  });

  group('OSForm — seletor de slot', () {
    testWidgets('sem profissional → horário LIVRE (fallback)', (tester) async {
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: FakeDispFiltrada(const [])),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('os-hora-livre')), findsOneWidget);
      expect(find.byKey(const ValueKey('os-hora-slots')), findsNothing);
    });

    testWidgets('profissional com disponibilidade → só slots livres', (
      tester,
    ) async {
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '08:00',
          fim: '10:00',
          duracaoMin: 60,
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: disp),
      );
      await _settle(tester);

      await _escolherHoje(tester);
      await _selecionarProfissional(tester, 'Pedro');

      expect(find.byKey(const ValueKey('os-hora-slots')), findsOneWidget);
      expect(find.byKey(const ValueKey('os-hora-livre')), findsNothing);
    });

    testWidgets('profissional que não atende no dia → aviso claro', (
      tester,
    ) async {
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd2',
          profissional: 'p2',
          diasAtivos: List<bool>.filled(7, false),
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: disp),
      );
      await _settle(tester);

      await _escolherHoje(tester);
      await _selecionarProfissional(tester, 'Marina');

      expect(find.byKey(const ValueKey('os-hora-dia-inativo')), findsOneWidget);
      expect(find.text('Profissional não atende neste dia'), findsOneWidget);
    });

    testWidgets('sem disponibilidade cadastrada → mantém modo livre', (
      tester,
    ) async {
      // Seed vazio: o profissional 'p1' não tem registro de disponibilidade.
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: FakeDispFiltrada(const [])),
      );
      await _settle(tester);

      await _escolherHoje(tester);
      await _selecionarProfissional(tester, 'Pedro');

      expect(find.byKey(const ValueKey('os-hora-livre')), findsOneWidget);
    });

    testWidgets('reage à troca de profissional (slots → não atende)', (
      tester,
    ) async {
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '08:00',
          fim: '10:00',
          duracaoMin: 60,
        ),
        fakeDisponibilidade(
          id: 'd2',
          profissional: 'p2',
          diasAtivos: List<bool>.filled(7, false),
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: disp),
      );
      await _settle(tester);
      await _escolherHoje(tester);

      // Livre no início.
      expect(find.byKey(const ValueKey('os-hora-livre')), findsOneWidget);

      // Pedro (atende) → slots.
      await _selecionarProfissional(tester, 'Pedro');
      expect(find.byKey(const ValueKey('os-hora-slots')), findsOneWidget);

      // Marina (não atende) → aviso.
      await _selecionarProfissional(tester, 'Marina');
      expect(find.byKey(const ValueKey('os-hora-dia-inativo')), findsOneWidget);
    });
  });
}
