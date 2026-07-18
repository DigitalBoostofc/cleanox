/// fakes_onda2.dart — Fakes sem rede para os testes da Onda 2 do Painel
/// (Clientes / Ordens / Execução admin). Cada fake implementa a interface
/// congelada do core e só cobre o que a tela consome; o resto lança.
library;

import 'dart:async';

import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/cliente.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/clientes_repository.dart';
import 'package:cleanos/core/repositories/evidencias_repository.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/core/repositories/servicos_repository.dart';
import 'package:cleanos/core/repositories/usuarios_repository.dart';
import 'package:cleanos/core/repositories/whatsapp_repository.dart';

Cliente fakeCliente({
  required String id,
  String nome = 'Carlos',
  String? sobrenome = 'Silva',
  String telefone = '85999990000',
  String bairro = 'Centro',
  String? cidade = 'Fortaleza',
  bool ativo = true,
}) => Cliente(
  id: id,
  nome: nome,
  sobrenome: sobrenome,
  telefone: telefone,
  enderecoBairro: bairro,
  enderecoCidade: cidade,
  ativo: ativo,
);

/// Fake de `ClientesRepository`: página fixa (opcionalmente falha) + registra
/// create/update para asserção nos testes.
class FakeClientes implements ClientesRepository {
  FakeClientes({List<Cliente>? seed, this.failList = false})
    : seed = seed ?? const [];

  List<Cliente> seed;
  final bool failList;

  int createCount = 0;
  int updateCount = 0;
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<PageResult<Cliente>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome',
  }) async {
    if (failList) throw Exception('falha de rede');
    return PageResult<Cliente>(
      items: seed,
      page: 1,
      perPage: perPage,
      totalItems: seed.length,
      totalPages: 1,
    );
  }

  @override
  Future<Cliente> create(Map<String, dynamic> data) async {
    createCount++;
    lastCreate = data;
    return fakeCliente(id: 'novo', nome: (data['nome'] as String?) ?? 'Novo');
  }

  @override
  Future<Cliente> update(String id, Map<String, dynamic> data) async {
    updateCount++;
    lastUpdate = data;
    return fakeCliente(id: id, ativo: (data['ativo'] as bool?) ?? true);
  }

  @override
  Future<Cliente> getOne(String id) async => fakeCliente(id: id);

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Cliente?> findByTelefone(String telefone, {String? excludeId}) async {
    for (final c in seed) {
      if (excludeId != null && c.id == excludeId) continue;
      if (phonesMatch(c.telefone, telefone)) return c;
    }
    return null;
  }
}

/// Fake de `OrdensRepository`: cobre o que Painel/Execução consomem.
class FakeOrdens implements OrdensRepository {
  FakeOrdens({List<OrdemServico>? seed, this.one, this.failList = false})
    : seed = seed ?? const [];

  List<OrdemServico> seed;

  /// Retorno de `getOne` (execução admin).
  final OrdemServico? one;
  final bool failList;

  int createCount = 0;
  int updateCount = 0;
  Map<String, dynamic>? lastCreate;

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    if (failList) throw Exception('falha de rede');
    return PageResult<OrdemServico>(
      items: seed,
      page: 1,
      perPage: perPage,
      totalItems: seed.length,
      totalPages: 1,
    );
  }

  @override
  Future<OrdemServico> create(
    Map<String, dynamic> data, {
    String? expand,
  }) async {
    createCount++;
    lastCreate = data;
    return (one ?? seed.first);
  }

  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) async {
    updateCount++;
    return one ?? seed.firstWhere((o) => o.id == osId);
  }

  @override
  Future<OrdemServico> getOne(String osId, {String? expand}) async {
    if (one != null) return one!;
    return seed.firstWhere((o) => o.id == osId);
  }

  int deleteCount = 0;
  String? lastDeleted;

  @override
  Future<void> delete(String osId) async {
    deleteCount++;
    lastDeleted = osId;
    seed = [
      for (final o in seed)
        if (o.id != osId) o,
    ];
  }

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<OrdemServico> getExec(String osId) => _unused();
  @override
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch) => _unused();
  @override
  Future<OrdemServico> updateStatus(String osId, OSStatus novo) => _unused();
  @override
  Future<OrdemServico> cancelar(String osId, {required String motivo}) =>
      _unused();
  @override
  Stream<OrdemServicoEvent> subscribe({String topic = '*', String? filter}) =>
      const Stream.empty();
  @override
  Future<List<OrdemServico>> listDoProfissional(
    String profId, {
    DateRange? janela,
  }) => _unused();
}

class FakeServicos implements ServicosRepository {
  FakeServicos({List<ServicoPB>? ativos}) : ativos = ativos ?? const [];
  final List<ServicoPB> ativos;

  @override
  Future<List<ServicoPB>> listAtivos() async => ativos;

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<PageResult<ServicoPB>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome',
  }) => _unused();
  @override
  Future<ServicoPB> getOne(String id) => _unused();
  @override
  Future<ServicoPB> create(Map<String, dynamic> data) => _unused();
  @override
  Future<ServicoPB> update(String id, Map<String, dynamic> data) => _unused();
  @override
  Future<void> delete(String id) => _unused();
}

class FakeUsuarios implements UsuariosRepository {
  FakeUsuarios({List<User>? profissionais})
    : profissionais = profissionais ?? const [];
  final List<User> profissionais;

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) async =>
      profissionais;

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<User> getOne(String id) => _unused();
  @override
  Future<User> create(Map<String, dynamic> data, {AvatarUpload? avatar}) => _unused();
  @override
  Future<User> update(String id, Map<String, dynamic> data, {AvatarUpload? avatar}) => _unused();
  @override
  Future<void> delete(String id) => _unused();
  @override
  Future<void> redefinirSenha({
    required String userId,
    required String novaSenha,
    required String adminSenha,
  }) => _unused();
}

class FakeEvidencias implements EvidenciasRepository {
  FakeEvidencias({List<EvidenciaFoto>? fotos}) : fotos = fotos ?? const [];
  final List<EvidenciaFoto> fotos;

  @override
  Future<List<EvidenciaFoto>> listDaOS(String osId) async => fotos;

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input) =>
      _unused();
  @override
  Future<EvidenciaFoto> updateMeta(String id, EvidenciaUpdatePatch patch) =>
      _unused();
  @override
  Future<void> delete(String id) => _unused();
}

class FakeWhatsApp implements WhatsAppRepository {
  int enviarCount = 0;

  @override
  Future<void> enviarRelatorio(String osId) async {
    enviarCount++;
  }

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<AvisoResult> avisarACaminho(String osId) => _unused();
  @override
  Future<ContatoClienteResult> contatoCliente(String osId) => _unused();
  @override
  Future<WhatsAppStatus> status() => _unused();
  @override
  Future<WhatsAppStatus> connect() => _unused();
  @override
  Future<void> disconnect() => _unused();
}

/// FakeOrdens com a semântica REAL de PATCH do PocketBase: `update` aplica só as
/// chaves PRESENTES no payload; o que não vem no body permanece como está no
/// "banco". Também honra o filtro de status do servidor (`list`).
///
/// É o que dá para provar os bugs de estado do QA E2E: um fake que devolvesse o
/// payload como se fosse o registro inteiro esconderia justamente o F-234, em que
/// o `status` NÃO ia no body e o valor antigo (`atribuida`) sobrevivia no banco
/// ao lado de `profissional=""`.
class FakeOrdensPatch extends FakeOrdens {
  FakeOrdensPatch({required List<OrdemServico> seed}) : super(seed: seed);

  /// Todos os payloads que chegaram ao "servidor", na ordem.
  final List<Map<String, dynamic>> payloads = [];

  /// Quantas vezes a lista foi buscada — mede se a tela RECARREGOU (F-233).
  int listCount = 0;

  OrdemServico get registro => seed.first;

  /// O estado que o domínio proíbe: atribuída, mas sem ninguém atribuído.
  /// Espelha o `profissional=""` do PB (R2: relation opcional vazia é `""`).
  bool get estadoImpossivel =>
      registro.status == OSStatus.atribuida &&
      (registro.profissional ?? '').isEmpty;

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    listCount++;
    // Só recorta por STATUS; a janela de data (período) é ignorada pelo fake.
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
    payloads.add(Map<String, dynamic>.from(data));
    final atual = seed.firstWhere((o) => o.id == osId);
    final atualizado = atual.copyWith(
      status: data.containsKey('status')
          ? OSStatus.values.firstWhere((s) => s.wire == data['status'])
          : atual.status,
      profissional: data.containsKey('profissional')
          ? (data['profissional'] as String?) ?? ''
          : atual.profissional,
    );
    seed = [
      for (final o in seed)
        if (o.id == osId) atualizado else o,
    ];
    return atualizado;
  }
}
