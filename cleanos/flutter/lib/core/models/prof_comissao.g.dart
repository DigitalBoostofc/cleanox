// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prof_comissao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfComissaoImpl _$$ProfComissaoImplFromJson(Map<String, dynamic> json) =>
    _$ProfComissaoImpl(
      id: json['id'] as String,
      profissional: json['profissional'] as String,
      os: json['os'] as String,
      valorOs: (json['valor_os'] as num?)?.toDouble() ?? 0,
      valorComissao: (json['valor_comissao'] as num?)?.toDouble() ?? 0,
      tipoAplicado:
          $enumDecodeNullable(
            _$ComissaoTipoEnumMap,
            json['tipo_aplicado'],
            unknownValue: ComissaoTipo.percentual,
          ) ??
          ComissaoTipo.percentual,
      baseValor: (json['base_valor'] as num?)?.toDouble() ?? 0,
      status:
          $enumDecodeNullable(
            _$ComissaoStatusEnumMap,
            json['status'],
            unknownValue: ComissaoStatus.pendente,
          ) ??
          ComissaoStatus.pendente,
      data: json['data'] as String?,
      descricao: json['descricao'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$ProfComissaoImplToJson(_$ProfComissaoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'profissional': instance.profissional,
      'os': instance.os,
      'valor_os': instance.valorOs,
      'valor_comissao': instance.valorComissao,
      'tipo_aplicado': _$ComissaoTipoEnumMap[instance.tipoAplicado]!,
      'base_valor': instance.baseValor,
      'status': _$ComissaoStatusEnumMap[instance.status]!,
      'data': instance.data,
      'descricao': instance.descricao,
      'created': instance.created,
      'updated': instance.updated,
    };

const _$ComissaoTipoEnumMap = {
  ComissaoTipo.nenhuma: 'nenhuma',
  ComissaoTipo.percentual: 'percentual',
  ComissaoTipo.fixo: 'fixo',
};

const _$ComissaoStatusEnumMap = {
  ComissaoStatus.pendente: 'pendente',
  ComissaoStatus.paga: 'paga',
};
