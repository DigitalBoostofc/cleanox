// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cliente.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClienteImpl _$$ClienteImplFromJson(Map<String, dynamic> json) =>
    _$ClienteImpl(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? '',
      sobrenome: json['sobrenome'] as String?,
      telefone: json['telefone'] as String? ?? '',
      email: json['email'] as String?,
      enderecoRua: json['endereco_rua'] as String?,
      enderecoNumero: json['endereco_numero'] as String?,
      enderecoComplemento: json['endereco_complemento'] as String?,
      enderecoBairro: json['endereco_bairro'] as String? ?? '',
      enderecoCidade: json['endereco_cidade'] as String?,
      enderecoEstado: json['endereco_estado'] as String?,
      enderecoCep: json['endereco_cep'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      origem: json['origem'] as String?,
      observacoes: json['observacoes'] as String?,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$ClienteImplToJson(_$ClienteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'sobrenome': instance.sobrenome,
      'telefone': instance.telefone,
      'email': instance.email,
      'endereco_rua': instance.enderecoRua,
      'endereco_numero': instance.enderecoNumero,
      'endereco_complemento': instance.enderecoComplemento,
      'endereco_bairro': instance.enderecoBairro,
      'endereco_cidade': instance.enderecoCidade,
      'endereco_estado': instance.enderecoEstado,
      'endereco_cep': instance.enderecoCep,
      'ativo': instance.ativo,
      'origem': instance.origem,
      'observacoes': instance.observacoes,
      'created': instance.created,
      'updated': instance.updated,
    };
