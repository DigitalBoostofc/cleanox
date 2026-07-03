/// whatsapp_controller.dart — Estado/dados da seção WhatsApp admin (Onda 5).
///
/// Dois controllers independentes (fáceis de testar isoladamente, sem timers):
///   • [WhatsAppConnController] — status/conexão UAZAPI (status/connect/disconnect
///     + [refreshStatus] silencioso p/ o polling dirigido pela tela);
///   • [WhatsAppTemplatesController] — editor dos 7 templates (`/whatsapp/config`).
///
/// A INTERFACE de conexão é a congelada do core (`WhatsAppRepository`); o backend
/// responde com `status`/`qrcode`/`paircode`, já mapeados para `WhatsAppStatus`
/// pela impl PB (`PbPainelWhatsAppRepository`). Os templates ficam fora do core
/// (contrato do Painel, `WhatsAppConfigRepository`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/errors/os_error.dart';
import '../data/painel_providers.dart';
import '../data/whatsapp_config_repository.dart';

/// Mensagem amigável de erro de rota custom: prioriza o corpo `{error}` (409 do
/// WhatsApp desconectado), depois `{message}`, e cai no [describeOSError] do core.
String _waError(Object err) {
  if (err is ClientException) {
    if (err.statusCode == 0) return 'Sem conexão com o servidor.';
    final data = err.response;
    final e = data['error'];
    if (e is String && e.trim().isNotEmpty) return e.trim();
    final m = data['message'];
    if (m is String && m.trim().isNotEmpty && !_generico(m)) return m.trim();
    return 'Não foi possível falar com o WhatsApp. Tente novamente.';
  }
  return describeOSError(err).message;
}

bool _generico(String m) => m.toLowerCase().contains('something went wrong');

/* ─────────────────────────── Conexão / status ─────────────────────────── */

class WhatsAppConnState {
  const WhatsAppConnState({
    this.loading = true,
    this.actionLoading = false,
    this.connected = false,
    this.qrcode,
    this.paircode,
    this.profileName,
    this.error,
  });

  /// Carregamento INICIAL do status (spinner de tela).
  final bool loading;

  /// Ação em curso (connect/disconnect) — desabilita os botões.
  final bool actionLoading;

  final bool connected;
  final String? qrcode;
  final String? paircode;

  /// Nome do perfil do WhatsApp conectado (exibido ao lado do status).
  final String? profileName;
  final String? error;

  /// Aguardando leitura do QR/paircode (desconectado, mas com credencial pronta).
  bool get aguardandoQr => !connected && (qrcode != null || paircode != null);

  WhatsAppConnState copyWith({
    bool? loading,
    bool? actionLoading,
    bool? connected,
    Object? qrcode = _s,
    Object? paircode = _s,
    Object? profileName = _s,
    Object? error = _s,
  }) => WhatsAppConnState(
    loading: loading ?? this.loading,
    actionLoading: actionLoading ?? this.actionLoading,
    connected: connected ?? this.connected,
    qrcode: qrcode == _s ? this.qrcode : qrcode as String?,
    paircode: paircode == _s ? this.paircode : paircode as String?,
    profileName: profileName == _s
        ? this.profileName
        : profileName as String?,
    error: error == _s ? this.error : error as String?,
  );

  static const Object _s = Object();
}

class WhatsAppConnController extends StateNotifier<WhatsAppConnState> {
  WhatsAppConnController(this._ref) : super(const WhatsAppConnState()) {
    loadStatus();
  }

  final Ref _ref;

  Future<void> loadStatus() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final s = await _ref.read(painelWhatsappRepositoryProvider).status();
      state = state.copyWith(
        loading: false,
        connected: s.connected,
        qrcode: s.qr,
        paircode: s.paircode,
        profileName: s.profileName,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _waError(e));
    }
  }

  Future<void> connect() async {
    state = state.copyWith(
      actionLoading: true,
      error: null,
      qrcode: null,
      paircode: null,
      profileName: null,
    );
    try {
      final s = await _ref.read(painelWhatsappRepositoryProvider).connect();
      state = state.copyWith(
        actionLoading: false,
        connected: s.connected,
        qrcode: s.qr,
        paircode: s.paircode,
        profileName: s.profileName,
      );
    } catch (e) {
      state = state.copyWith(actionLoading: false, error: _waError(e));
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(actionLoading: true, error: null);
    try {
      await _ref.read(painelWhatsappRepositoryProvider).disconnect();
      state = state.copyWith(
        actionLoading: false,
        connected: false,
        qrcode: null,
        paircode: null,
        profileName: null,
      );
    } catch (e) {
      state = state.copyWith(actionLoading: false, error: _waError(e));
    }
  }

  /// Sondagem silenciosa (sem flags de loading) usada pelo polling da tela.
  /// Erros de rede são engolidos — o polling apenas segue tentando.
  Future<void> refreshStatus() async {
    try {
      final s = await _ref.read(painelWhatsappRepositoryProvider).status();
      if (!mounted) return;
      state = state.copyWith(
        connected: s.connected,
        // Ao conectar, some com o QR; senão preserva o que veio.
        qrcode: s.connected ? null : (s.qr ?? state.qrcode),
        paircode: s.connected ? null : (s.paircode ?? state.paircode),
        profileName: s.profileName ?? state.profileName,
      );
    } catch (_) {
      /* polling silencioso */
    }
  }
}

final whatsAppConnControllerProvider =
    StateNotifierProvider.autoDispose<
      WhatsAppConnController,
      WhatsAppConnState
    >((ref) => WhatsAppConnController(ref));

/* ─────────────────────────── Templates ─────────────────────────── */

class WhatsAppTemplatesState {
  const WhatsAppTemplatesState({
    this.templates = WhatsAppTemplates.empty,
    this.loading = true,
    this.saving = false,
    this.error,
    this.saved = false,
  });

  final WhatsAppTemplates templates;
  final bool loading;
  final bool saving;
  final String? error;

  /// Salvo com sucesso (a tela mostra o banner de sucesso e depois limpa).
  final bool saved;

  WhatsAppTemplatesState copyWith({
    WhatsAppTemplates? templates,
    bool? loading,
    bool? saving,
    Object? error = _s,
    bool? saved,
  }) => WhatsAppTemplatesState(
    templates: templates ?? this.templates,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: error == _s ? this.error : error as String?,
    saved: saved ?? this.saved,
  );

  static const Object _s = Object();
}

class WhatsAppTemplatesController
    extends StateNotifier<WhatsAppTemplatesState> {
  WhatsAppTemplatesController(this._ref)
    : super(const WhatsAppTemplatesState()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final t = await _ref.read(whatsappConfigRepositoryProvider).load();
      state = state.copyWith(templates: t, loading: false, error: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: _waError(e));
    }
  }

  /// Edição em memória de um campo (sem tocar no servidor).
  void edit(WhatsAppTemplates Function(WhatsAppTemplates t) patch) {
    state = state.copyWith(templates: patch(state.templates), saved: false);
  }

  Future<void> save() async {
    state = state.copyWith(saving: true, error: null, saved: false);
    try {
      final t = await _ref
          .read(whatsappConfigRepositoryProvider)
          .save(state.templates);
      state = state.copyWith(templates: t, saving: false, saved: true);
    } catch (e) {
      state = state.copyWith(saving: false, error: _waError(e), saved: false);
    }
  }

  /// Reseta o flag de sucesso (a tela chama após exibir o banner).
  void clearSaved() {
    if (state.saved) state = state.copyWith(saved: false);
  }
}

final whatsAppTemplatesControllerProvider =
    StateNotifierProvider.autoDispose<
      WhatsAppTemplatesController,
      WhatsAppTemplatesState
    >((ref) => WhatsAppTemplatesController(ref));
