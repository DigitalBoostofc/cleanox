/// fakes_fin_pb.dart — Servidor PocketBase FAKE (transporte HTTP mockado) para
/// testar o `PbFinanceiroRepository` no contrato de SALDO SERVER-SIDE, SEM
/// PocketBase real.
///
/// Injeta um `MockClient` no `PocketBase` (mesmo padrão de
/// `core/ordens_repository_test.dart`) e MODELA as duas fronteiras do novo
/// contrato:
///   • CRUD de `fin_lancamentos` e `fin_contas` — SEM efeito no saldo (o cliente
///     não muta mais `saldo_atual`). Registra cada PATCH de conta ([contaPatches]
///     / [contaPatchBodies]) para provar que o repo NÃO grava saldo.
///   • Rotas transacionais custom — `POST /api/cleanos/fin/conta/{id}/ajuste` e
///     `POST /api/cleanos/fin/transferencia` — registra cada chamada ([ajustes] /
///     [transferencias]) e emula as validações/erros do backend (400/404) para
///     provar que o repo só POSTa e propaga o erro (sem rollback client-side).
///
/// Injeção de erro (para provar tradução/propagação):
///   • [ajusteFailStatus]/[ajusteFailMsg]: força a rota de ajuste a falhar
///     (ex.: 403 sem permissão);
///   • [transferFailStatus]/[transferFailMsg]: idem para a transferência.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Uma mutação de `saldo_atual` observada (id da conta + valor gravado).
/// No novo contrato NENHUMA deve acontecer — a lista deve ficar VAZIA.
class ContaPatch {
  ContaPatch(this.id, this.saldo);
  final String id;
  final double saldo;
}

/// Uma chamada à rota de ajuste manual de saldo.
class AjusteCall {
  AjusteCall(this.contaId, this.body);
  final String contaId;
  final Map<String, dynamic> body;
}

/// Uma chamada à rota de transferência.
class TransferCall {
  TransferCall(this.body);
  final Map<String, dynamic> body;
}

class FakeFinPb {
  FakeFinPb({
    Map<String, double>? saldos,
    Map<String, Map<String, dynamic>>? lancamentos,
  }) : saldos = {...?saldos},
       lancamentos = {...?lancamentos};

  /// Saldo corrente de cada conta (id → saldo_atual). Mutado só pelas ROTAS
  /// transacionais (server-side), nunca por PATCH de `fin_contas`.
  final Map<String, double> saldos;

  /// Lançamentos em memória (id → record json).
  final Map<String, Map<String, dynamic>> lancamentos;

  /// Toda mutação de `saldo_atual` via PATCH de `fin_contas` observada. Deve
  /// ficar VAZIA no novo contrato (o cliente não grava saldo).
  final List<ContaPatch> contaPatches = [];

  /// Corpo de CADA PATCH de `fin_contas` (p/ provar que `saldo_atual` não é
  /// enviado, mesmo que o valor não mude).
  final List<Map<String, dynamic>> contaPatchBodies = [];

  /// Chamadas à rota de ajuste de saldo, em ordem.
  final List<AjusteCall> ajustes = [];

  /// Chamadas à rota de transferência, em ordem.
  final List<TransferCall> transferencias = [];

  /// Quantos GET de um lançamento individual (`getOne`) — deve ser 0: o repo
  /// não lê o registro antigo antes de mutar (sem read-then-write).
  int lancGetCount = 0;

  /// Força a rota de ajuste a falhar com este status/mensagem (ex.: 403).
  int? ajusteFailStatus;
  String ajusteFailMsg = 'ajuste falhou';

  /// Força a rota de transferência a falhar com este status/mensagem.
  int? transferFailStatus;
  String transferFailMsg = 'transferência falhou';

  PocketBase client() => PocketBase(
    'http://pb.test',
    httpClientFactory: () => MockClient(_handle),
  );

  /* ─────────────────────────── roteamento ─────────────────────────── */

  Future<http.Response> _handle(http.Request req) async {
    final seg = req.url.pathSegments;
    // Rotas custom: /api/cleanos/fin/...
    if (seg.length >= 3 && seg[1] == 'cleanos' && seg[2] == 'fin') {
      // seg = [api, cleanos, fin, <conta|transferencia>, ...]
      if (seg.length >= 6 && seg[3] == 'conta' && seg[5] == 'ajuste') {
        return _ajuste(seg[4], req);
      }
      if (seg.length >= 4 && seg[3] == 'transferencia') {
        return _transferencia(req);
      }
      return _err(404, 'rota custom desconhecida: ${req.url.path}');
    }
    // CRUD de coleção: /api/collections/<col>/records/[id]
    final col = seg.length >= 3 ? seg[2] : '';
    final id = seg.length >= 5 ? seg[4] : null;
    switch (col) {
      case 'fin_contas':
        return _contas(req.method, id, req);
      case 'fin_lancamentos':
        return _lancs(req.method, id, req);
      default:
        return _err(404, 'coleção desconhecida: $col');
    }
  }

  /* ─────────────────────────── rotas transacionais ─────────────────────────── */

  Future<http.Response> _ajuste(String contaId, http.Request req) async {
    final body = _body(req);
    ajustes.add(AjusteCall(contaId, body));
    if (ajusteFailStatus != null) {
      return _err(ajusteFailStatus!, ajusteFailMsg);
    }
    // Validação/erros do backend (fin_saldo_lib.ajusteConta).
    if (body['delta'] == null && body['novoSaldo'] == null) {
      return _err(400, "Informe 'delta' ou 'novoSaldo'.");
    }
    if (body['delta'] != null) {
      final delta = (body['delta'] as num).toDouble();
      if (!saldos.containsKey(contaId)) {
        // delta não-nulo mas conta inexistente → 400 (via delta).
        if ((delta * 100).round() != 0) {
          return _err(400, "Conta '$contaId' não encontrada.");
        }
      } else {
        saldos[contaId] = _round2((saldos[contaId] ?? 0) + delta);
      }
    } else {
      final novo = (body['novoSaldo'] as num).toDouble();
      if (!saldos.containsKey(contaId)) {
        return _err(404, "conta $contaId inexistente"); // via novoSaldo → 404
      }
      saldos[contaId] = _round2(novo);
    }
    return _ok({
      'ok': true,
      'conta_id': contaId,
      'saldo_atual': saldos[contaId] ?? 0,
    });
  }

  Future<http.Response> _transferencia(http.Request req) async {
    final body = _body(req);
    transferencias.add(TransferCall(body));
    if (transferFailStatus != null) {
      return _err(transferFailStatus!, transferFailMsg);
    }
    final from = body['from'] as String?;
    final to = body['to'] as String?;
    final valor = (body['valor'] as num?)?.toDouble();
    if (from == null || to == null || from.isEmpty || to.isEmpty) {
      return _err(400, "Informe 'from' e 'to'.");
    }
    if (from == to) return _err(400, 'Origem e destino são iguais.');
    if (valor == null || valor <= 0) return _err(400, "'valor' deve ser > 0.");
    if (!saldos.containsKey(from) || !saldos.containsKey(to)) {
      return _err(404, 'conta inexistente na transferência');
    }
    saldos[from] = _round2(saldos[from]! - valor);
    saldos[to] = _round2(saldos[to]! + valor);
    return _ok({
      'ok': true,
      'from': {'conta_id': from, 'saldo_atual': saldos[from]},
      'to': {'conta_id': to, 'saldo_atual': saldos[to]},
    });
  }

  /* ─────────────────────────── CRUD (sem efeito no saldo) ─────────────────────────── */

  Future<http.Response> _contas(
    String method,
    String? id,
    http.Request req,
  ) async {
    if (id == null) return _err(404, 'lista de contas não usada nos testes');
    if (method == 'GET') {
      if (!saldos.containsKey(id)) return _err(404, 'conta $id inexistente');
      return _ok(_contaJson(id, saldos[id]!));
    }
    if (method == 'PATCH') {
      final body = _body(req);
      contaPatchBodies.add(body);
      // Registra APENAS se o cliente tentou gravar saldo_atual (não deve!).
      if (body.containsKey('saldo_atual')) {
        final v = (body['saldo_atual'] as num).toDouble();
        saldos[id] = v;
        contaPatches.add(ContaPatch(id, v));
      }
      return _ok(_contaJson(id, saldos[id] ?? 0));
    }
    return _err(405, 'método $method não suportado em fin_contas');
  }

  Future<http.Response> _lancs(
    String method,
    String? id,
    http.Request req,
  ) async {
    if (method == 'POST') {
      final body = _body(req);
      final newId = 'lanc_${lancamentos.length + 1}';
      final rec = _lancJson(newId, body);
      lancamentos[newId] = rec;
      return _ok(rec);
    }
    if (method == 'GET' && id != null) {
      lancGetCount++;
      final rec = lancamentos[id];
      if (rec == null) return _err(404, 'lançamento $id inexistente');
      return _ok(rec);
    }
    if (method == 'PATCH' && id != null) {
      final body = _body(req);
      final rec = {...?lancamentos[id], ...body, 'id': id};
      lancamentos[id] = rec;
      return _ok(rec);
    }
    if (method == 'DELETE' && id != null) {
      lancamentos.remove(id);
      return http.Response('', 204);
    }
    return _err(405, 'método $method não suportado em fin_lancamentos');
  }

  /* ─────────────────────────── helpers ─────────────────────────── */

  Map<String, dynamic> _body(http.Request req) =>
      req.body.isEmpty ? {} : jsonDecode(req.body) as Map<String, dynamic>;

  static double _round2(double v) => (v * 100).round() / 100.0;

  Map<String, dynamic> _contaJson(String id, double saldo) => {
    'id': id,
    'collectionId': 'contas',
    'collectionName': 'fin_contas',
    'nome': 'Conta $id',
    'saldo_atual': saldo,
    'ativo': true,
  };

  Map<String, dynamic> _lancJson(String id, Map<String, dynamic> body) => {
    'id': id,
    'collectionId': 'lancs',
    'collectionName': 'fin_lancamentos',
    ...body,
  };

  http.Response _ok(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  http.Response _err(int code, String message) => http.Response(
    jsonEncode({'code': code, 'message': message, 'data': {}}),
    code,
    headers: {'content-type': 'application/json'},
  );
}
