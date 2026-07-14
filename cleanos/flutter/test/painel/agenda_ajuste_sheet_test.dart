/// agenda_ajuste_sheet_test.dart — AJUSTE por sheet no APK / web estreita
/// (Fase 3, spec §7/§10 — D3/D6/D7/D11).
///
/// Duas camadas:
/// 1. **o sheet isolado** — steppers de ±15, piso de 15 min de duração, piso de
///    00:00 no início (D7), aviso de sobreposição que NÃO bloqueia o salvar;
/// 2. **a tela inteira a 390px** (o caminho real do APK e da web estreita) —
///    long-press no card de uma OS `agendada` abre o sheet; numa `concluida`/
///    `cancelada` (D6) NÃO abre; salvar dispara UM PATCH com `data_hora` e
///    `duracao_min`; cancelar não muda nada.
library;

import 'dart:async';

import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/agenda/agenda_controller.dart';
import 'package:cleanos/painel/agenda/agenda_screen.dart';
import 'package:cleanos/painel/agenda/ajuste_sheet.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda3.dart' show FakeUsuariosFull, fakeDisponibilidade, fakeUser;
import 'painel_test_helpers.dart';

/// Relógio FIXO (nada de `DateTime.now()` no meio do teste — gate G-8).
final DateTime _agoraUtc = DateTime.utc(2026, 7, 13, 12); // 09:00 BRT
final DateTime _hoje = DateTime(2026, 7, 13);

/// Viewport de celular (a mesma do APK e da web estreita).
const Size _celular = Size(390, 844);

String _pb(String hhmm, {DateTime? dia}) {
  final d = dia ?? _hoje;
  String p(int n) => n.toString().padLeft(2, '0');
  return localInputToPBDate('${d.year}-${p(d.month)}-${p(d.day)}T$hhmm');
}

OrdemServico _os(
  String id,
  String nome,
  String hhmm, {
  int? duracaoMin,
  OSStatus status = OSStatus.agendada,
  String prof = 'p1',
}) => OrdemServico(
  id: id,
  nomeCurto: nome,
  dataHora: _pb(hhmm),
  duracaoMin: duracaoMin,
  profissional: prof,
  status: status,
);

/* ══════════════════════════ fakes ══════════════════════════ */

/// `OrdensRepository` que REGISTRA o corpo do PATCH (é o contrato que importa).
class _OrdensSpy implements OrdensRepository {
  _OrdensSpy(this.seed);
  final List<OrdemServico> seed;

  int updateCount = 0;
  String? lastId;
  Map<String, dynamic>? lastBody;

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async => PageResult<OrdemServico>(
    items: seed,
    page: 1,
    perPage: perPage,
    totalItems: seed.length,
    totalPages: 1,
  );

  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) async {
    updateCount++;
    lastId = osId;
    lastBody = data;
    final atual = seed.firstWhere((o) => o.id == osId);
    return atual.copyWith(
      dataHora: (data['data_hora'] as String?) ?? atual.dataHora,
      duracaoMin: (data['duracao_min'] as int?) ?? atual.duracaoMin,
    );
  }

  Never _naoUsado() => throw UnimplementedError('não usado neste teste');
  @override
  Future<OrdemServico> getExec(String osId) => _naoUsado();
  @override
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch) => _naoUsado();
  @override
  Future<OrdemServico> updateStatus(String osId, OSStatus novo) => _naoUsado();
  @override
  Stream<OrdemServicoEvent> subscribe({String topic = '*', String? filter}) =>
      const Stream.empty();
  @override
  Future<List<OrdemServico>> listDoProfissional(
    String profId, {
    DateRange? janela,
  }) => _naoUsado();
  @override
  Future<OrdemServico> getOne(String osId, {String? expand}) => _naoUsado();
  @override
  Future<OrdemServico> create(Map<String, dynamic> data, {String? expand}) =>
      _naoUsado();
  @override
  Future<void> delete(String osId) => _naoUsado();
}

class _DispFake implements DisponibilidadeRepository {
  _DispFake(this.itens);
  final List<Disponibilidade> itens;

  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async => PageResult<Disponibilidade>(
    items: itens,
    page: 1,
    perPage: perPage,
    totalItems: itens.length,
    totalPages: 1,
  );

  Never _naoUsado() => throw UnimplementedError('não usado neste teste');
  @override
  Future<Disponibilidade> getOne(String id) => _naoUsado();
  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) => _naoUsado();
  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) =>
      _naoUsado();
  @override
  Future<void> delete(String id) => _naoUsado();
}

/* ══════════════════════════ harness ══════════════════════════ */

/// Sobe a AGENDA de verdade num celular (390px) com os fakes e o relógio fixo.
///
/// [easypay] = o casco Fintech Clean (APK **e** web estreita — nas duas o
/// `isNarrowWebProvider`/`isFintechCleanProvider` está ligado). Desligado, o
/// cenário é a web "média" (< 760px, mas ≥ 600dp): mesmas listas de cards, visual
/// clássico — por isso o [size] também muda.
Future<_OrdensSpy> _pumpAgenda(
  WidgetTester tester,
  List<OrdemServico> seed, {
  List<Disponibilidade> disp = const [],
  bool easypay = true,
  Size size = _celular,
}) async {
  final ordens = _OrdensSpy(seed);
  await pumpPainel(
    tester,
    const AgendaScreen(),
    size: size,
    overrides: [
      ...painelOverrides(user: painelUser()),
      ordensRepositoryProvider.overrideWithValue(ordens),
      usuariosRepositoryProvider.overrideWithValue(
        FakeUsuariosFull(seed: [fakeUser(id: 'p1')]),
      ),
      disponibilidadeRepositoryProvider.overrideWithValue(_DispFake(disp)),
      // APK / web estreita: o casco Fintech Clean (cards Easypay).
      if (easypay) isNarrowWebProvider.overrideWithValue(true),
      agendaControllerProvider.overrideWith(
        (ref) => AgendaController(ref, now: () => _agoraUtc),
      ),
    ],
  );
  // Deixa o load inicial (Future dos fakes) completar e a lista aparecer.
  await tester.pumpAndSettle();
  return ordens;
}

/// Sobe SÓ o sheet (sem controller/rede) — as regras dos steppers.
Future<List<(DateTime, int, int)>> _pumpSheet(
  WidgetTester tester,
  OrdemServico os, {
  List<Intervalo> ocupados = const [],
  Disponibilidade? disp,
}) async {
  final salvos = <(DateTime, int, int)>[];
  await pumpPainel(
    tester,
    AjusteOsSheet(
      os: os,
      dia: _hoje,
      hoje: _hoje,
      disp: disp,
      ocupados: ocupados,
      onSalvar: (dia, startMin, duracaoMin) =>
          salvos.add((dia, startMin, duracaoMin)),
    ),
    size: _celular,
    overrides: painelOverrides(user: painelUser()),
  );
  return salvos;
}

Future<void> _toque(WidgetTester tester, String chave) async {
  await tester.tap(find.byKey(ValueKey(chave)));
  await tester.pump();
}

String _faixaNaTela(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('ajuste-faixa'))).data!;

bool _habilitado(WidgetTester tester, String chave) =>
    tester.widget<IconButton>(find.byKey(ValueKey(chave))).onPressed != null;

void main() {
  group('sheet isolado — steppers de ±15 (D3)', () {
    testWidgets('início e duração andam de 15 em 15 min', (tester) async {
      await _pumpSheet(tester, _os('a', 'Ana', '14:00', duracaoMin: 60));
      expect(_faixaNaTela(tester), '14:00–15:00 · 1h');

      await _toque(tester, 'ajuste-inicio-mais'); // 14:15
      await _toque(tester, 'ajuste-duracao-menos'); // 45 min
      expect(_faixaNaTela(tester), '14:15–15:00 · 45 min');

      await _toque(tester, 'ajuste-inicio-menos'); // 14:00
      expect(_faixaNaTela(tester), '14:00–14:45 · 45 min');
    });

    testWidgets('duração não desce abaixo de 15 min', (tester) async {
      await _pumpSheet(tester, _os('a', 'Ana', '14:00', duracaoMin: 30));

      await _toque(tester, 'ajuste-duracao-menos'); // 15 min — o piso
      expect(_faixaNaTela(tester), '14:00–14:15 · 15 min');
      expect(
        _habilitado(tester, 'ajuste-duracao-menos'),
        isFalse,
        reason: 'no piso, o botão − nem existe como afordância',
      );
    });

    testWidgets('à meia-noite, adiantar não rola pro dia anterior (D7)', (
      tester,
    ) async {
      await _pumpSheet(tester, _os('a', 'Ana', '00:00', duracaoMin: 60));
      expect(_faixaNaTela(tester), '00:00–01:00 · 1h');
      expect(_habilitado(tester, 'ajuste-inicio-menos'), isFalse);
      expect(_habilitado(tester, 'ajuste-inicio-mais'), isTrue);
    });

    testWidgets('cancelar não salva nada', (tester) async {
      final salvos = await _pumpSheet(
        tester,
        _os('a', 'Ana', '14:00', duracaoMin: 60),
      );

      await _toque(tester, 'ajuste-inicio-mais');
      await tester.tap(find.text('Cancelar'));
      await tester.pump();

      expect(salvos, isEmpty);
    });

    testWidgets('salvar devolve dia + início + duração em minutos-BRT', (
      tester,
    ) async {
      final salvos = await _pumpSheet(
        tester,
        _os('a', 'Ana', '14:00', duracaoMin: 60),
      );

      await _toque(tester, 'ajuste-inicio-mais'); // 14:15
      await _toque(tester, 'ajuste-duracao-mais'); // 75 min
      await tester.tap(find.byKey(const ValueKey('ajuste-salvar')));
      await tester.pump();

      expect(salvos, [(_hoje, 14 * 60 + 15, 75)]);
    });

    testWidgets('OS antiga (sem duracao_min) abre na duração do PROFISSIONAL', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        _os('a', 'Ana', '09:00'),
        disp: fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          duracaoMin: 90,
        ),
      );
      expect(_faixaNaTela(tester), '09:00–10:30 · 1h30');
    });
  });

  group('aviso de sobreposição (D11) — avisa, nunca bloqueia', () {
    testWidgets('aparece quando a faixa escolhida colide, e Salvar continua ok', (
      tester,
    ) async {
      final salvos = await _pumpSheet(
        tester,
        _os('a', 'Ana', '08:00', duracaoMin: 60),
        // Bruno ocupa 09:00–10:00 (encostar não é sobrepor: half-open).
        ocupados: const [
          Intervalo(
            id: 'b',
            startMin: 9 * 60,
            endMin: 10 * 60,
            label: 'Bruno',
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey('ajuste-aviso-sobreposicao')),
        findsNothing,
        reason: '08:00–09:00 encosta em 09:00, não sobrepõe',
      );

      await _toque(tester, 'ajuste-inicio-mais'); // 08:15–09:15 → colide

      expect(
        find.byKey(const ValueKey('ajuste-aviso-sobreposicao')),
        findsOneWidget,
      );
      expect(find.textContaining('Sobrepõe OS de Bruno'), findsOneWidget);
      expect(find.textContaining('Pode salvar assim mesmo'), findsOneWidget);

      // Sobrepor é PERMITIDO: o botão continua vivo e grava.
      await tester.tap(find.byKey(const ValueKey('ajuste-salvar')));
      await tester.pump();
      expect(salvos, [(_hoje, 8 * 60 + 15, 60)]);
    });
  });

  group('tela a 390px — long-press no card (D3/D6)', () {
    testWidgets('long-press numa OS agendada abre o sheet', (tester) async {
      await _pumpAgenda(tester, [_os('a', 'Ana', '08:00', duracaoMin: 60)]);
      expect(find.text('Ana'), findsOneWidget);

      await tester.longPress(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Ajustar horário'), findsOneWidget);
      expect(_faixaNaTela(tester), '08:00–09:00 · 1h');
    });

    testWidgets('long-press numa OS atribuida abre o sheet', (tester) async {
      await _pumpAgenda(tester, [
        _os('a', 'Ana', '08:00', duracaoMin: 60, status: OSStatus.atribuida),
      ]);

      await tester.longPress(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Ajustar horário'), findsOneWidget);
    });

    testWidgets('long-press em concluida/cancelada/em_andamento NÃO abre (D6)', (
      tester,
    ) async {
      await _pumpAgenda(tester, [
        _os('a', 'Ana', '08:00', duracaoMin: 60), // controle: essa ajusta
        _os('c', 'Carla', '10:00', status: OSStatus.concluida),
        _os('d', 'Duda', '14:00', status: OSStatus.cancelada),
        _os('e', 'Elis', '16:00', status: OSStatus.emAndamento),
      ]);

      // Só a `agendada` tem a afordância de long-press (nem gesto, nem promessa).
      expect(find.byKey(const ValueKey('agenda-card-lp-a')), findsOneWidget);
      for (final id in ['c', 'd', 'e']) {
        expect(find.byKey(ValueKey('agenda-card-lp-$id')), findsNothing);
      }

      // E segurar o card travado não abre nada.
      for (final id in ['c', 'd', 'e']) {
        await tester.longPress(find.byKey(ValueKey('agenda-card-$id')));
        await tester.pumpAndSettle();
        expect(
          find.text('Ajustar horário'),
          findsNothing,
          reason: 'a OS $id não pode ser ajustada pela agenda',
        );
      }
    });

    testWidgets('long-press no 3º card da lista abre o sheet DAQUELA OS', (
      tester,
    ) async {
      // Prova que o ponteiro chega no card certo (e não no primeiro da lista) —
      // é o que dá valor ao teste do D6 acima, que espera "não abre".
      await _pumpAgenda(tester, [
        _os('a', 'Ana', '08:00', duracaoMin: 60),
        _os('b', 'Bruno', '10:00', duracaoMin: 60),
        _os('c', 'Carla', '14:00', duracaoMin: 30),
      ]);

      await tester.longPress(find.byKey(const ValueKey('agenda-card-c')));
      await tester.pumpAndSettle();

      expect(_faixaNaTela(tester), '14:00–14:30 · 30 min');
    });

    testWidgets('toque continua abrindo o DETALHE (o long-press não roubou)', (
      tester,
    ) async {
      await _pumpAgenda(tester, [_os('a', 'Ana', '08:00', duracaoMin: 60)]);

      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Ajustar horário'), findsNothing);
      expect(find.text('Data / Hora'), findsOneWidget); // diálogo de detalhe
    });

    testWidgets('web estreita clássica (card não-Easypay) também abre o sheet', (
      tester,
    ) async {
      await _pumpAgenda(
        tester,
        [_os('a', 'Ana', '08:00', duracaoMin: 60)],
        easypay: false,
        size: const Size(700, 900), // < 760 → listas de card, toolbar clássica
      );

      await tester.longPress(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Ajustar horário'), findsOneWidget);
      expect(_faixaNaTela(tester), '08:00–09:00 · 1h');
    });

    testWidgets('salvar persiste data_hora + duracao_min num ÚNICO PATCH', (
      tester,
    ) async {
      // Sem `duracao_min` no banco (OS antiga): salvar materializa o que o
      // usuário VIU no sheet (60 min, o padrão).
      final ordens = await _pumpAgenda(tester, [_os('a', 'Ana', '08:00')]);

      await tester.longPress(find.text('Ana'));
      await tester.pumpAndSettle();
      await _toque(tester, 'ajuste-inicio-mais'); // 08:15
      await _toque(tester, 'ajuste-duracao-mais'); // 75 min
      await tester.tap(find.byKey(const ValueKey('ajuste-salvar')));
      await tester.pumpAndSettle();

      expect(ordens.updateCount, 1, reason: 'um PATCH, não dois');
      expect(ordens.lastId, 'a');
      expect(ordens.lastBody, {
        'data_hora': _pb('08:15'),
        'duracao_min': 75,
      });
      // Sheet fechou e o card já mostra a faixa nova (otimista + confirmada).
      expect(find.text('Ajustar horário'), findsNothing);
      expect(find.textContaining('08:15–09:30'), findsOneWidget);
    });

    testWidgets('cancelar não gera PATCH nenhum', (tester) async {
      final ordens = await _pumpAgenda(tester, [
        _os('a', 'Ana', '08:00', duracaoMin: 60),
      ]);

      await tester.longPress(find.text('Ana'));
      await tester.pumpAndSettle();
      await _toque(tester, 'ajuste-inicio-mais');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(ordens.updateCount, 0);
      expect(find.textContaining('08:00–09:00'), findsOneWidget);
    });

    testWidgets('aviso de sobreposição sai da agenda já carregada (D11)', (
      tester,
    ) async {
      await _pumpAgenda(tester, [
        _os('a', 'Ana', '08:00', duracaoMin: 60),
        _os('b', 'Bruno', '09:00', duracaoMin: 60), // ocupa 09:00–10:00
        _os('c', 'Carla', '08:30', duracaoMin: 60, status: OSStatus.cancelada),
      ]);

      await tester.longPress(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ajuste-aviso-sobreposicao')),
        findsNothing,
        reason: 'a cancelada de Carla (08:30) NÃO conta como ocupação',
      );

      await _toque(tester, 'ajuste-inicio-mais'); // 08:15–09:15 → pega o Bruno
      expect(find.textContaining('Sobrepõe OS de Bruno'), findsOneWidget);
    });
  });
}
