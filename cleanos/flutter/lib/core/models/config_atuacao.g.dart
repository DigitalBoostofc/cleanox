// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_atuacao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConfigAtuacaoCidadeImpl _$$ConfigAtuacaoCidadeImplFromJson(
  Map<String, dynamic> json,
) => _$ConfigAtuacaoCidadeImpl(
  nome: json['nome'] as String? ?? '',
  principal: json['principal'] as bool? ?? false,
  bairros:
      (json['bairros'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$$ConfigAtuacaoCidadeImplToJson(
  _$ConfigAtuacaoCidadeImpl instance,
) => <String, dynamic>{
  'nome': instance.nome,
  'principal': instance.principal,
  'bairros': instance.bairros,
};

_$ConfigAtuacaoImpl _$$ConfigAtuacaoImplFromJson(Map<String, dynamic> json) =>
    _$ConfigAtuacaoImpl(
      id: json['id'] as String,
      estado: json['estado'] as String? ?? '',
      cidades:
          (json['cidades'] as List<dynamic>?)
              ?.map(
                (e) => ConfigAtuacaoCidade.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <ConfigAtuacaoCidade>[],
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$ConfigAtuacaoImplToJson(_$ConfigAtuacaoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'estado': instance.estado,
      'cidades': instance.cidades.map((e) => e.toJson()).toList(),
      'created': instance.created,
      'updated': instance.updated,
    };
