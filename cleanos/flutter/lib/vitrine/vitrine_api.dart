/// Cliente HTTP da vitrine → rotas públicas + admin PocketBase `/api/cleanos/vitrine/*`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../core/env/env.dart';

class VitrineServico {
  const VitrineServico({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.categoria,
    required this.grupo,
    required this.valorBase,
    required this.valorBaseMax,
    required this.tempoMedioMin,
    required this.tempoMedioLabel,
    required this.orientacoesPre,
    this.vitrineDestaque = false,
  });

  final String id;
  final String nome;
  final String descricao;
  final String categoria;
  final String grupo;
  final double valorBase;
  final double valorBaseMax;
  final int tempoMedioMin;
  final String tempoMedioLabel;
  final String orientacoesPre;
  final bool vitrineDestaque;

  factory VitrineServico.fromJson(Map<String, dynamic> j) => VitrineServico(
        id: '${j['id'] ?? ''}',
        nome: '${j['nome'] ?? ''}',
        descricao: '${j['descricao'] ?? ''}',
        categoria: '${j['categoria'] ?? ''}',
        grupo: '${j['grupo'] ?? ''}',
        valorBase: (j['valor_base'] as num?)?.toDouble() ?? 0,
        valorBaseMax: (j['valor_base_max'] as num?)?.toDouble() ?? 0,
        tempoMedioMin: (j['tempo_medio_min'] as num?)?.toInt() ?? 0,
        tempoMedioLabel: '${j['tempo_medio_label'] ?? ''}',
        orientacoesPre: '${j['orientacoes_pre'] ?? ''}',
        vitrineDestaque: j['vitrine_destaque'] == true,
      );
}

class VitrineSlot {
  const VitrineSlot({required this.hora, required this.token});
  final String hora;
  final String token;

  factory VitrineSlot.fromJson(Map<String, dynamic> j) => VitrineSlot(
        hora: '${j['hora'] ?? ''}',
        token: '${j['token'] ?? ''}',
      );
}

class VitrineOrderBump {
  const VitrineOrderBump({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.badge,
    required this.servicoOferta,
    required this.precoCheio,
    required this.precoPromo,
    this.servicoNome = '',
    this.ativo = true,
    this.gatilhoTipo = 'qualquer_grupo',
    this.gatilhoValores = const [],
    this.excluirSe = const [],
    this.prioridade = 0,
    this.fotoUrl = '',
  });

  final String id;
  final String titulo;
  final String descricao;
  final String badge;
  final String servicoOferta;
  final String servicoNome;
  final double precoCheio;
  final double precoPromo;
  final bool ativo;
  final String gatilhoTipo;
  final List<String> gatilhoValores;
  final List<String> excluirSe;
  final int prioridade;
  final String fotoUrl;

  factory VitrineOrderBump.fromJson(Map<String, dynamic> j) => VitrineOrderBump(
        id: '${j['id'] ?? ''}',
        titulo: '${j['titulo'] ?? ''}',
        descricao: '${j['descricao'] ?? ''}',
        badge: '${j['badge'] ?? ''}',
        servicoOferta: '${j['servico_oferta'] ?? ''}',
        servicoNome: '${j['servico_nome'] ?? ''}',
        precoCheio: (j['preco_cheio'] as num?)?.toDouble() ?? 0,
        precoPromo: (j['preco_promo'] as num?)?.toDouble() ?? 0,
        ativo: j['ativo'] != false,
        gatilhoTipo: '${j['gatilho_tipo'] ?? 'qualquer_grupo'}',
        gatilhoValores: _strList(j['gatilho_valores']),
        excluirSe: _strList(j['excluir_se']),
        prioridade: (j['prioridade'] as num?)?.toInt() ?? 0,
        fotoUrl: '${j['foto_url'] ?? ''}',
      );

  static List<String> _strList(dynamic v) {
    if (v is! List) return const [];
    return [for (final e in v) '$e'];
  }
}

class VitrineMidia {
  const VitrineMidia({
    required this.id,
    required this.chave,
    required this.titulo,
    required this.url,
    this.ordem = 0,
  });

  final String id;
  final String chave;
  final String titulo;
  final String url;
  final int ordem;

  factory VitrineMidia.fromJson(Map<String, dynamic> j) => VitrineMidia(
        id: '${j['id'] ?? ''}',
        chave: '${j['chave'] ?? ''}',
        titulo: '${j['titulo'] ?? ''}',
        url: '${j['url'] ?? j['url_externa'] ?? ''}',
        ordem: (j['ordem'] as num?)?.toInt() ?? 0,
      );
}

class VitrineBootstrap {
  const VitrineBootstrap({
    required this.config,
    required this.midia,
    this.estado = '',
    this.cidades = const [],
  });

  final VitrineConfig config;
  final List<VitrineMidia> midia;
  final String estado;
  final List<String> cidades;

  /// Mapa chave → URL (primeira ocorrência ganha).
  Map<String, String> get midiaByChave {
    final m = <String, String>{};
    for (final it in midia) {
      final k = it.chave.trim().toLowerCase();
      if (k.isEmpty || it.url.isEmpty) continue;
      m.putIfAbsent(k, () => it.url);
    }
    return m;
  }
}

class VitrineConfig {
  const VitrineConfig({
    this.id = '',
    this.heroTitulo = 'Orçamento em 1 minuto',
    this.heroSubtitulo =
        'Escolha o que precisa limpar e agende no horário ideal',
    this.heroCta = 'Montar orçamento',
    this.whatsappExibido = '',
    this.rodapeMsg = 'Pagamento só no local · maquininha Cleanox',
    this.cidadesTexto = '',
    this.comoFunciona = '',
  });

  final String id;
  final String heroTitulo;
  final String heroSubtitulo;
  final String heroCta;
  final String whatsappExibido;
  final String rodapeMsg;
  final String cidadesTexto;
  final String comoFunciona;

  factory VitrineConfig.fromJson(Map<String, dynamic> j) => VitrineConfig(
        id: '${j['id'] ?? ''}',
        heroTitulo: '${j['hero_titulo'] ?? 'Orçamento em 1 minuto'}',
        heroSubtitulo:
            '${j['hero_subtitulo'] ?? 'Escolha o que precisa limpar e agende no horário ideal'}',
        heroCta: '${j['hero_cta'] ?? 'Montar orçamento'}',
        whatsappExibido: '${j['whatsapp_exibido'] ?? ''}',
        rodapeMsg:
            '${j['rodape_msg'] ?? 'Pagamento só no local · maquininha Cleanox'}',
        cidadesTexto: '${j['cidades_texto'] ?? ''}',
        comoFunciona: '${j['como_funciona'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'hero_titulo': heroTitulo,
        'hero_subtitulo': heroSubtitulo,
        'hero_cta': heroCta,
        'whatsapp_exibido': whatsappExibido,
        'rodape_msg': rodapeMsg,
        'cidades_texto': cidadesTexto,
        'como_funciona': comoFunciona,
      };

  VitrineConfig copyWith({
    String? heroTitulo,
    String? heroSubtitulo,
    String? heroCta,
    String? whatsappExibido,
    String? rodapeMsg,
    String? cidadesTexto,
    String? comoFunciona,
  }) =>
      VitrineConfig(
        id: id,
        heroTitulo: heroTitulo ?? this.heroTitulo,
        heroSubtitulo: heroSubtitulo ?? this.heroSubtitulo,
        heroCta: heroCta ?? this.heroCta,
        whatsappExibido: whatsappExibido ?? this.whatsappExibido,
        rodapeMsg: rodapeMsg ?? this.rodapeMsg,
        cidadesTexto: cidadesTexto ?? this.cidadesTexto,
        comoFunciona: comoFunciona ?? this.comoFunciona,
      );
}

class VitrineAgendarResult {
  const VitrineAgendarResult({
    required this.osRef,
    required this.data,
    required this.hora,
    required this.servico,
    required this.valor,
    required this.mensagem,
  });

  final String osRef;
  final String data;
  final String hora;
  final String servico;
  final double valor;
  final String mensagem;

  factory VitrineAgendarResult.fromJson(Map<String, dynamic> j) =>
      VitrineAgendarResult(
        osRef: '${j['os_ref'] ?? ''}',
        data: '${j['data'] ?? ''}',
        hora: '${j['hora'] ?? ''}',
        servico: '${j['servico'] ?? ''}',
        valor: (j['valor'] as num?)?.toDouble() ?? 0,
        mensagem: '${j['mensagem'] ?? ''}',
      );
}

class VitrineAdminServico {
  const VitrineAdminServico({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.valorBase,
    required this.vitrine,
    required this.vitrineDestaque,
    required this.ativo,
  });

  final String id;
  final String nome;
  final String grupo;
  final double valorBase;
  final bool vitrine;
  final bool vitrineDestaque;
  final bool ativo;

  factory VitrineAdminServico.fromJson(Map<String, dynamic> j) =>
      VitrineAdminServico(
        id: '${j['id'] ?? ''}',
        nome: '${j['nome'] ?? ''}',
        grupo: '${j['grupo'] ?? ''}',
        valorBase: (j['valor_base'] as num?)?.toDouble() ?? 0,
        vitrine: j['vitrine'] != false,
        vitrineDestaque: j['vitrine_destaque'] == true,
        ativo: j['ativo'] == true,
      );
}

class VitrineAgendamentoResumo {
  const VitrineAgendamentoResumo({
    required this.id,
    required this.osRef,
    required this.nomeCurto,
    required this.tipoServicoNome,
    required this.dataHora,
    required this.valorServico,
    required this.status,
    required this.bairro,
  });

  final String id;
  final String osRef;
  final String nomeCurto;
  final String tipoServicoNome;
  final String dataHora;
  final double valorServico;
  final String status;
  final String bairro;

  factory VitrineAgendamentoResumo.fromJson(Map<String, dynamic> j) =>
      VitrineAgendamentoResumo(
        id: '${j['id'] ?? ''}',
        osRef: '${j['os_ref'] ?? ''}',
        nomeCurto: '${j['nome_curto'] ?? ''}',
        tipoServicoNome: '${j['tipo_servico_nome'] ?? ''}',
        dataHora: '${j['data_hora'] ?? ''}',
        valorServico: (j['valor_servico'] as num?)?.toDouble() ?? 0,
        status: '${j['status'] ?? ''}',
        bairro: '${j['bairro'] ?? ''}',
      );
}

class VitrineApiException implements Exception {
  VitrineApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class VitrineApi {
  VitrineApi({http.Client? client, String? baseUrl, PocketBase? pb})
      : _client = client ?? http.Client(),
        _base = (baseUrl ?? Env.pbUrl).replaceAll(RegExp(r'/$'), ''),
        _pb = pb;

  final http.Client _client;
  final String _base;
  final PocketBase? _pb;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$_base$path').replace(queryParameters: q);

  Map<String, String> get _authHeaders {
    final token = _pb?.authStore.token;
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': token};
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? q,
    bool auth = false,
  ]) async {
    final res = await _client.get(
      _u(path, q),
      headers: auth ? _authHeaders : const {},
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth) ..._authHeaders,
    };
    final uri = _u(path);
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response res;
    switch (method) {
      case 'POST':
        res = await _client.post(uri, headers: headers, body: encoded);
      case 'PUT':
        res = await _client.put(uri, headers: headers, body: encoded);
      case 'PATCH':
        res = await _client.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        res = await _client.delete(uri, headers: headers);
      default:
        throw ArgumentError(method);
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> j = {};
    try {
      final d = jsonDecode(res.body);
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw VitrineApiException(
        '${j['error'] ?? 'Erro ${res.statusCode}'}',
        status: res.statusCode,
      );
    }
    return j;
  }

  Future<List<VitrineServico>> listServicos() async {
    final j = await _get('/api/cleanos/vitrine/servicos');
    final items = j['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) VitrineServico.fromJson(it),
    ];
  }

  Future<VitrineConfig> getConfig() async {
    final j = await _get('/api/cleanos/vitrine/config');
    return VitrineConfig.fromJson(j);
  }

  /// Boot: config + mídia (mapa por chave) + atuação.
  Future<VitrineBootstrap> bootstrap() async {
    final j = await _get('/api/cleanos/vitrine/bootstrap');
    final cfg = VitrineConfig.fromJson(
      j['config'] is Map<String, dynamic>
          ? j['config'] as Map<String, dynamic>
          : j,
    );
    final midiaRaw = j['midia'];
    final midia = <VitrineMidia>[];
    if (midiaRaw is List) {
      for (final it in midiaRaw) {
        if (it is Map<String, dynamic>) {
          midia.add(VitrineMidia.fromJson(it));
        }
      }
    }
    final at = j['atuacao'];
    var estado = '';
    var cidades = <String>[];
    if (at is Map<String, dynamic>) {
      estado = '${at['estado'] ?? ''}';
      final c = at['cidades'];
      if (c is List) cidades = c.map((e) => '$e').toList();
    }
    return VitrineBootstrap(
      config: cfg,
      midia: midia,
      estado: estado,
      cidades: cidades,
    );
  }

  Future<List<VitrineOrderBump>> orderBumps(List<String> servicoIds) async {
    final j = await _get('/api/cleanos/vitrine/order-bumps', {
      'servicos': servicoIds.join(','),
    });
    final items = j['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) VitrineOrderBump.fromJson(it),
    ];
  }

  Future<({String estado, List<String> cidades})> atuacao() async {
    final j = await _get('/api/cleanos/vitrine/atuacao');
    final c = j['cidades'];
    return (
      estado: '${j['estado'] ?? ''}',
      cidades: c is List ? c.map((e) => '$e').toList() : <String>[],
    );
  }

  Future<List<VitrineSlot>> slots({
    String? servicoId,
    required String dataYmd,
    int? duracaoMin,
  }) async {
    final q = <String, String>{'data': dataYmd};
    if (servicoId != null && servicoId.isNotEmpty) q['servico'] = servicoId;
    if (duracaoMin != null && duracaoMin > 0) {
      q['duracao'] = '$duracaoMin';
    }
    final j = await _get('/api/cleanos/vitrine/slots', q);
    final list = j['slots'];
    if (list is! List) return const [];
    return [
      for (final it in list)
        if (it is Map<String, dynamic>) VitrineSlot.fromJson(it),
    ];
  }

  Future<VitrineAgendarResult> agendar(Map<String, dynamic> body) async {
    final j = await _send('POST', '/api/cleanos/vitrine/agendar', body);
    return VitrineAgendarResult.fromJson(j);
  }

  // ── Admin ────────────────────────────────────────────────────────────────

  Future<VitrineConfig> adminGetConfig() async {
    final j = await _get('/api/cleanos/vitrine/admin/config', null, true);
    return VitrineConfig.fromJson(j);
  }

  Future<VitrineConfig> adminSaveConfig(VitrineConfig c) async {
    final j = await _send(
      'PUT',
      '/api/cleanos/vitrine/admin/config',
      c.toJson(),
      auth: true,
    );
    return VitrineConfig.fromJson(j);
  }

  Future<List<VitrineAdminServico>> adminListServicos() async {
    final j = await _get('/api/cleanos/vitrine/admin/servicos', null, true);
    final items = j['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) VitrineAdminServico.fromJson(it),
    ];
  }

  Future<void> adminPatchServico(
    String id, {
    bool? vitrine,
    bool? vitrineDestaque,
  }) async {
    await _send(
      'PATCH',
      '/api/cleanos/vitrine/admin/servicos/$id',
      {
        if (vitrine != null) 'vitrine': vitrine,
        if (vitrineDestaque != null) 'vitrine_destaque': vitrineDestaque,
      },
      auth: true,
    );
  }

  Future<List<VitrineOrderBump>> adminListBumps() async {
    final j = await _get('/api/cleanos/vitrine/admin/order-bumps', null, true);
    final items = j['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) VitrineOrderBump.fromJson(it),
    ];
  }

  Future<VitrineOrderBump> adminSaveBump(
    Map<String, dynamic> body, {
    String? id,
  }) async {
    final j = id == null || id.isEmpty
        ? await _send(
            'POST',
            '/api/cleanos/vitrine/admin/order-bumps',
            body,
            auth: true,
          )
        : await _send(
            'PUT',
            '/api/cleanos/vitrine/admin/order-bumps/$id',
            body,
            auth: true,
          );
    return VitrineOrderBump.fromJson(j);
  }

  Future<void> adminDeleteBump(String id) async {
    await _send(
      'DELETE',
      '/api/cleanos/vitrine/admin/order-bumps/$id',
      null,
      auth: true,
    );
  }

  Future<List<VitrineAgendamentoResumo>> adminAgendamentos() async {
    final j = await _get(
      '/api/cleanos/vitrine/admin/agendamentos',
      {'limit': '40'},
      true,
    );
    final items = j['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) VitrineAgendamentoResumo.fromJson(it),
    ];
  }

  Future<List<Map<String, dynamic>>> adminMidia() async {
    final j = await _get('/api/cleanos/vitrine/admin/midia', null, true);
    final items = j['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) it,
    ];
  }
}

/// Instância padrão (sem auth). Admin usa [vitrineApiWithPb].
final vitrineApiProvider = VitrineApi();

VitrineApi vitrineApiWithPb(PocketBase pb) => VitrineApi(pb: pb);
