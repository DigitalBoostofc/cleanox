/// meus_servicos_controller.dart — Estado + ações da lista "Meus serviços".
///
/// Espelha a lógica de `MeusServicos.tsx`: três janelas (hoje / próximas /
/// atrasadas em aberto), dedupe fetch×realtime por geração + id, e as ações do
/// card (iniciar, avisar-a-caminho, registrar pagamento, concluir com checagem de
/// checklist obrigatório). Consome só o contrato congelado (`OrdensRepository`,
/// `WhatsAppRepository`) — nada de acesso direto ao PocketBase aqui.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/repositories/ordens_repository.dart';
import '../../core/repositories/repo_types.dart';
import '../../core/repositories/whatsapp_repository.dart';
import '../data/prof_filters.dart';
import '../data/prof_providers.dart';
import '../../core/auth/auth_providers.dart';

/// Estado imutável da tela de serviços.
class MeusServicosState {
  const MeusServicosState({
    this.today = const [],
    this.upcoming = const [],
    this.pastOpen = const [],
    this.loading = false,
    this.error,
    this.offline = false,
    this.lastLoadedAt,
  });

  final List<OrdemServico> today;
  final List<OrdemServico> upcoming;
  final List<OrdemServico> pastOpen;
  final bool loading;
  final String? error;
  final bool offline;
  final DateTime? lastLoadedAt;

  bool get isEmpty => today.isEmpty && upcoming.isEmpty && pastOpen.isEmpty;

  MeusServicosState copyWith({
    List<OrdemServico>? today,
    List<OrdemServico>? upcoming,
    List<OrdemServico>? pastOpen,
    bool? loading,
    Object? error = _sentinel,
    bool? offline,
    DateTime? lastLoadedAt,
  }) {
    return MeusServicosState(
      today: today ?? this.today,
      upcoming: upcoming ?? this.upcoming,
      pastOpen: pastOpen ?? this.pastOpen,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      offline: offline ?? this.offline,
      lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
    );
  }

  static const Object _sentinel = Object();
}

/// Resultado de "tentar concluir": ou concluiu, ou precisa abrir o checklist.
enum ConcluirResultado { concluida, checklistPendente }

/// Seção da lista a que uma OS pertence (espelha os 3 fetches do refresh).
/// `none` = fora de todas as janelas (não deve aparecer para o profissional).
enum _Bucket { today, upcoming, pastOpen, none }

class MeusServicosController extends AutoDisposeNotifier<MeusServicosState> {
  int _gen = 0;
  String? _profId;

  /// Enquanto um refresh está em voo, os eventos realtime são bufferizados para
  /// serem REAPLICADOS após o fetch — assim dados possivelmente mais antigos do
  /// fetch não sobrescrevem um update realtime mais novo (anti lost-update).
  bool _refreshInFlight = false;
  final List<OrdemServicoEvent> _bufferedDuringRefresh = [];

  OrdensRepository get _repo => ref.read(ordensRepositoryProvider);
  WhatsAppRepository get _whats => ref.read(whatsappRepositoryProvider);

  @override
  MeusServicosState build() {
    _profId = ref.watch(currentProfIdProvider);

    // Realtime: aplica cada evento sobre as listas (dedupe por id).
    ref.listen(ordensRealtimeProvider, (_, next) {
      final ev = next.valueOrNull;
      if (ev != null) _onRealtime(ev);
    });

    final id = _profId;
    if (id != null) {
      // ignore: discarded_futures
      Future.microtask(refresh);
      return const MeusServicosState(loading: true);
    }
    return const MeusServicosState();
  }

  /// Recarrega as três janelas (hoje / próximas / atrasadas em aberto).
  Future<void> refresh() async {
    final id = _profId;
    if (id == null) return;
    final gen = ++_gen;
    _bufferedDuringRefresh.clear();
    _refreshInFlight = true;
    state = state.copyWith(loading: true, error: null, offline: false);

    final bounds = getBrtDayBounds();
    try {
      // A-04: filtros via prof_filters (escaping pbStringLiteral, nunca
      // interpolação crua — mesma convenção do painel_filters).
      final results = await Future.wait([
        _repo.list(
          perPage: 50,
          sort: 'data_hora',
          filter: profOrdensHojeFilter(id, bounds),
        ),
        _repo.list(
          perPage: 20,
          sort: 'data_hora',
          filter: profOrdensProximasFilter(id, bounds),
        ),
        _repo.list(
          perPage: 20,
          sort: 'data_hora',
          filter: profOrdensAtrasadasAbertasFilter(id, bounds),
        ),
      ]);
      if (gen != _gen) return;
      state = state.copyWith(
        today: results[0].items,
        upcoming: results[1].items,
        pastOpen: results[2].items,
        loading: false,
        error: null,
        offline: false,
        lastLoadedAt: DateTime.now(),
      );
      // Reaplica os eventos realtime chegados durante o fetch — o realtime
      // (estado mais novo do servidor) vence os dados do fetch; uma OS
      // concluída/deletada nesse meio-tempo não "ressuscita".
      for (final ev in _bufferedDuringRefresh) {
        _applyEvent(ev);
      }
    } catch (err) {
      if (gen != _gen) return;
      final info = describeOSError(err);
      state = state.copyWith(
        loading: false,
        error: info.message,
        offline: info.isOffline,
      );
    } finally {
      if (gen == _gen) {
        _refreshInFlight = false;
        _bufferedDuringRefresh.clear();
      }
    }
  }

  // ── realtime ────────────────────────────────────────────────────────────

  /// Ponto de entrada dos eventos realtime: aplica ao vivo e, se um refresh está
  /// em voo, bufferiza para reaplicar depois do fetch (anti lost-update).
  void _onRealtime(OrdemServicoEvent ev) {
    if (_refreshInFlight) _bufferedDuringRefresh.add(ev);
    _applyEvent(ev);
  }

  void _applyEvent(OrdemServicoEvent ev) {
    final rec = ev.record;
    if (rec == null) return;
    switch (ev.action) {
      // CREATE e UPDATE convergem no mesmo upsert idempotente (dedupe por id):
      // um CREATE reentregue ou um UPDATE de OS ausente não duplica nem perde.
      case OSEventAction.create:
      case OSEventAction.update:
        _upsert(rec);
      case OSEventAction.delete:
        _removeById(rec.id);
      case OSEventAction.unknown:
        break;
    }
  }

  /// Bucket ao qual a OS pertence AGORA — espelha os 3 filtros do [refresh].
  /// `none` = não é do profissional, ou é passada e já encerrada (fora das janelas).
  _Bucket _bucketFor(OrdemServico rec) {
    if (rec.profissional != _profId) return _Bucket.none;
    final bounds = getBrtDayBounds();
    final dh = rec.dataHora;
    if (dh.isEmpty) return _Bucket.none;
    if (dh.compareTo(bounds.todayStart) >= 0 &&
        dh.compareTo(bounds.tomorrowStart) < 0) {
      return _Bucket.today;
    }
    if (dh.compareTo(bounds.tomorrowStart) >= 0) return _Bucket.upcoming;
    // Passado: só "em aberto" (atribuída/em andamento) entra em pastOpen.
    if (rec.status == OSStatus.atribuida ||
        rec.status == OSStatus.emAndamento) {
      return _Bucket.pastOpen;
    }
    return _Bucket.none;
  }

  /// Insere/atualiza a OS na seção correta, deduplicando por id e re-bucketizando
  /// (reagendamento/mudança de status movem o card entre hoje/próximas/atrasadas).
  void _upsert(OrdemServico rec) {
    final bucket = _bucketFor(rec);
    // Dedupe por id: remove qualquer cópia anterior de TODAS as listas.
    var today = state.today.where((o) => o.id != rec.id).toList();
    var upcoming = state.upcoming.where((o) => o.id != rec.id).toList();
    var pastOpen = state.pastOpen.where((o) => o.id != rec.id).toList();
    int cmp(OrdemServico a, OrdemServico b) => a.dataHora.compareTo(b.dataHora);
    switch (bucket) {
      case _Bucket.today:
        today = [...today, rec]..sort(cmp);
      case _Bucket.upcoming:
        upcoming = [...upcoming, rec]..sort(cmp);
      case _Bucket.pastOpen:
        pastOpen = [...pastOpen, rec]..sort(cmp);
      case _Bucket.none:
        break; // encerrada no passado / reatribuída a outro → só remove
    }
    state = state.copyWith(
      today: today,
      upcoming: upcoming,
      pastOpen: pastOpen,
    );
  }

  void _removeById(String id) {
    state = state.copyWith(
      today: state.today.where((o) => o.id != id).toList(),
      upcoming: state.upcoming.where((o) => o.id != id).toList(),
      pastOpen: state.pastOpen.where((o) => o.id != id).toList(),
    );
  }

  // ── ações ────────────────────────────────────────────────────────────────

  /// Inicia o serviço (atribuida → em_andamento). Libera o endereço.
  Future<void> iniciar(OrdemServico os) async {
    final updated = await _repo.updateStatus(os.id, OSStatus.emAndamento);
    _upsert(updated);
  }

  /// Avisa o cliente "a caminho" (rota custom). Marca `aviso_a_caminho_em`.
  Future<AvisoResult> avisarACaminho(OrdemServico os) async {
    final res = await _whats.avisarACaminho(os.id);
    if (res.ok) _upsert(os.copyWith(avisoACaminhoEm: res.sentAt));
    return res;
  }

  /// Registra pagamento (valor + forma) — pré-requisito para concluir.
  Future<void> registrarPagamento(
    OrdemServico os, {
    required double valor,
    required FormaPagamento forma,
  }) async {
    final updated = await _repo.patchExec(
      os.id,
      OSExecPatch(valorPago: valor, formaPagamento: forma),
    );
    _upsert(updated);
  }

  /// Conclui a OS. Antes, valida checklist obrigatório (via getExec). Se houver
  /// item obrigatório pendente, devolve [ConcluirResultado.checklistPendente]
  /// (a tela abre a execução com banner). O pagamento é pré-requisito e é
  /// checado pela UI + servidor.
  ///
  /// A-03: se o getExec falhar (offline/403), NÃO conclui às cegas — o erro
  /// propaga e a tela mostra o toast (o usuário tenta de novo). O servidor
  /// também impõe checklist obrigatório e pagamento na conclusão
  /// (`guardOrdemUpdateRequest`/`assertPaymentIfConcluida` em
  /// cleanos/pb/pb_hooks/os_logic.js); esta checagem client-side só antecipa
  /// o feedback (banner na tela de execução em vez de 400 do servidor).
  Future<ConcluirResultado> concluir(OrdemServico os) async {
    final exec = await _repo.getExec(os.id);
    if (exec.checklistExec.isNotEmpty && exec.temItensObrigatoriosPendentes) {
      return ConcluirResultado.checklistPendente;
    }
    final updated = await _repo.updateStatus(os.id, OSStatus.concluida);
    _upsert(updated);
    return ConcluirResultado.concluida;
  }
}

final meusServicosProvider =
    AutoDisposeNotifierProvider<MeusServicosController, MeusServicosState>(
      MeusServicosController.new,
    );
