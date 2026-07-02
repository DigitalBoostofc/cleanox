/// whatsapp_config_repository.dart — Templates de mensagem automática (WhatsApp).
///
/// A INTERFACE congelada do core (`WhatsAppRepository`) cobre a CONEXÃO da
/// instância (status/connect/disconnect) mas NÃO os templates de mensagem — que
/// vivem em `/api/cleanos/whatsapp/config`. Como o core está congelado (não posso
/// alterá-lo), este contrato dos templates fica na camada de dados do Painel, ao
/// lado da impl PB de conexão (`pb_painel_whatsapp_repository.dart`).
///
/// Rotas (ver `pb_hooks/ratings_routes.pb.js`):
///   GET  /api/cleanos/whatsapp/config  → admin/gerente — estado dos 7 templates
///   POST /api/cleanos/whatsapp/config  → SÓ admin — grava o subconjunto enviado
///
/// Inclui os 3 templates de rastreamento "estou a caminho" do doc 09 §3
/// (`aviso_5min_texto`, `aviso_1min_texto`, `aviso_cheguei_texto`).
library;

import 'package:pocketbase/pocketbase.dart';

/// Prefixo das rotas custom do CleanOS (espelha o web: `/api/cleanos/...`).
const String _base = '/api/cleanos';

/// Os 7 templates de mensagem automática editáveis pelo admin. Espelha 1:1 as
/// chaves de `/whatsapp/config` do backend. Todos são texto livre com placeholders
/// `{nome}`/`{servico}` resolvidos server-side no envio.
class WhatsAppTemplates {
  const WhatsAppTemplates({
    this.avisoTemplate = '',
    this.avaliacaoPollTexto = '',
    this.avaliacaoMotivoTexto = '',
    this.avaliacaoAgradecimento = '',
    this.aviso5minTexto = '',
    this.aviso1minTexto = '',
    this.avisoChegueiTexto = '',
  });

  /// Aviso "estou a caminho" (disparo manual pelo profissional).
  final String avisoTemplate;

  /// Enquete de avaliação (pergunta da nota).
  final String avaliacaoPollTexto;

  /// Pergunta do motivo (notas 1–3).
  final String avaliacaoMotivoTexto;

  /// Mensagem de agradecimento pós-avaliação.
  final String avaliacaoAgradecimento;

  /// doc 09 §3 — aviso automático "chega em ~5 min" (cron de rastreamento).
  final String aviso5minTexto;

  /// doc 09 §3 — aviso automático "chega em ~1 min" (cron de rastreamento).
  final String aviso1minTexto;

  /// doc 09 §3 — aviso "cheguei ao local" (POST /cheguei).
  final String avisoChegueiTexto;

  static const WhatsAppTemplates empty = WhatsAppTemplates();

  factory WhatsAppTemplates.fromJson(Map<String, dynamic> json) {
    String s(String k) => (json[k] as String?) ?? '';
    return WhatsAppTemplates(
      avisoTemplate: s('aviso_template'),
      avaliacaoPollTexto: s('avaliacao_poll_texto'),
      avaliacaoMotivoTexto: s('avaliacao_motivo_texto'),
      avaliacaoAgradecimento: s('avaliacao_agradecimento'),
      aviso5minTexto: s('aviso_5min_texto'),
      aviso1minTexto: s('aviso_1min_texto'),
      avisoChegueiTexto: s('aviso_cheguei_texto'),
    );
  }

  /// Corpo do POST — envia todos os campos (o backend só grava os presentes).
  Map<String, dynamic> toBody() => {
    'aviso_template': avisoTemplate,
    'avaliacao_poll_texto': avaliacaoPollTexto,
    'avaliacao_motivo_texto': avaliacaoMotivoTexto,
    'avaliacao_agradecimento': avaliacaoAgradecimento,
    'aviso_5min_texto': aviso5minTexto,
    'aviso_1min_texto': aviso1minTexto,
    'aviso_cheguei_texto': avisoChegueiTexto,
  };

  WhatsAppTemplates copyWith({
    String? avisoTemplate,
    String? avaliacaoPollTexto,
    String? avaliacaoMotivoTexto,
    String? avaliacaoAgradecimento,
    String? aviso5minTexto,
    String? aviso1minTexto,
    String? avisoChegueiTexto,
  }) => WhatsAppTemplates(
    avisoTemplate: avisoTemplate ?? this.avisoTemplate,
    avaliacaoPollTexto: avaliacaoPollTexto ?? this.avaliacaoPollTexto,
    avaliacaoMotivoTexto: avaliacaoMotivoTexto ?? this.avaliacaoMotivoTexto,
    avaliacaoAgradecimento:
        avaliacaoAgradecimento ?? this.avaliacaoAgradecimento,
    aviso5minTexto: aviso5minTexto ?? this.aviso5minTexto,
    aviso1minTexto: aviso1minTexto ?? this.aviso1minTexto,
    avisoChegueiTexto: avisoChegueiTexto ?? this.avisoChegueiTexto,
  );
}

/// Contrato de leitura/gravação dos templates (injetado por Riverpod). A UI
/// depende da abstração, nunca da impl PB.
abstract class WhatsAppConfigRepository {
  /// GET /whatsapp/config — estado atual dos 7 templates (admin/gerente).
  Future<WhatsAppTemplates> load();

  /// POST /whatsapp/config — grava os templates (SÓ admin). Retorna o estado
  /// completo após a atualização.
  Future<WhatsAppTemplates> save(WhatsAppTemplates templates);
}

/// Impl sobre o SDK PocketBase via `pb.send` (o Authorization vai automático).
class PbWhatsAppConfigRepository implements WhatsAppConfigRepository {
  PbWhatsAppConfigRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<WhatsAppTemplates> load() async {
    final res = await _pb.send<Map<String, dynamic>>('$_base/whatsapp/config');
    return WhatsAppTemplates.fromJson(res);
  }

  @override
  Future<WhatsAppTemplates> save(WhatsAppTemplates templates) async {
    final res = await _pb.send<Map<String, dynamic>>(
      '$_base/whatsapp/config',
      method: 'POST',
      body: templates.toBody(),
    );
    return WhatsAppTemplates.fromJson(res);
  }
}
