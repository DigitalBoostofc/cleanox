/// fakes_onda5.dart — Fakes sem rede para a Onda 5 do Painel (Avaliações +
/// WhatsApp). Cada fake implementa a interface consumida pela tela; o resto
/// lança. Reaproveita `FakeOrdens` (fakes_onda2) para a lista de avaliações.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/usuarios_repository.dart';
import 'package:cleanos/core/repositories/whatsapp_repository.dart';
import 'package:cleanos/painel/data/whatsapp_config_repository.dart';

/// OS já avaliada, com os campos que a tela de Avaliações lê.
OrdemServico fakeAvaliacaoOS({
  required String id,
  double nota = 5,
  String? motivo,
  String nomeCurto = 'Carlos S.',
  String servico = 'Higienização de sofá',
  String avaliacaoEm = '2026-06-20 14:30:00.000Z',
  String dataHora = '2026-06-19 10:00:00.000Z',
  User? profissional,
}) => OrdemServico(
  id: id,
  status: OSStatus.concluida,
  nomeCurto: nomeCurto,
  tipoServicoNome: servico,
  dataHora: dataHora,
  avaliacaoNota: nota,
  avaliacaoMotivo: motivo,
  avaliacaoEm: avaliacaoEm,
  expand: profissional == null ? null : OSExpand(profissional: profissional),
);

/// Fake de `UsuariosRepository`: devolve uma lista fixa de usuários (a tela de
/// Avaliações lê os profissionais para montar o acordeão).
class FakeUsuariosRepo implements UsuariosRepository {
  FakeUsuariosRepo(this.users);
  final List<User> users;

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) async =>
      users;

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<User> getOne(String id) => _unused();
  @override
  Future<User> create(Map<String, dynamic> data, {AvatarUpload? avatar}) => _unused();
  @override
  Future<User> update(String id, Map<String, dynamic> data, {AvatarUpload? avatar}) => _unused();
  @override
  Future<void> delete(String id) => _unused();
}

/// Fake de `WhatsAppRepository` (status/connect/disconnect) configurável.
/// `statusQueue` permite simular o polling (cada chamada de [status] consome o
/// próximo; o último valor é mantido).
class FakeWhatsAppConn implements WhatsAppRepository {
  FakeWhatsAppConn({
    WhatsAppStatus? initial,
    this.connectResult,
    this.failStatus = false,
    this.failConnect = false,
  }) : _current = initial ?? const WhatsAppStatus(connected: false);

  WhatsAppStatus _current;
  final WhatsAppStatus? connectResult;
  final bool failStatus;
  final bool failConnect;

  int statusCount = 0;
  int connectCount = 0;
  int disconnectCount = 0;

  /// Muda o valor que [status]/[refreshStatus] retornarão a partir de agora
  /// (usado para simular "o cliente escaneou o QR" durante o polling).
  void setStatus(WhatsAppStatus s) => _current = s;

  @override
  Future<WhatsAppStatus> status() async {
    statusCount++;
    if (failStatus) throw Exception('falha de status');
    return _current;
  }

  @override
  Future<WhatsAppStatus> connect() async {
    connectCount++;
    if (failConnect) throw Exception('falha ao conectar');
    final r = connectResult ?? const WhatsAppStatus(connected: false);
    _current = r;
    return r;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _current = const WhatsAppStatus(connected: false);
  }

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<AvisoResult> avisarACaminho(String osId) => _unused();
  @override
  Future<void> enviarRelatorio(String osId) => _unused();
}

/// Fake de `WhatsAppConfigRepository`: seed dos templates + registro do save.
class FakeWhatsAppConfig implements WhatsAppConfigRepository {
  FakeWhatsAppConfig({WhatsAppTemplates? seed, this.failLoad = false})
    : templates = seed ?? WhatsAppTemplates.empty;

  WhatsAppTemplates templates;
  final bool failLoad;

  int loadCount = 0;
  int saveCount = 0;
  WhatsAppTemplates? lastSaved;

  @override
  Future<WhatsAppTemplates> load() async {
    loadCount++;
    if (failLoad) throw Exception('falha ao carregar');
    return templates;
  }

  @override
  Future<WhatsAppTemplates> save(WhatsAppTemplates t) async {
    saveCount++;
    lastSaved = t;
    templates = t;
    return t;
  }
}
