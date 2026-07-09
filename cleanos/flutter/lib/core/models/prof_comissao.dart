/// prof_comissao.dart — Extrato de comissão do profissional (coleção prof_comissoes).
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'collections.dart';

part 'prof_comissao.freezed.dart';
part 'prof_comissao.g.dart';

@freezed
class ProfComissao with _$ProfComissao {
  const factory ProfComissao({
    required String id,
    required String profissional,
    required String os,
    @JsonKey(name: 'valor_os') @Default(0) double valorOs,
    @JsonKey(name: 'valor_comissao') @Default(0) double valorComissao,
    @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
    @Default(ComissaoTipo.percentual)
    ComissaoTipo tipoAplicado,
    @JsonKey(name: 'base_valor') @Default(0) double baseValor,
    @JsonKey(unknownEnumValue: ComissaoStatus.pendente)
    @Default(ComissaoStatus.pendente)
    ComissaoStatus status,
    String? data,
    @Default('') String descricao,
    String? created,
    String? updated,
  }) = _ProfComissao;

  const ProfComissao._();

  factory ProfComissao.fromJson(Map<String, dynamic> json) =>
      _$ProfComissaoFromJson(json);

  factory ProfComissao.fromRecord(RecordModel record) {
    final j = Map<String, dynamic>.from(record.toJson());
    // Relation fields may arrive as id string.
    final p = j['profissional'];
    if (p is Map) j['profissional'] = p['id'] ?? '';
    final o = j['os'];
    if (o is Map) j['os'] = o['id'] ?? '';
    return ProfComissao.fromJson(j);
  }
}
