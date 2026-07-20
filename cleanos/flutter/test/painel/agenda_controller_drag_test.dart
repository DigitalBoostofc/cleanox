/// agenda_controller_drag_test.dart — A CORRIDA do drop (Fase 2, spec R-A3/§11).
///
/// Três travas, uma por classe de bug real:
/// 1. **token de sequência no `load`** — a resposta de um load ANTIGO não pode
///    sobrescrever o estado mais novo (trocar de semana rápido, ou soltar um
///    bloco enquanto a janela recarrega);
/// 2. **`_pendingDrag`** — a OS com PATCH em voo sobrevive a um `load()`
///    concorrente (senão o bloco PULA de volta pro horário antigo até o servidor
///    responder) e não pode ser arrastada de novo;
/// 3. **rollback cirúrgico** — a falha desfaz SÓ aquela OS; o que outro admin
///    mudou no meio do voo (outra OS) permanece.
///
/// Cobre também o refresh-on-focus (R-M7: recalcular "hoje") e a disponibilidade
/// por profissional (D9 — a pendência aberta da Fase 1).
library;

import 'dart:async';

import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/agenda/agenda_controller.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda3.dart' show FakeUsuariosFull, fakeDisponibilidade, fakeUser;

/// Hoje (fixo) do relógio injetado no controller — nada de `DateTime.now()`.
final DateTime _hojeUtc = DateTime.utc(2026, 7, 13, 12); // 09:00 BRT
final DateTime _hoje = DateTime(2026, 7, 13);

String _pb(String hhmm, {DateTime? dia}) {
  final d = dia ?? _hoje;
  String p(int n) => n.toString().padLeft(2, '0');
  return localInputToPBDate('${d.year}-${p(d.month)}-${p(d.day)}T$hhmm');
}

OrdemServico _os(String id, String hhmm, {int? duracaoMin, String? prof}) =>
    OrdemServico(
      id: id,
      nomeCurto: id.toUpperCase(),
      dataHora: _pb(hhmm),
      duracaoMin: duracaoMin,
      profissional: prof,
      status: OSStatus.agendada,
    );

/// `OrdensRepository` com as respostas SEGURADAS por completers — é o único jeito
/// de reproduzir a corrida (resposta velha chegando depois da nova).
class _OrdensGated implements OrdensRepository {
  _OrdensGated(this.inicial);

  final List<OrdemServico> inicial;

  /// Um completer por chamada de `list` (a partir da 1ª pós-construtor): o teste
  /// escolhe a ORDEM em que elas respondem.
  final Map<int, Completer<List<OrdemServico>>> filaList = {};
  int listCount = 0;

  Completer<OrdemServico>? gateUpdate;
  int updateCount = 0;
  Map<String, dynamic>? lastUpdateBody;
  String? lastUpdateId;

  /// `list` #0 (a do construtor) responde na hora; as demais entram na fila.
  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    final n = listCount++;
    final itens = n == 0
        ? inicial
        : await (filaList[n] = Completer<List<OrdemServico>>()).future;
    return PageResult<OrdemServico>(
      items: itens,
      page: 1,
      perPage: perPage,
      totalItems: itens.length,
      totalPages: 1,
    );
  }

  /// Responde a n-ésima chamada de `list` (1 = a 1ª depois do construtor).
  void responderList(int n, List<OrdemServico> itens) =>
      filaList[n]!.complete(itens);

  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) {
    updateCount++;
    lastUpdateId = osId;
    lastUpdateBody = data;
    gateUpdate = Completer<OrdemServico>();
    return gateUpdate!.future;
  }

  Never _naoUsado() => throw UnimplementedError('não usado neste teste');
  @override
  Future<OrdemServico> getExec(String osId) => _naoUsado();
  @override
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch) => _naoUsado();
  @override
  Future<OrdemServico> updateStatus(String osId, OSStatus novo) => _naoUsado();
  @override
  Future<OrdemServico> cancelar(String osId, {required String motivo}) =>
      _naoUsado();
  
  @override
  Future<OrdemServico> reabrir(String osId) => _naoUsado();
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

/// Sobe o controller com os fakes e um RELÓGIO controlado pelo teste.
({ProviderContainer container, _OrdensGated ordens, AgendaController ctrl})
_montar(
  List<OrdemServico> seed, {
  List<Disponibilidade> disp = const [],
  DateTime Function()? now,
}) {
  final ordens = _OrdensGated(seed);
  final container = ProviderContainer(
    overrides: [
      ordensRepositoryProvider.overrideWithValue(ordens),
      usuariosRepositoryProvider.overrideWithValue(
        FakeUsuariosFull(seed: [fakeUser(id: 'p1')]),
      ),
      disponibilidadeRepositoryProvider.overrideWithValue(_DispFake(disp)),
      agendaControllerProvider.overrideWith(
        (ref) => AgendaController(ref, now: now ?? () => _hojeUtc),
      ),
    ],
  );
  addTearDown(container.dispose);
  // `listen` mantém o autoDispose vivo durante o teste.
  container.listen<AgendaState>(agendaControllerProvider, (_, _) {});
  return (
    container: container,
    ordens: ordens,
    ctrl: container.read(agendaControllerProvider.notifier),
  );
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

AgendaState _estado(ProviderContainer c) => c.read(agendaControllerProvider);

OrdemServico _acha(AgendaState s, String id) =>
    s.osList.firstWhere((o) => o.id == id);

void main() {
  test('load inicial popula a lista e a disponibilidade por profissional', () async {
    final m = _montar(
      [_os('a', '08:00', prof: 'p1')],
      disp: [fakeDisponibilidade(id: 'd1', profissional: 'p1', duracaoMin: 90)],
    );
    await _tick();

    final s = _estado(m.container);
    expect(s.loading, isFalse);
    expect(s.osList, hasLength(1));
    // D9: OS sem duração própria cai na duração do PROFISSIONAL (90), não em 60.
    expect(s.dispByProf['p1']?.duracaoMin, 90);
    expect(duracaoEfetivaMin(_acha(s, 'a'), s.dispByProf['p1']), 90);
  });

  test('drop aplica o RECORD CONFIRMADO pelo servidor (sem recarregar a janela)',
      () async {
    final m = _montar([_os('a', '08:00')]);
    await _tick();
    final listsAntes = m.ordens.listCount;

    final drop = m.ctrl.moverOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 9 * 60,
    );

    // Otimista: o bloco já está às 09:00 e a OS está "em voo".
    expect(_acha(_estado(m.container), 'a').dataHora, _pb('09:00'));
    expect(_estado(m.container).pendentes, {'a'});
    expect(m.ordens.lastUpdateBody, {'data_hora': _pb('09:00')});

    // O servidor confirma com o SEU horário canônico (09:00 + segundos).
    m.ordens.gateUpdate!.complete(
      _os('a', '08:00').copyWith(dataHora: _pb('09:00'), duracaoMin: 60),
    );
    await drop;

    final s = _estado(m.container);
    expect(_acha(s, 'a').dataHora, _pb('09:00'));
    expect(_acha(s, 'a').duracaoMin, 60, reason: 'veio do record do servidor');
    expect(s.pendentes, isEmpty);
    expect(m.ordens.listCount, listsAntes, reason: 'drop NÃO chama load()');
  });

  test('redimensionar manda só duracao_min', () async {
    final m = _montar([_os('a', '08:00', duracaoMin: 60)]);
    await _tick();

    final drop = m.ctrl.redimensionarOs(_acha(_estado(m.container), 'a'), 120);
    expect(m.ordens.lastUpdateBody, {'duracao_min': 120});
    expect(_acha(_estado(m.container), 'a').duracaoMin, 120); // otimista

    m.ordens.gateUpdate!.complete(_os('a', '08:00', duracaoMin: 120));
    await drop;
    expect(_acha(_estado(m.container), 'a').duracaoMin, 120);
    expect(_estado(m.container).pendentes, isEmpty);
  });

  test('drop INERTE (mesmo horário) não gasta PATCH', () async {
    final m = _montar([_os('a', '08:00', duracaoMin: 60)]);
    await _tick();
    final os = _acha(_estado(m.container), 'a');

    await m.ctrl.moverOs(os, dia: _hoje, startMin: 8 * 60);
    await m.ctrl.redimensionarOs(os, 60);

    expect(m.ordens.updateCount, 0);
  });

  test('resposta VELHA de load não sobrescreve o estado mais novo', () async {
    final m = _montar([_os('a', '08:00')]);
    await _tick();

    m.ctrl.load(); // list #1 (vai responder por último — é a velha)
    await _tick();
    m.ctrl.load(); // list #2 (a nova)
    await _tick();

    // A NOVA responde primeiro.
    m.ordens.responderList(2, [_os('novo', '15:00')]);
    await _tick();
    expect(_estado(m.container).osList.single.id, 'novo');

    // A VELHA chega atrasada — e deve ser DESCARTADA.
    m.ordens.responderList(1, [_os('velho', '07:00')]);
    await _tick();

    final s = _estado(m.container);
    expect(s.osList.single.id, 'novo', reason: 'seq antiga não pode clobberar');
    expect(s.loading, isFalse);
  });

  test('load concorrente PRESERVA a OS com drop em voo', () async {
    final m = _montar([_os('a', '08:00'), _os('b', '10:00')]);
    await _tick();

    // Drop de A (em voo, PATCH segurado).
    final drop = m.ctrl.moverOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 9 * 60,
    );
    expect(_estado(m.container).pendentes, {'a'});

    // Um load concorrente traz o horário ANTIGO de A (o servidor ainda não
    // gravou) e uma mudança de B feita por outro admin.
    m.ctrl.load();
    await _tick();
    m.ordens.responderList(1, [_os('a', '08:00'), _os('b', '11:00')]);
    await _tick();

    var s = _estado(m.container);
    expect(
      _acha(s, 'a').dataHora,
      _pb('09:00'),
      reason: 'a OS em voo mantém a versão otimista — o bloco não pula de volta',
    );
    expect(_acha(s, 'b').dataHora, _pb('11:00'), reason: 'B veio do servidor');

    // Servidor confirma A.
    m.ordens.gateUpdate!.complete(_os('a', '09:00'));
    await drop;
    s = _estado(m.container);
    expect(_acha(s, 'a').dataHora, _pb('09:00'));
    expect(s.pendentes, isEmpty);
  });

  test('falha no drop: rollback restaura SÓ a OS afetada', () async {
    final m = _montar([_os('a', '08:00'), _os('b', '10:00')]);
    await _tick();

    final drop = m.ctrl.moverOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 9 * 60,
    );

    // No meio do voo, um load traz B mudado por outro admin.
    m.ctrl.load();
    await _tick();
    m.ordens.responderList(1, [_os('a', '08:00'), _os('b', '11:00')]);
    await _tick();

    // O PATCH falha.
    m.ordens.gateUpdate!.completeError(Exception('500'));
    await drop;

    final s = _estado(m.container);
    expect(_acha(s, 'a').dataHora, _pb('08:00'), reason: 'A volta pro lugar');
    expect(
      _acha(s, 'b').dataHora,
      _pb('11:00'),
      reason: 'o rollback NÃO pode ressuscitar a lista antiga inteira',
    );
    expect(s.pendentes, isEmpty);
    expect(s.dragError, isNotNull);
    expect(s.error, isNull, reason: 'falha de drop não vira tela de erro');

    m.ctrl.limparDragError();
    expect(_estado(m.container).dragError, isNull);
  });

  test('2º drag da MESMA OS enquanto o 1º está em voo é ignorado', () async {
    final m = _montar([_os('a', '08:00')]);
    await _tick();
    final os = _acha(_estado(m.container), 'a');

    final drop = m.ctrl.moverOs(os, dia: _hoje, startMin: 9 * 60);
    await m.ctrl.moverOs(os, dia: _hoje, startMin: 10 * 60); // ignorado
    expect(m.ordens.updateCount, 1);
    expect(_acha(_estado(m.container), 'a').dataHora, _pb('09:00'));

    m.ordens.gateUpdate!.complete(_os('a', '09:00'));
    await drop;
    expect(_estado(m.container).pendentes, isEmpty);
  });

  test('ajustarOs (sheet do APK): início + duração num ÚNICO PATCH', () async {
    final m = _montar([_os('a', '08:00', duracaoMin: 60)]);
    await _tick();

    final salvar = m.ctrl.ajustarOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 8 * 60 + 15,
      duracaoMin: 75,
    );

    expect(m.ordens.updateCount, 1, reason: 'um PATCH, não um por campo');
    expect(m.ordens.lastUpdateBody, {
      'data_hora': _pb('08:15'),
      'duracao_min': 75,
    });
    // Otimista na tela, e a OS fica "em voo" (não aceita outro ajuste).
    expect(_acha(_estado(m.container), 'a').dataHora, _pb('08:15'));
    expect(_estado(m.container).pendentes, {'a'});

    m.ordens.gateUpdate!.complete(_os('a', '08:15', duracaoMin: 75));
    await salvar;
    expect(_estado(m.container).pendentes, isEmpty);
  });

  test('ajustarOs manda SÓ o campo que mudou', () async {
    final m = _montar([_os('a', '08:00', duracaoMin: 60)]);
    await _tick();
    final os = _acha(_estado(m.container), 'a');

    m.ctrl.ajustarOs(os, dia: _hoje, startMin: 8 * 60, duracaoMin: 90);
    expect(m.ordens.lastUpdateBody, {'duracao_min': 90});
    m.ordens.gateUpdate!.complete(_os('a', '08:00', duracaoMin: 90));
    await _tick();

    m.ctrl.ajustarOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 9 * 60,
      duracaoMin: 90,
    );
    expect(m.ordens.lastUpdateBody, {'data_hora': _pb('09:00')});
  });

  test('ajustarOs sem mudança nenhuma não gasta PATCH', () async {
    final m = _montar([_os('a', '08:00', duracaoMin: 60)]);
    await _tick();

    await m.ctrl.ajustarOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 8 * 60,
      duracaoMin: 60,
    );

    expect(m.ordens.updateCount, 0);
  });

  test('ajustarOs falhou: rollback devolve horário E duração', () async {
    final m = _montar([_os('a', '08:00', duracaoMin: 60)]);
    await _tick();

    final salvar = m.ctrl.ajustarOs(
      _acha(_estado(m.container), 'a'),
      dia: _hoje,
      startMin: 10 * 60,
      duracaoMin: 30,
    );
    m.ordens.gateUpdate!.completeError(Exception('500'));
    await salvar;

    final s = _estado(m.container);
    expect(_acha(s, 'a').dataHora, _pb('08:00'));
    expect(_acha(s, 'a').duracaoMin, 60);
    expect(s.dragError, isNotNull);
    expect(s.pendentes, isEmpty);
  });

  test('refresh-on-focus recalcula HOJE e leva a âncora junto (R-M7)', () async {
    var agora = _hojeUtc;
    final m = _montar([_os('a', '08:00')], now: () => agora);
    await _tick();
    expect(_estado(m.container).hoje, _hoje);
    expect(_estado(m.container).anchor, _hoje);

    // A aba ficou aberta e virou o dia.
    agora = DateTime.utc(2026, 7, 14, 12);
    m.ctrl.refreshOnFocus();
    await _tick();

    final s = _estado(m.container);
    expect(s.hoje, DateTime(2026, 7, 14));
    expect(s.anchor, DateTime(2026, 7, 14), reason: 'âncora grudada em "hoje"');
    expect(m.ordens.listCount, greaterThan(1), reason: 'recarrega a janela');

    m.ordens.responderList(1, [_os('a', '08:00')]);
    await _tick();
    expect(_estado(m.container).loading, isFalse);
  });

  test('refresh-on-focus não arrasta uma âncora que o usuário moveu', () async {
    var agora = _hojeUtc;
    final m = _montar([_os('a', '08:00')], now: () => agora);
    await _tick();

    // Usuário navegou para outra semana.
    m.ctrl.setWeekWindowStart(DateTime(2026, 8, 3), forceLoad: true);
    await _tick();
    m.ordens.responderList(1, const []);
    await _tick();

    agora = DateTime.utc(2026, 7, 14, 12);
    m.ctrl.refreshOnFocus();
    await _tick();

    final s = _estado(m.container);
    expect(s.hoje, DateTime(2026, 7, 14), reason: '"hoje" ainda é recalculado');
    expect(s.anchor, DateTime(2026, 8, 3), reason: 'mas a âncora fica onde está');
  });
}
