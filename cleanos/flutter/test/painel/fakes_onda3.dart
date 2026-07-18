/// fakes_onda3.dart — Fakes sem rede para os testes da Onda 3 do Painel
/// (Serviços / Usuários+Disponibilidade / Agenda). Cada fake implementa a interface
/// congelada do core e cobre o que a tela consome; o resto lança.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/core/repositories/servicos_repository.dart';
import 'package:cleanos/core/repositories/usuarios_repository.dart';
import 'package:pocketbase/pocketbase.dart';

/* ─────────────────────────── builders ─────────────────────────── */

ServicoPB fakeServico({
  required String id,
  String nome = 'Higienização de Sofá',
  Categoria categoria = Categoria.residencial,
  Grupo grupo = Grupo.sofa,
  double valorBase = 150,
  TipoValor tipoValor = TipoValor.fixo,
  ServicoStatus status = ServicoStatus.ativo,
  String? tempoMedioLabel = '2h',
  List<ChecklistTemplateItem> checklist = const [],
}) => ServicoPB(
  id: id,
  nome: nome,
  categoria: categoria,
  grupo: grupo,
  valorBase: valorBase,
  tipoValor: tipoValor,
  status: status,
  ativo: status == ServicoStatus.ativo,
  tempoMedioLabel: tempoMedioLabel,
  checklistPadrao: checklist,
);

User fakeUser({
  required String id,
  String name = 'Pedro Santos',
  String email = 'pedro@cleanos.app',
  Role role = Role.profissional,
}) => User(id: id, name: name, email: email, role: role);

Disponibilidade fakeDisponibilidade({
  required String id,
  required String profissional,
  int duracaoMin = 60,
  String inicio = '08:00',
  String fim = '10:00',
  List<bool>? diasAtivos,
}) {
  final ativos =
      diasAtivos ?? List<bool>.filled(7, true); // todos os dias por padrão
  return Disponibilidade(
    id: id,
    profissional: profissional,
    duracaoMin: duracaoMin,
    dias: [
      for (var i = 0; i < 7; i++)
        DisponibilidadeDiaPB(ativo: ativos[i], inicio: inicio, fim: fim),
    ],
  );
}

/// OS de agenda: `data_hora` é UTC; passe a hora UTC que mapeia p/ o BRT desejado
/// (BRT = UTC-3), ex.: 11:00Z → 08:00 BRT.
OrdemServico fakeOSAgenda({
  required String id,
  required String profissionalId,
  String nomeCurto = 'Carlos S.',
  String tipoServicoNome = 'Sofá 3 lugares',
  String dataHoraUtc = '2026-07-01 11:00:00',
  OSStatus status = OSStatus.atribuida,
  User? profExpand,
}) => OrdemServico(
  id: id,
  nomeCurto: nomeCurto,
  tipoServicoNome: tipoServicoNome,
  dataHora: dataHoraUtc,
  profissional: profissionalId,
  status: status,
  valorServico: 150,
  expand: profExpand == null ? null : OSExpand(profissional: profExpand),
);

/* ─────────────────────────── fakes ─────────────────────────── */

/// Fake completo de `ServicosRepository` (lista paginada + CRUD com contadores).
class FakeServicosFull implements ServicosRepository {
  FakeServicosFull({List<ServicoPB>? seed, this.failList = false})
    : seed = seed ?? const [];

  List<ServicoPB> seed;
  final bool failList;

  int createCount = 0;
  int updateCount = 0;
  int deleteCount = 0;
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<List<ServicoPB>> listAtivos() async =>
      seed.where((s) => s.ativo).toList();

  @override
  Future<PageResult<ServicoPB>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome',
  }) async {
    if (failList) throw Exception('falha de rede');
    return PageResult<ServicoPB>(
      items: seed,
      page: 1,
      perPage: perPage,
      totalItems: seed.length,
      totalPages: 1,
    );
  }

  @override
  Future<ServicoPB> getOne(String id) async =>
      seed.firstWhere((s) => s.id == id, orElse: () => fakeServico(id: id));

  @override
  Future<ServicoPB> create(Map<String, dynamic> data) async {
    createCount++;
    lastCreate = data;
    return fakeServico(id: 'novo', nome: (data['nome'] as String?) ?? 'Novo');
  }

  @override
  Future<ServicoPB> update(String id, Map<String, dynamic> data) async {
    updateCount++;
    lastUpdate = data;
    return fakeServico(id: id, nome: (data['nome'] as String?) ?? 'Serviço');
  }

  @override
  Future<void> delete(String id) async {
    deleteCount++;
  }
}

/// Fake completo de `UsuariosRepository` (lista + CRUD com contadores).
class FakeUsuariosFull implements UsuariosRepository {
  FakeUsuariosFull({List<User>? seed, this.failList = false})
    : seed = seed ?? const [];

  List<User> seed;
  final bool failList;

  int createCount = 0;
  int updateCount = 0;
  int deleteCount = 0;
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) async {
    if (failList) throw Exception('falha de rede');
    return seed;
  }

  @override
  Future<User> getOne(String id) async =>
      seed.firstWhere((u) => u.id == id, orElse: () => fakeUser(id: id));

  @override
  Future<User> create(Map<String, dynamic> data, {AvatarUpload? avatar}) async {
    createCount++;
    lastCreate = data;
    return fakeUser(id: 'novo', name: (data['name'] as String?) ?? 'Novo');
  }

  @override
  Future<User> update(String id, Map<String, dynamic> data, {AvatarUpload? avatar}) async {
    updateCount++;
    lastUpdate = data;
    return fakeUser(id: id, name: (data['name'] as String?) ?? 'Nome');
  }

  @override
  Future<void> delete(String id) async {
    deleteCount++;
  }

  // Redefinição de senha por admin.
  int redefinirCount = 0;
  String? lastRedefinirUserId;
  String? lastRedefinirNovaSenha;
  String? lastRedefinirAdminSenha;

  /// Se setado, `redefinirSenha` lança (simula 400/403 do PB).
  Object? redefinirError;

  @override
  Future<void> redefinirSenha({
    required String userId,
    required String novaSenha,
    required String adminSenha,
  }) async {
    redefinirCount++;
    lastRedefinirUserId = userId;
    lastRedefinirNovaSenha = novaSenha;
    lastRedefinirAdminSenha = adminSenha;
    final err = redefinirError;
    if (err != null) throw err;
  }
}

/// Fake de `UsuariosRepository` que bloqueia o delete com um 400 do PocketBase
/// (simula o hook `prof_delete.pb.js` quando há OS em aberto).
class FakeUsuariosDeleteBlocked extends FakeUsuariosFull {
  FakeUsuariosDeleteBlocked({required List<User> seed}) : super(seed: seed);

  /// Mensagem PT-BR retornada pelo hook (campo `message` do erro 400).
  static const String blockedMessage =
      'Não é possível excluir este profissional: ele possui uma ordem de '
      'serviço em aberto (não concluída/cancelada). Conclua ou cancele essa '
      'ordem de serviço antes de excluir o profissional.';

  @override
  Future<void> delete(String id) async {
    throw ClientException(
      statusCode: 400,
      response: {'message': blockedMessage},
    );
  }
}

/// Fake de `DisponibilidadeRepository` (lista por profissional + upsert com contadores).
class FakeDisponibilidade implements DisponibilidadeRepository {
  FakeDisponibilidade({List<Disponibilidade>? seed}) : seed = seed ?? const [];

  List<Disponibilidade> seed;

  int createCount = 0;
  int updateCount = 0;
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async {
    return PageResult<Disponibilidade>(
      items: seed,
      page: 1,
      perPage: perPage,
      totalItems: seed.length,
      totalPages: 1,
    );
  }

  @override
  Future<Disponibilidade> getOne(String id) async =>
      seed.firstWhere((d) => d.id == id);

  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) async {
    createCount++;
    lastCreate = data;
    return fakeDisponibilidade(
      id: 'novo',
      profissional: (data['profissional'] as String?) ?? '',
    );
  }

  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) async {
    updateCount++;
    lastUpdate = data;
    return fakeDisponibilidade(
      id: id,
      profissional: (data['profissional'] as String?) ?? '',
    );
  }

  @override
  Future<void> delete(String id) async {}
}
