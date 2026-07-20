/// os_execucao.dart — Campos JSON RICOS da execução da OS (marcáveis pelo profissional).
///
/// Fonte: `web/src/lib/servicos/types.ts` — ChecklistExecItem, ServicoAdicionalOS,
/// ObservacaoProfissional, EvidenciaFoto, FaseFoto. Chaves JSON em **camelCase**
/// (é a UI/relatório que consome estes objetos, gravados como JSONField na OS).
///
/// Inclui também `OSEvidenciaPB` (coleção `os_evidencias`, snake_case) e o mapper
/// para `EvidenciaFoto`, espelhando `evidenciaToFoto` de os/osStore.ts.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'servico.dart';

part 'os_execucao.freezed.dart';
part 'os_execucao.g.dart';

/* ---- Checklist de execução (marcável pelo profissional) ---- */

enum ChecklistExecStatus {
  @JsonValue('pendente')
  pendente,
  @JsonValue('concluido')
  concluido;

  String get wire => name;
}

@freezed
class ChecklistExecItem with _$ChecklistExecItem {
  const factory ChecklistExecItem({
    @Default('') String id,
    @Default('') String titulo,
    @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
    @Default(ChecklistExecStatus.pendente)
    ChecklistExecStatus status,
    String? observacao,

    /// ISO datetime de conclusão.
    String? concluidoEm,
    String? concluidoPor,

    /// IDs de EvidenciaFoto vinculadas a este item.
    @Default(<String>[]) List<String> fotosIds,

    /// Propagado do template: bloqueia conclusão da OS enquanto pendente.
    @Default(false) bool obrigatorio,

    /// Quando preenchido, o item pertence ao checklist de um serviço EXTRA
    /// (`adicionais[].id`) — a UI mostra em seção separada do checklist principal.
    String? adicionalId,
  }) = _ChecklistExecItem;

  const ChecklistExecItem._();

  factory ChecklistExecItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistExecItemFromJson(json);

  bool get concluido => status == ChecklistExecStatus.concluido;
}

/* ---- Serviços adicionais na OS ---- */

enum AprovacaoStatus {
  @JsonValue('nao_requer')
  naoRequer,
  @JsonValue('aguardando')
  aguardando,
  @JsonValue('aprovado')
  aprovado,
  @JsonValue('recusado')
  recusado;

  String get wire => switch (this) {
    AprovacaoStatus.naoRequer => 'nao_requer',
    AprovacaoStatus.aguardando => 'aguardando',
    AprovacaoStatus.aprovado => 'aprovado',
    AprovacaoStatus.recusado => 'recusado',
  };
}

@freezed
class ServicoAdicionalOS with _$ServicoAdicionalOS {
  const factory ServicoAdicionalOS({
    @Default('') String id,

    /// Presente quando o adicional veio do catálogo de serviços.
    String? serviceId,
    @Default('') String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    @Default(0) double valor,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TipoValor? tipoValor,
    @Default(1) int quantidade,
    String? motivo,
    String? observacao,
    @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
    @Default(AprovacaoStatus.naoRequer)
    AprovacaoStatus aprovacao,
  }) = _ServicoAdicionalOS;

  factory ServicoAdicionalOS.fromJson(Map<String, dynamic> json) =>
      _$ServicoAdicionalOSFromJson(json);
}

/* ---- Observações técnicas do profissional ---- */

enum ObservacaoTipo {
  @JsonValue('geral')
  geral,
  @JsonValue('ponto')
  ponto,
  @JsonValue('limitacao')
  limitacao,
  @JsonValue('recomendacao')
  recomendacao,
  @JsonValue('intercorrencia')
  intercorrencia,
  @JsonValue('revisao')
  revisao;

  String get wire => name;
}

@freezed
class ObservacaoProfissional with _$ObservacaoProfissional {
  const factory ObservacaoProfissional({
    @Default('') String id,
    @Default('') String texto,

    /// Se true, aparece no relatório final ao cliente.
    @Default(false) bool visivelCliente,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ObservacaoTipo? tipo,
    String? criadoPor,

    /// ISO datetime.
    @Default('') String criadoEm,
    @Default(<String>[]) List<String> fotosIds,
  }) = _ObservacaoProfissional;

  factory ObservacaoProfissional.fromJson(Map<String, dynamic> json) =>
      _$ObservacaoProfissionalFromJson(json);
}

/* ---- Evidências (fotos antes/durante/depois) ---- */

enum FaseFoto {
  @JsonValue('antes')
  antes,
  @JsonValue('durante')
  durante,
  @JsonValue('depois')
  depois;

  String get wire => name;

  String get label => switch (this) {
    FaseFoto.antes => 'Antes',
    FaseFoto.durante => 'Durante',
    FaseFoto.depois => 'Depois',
  };
}

/// Tipo de DOMÍNIO da evidência (mapeado de OSEvidenciaPB via `evidenciaToFoto`).
@freezed
class EvidenciaFoto with _$EvidenciaFoto {
  const factory EvidenciaFoto({
    @Default('') String id,

    /// URL do arquivo protegido no PB (precisa de file token na query).
    @Default('') String url,
    @JsonKey(unknownEnumValue: FaseFoto.antes)
    @Default(FaseFoto.antes)
    FaseFoto fase,
    String? legenda,

    /// ISO datetime do envio.
    @Default('') String criadoEm,
    String? enviadoPor,
    String? checklistItemId,
    String? observacaoId,
    String? adicionalId,
  }) = _EvidenciaFoto;

  factory EvidenciaFoto.fromJson(Map<String, dynamic> json) =>
      _$EvidenciaFotoFromJson(json);

  /// Mapper `OSEvidenciaPB` (registro PB, snake_case) → `EvidenciaFoto`
  /// (domínio), espelhando `evidenciaToFoto` de os/osStore.ts. [url] já deve
  /// trazer o file token — o `EvidenciasRepository` (Fase 2) monta a URL
  /// protegida do arquivo antes de chamar este mapper.
  factory EvidenciaFoto.fromPB(OSEvidenciaPB pb, {required String url}) =>
      EvidenciaFoto(
        id: pb.id,
        url: url,
        fase: pb.fase ?? FaseFoto.antes,
        legenda: pb.legenda,
        criadoEm: pb.created ?? '',
        enviadoPor: pb.enviadoPor,
        checklistItemId: pb.checklistItemId,
        observacaoId: pb.observacaoId,
        adicionalId: pb.adicionalId,
      );
}

/* ---- os_evidencias — 🔒 registro PB (snake_case) ---- */
@freezed
class OSEvidenciaPB with _$OSEvidenciaPB {
  const factory OSEvidenciaPB({
    required String id,
    @Default('') String os,
    String? foto,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    FaseFoto? fase,
    String? legenda,
    @JsonKey(name: 'checklist_item_id') String? checklistItemId,
    @JsonKey(name: 'observacao_id') String? observacaoId,
    @JsonKey(name: 'adicional_id') String? adicionalId,
    @JsonKey(name: 'enviado_por') String? enviadoPor,
    String? created,
    String? updated,
  }) = _OSEvidenciaPB;

  const OSEvidenciaPB._();

  factory OSEvidenciaPB.fromJson(Map<String, dynamic> json) =>
      _$OSEvidenciaPBFromJson(json);

  factory OSEvidenciaPB.fromRecord(RecordModel record) =>
      OSEvidenciaPB.fromJson(record.toJson());
}
