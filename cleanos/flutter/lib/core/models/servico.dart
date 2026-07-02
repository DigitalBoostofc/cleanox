/// servico.dart — Porte do catálogo RICO de serviços e do snapshot congelado na OS.
///
/// Fonte: `web/src/lib/servicos/types.ts` (Categoria, Grupo, TipoValor, ServicoStatus,
/// ChecklistTemplateItem, ServiceSnapshot, Servico) + `ServicoPB` de collections.ts.
///
/// ⚠️ Convenção de chaves JSON:
///   - `ServicoPB` (coleção `servicos`) usa **snake_case** (valor_base, tipo_valor…).
///   - `ServiceSnapshot`/`ChecklistTemplateItem` são campos JSON GRAVADOS PELO HOOK
///     com **camelCase** (serviceId, valorBase, checklistPadrao…) — ver
///     `fillServiceSnapshot` em pb_hooks/os_logic.js. As chaves Dart espelham isso.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'servico.freezed.dart';
part 'servico.g.dart';

/* ---- Taxonomia ---- */

enum Categoria {
  @JsonValue('veicular')
  veicular,
  @JsonValue('residencial')
  residencial;

  String get wire => name;
}

enum Grupo {
  @JsonValue('plano')
  plano,
  @JsonValue('promocao')
  promocao,
  @JsonValue('adicional')
  adicional,
  @JsonValue('avulsos')
  avulsos,
  @JsonValue('sofa')
  sofa,
  @JsonValue('colchao')
  colchao,
  @JsonValue('outros')
  outros;

  String get wire => name;
}

enum TipoValor {
  @JsonValue('fixo')
  fixo,
  @JsonValue('faixa')
  faixa,
  @JsonValue('variavel')
  variavel;

  String get wire => name;
}

enum ServicoStatus {
  @JsonValue('ativo')
  ativo,
  @JsonValue('inativo')
  inativo;

  String get wire => name;
}

/* ---- Item do checklist PADRÃO (template do serviço) ---- */
@freezed
class ChecklistTemplateItem with _$ChecklistTemplateItem {
  const factory ChecklistTemplateItem({
    @Default('') String id,
    @Default('') String titulo,

    /// Ordem de exibição/execução (1-based).
    @Default(0) int ordem,

    /// Se true, DEVE estar concluído antes de concluir a OS.
    @Default(false) bool obrigatorio,
  }) = _ChecklistTemplateItem;

  factory ChecklistTemplateItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistTemplateItemFromJson(json);
}

/* ---- Snapshot congelado do serviço na OS (camelCase, gravado pelo hook) ---- */
@freezed
class ServiceSnapshot with _$ServiceSnapshot {
  const factory ServiceSnapshot({
    @Default('') String serviceId,
    @Default('') String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    @Default(0) double valorBase,
    double? valorBaseMax,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TipoValor? tipoValor,
    double? tempoMedioMin,
    @Default('') String tempoMedioLabel,

    /// Equivale a Servico.observacao no instante da captura.
    String? observacaoTecnica,
    @Default(<ChecklistTemplateItem>[])
    List<ChecklistTemplateItem> checklistPadrao,
    String? orientacoesPreServico,
    String? orientacoesPosServico,

    /// ISO datetime de quando o snapshot foi capturado.
    @Default('') String capturedAt,
  }) = _ServiceSnapshot;

  factory ServiceSnapshot.fromJson(Map<String, dynamic> json) =>
      _$ServiceSnapshotFromJson(json);
}

/* ---- Serviço do catálogo RICO (coleção `servicos`, snake_case) ---- */
@freezed
class ServicoPB with _$ServicoPB {
  const factory ServicoPB({
    required String id,
    @Default('') String slug,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    @Default('') String nome,
    String? descricao,
    @JsonKey(name: 'valor_base') @Default(0) double valorBase,
    @JsonKey(name: 'valor_base_max') double? valorBaseMax,
    @JsonKey(
      name: 'tipo_valor',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    TipoValor? tipoValor,
    @JsonKey(name: 'tempo_medio_min') double? tempoMedioMin,
    @JsonKey(name: 'tempo_medio_label') String? tempoMedioLabel,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ServicoStatus? status,
    String? observacao,
    @JsonKey(name: 'checklist_padrao')
    @Default(<ChecklistTemplateItem>[])
    List<ChecklistTemplateItem> checklistPadrao,
    @JsonKey(name: 'orientacoes_pre') String? orientacoesPre,
    @JsonKey(name: 'orientacoes_pos') String? orientacoesPos,
    @JsonKey(name: 'adicionais_relacionados')
    @Default(<String>[])
    List<String> adicionaisRelacionados,

    /// 🔁 legado sincronizado = valor_base.
    @JsonKey(name: 'preco_base') @Default(0) double precoBase,

    /// 🔁 legado sincronizado = (status === 'ativo').
    @Default(false) bool ativo,
    String? created,
    String? updated,
  }) = _ServicoPB;

  const ServicoPB._();

  factory ServicoPB.fromJson(Map<String, dynamic> json) =>
      _$ServicoPBFromJson(json);

  factory ServicoPB.fromRecord(RecordModel record) =>
      ServicoPB.fromJson(record.toJson());
}
