// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disponibilidade.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DisponibilidadeDiaPBImpl _$$DisponibilidadeDiaPBImplFromJson(
  Map<String, dynamic> json,
) => _$DisponibilidadeDiaPBImpl(
  ativo: json['ativo'] as bool? ?? false,
  inicio: json['inicio'] as String? ?? '',
  fim: json['fim'] as String? ?? '',
);

Map<String, dynamic> _$$DisponibilidadeDiaPBImplToJson(
  _$DisponibilidadeDiaPBImpl instance,
) => <String, dynamic>{
  'ativo': instance.ativo,
  'inicio': instance.inicio,
  'fim': instance.fim,
};

_$DisponibilidadeImpl _$$DisponibilidadeImplFromJson(
  Map<String, dynamic> json,
) => _$DisponibilidadeImpl(
  id: json['id'] as String,
  profissional: json['profissional'] as String? ?? '',
  duracaoMin: (json['duracao_min'] as num?)?.toInt() ?? 0,
  dias:
      (json['dias'] as List<dynamic>?)
          ?.map((e) => DisponibilidadeDiaPB.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <DisponibilidadeDiaPB>[],
  created: json['created'] as String?,
  updated: json['updated'] as String?,
);

Map<String, dynamic> _$$DisponibilidadeImplToJson(
  _$DisponibilidadeImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'profissional': instance.profissional,
  'duracao_min': instance.duracaoMin,
  'dias': instance.dias.map((e) => e.toJson()).toList(),
  'created': instance.created,
  'updated': instance.updated,
};
