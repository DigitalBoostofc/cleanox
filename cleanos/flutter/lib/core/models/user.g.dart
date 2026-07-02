// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  email: json['email'] as String? ?? '',
  role:
      $enumDecodeNullable(
        _$RoleEnumMap,
        json['role'],
        unknownValue: Role.profissional,
      ) ??
      Role.profissional,
  nome: json['nome'] as String?,
  verified: json['verified'] as bool? ?? false,
  emailVisibility: json['emailVisibility'] as bool? ?? false,
  created: json['created'] as String?,
  updated: json['updated'] as String?,
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'role': _$RoleEnumMap[instance.role]!,
      'nome': instance.nome,
      'verified': instance.verified,
      'emailVisibility': instance.emailVisibility,
      'created': instance.created,
      'updated': instance.updated,
    };

const _$RoleEnumMap = {
  Role.admin: 'admin',
  Role.gerente: 'gerente',
  Role.profissional: 'profissional',
};
