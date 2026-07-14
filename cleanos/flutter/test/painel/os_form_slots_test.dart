/// os_form_slots_test.dart — Horário/duração da Nova OS (agenda estilo Google).
///
/// A Fase 1 da agenda APOSENTOU o seletor de slot do formulário: com sobreposição
/// permitida, esconder horários "ocupados" só impedia encaixes legítimos (D10). O
/// que este teste cobre agora:
///   (a) a função PURA `computeOSDaySlots` — que CONTINUA viva porque o
///       `os_inline_section` (Clientes) ainda oferece slots;
///   (b) o formulário: entrada LIVRE 'HH:MM' com snap de 15 min, Duração
///       PREFILADA (visível) com a do profissional (D9), e o AVISO amarelo de
///       sobreposição que NÃO bloqueia o salvar (D2/D11).
library;

import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
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
/// (`profissional = 'id'`) — necessário p/ o form diferenciar profs.
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
  clientesRepositoryProvider.overrideWithValue(
    FakeClientes(
      seed: [fakeCliente(id: 'c1', nome: 'Carlos', sobrenome: 'Silva')],
    ),
  ),
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

/// Deixa os lookups + fetches de disponibilidade/ocupação assentarem.
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

/// Digita no campo de hora e TIRA O FOCO (é o que dispara o snap de 15 min).
Future<void> _digitarHora(WidgetTester tester, String hhmm) async {
  await tester.enterText(find.byKey(const ValueKey('os-hora-input')), hhmm);
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester);
}

/// OS já agendada HOJE para [prof], às [hhmm] BRT, com [duracaoMin].
OrdemServico _osOcupada({
  required String id,
  required String prof,
  required String hhmm,
  int? duracaoMin,
  String nomeCurto = 'Carlos S.',
  OSStatus status = OSStatus.atribuida,
}) => OrdemServico(
  id: id,
  profissional: prof,
  nomeCurto: nomeCurto,
  status: status,
  duracaoMin: duracaoMin,
  dataHora: localInputToPBDate('${todayLocalDate()}T$hhmm'),
);

void main() {
  group('computeOSDaySlots (puro — ainda usado pelo os_inline_section)', () {
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

  group('OSForm — hora LIVRE (o dropdown de slots foi aposentado)', () {
    testWidgets('o seletor de slot não existe mais; a hora é campo de texto', (
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

      expect(find.byKey(const ValueKey('os-hora-input')), findsOneWidget);
      // Nada de dropdown de slots, nem dos avisos que escondiam horários.
      expect(find.byKey(const ValueKey('os-hora-slots')), findsNothing);
      expect(find.byKey(const ValueKey('os-hora-livre')), findsNothing);
      expect(find.text('Profissional não atende neste dia'), findsNothing);
      expect(find.text('Sem horários disponíveis nesta data'), findsNothing);
    });

    testWidgets('horário fora da grade de 15min sofre snap ao sair do campo', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: FakeDispFiltrada(const [])),
      );
      await _settle(tester);

      await _digitarHora(tester, '09:07');
      final campo = tester.widget<TextField>(
        find.byKey(const ValueKey('os-hora-input')),
      );
      expect(campo.controller?.text, '09:00');
    });

    testWidgets('hora inválida vira erro de validação (não salva)', (
      tester,
    ) async {
      final ordens = FakeOrdens();
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: FakeDispFiltrada(const []), ordens: ordens),
      );
      await _settle(tester);

      await _digitarHora(tester, '99:99');
      expect(find.text('Horário inválido (HH:MM)'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await _settle(tester);
      expect(ordens.createCount, 0);
    });
  });

  group('OSForm — Duração prefilada (D9)', () {
    testWidgets('escolher o profissional prefila a duração DELE, visível', (
      tester,
    ) async {
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '08:00',
          fim: '18:00',
          duracaoMin: 90,
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

      final dd = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const ValueKey('os-duracao')),
      );
      expect(dd.initialValue, 90);
      expect(find.byKey(const ValueKey('os-duracao-prefill')), findsOneWidget);
    });

    testWidgets('sem profissional → duração cai no padrão de 60 min', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: FakeDispFiltrada(const [])),
      );
      await _settle(tester);

      final dd = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const ValueKey('os-duracao')),
      );
      expect(dd.initialValue, kDuracaoPadraoMin);
      // Sem profissional não há "duração padrão do profissional" a anunciar.
      expect(find.byKey(const ValueKey('os-duracao-prefill')), findsNothing);
    });

    testWidgets('a duração escolhida é gravada em duracao_min', (tester) async {
      final ordens = FakeOrdens();
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: FakeDispFiltrada(const []), ordens: ordens),
      );
      await _settle(tester);

      // Mínimo p/ salvar: cliente (busca no servidor) + valor + data.
      final campos = find.descendant(
        of: find.byType(OSForm),
        matching: find.byType(TextField),
      );
      await tester.enterText(campos.at(0), 'Car');
      await tester.pump(const Duration(milliseconds: 400)); // debounce
      await tester.pump();
      await tester.tap(find.text('Carlos Silva').last);
      await tester.pumpAndSettle();
      await tester.enterText(campos.at(3), '150'); // picker=0, tipo=1, hora=2
      await tester.pump();
      await _escolherHoje(tester);

      // Duração: 120 min.
      await tester.tap(find.byKey(const ValueKey('os-duracao')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(labelDuracao(120)).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await _settle(tester);

      expect(ordens.createCount, 1);
      expect(ordens.lastCreate?['duracao_min'], 120);
    });
  });

  group('OSForm — aviso de sobreposição (D2/D11)', () {
    testWidgets('encaixar dentro de uma OS existente AVISA (e deixa salvar)', (
      tester,
    ) async {
      final ordens = FakeOrdens(
        seed: [_osOcupada(id: 'x', prof: 'p1', hhmm: '08:00', duracaoMin: 120)],
      );
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '08:00',
          fim: '18:00',
          duracaoMin: 60,
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: disp, ordens: ordens),
      );
      await _settle(tester);
      await _escolherHoje(tester);
      await _selecionarProfissional(tester, 'Pedro');

      // 09:00 + 60min cai DENTRO da OS das 08:00–10:00.
      await _digitarHora(tester, '09:00');

      expect(
        find.byKey(const ValueKey('os-aviso-sobreposicao')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sobrepõe OS de Carlos S. (08:00–10:00)'),
        findsOneWidget,
      );
      // NÃO bloqueia: o Salvar continua lá, clicável.
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('encostar (sem invadir) NÃO avisa — intervalo half-open', (
      tester,
    ) async {
      final ordens = FakeOrdens(
        seed: [_osOcupada(id: 'x', prof: 'p1', hhmm: '08:00', duracaoMin: 120)],
      );
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '08:00',
          fim: '18:00',
          duracaoMin: 60,
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: disp, ordens: ordens),
      );
      await _settle(tester);
      await _escolherHoje(tester);
      await _selecionarProfissional(tester, 'Pedro');

      // 10:00 começa exatamente quando a outra termina.
      await _digitarHora(tester, '10:00');
      expect(find.byKey(const ValueKey('os-aviso-sobreposicao')), findsNothing);
    });

    testWidgets('OS concluída no dia NÃO gera aviso fantasma (D11)', (
      tester,
    ) async {
      final ordens = FakeOrdens(
        seed: [
          _osOcupada(
            id: 'c',
            prof: 'p1',
            hhmm: '08:00',
            duracaoMin: 120,
            status: OSStatus.concluida,
          ),
        ],
      );
      final disp = FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '08:00',
          fim: '18:00',
          duracaoMin: 60,
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        overrides: _overrides(disp: disp, ordens: ordens),
      );
      await _settle(tester);
      await _escolherHoje(tester);
      await _selecionarProfissional(tester, 'Pedro');
      await _digitarHora(tester, '09:00');

      expect(find.byKey(const ValueKey('os-aviso-sobreposicao')), findsNothing);
    });
  });
}
