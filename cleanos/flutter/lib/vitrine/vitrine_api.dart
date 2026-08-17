/// Cliente HTTP da vitrine → rotas públicas + admin PocketBase `/api/cleanos/vitrine/*`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../core/env/env.dart';
import 'widgets/vitrine_hero_catalogo.dart';

enum VitrineServicoLayout {
  destaque('destaque'),
  fotografico('fotografico'),
  antesDepois('antes_depois'),
  compacto('compacto');

  const VitrineServicoLayout(this.apiValue);
  final String apiValue;

  static VitrineServicoLayout parse(dynamic value) => values.firstWhere(
    (item) => item.apiValue == '$value',
    orElse: () => VitrineServicoLayout.fotografico,
  );
}

enum VitrinePrecoModo {
  valor('valor'),
  aPartirDe('a_partir_de'),
  sobAvaliacao('sob_avaliacao'),
  ocultar('ocultar');

  const VitrinePrecoModo(this.apiValue);
  final String apiValue;

  static VitrinePrecoModo parse(dynamic value) => values.firstWhere(
    (item) => item.apiValue == '$value',
    orElse: () => VitrinePrecoModo.aPartirDe,
  );
}

class VitrineServico {
  const VitrineServico({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.categoria,
    required this.grupo,
    this.subgrupo = '', // legado: parse da API; a vitrine não filtra por ele
    required this.valorBase,
    required this.valorBaseMax,
    required this.tempoMedioMin,
    required this.tempoMedioLabel,
    required this.orientacoesPre,
    this.vitrineDestaque = false,
    this.layout = VitrineServicoLayout.fotografico,
    this.vitrineTitulo = '',
    this.vitrineDescricao = '',
    this.vitrineBadge = '',
    this.vitrineCta = '',
    this.precoModo = VitrinePrecoModo.aPartirDe,
    this.vitrineOrdem = 0,
  });

  final String id;
  final String nome;
  final String descricao;
  final String categoria;
  final String grupo;
  final String subgrupo;
  final double valorBase;
  final double valorBaseMax;
  final int tempoMedioMin;
  final String tempoMedioLabel;
  final String orientacoesPre;
  final bool vitrineDestaque;
  final VitrineServicoLayout layout;
  final String vitrineTitulo;
  final String vitrineDescricao;
  final String vitrineBadge;
  final String vitrineCta;
  final VitrinePrecoModo precoModo;
  final int vitrineOrdem;

  String get tituloComercial =>
      vitrineTitulo.trim().isNotEmpty ? vitrineTitulo.trim() : nome;
  String get descricaoComercial =>
      vitrineDescricao.trim().isNotEmpty ? vitrineDescricao.trim() : descricao;
  String get ctaComercial =>
      vitrineCta.trim().isNotEmpty ? vitrineCta.trim() : 'Adicionar';

  factory VitrineServico.fromJson(Map<String, dynamic> j) => VitrineServico(
    id: '${j['id'] ?? ''}',
    nome: '${j['nome'] ?? ''}',
    descricao: '${j['descricao'] ?? ''}',
    categoria: '${j['categoria'] ?? ''}',
    grupo: '${j['grupo'] ?? ''}',
    subgrupo: '${j['subgrupo'] ?? ''}',
    valorBase: (j['valor_base'] as num?)?.toDouble() ?? 0,
    valorBaseMax: (j['valor_base_max'] as num?)?.toDouble() ?? 0,
    tempoMedioMin: (j['tempo_medio_min'] as num?)?.toInt() ?? 0,
    tempoMedioLabel: '${j['tempo_medio_label'] ?? ''}',
    orientacoesPre: '${j['orientacoes_pre'] ?? ''}',
    vitrineDestaque: j['vitrine_destaque'] == true,
    layout: VitrineServicoLayout.parse(j['vitrine_layout']),
    vitrineTitulo: '${j['vitrine_titulo'] ?? ''}',
    vitrineDescricao: '${j['vitrine_descricao'] ?? ''}',
    vitrineBadge: '${j['vitrine_badge'] ?? ''}',
    vitrineCta: '${j['vitrine_cta'] ?? ''}',
    precoModo: VitrinePrecoModo.parse(j['vitrine_preco_modo']),
    vitrineOrdem: (j['vitrine_ordem'] as num?)?.toInt() ?? 0,
  );
}

class VitrineSlot {
  const VitrineSlot({required this.hora, required this.token});
  final String hora;
  final String token;

  factory VitrineSlot.fromJson(Map<String, dynamic> j) =>
      VitrineSlot(hora: '${j['hora'] ?? ''}', token: '${j['token'] ?? ''}');
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
    this.servicoId = '',
    this.papel = '',
    this.parId = '',
    this.legenda = '',
    this.focoX = 50,
    this.focoY = 50,
  });

  final String id;
  final String chave;
  final String titulo;
  final String url;
  final int ordem;
  final String servicoId;
  final String papel;
  final String parId;
  final String legenda;
  final double focoX;
  final double focoY;

  double get alignmentX => (focoX.clamp(0, 100) - 50) / 50;
  double get alignmentY => (focoY.clamp(0, 100) - 50) / 50;

  factory VitrineMidia.fromJson(Map<String, dynamic> j) => VitrineMidia(
    id: '${j['id'] ?? ''}',
    chave: '${j['chave'] ?? ''}',
    titulo: '${j['titulo'] ?? ''}',
    url: '${j['url'] ?? j['url_externa'] ?? ''}',
    ordem: (j['ordem'] as num?)?.toInt() ?? 0,
    servicoId: '${j['servico'] ?? ''}',
    papel: '${j['papel'] ?? ''}',
    parId: '${j['par_id'] ?? ''}',
    legenda: '${j['legenda'] ?? ''}',
    focoX: (j['foco_x'] as num?)?.toDouble() ?? 50,
    focoY: (j['foco_y'] as num?)?.toDouble() ?? 50,
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

  List<VitrineMidia> midiaDoServico(String servicoId, {String? papel}) => [
    for (final item in midia)
      if (item.servicoId == servicoId &&
          (papel == null || item.papel == papel) &&
          item.url.isNotEmpty)
        item,
  ]..sort((a, b) {
      final pa = a.papel == 'capa' ? 0 : (a.papel == 'antes' ? 1 : 2);
      final pb = b.papel == 'capa' ? 0 : (b.papel == 'antes' ? 1 : 2);
      if (pa != pb) return pa - pb;
      return a.ordem.compareTo(b.ordem);
    });

  VitrineMidia? capaDoServico(String servicoId) {
    final capas = midiaDoServico(servicoId, papel: 'capa');
    if (capas.isNotEmpty) return capas.first;
    final todas = midiaDoServico(servicoId);
    return todas.isEmpty ? null : todas.first;
  }
}

class VitrineConfig {
  const VitrineConfig({
    this.id = '',
    this.heroTitulo = 'Agende seu serviço',
    this.heroSubtitulo =
        'Escolha o que precisa limpar e marque data e horário',
    this.heroCta = 'Agendar agora',
    this.heroCtaAtivo = true,
    this.whatsappExibido = '',
    this.rodapeMsg = 'Pagamento só no local · maquininha Cleanox',
    this.cidadesTexto = '',
    this.comoFunciona =
        '1) Selecione os serviços\n'
        '2) Escolha data e horário\n'
        '3) Informe contato e endereço\n'
        '4) Revise e confirme\n'
        '5) OS criada — a Cleanox atribui a equipe',
    this.capacidadeSimultanea = 0,
    this.horarioInicio = '08:00',
    this.horarioFim = '18:00',
    this.passoMin = 30,
    this.antecedenciaMinutos = 60,
    this.horizonteDias = 14,
    this.macroAutoPrimeiro = true,
    this.macroResidTitulo = 'Higienização residencial',
    this.macroResidSubtitulo = 'Sofá, colchão, poltrona, tapete e mais',
    this.macroResidIcone = 'cleaning',
    this.macroAutoTitulo = 'Estética automotiva',
    this.macroAutoSubtitulo = 'Bancos, teto, carpete e pacotes Cleanox',
    this.macroAutoIcone = 'car',
    this.homeDestaquesTitulo = 'Ofertas em destaque',
    this.homeDestaquesCta = 'Ver todos',
    this.homeDestaquesAtivo = true,
    this.heroCatalogo = const VitrineHeroCatalogo(),
  });

  final String id;
  final String heroTitulo;
  final String heroSubtitulo;
  final String heroCta;
  final bool heroCtaAtivo;
  final String whatsappExibido;
  final String rodapeMsg;
  final String cidadesTexto;
  final String comoFunciona;
  final int capacidadeSimultanea;
  final String horarioInicio;
  final String horarioFim;
  final int passoMin;
  final int antecedenciaMinutos;
  final int horizonteDias;
  final bool macroAutoPrimeiro;
  final String macroResidTitulo;
  final String macroResidSubtitulo;
  final String macroResidIcone;
  final String macroAutoTitulo;
  final String macroAutoSubtitulo;
  final String macroAutoIcone;
  final String homeDestaquesTitulo;
  final String homeDestaquesCta;
  final bool homeDestaquesAtivo;
  final VitrineHeroCatalogo heroCatalogo;

  factory VitrineConfig.fromJson(Map<String, dynamic> j) => VitrineConfig(
    id: '${j['id'] ?? ''}',
    heroTitulo: '${j['hero_titulo'] ?? 'Agende seu serviço'}',
    heroSubtitulo:
        '${j['hero_subtitulo'] ?? 'Escolha o que precisa limpar e marque data e horário'}',
    heroCta: '${j['hero_cta'] ?? 'Agendar agora'}',
    heroCtaAtivo: _boolCfg(j['hero_cta_ativo'], true),
    whatsappExibido: '${j['whatsapp_exibido'] ?? ''}',
    rodapeMsg:
        '${j['rodape_msg'] ?? 'Pagamento só no local · maquininha Cleanox'}',
    cidadesTexto: '${j['cidades_texto'] ?? ''}',
    comoFunciona: '${j['como_funciona'] ?? ''}',
    capacidadeSimultanea: (j['capacidade_simultanea'] as num?)?.toInt() ?? 0,
    horarioInicio: '${j['horario_inicio'] ?? '08:00'}',
    horarioFim: '${j['horario_fim'] ?? '18:00'}',
    passoMin: (j['passo_min'] as num?)?.toInt() ?? 30,
    antecedenciaMinutos: (j['antecedencia_minutos'] as num?)?.toInt() ?? 60,
    horizonteDias: (j['horizonte_dias'] as num?)?.toInt() ?? 14,
    macroAutoPrimeiro: _boolCfg(j['macro_auto_primeiro'], true),
    macroResidTitulo:
        '${j['macro_resid_titulo'] ?? 'Higienização residencial'}',
    macroResidSubtitulo:
        '${j['macro_resid_subtitulo'] ?? 'Sofá, colchão, poltrona, tapete e mais'}',
    macroResidIcone: '${j['macro_resid_icone'] ?? 'cleaning'}',
    macroAutoTitulo: '${j['macro_auto_titulo'] ?? 'Estética automotiva'}',
    macroAutoSubtitulo:
        '${j['macro_auto_subtitulo'] ?? 'Bancos, teto, carpete e pacotes Cleanox'}',
    macroAutoIcone: '${j['macro_auto_icone'] ?? 'car'}',
    homeDestaquesTitulo:
        '${j['home_destaques_titulo'] ?? 'Ofertas em destaque'}',
    homeDestaquesCta: '${j['home_destaques_cta'] ?? 'Ver todos'}',
    homeDestaquesAtivo: _boolCfg(j['home_destaques_ativo'], true),
    heroCatalogo: VitrineHeroCatalogo.parse(j['hero_catalogo_json']),
  );

  Map<String, dynamic> toJson() => {
    'hero_titulo': heroTitulo,
    'hero_subtitulo': heroSubtitulo,
    'hero_cta': heroCta,
    'hero_cta_ativo': heroCtaAtivo,
    'whatsapp_exibido': whatsappExibido,
    'rodape_msg': rodapeMsg,
    'cidades_texto': cidadesTexto,
    'como_funciona': comoFunciona,
    'capacidade_simultanea': capacidadeSimultanea,
    'horario_inicio': horarioInicio,
    'horario_fim': horarioFim,
    'passo_min': passoMin,
    'antecedencia_minutos': antecedenciaMinutos,
    'horizonte_dias': horizonteDias,
    'macro_auto_primeiro': macroAutoPrimeiro,
    'macro_resid_titulo': macroResidTitulo,
    'macro_resid_subtitulo': macroResidSubtitulo,
    'macro_resid_icone': macroResidIcone,
    'macro_auto_titulo': macroAutoTitulo,
    'macro_auto_subtitulo': macroAutoSubtitulo,
    'macro_auto_icone': macroAutoIcone,
    'home_destaques_titulo': homeDestaquesTitulo,
    'home_destaques_cta': homeDestaquesCta,
    'home_destaques_ativo': homeDestaquesAtivo,
    'hero_catalogo_json': heroCatalogo.encode(),
  };

  VitrineConfig copyWith({
    String? heroTitulo,
    String? heroSubtitulo,
    String? heroCta,
    bool? heroCtaAtivo,
    String? whatsappExibido,
    String? rodapeMsg,
    String? cidadesTexto,
    String? comoFunciona,
    int? capacidadeSimultanea,
    String? horarioInicio,
    String? horarioFim,
    int? passoMin,
    int? antecedenciaMinutos,
    int? horizonteDias,
    bool? macroAutoPrimeiro,
    String? macroResidTitulo,
    String? macroResidSubtitulo,
    String? macroResidIcone,
    String? macroAutoTitulo,
    String? macroAutoSubtitulo,
    String? macroAutoIcone,
    String? homeDestaquesTitulo,
    String? homeDestaquesCta,
    bool? homeDestaquesAtivo,
    VitrineHeroCatalogo? heroCatalogo,
  }) => VitrineConfig(
    id: id,
    heroTitulo: heroTitulo ?? this.heroTitulo,
    heroSubtitulo: heroSubtitulo ?? this.heroSubtitulo,
    heroCta: heroCta ?? this.heroCta,
    heroCtaAtivo: heroCtaAtivo ?? this.heroCtaAtivo,
    whatsappExibido: whatsappExibido ?? this.whatsappExibido,
    rodapeMsg: rodapeMsg ?? this.rodapeMsg,
    cidadesTexto: cidadesTexto ?? this.cidadesTexto,
    comoFunciona: comoFunciona ?? this.comoFunciona,
    capacidadeSimultanea: capacidadeSimultanea ?? this.capacidadeSimultanea,
    horarioInicio: horarioInicio ?? this.horarioInicio,
    horarioFim: horarioFim ?? this.horarioFim,
    passoMin: passoMin ?? this.passoMin,
    antecedenciaMinutos: antecedenciaMinutos ?? this.antecedenciaMinutos,
    horizonteDias: horizonteDias ?? this.horizonteDias,
    macroAutoPrimeiro: macroAutoPrimeiro ?? this.macroAutoPrimeiro,
    macroResidTitulo: macroResidTitulo ?? this.macroResidTitulo,
    macroResidSubtitulo: macroResidSubtitulo ?? this.macroResidSubtitulo,
    macroResidIcone: macroResidIcone ?? this.macroResidIcone,
    macroAutoTitulo: macroAutoTitulo ?? this.macroAutoTitulo,
    macroAutoSubtitulo: macroAutoSubtitulo ?? this.macroAutoSubtitulo,
    macroAutoIcone: macroAutoIcone ?? this.macroAutoIcone,
    homeDestaquesTitulo: homeDestaquesTitulo ?? this.homeDestaquesTitulo,
    homeDestaquesCta: homeDestaquesCta ?? this.homeDestaquesCta,
    homeDestaquesAtivo: homeDestaquesAtivo ?? this.homeDestaquesAtivo,
    heroCatalogo: heroCatalogo ?? this.heroCatalogo,
  );
}

bool _boolCfg(Object? v, bool fallback) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'sim') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'nao' || s == 'não') {
      return false;
    }
  }
  return fallback;
}

class VitrineAgendarResult {
  const VitrineAgendarResult({
    required this.osRef,
    required this.data,
    required this.hora,
    required this.servico,
    required this.valor,
    required this.mensagem,
    this.bairro = '',
    this.cidade = '',
  });

  final String osRef;
  final String data;
  final String hora;
  final String servico;
  final double valor;
  final String mensagem;
  final String bairro;
  final String cidade;

  factory VitrineAgendarResult.fromJson(Map<String, dynamic> j) =>
      VitrineAgendarResult(
        osRef: '${j['os_ref'] ?? ''}',
        data: '${j['data'] ?? ''}',
        hora: '${j['hora'] ?? ''}',
        servico: '${j['servico'] ?? ''}',
        valor: (j['valor'] as num?)?.toDouble() ?? 0,
        mensagem: '${j['mensagem'] ?? ''}',
        bairro: '${j['bairro'] ?? ''}',
        cidade: '${j['cidade'] ?? ''}',
      );
}

class VitrineAdminServico {
  const VitrineAdminServico({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.categoria,
    required this.valorBase,
    required this.vitrine,
    required this.vitrineDestaque,
    required this.ativo,
    this.layout = VitrineServicoLayout.fotografico,
    this.vitrineTitulo = '',
    this.vitrineDescricao = '',
    this.vitrineBadge = '',
    this.vitrineCta = '',
    this.precoModo = VitrinePrecoModo.aPartirDe,
    this.vitrineOrdem = 0,
  });

  final String id;
  final String nome;
  final String grupo;
  final String categoria;
  final double valorBase;
  final bool vitrine;
  final bool vitrineDestaque;
  final bool ativo;
  final VitrineServicoLayout layout;
  final String vitrineTitulo;
  final String vitrineDescricao;
  final String vitrineBadge;
  final String vitrineCta;
  final VitrinePrecoModo precoModo;
  final int vitrineOrdem;

  /// Macro canônica: `veicular` | `residencial` | `outros`.
  String get macroCategoria {
    final c = categoria.trim().toLowerCase();
    final g = grupo.trim().toLowerCase();
    if (c == 'veicular' ||
        c.contains('veic') ||
        c.contains('auto') ||
        g.contains('auto')) {
      return 'veicular';
    }
    if (c == 'residencial' ||
        c.contains('resid') ||
        c.contains('domic') ||
        {
          'sofa',
          'sofá',
          'colchao',
          'colchão',
          'poltrona',
          'tapete',
          'cadeira',
          'cama',
        }.any((k) => g.contains(k))) {
      return 'residencial';
    }
    if (c.isEmpty && g.isEmpty) return 'outros';
    // Cadastro antigo sem categoria: se não parece auto, trata como residencial.
    if (c.isEmpty) return 'residencial';
    return 'outros';
  }

  factory VitrineAdminServico.fromJson(Map<String, dynamic> j) =>
      VitrineAdminServico(
        id: '${j['id'] ?? ''}',
        nome: '${j['nome'] ?? ''}',
        grupo: '${j['grupo'] ?? ''}',
        categoria: '${j['categoria'] ?? ''}',
        valorBase: (j['valor_base'] as num?)?.toDouble() ?? 0,
        vitrine: j['vitrine'] != false,
        vitrineDestaque: j['vitrine_destaque'] == true,
        ativo: j['ativo'] == true,
        layout: VitrineServicoLayout.parse(j['vitrine_layout']),
        vitrineTitulo: '${j['vitrine_titulo'] ?? ''}',
        vitrineDescricao: '${j['vitrine_descricao'] ?? ''}',
        vitrineBadge: '${j['vitrine_badge'] ?? ''}',
        vitrineCta: '${j['vitrine_cta'] ?? ''}',
        precoModo: VitrinePrecoModo.parse(j['vitrine_preco_modo']),
        vitrineOrdem: (j['vitrine_ordem'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toPatchJson() => {
    'vitrine': vitrine,
    'vitrine_destaque': vitrineDestaque,
    'vitrine_layout': layout.apiValue,
    'vitrine_titulo': vitrineTitulo,
    'vitrine_descricao': vitrineDescricao,
    'vitrine_badge': vitrineBadge,
    'vitrine_cta': vitrineCta,
    'vitrine_preco_modo': precoModo.apiValue,
    'vitrine_ordem': vitrineOrdem,
  };

  VitrineAdminServico copyWith({
    bool? vitrine,
    bool? vitrineDestaque,
    bool? ativo,
    VitrineServicoLayout? layout,
    String? vitrineTitulo,
    String? vitrineDescricao,
    String? vitrineBadge,
    String? vitrineCta,
    VitrinePrecoModo? precoModo,
    int? vitrineOrdem,
  }) =>
      VitrineAdminServico(
        id: id,
        nome: nome,
        grupo: grupo,
        categoria: categoria,
        valorBase: valorBase,
        vitrine: vitrine ?? this.vitrine,
        vitrineDestaque: vitrineDestaque ?? this.vitrineDestaque,
        ativo: ativo ?? this.ativo,
        layout: layout ?? this.layout,
        vitrineTitulo: vitrineTitulo ?? this.vitrineTitulo,
        vitrineDescricao: vitrineDescricao ?? this.vitrineDescricao,
        vitrineBadge: vitrineBadge ?? this.vitrineBadge,
        vitrineCta: vitrineCta ?? this.vitrineCta,
        precoModo: precoModo ?? this.precoModo,
        vitrineOrdem: vitrineOrdem ?? this.vitrineOrdem,
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
      _base = (baseUrl ?? pb?.baseURL ?? Env.pbUrl).replaceAll(
        RegExp(r'/$'),
        '',
      ),
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
    VitrineServicoLayout? layout,
    String? vitrineTitulo,
    String? vitrineDescricao,
    String? vitrineBadge,
    String? vitrineCta,
    VitrinePrecoModo? precoModo,
    int? vitrineOrdem,
  }) async {
    await _send('PATCH', '/api/cleanos/vitrine/admin/servicos/$id', {
      if (vitrine != null) 'vitrine': vitrine,
      if (vitrineDestaque != null) 'vitrine_destaque': vitrineDestaque,
      if (layout != null) 'vitrine_layout': layout.apiValue,
      if (vitrineTitulo != null) 'vitrine_titulo': vitrineTitulo,
      if (vitrineDescricao != null) 'vitrine_descricao': vitrineDescricao,
      if (vitrineBadge != null) 'vitrine_badge': vitrineBadge,
      if (vitrineCta != null) 'vitrine_cta': vitrineCta,
      if (precoModo != null) 'vitrine_preco_modo': precoModo.apiValue,
      if (vitrineOrdem != null) 'vitrine_ordem': vitrineOrdem,
    }, auth: true);
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
    final j = await _get('/api/cleanos/vitrine/admin/agendamentos', {
      'limit': '40',
    }, true);
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
