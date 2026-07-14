/// cliente.dart — 🔒 COFRE. Porte de `Cliente` de collections.ts.
///
/// ANTI-DESVIO: este modelo carrega dados SENSÍVEIS (telefone, e-mail, endereço
/// completo). SÓ o Painel (admin/gerente) injeta/consome `ClientesRepository`.
/// O app do profissional NUNCA importa este modelo nem a coleção `clientes`
/// (negada por regra de servidor). Ver `guardOrdemUpdateRequest` / regras PB.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'cliente.freezed.dart';
part 'cliente.g.dart';

@freezed
class Cliente with _$Cliente {
  const factory Cliente({
    required String id,
    @Default('') String nome,
    String? sobrenome,

    /// SENSÍVEL — nunca exposto ao profissional.
    @Default('') String telefone,
    String? email,
    @JsonKey(name: 'endereco_rua') String? enderecoRua,
    @JsonKey(name: 'endereco_numero') String? enderecoNumero,
    @JsonKey(name: 'endereco_complemento') String? enderecoComplemento,

    /// Seguro — vira `bairro` na OS via hook.
    @JsonKey(name: 'endereco_bairro') @Default('') String enderecoBairro,
    @JsonKey(name: 'endereco_cidade') String? enderecoCidade,
    @JsonKey(name: 'endereco_estado') String? enderecoEstado,
    @JsonKey(name: 'endereco_cep') String? enderecoCep,
    @Default(true) bool ativo,

    /// Origem do lead (Instagram, Facebook, Indicação…). Opcional; "" = não
    /// informado. Alimenta relatório de origem e a atribuição do Meta CAPI.
    String? origem,
    String? observacoes,
    String? created,
    String? updated,
  }) = _Cliente;

  const Cliente._();

  factory Cliente.fromJson(Map<String, dynamic> json) =>
      _$ClienteFromJson(json);

  factory Cliente.fromRecord(RecordModel record) =>
      Cliente.fromJson(record.toJson());

  /// Origens possíveis do lead (slug persistido, rótulo exibido), na ordem de
  /// exibição. Fonte única: espelha o SelectField `clientes.origem` do PB e
  /// alimenta tanto o dropdown do form quanto a lista/card.
  static const List<(String, String)> origemOpcoes = [
    ('instagram', 'Instagram'),
    ('facebook', 'Facebook'),
    ('google', 'Google'),
    ('site', 'Site'),
    ('indicacao', 'Indicação'),
    ('whatsapp', 'WhatsApp'),
    ('parceria', 'Parceria'),
    ('outro', 'Outro'),
  ];

  /// Rótulo amigável da origem, ou `null` quando não informada.
  String? get origemLabel {
    final o = (origem ?? '').trim();
    if (o.isEmpty) return null;
    for (final (slug, rotulo) in origemOpcoes) {
      if (slug == o) return rotulo;
    }
    return o;
  }

  /// "Carlos", "Silva" → "Carlos S." (espelha `shortName` do hook — nunca expõe
  /// o sobrenome inteiro). É o que o servidor denormaliza em `nome_curto`.
  String get nomeCurto {
    final n = nome.trim();
    final s = (sobrenome ?? '').trim();
    if (s.isEmpty) return n;
    return '$n ${s[0].toUpperCase()}.';
  }
}
