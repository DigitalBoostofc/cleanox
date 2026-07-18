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
  whatsapp: json['whatsapp'] as String?,
  comissaoTipo:
      $enumDecodeNullable(
        _$ComissaoTipoEnumMap,
        json['comissao_tipo'],
        unknownValue: ComissaoTipo.nenhuma,
      ) ??
      ComissaoTipo.nenhuma,
  comissaoValor: (json['comissao_valor'] as num?)?.toDouble() ?? 0,
  pagamentoFrequencia: $enumDecodeNullable(
    _$PagamentoFrequenciaEnumMap,
    json['pagamento_frequencia'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  pagamentoDia: (json['pagamento_dia'] as num?)?.toInt() ?? 0,
  pagamentoDia2: (json['pagamento_dia_2'] as num?)?.toInt() ?? 0,
  avatar: json['avatar'] as String? ?? '',
  corAgenda: json['cor_agenda'] as String? ?? '',
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
      'whatsapp': instance.whatsapp,
      'comissao_tipo': _$ComissaoTipoEnumMap[instance.comissaoTipo]!,
      'comissao_valor': instance.comissaoValor,
      'pagamento_frequencia':
          _$PagamentoFrequenciaEnumMap[instance.pagamentoFrequencia],
      'pagamento_dia': instance.pagamentoDia,
      'pagamento_dia_2': instance.pagamentoDia2,
      'avatar': instance.avatar,
      'cor_agenda': instance.corAgenda,
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

const _$ComissaoTipoEnumMap = {
  ComissaoTipo.nenhuma: 'nenhuma',
  ComissaoTipo.percentual: 'percentual',
  ComissaoTipo.fixo: 'fixo',
  ComissaoTipo.diaria: 'diaria',
};

const _$PagamentoFrequenciaEnumMap = {
  PagamentoFrequencia.diario: 'diario',
  PagamentoFrequencia.semanal: 'semanal',
  PagamentoFrequencia.quinzenal: 'quinzenal',
  PagamentoFrequencia.mensal: 'mensal',
};
