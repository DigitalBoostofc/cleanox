/// meus_servicos_realtime_test.dart — Reconciliação realtime da lista de serviços.
///
/// Cobre as zonas cegas do controller (finding HIGH):
///  - CREATE reentregue por id NÃO duplica o card,
///  - UPDATE de OS ausente (mas da janela do profissional) APARECE,
///  - DELETE remove,
///  - reagendamento (novo data_hora) RE-BUCKETIZA entre hoje/próximas/atrasadas,
///  - lost-update: evento realtime durante um refresh em voo não é sobrescrito
///    por dados mais antigos do fetch; OS concluída não "ressuscita".
library;

import 'dart:async';

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/meus_servicos/meus_servicos_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);

final _bounds = getBrtDayBounds();
final _todayVal = _bounds.todayStart; // >= todayStart && < tomorrowStart
final _upcomingVal = _bounds.tomorrowStart; // >= tomorrowStart
const _pastVal = '2000-01-01 00:00:00'; // < todayStart

OrdemServico _os(
  String id, {
  required String dataHora,
  OSStatus status = OSStatus.atribuida,
  String prof = 'p1',
}) => OrdemServico(
  id: id,
  nomeCurto: 'Cliente $id',
  status: status,
  profissional: prof,
  dataHora: dataHora,
);

OrdemServicoEvent _ev(OSEventAction a, OrdemServico rec) =>
    OrdemServicoEvent(action: a, record: rec);

ProviderContainer _container(FakeOrdensRepository repo) {
  final c = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      ordensRepositoryProvider.overrideWithValue(repo),
      ordensRealtimeProvider.overrideWith((ref) => repo.subscribe()),
    ],
  );
  addTearDown(c.dispose);
  c.listen(meusServicosProvider, (_, __) {});
  return c;
}

/// Deixa microtasks/stream do StreamProvider drenarem.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

MeusServicosState _read(ProviderContainer c) => c.read(meusServicosProvider);

void main() {
  test('CREATE reentregue por id não duplica o card', () async {
    final repo = FakeOrdensRepository();
    final c = _container(repo);
    await _settle();

    final os = _os('a', dataHora: _todayVal);
    repo.emit(_ev(OSEventAction.create, os));
    await _settle();
    repo.emit(_ev(OSEventAction.create, os)); // reentrega do mesmo CREATE
    await _settle();

    final s = _read(c);
    expect(s.today.where((o) => o.id == 'a'), hasLength(1));
  });

  test('UPDATE de OS ausente na lista (mas da janela) aparece', () async {
    final repo = FakeOrdensRepository();
    final c = _container(repo);
    await _settle();

    repo.emit(_ev(OSEventAction.update, _os('b', dataHora: _todayVal)));
    await _settle();

    expect(_read(c).today.map((o) => o.id), contains('b'));
  });

  test('DELETE remove o card', () async {
    final repo = FakeOrdensRepository();
    final c = _container(repo);
    await _settle();

    final os = _os('a', dataHora: _todayVal);
    repo.emit(_ev(OSEventAction.create, os));
    await _settle();
    expect(_read(c).today.map((o) => o.id), contains('a'));

    repo.emit(_ev(OSEventAction.delete, os));
    await _settle();
    expect(_read(c).today.map((o) => o.id), isNot(contains('a')));
  });

  test('reagendamento re-bucketiza (hoje → próximas)', () async {
    final repo = FakeOrdensRepository();
    final c = _container(repo);
    await _settle();

    repo.emit(_ev(OSEventAction.create, _os('a', dataHora: _todayVal)));
    await _settle();
    expect(_read(c).today.map((o) => o.id), contains('a'));

    // Mesmo id, novo data_hora (amanhã) → deve mover de today p/ upcoming.
    repo.emit(_ev(OSEventAction.update, _os('a', dataHora: _upcomingVal)));
    await _settle();

    final s = _read(c);
    expect(s.today.map((o) => o.id), isNot(contains('a')));
    expect(s.upcoming.map((o) => o.id), contains('a'));
    expect(s.upcoming.where((o) => o.id == 'a'), hasLength(1));
  });

  test('OS reatribuída a outro profissional some da lista', () async {
    final repo = FakeOrdensRepository();
    final c = _container(repo);
    await _settle();

    repo.emit(_ev(OSEventAction.create, _os('a', dataHora: _todayVal)));
    await _settle();
    expect(_read(c).today.map((o) => o.id), contains('a'));

    // UPDATE reatribuindo para outro prof → remove das minhas listas.
    repo.emit(
      _ev(OSEventAction.update, _os('a', dataHora: _todayVal, prof: 'p2')),
    );
    await _settle();
    expect(_read(c).today.map((o) => o.id), isNot(contains('a')));
  });

  test(
    'lost-update: realtime durante refresh vence dados antigos do fetch',
    () async {
      final repo = FakeOrdensRepository();
      final c = _container(repo);
      await _settle();

      // Fetch em voo devolve 'a' ANTIGA em "hoje" (call index 0).
      repo.listCallCount = 0;
      repo.listByIndex = (i) =>
          i == 0 ? [_os('a', dataHora: _todayVal)] : const [];
      final gate = Completer<void>();
      repo.listGate = gate;

      // Dispara o refresh (não aguarda) — fica preso no gate.
      // ignore: discarded_futures
      final refreshFut = c.read(meusServicosProvider.notifier).refresh();

      // Durante o refresh, chega um UPDATE mais novo: 'a' reagendada p/ amanhã.
      repo.emit(_ev(OSEventAction.update, _os('a', dataHora: _upcomingVal)));
      await _settle();

      // Libera o fetch (dados antigos) e deixa reconciliar.
      gate.complete();
      await refreshFut;
      await _settle();

      final s = _read(c);
      // O realtime (amanhã) tem que prevalecer sobre o fetch (hoje).
      expect(s.today.map((o) => o.id), isNot(contains('a')));
      expect(s.upcoming.map((o) => o.id), contains('a'));
    },
  );

  test('OS concluída durante refresh não ressuscita', () async {
    final repo = FakeOrdensRepository();
    final c = _container(repo);
    await _settle();

    // Fetch em voo devolve 'a' AINDA em aberto em "atrasadas" (call index 2).
    repo.listCallCount = 0;
    repo.listByIndex = (i) => i == 2
        ? [_os('a', dataHora: _pastVal, status: OSStatus.emAndamento)]
        : const [];
    final gate = Completer<void>();
    repo.listGate = gate;

    // ignore: discarded_futures
    final refreshFut = c.read(meusServicosProvider.notifier).refresh();

    // Durante o refresh, 'a' é concluída (passado + concluída → fora das janelas).
    repo.emit(
      _ev(
        OSEventAction.update,
        _os('a', dataHora: _pastVal, status: OSStatus.concluida),
      ),
    );
    await _settle();

    gate.complete();
    await refreshFut;
    await _settle();

    final s = _read(c);
    expect(s.pastOpen.map((o) => o.id), isNot(contains('a')));
    expect(s.today.map((o) => o.id), isNot(contains('a')));
    expect(s.upcoming.map((o) => o.id), isNot(contains('a')));
  });
}
