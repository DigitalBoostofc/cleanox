// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'servico.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChecklistTemplateItemImpl _$$ChecklistTemplateItemImplFromJson(
  Map<String, dynamic> json,
) => _$ChecklistTemplateItemImpl(
  id: json['id'] as String? ?? '',
  titulo: json['titulo'] as String? ?? '',
  ordem: (json['ordem'] as num?)?.toInt() ?? 0,
  obrigatorio: json['obrigatorio'] as bool? ?? false,
);

Map<String, dynamic> _$$ChecklistTemplateItemImplToJson(
  _$ChecklistTemplateItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'titulo': instance.titulo,
  'ordem': instance.ordem,
  'obrigatorio': instance.obrigatorio,
};

_$ServiceSnapshotImpl _$$ServiceSnapshotImplFromJson(
  Map<String, dynamic> json,
) => _$ServiceSnapshotImpl(
  serviceId: json['serviceId'] as String? ?? '',
  nome: json['nome'] as String? ?? '',
  categoria: $enumDecodeNullable(
    _$CategoriaEnumMap,
    json['categoria'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  grupo: $enumDecodeNullable(
    _$GrupoEnumMap,
    json['grupo'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  valorBase: (json['valorBase'] as num?)?.toDouble() ?? 0,
  valorBaseMax: (json['valorBaseMax'] as num?)?.toDouble(),
  tipoValor: $enumDecodeNullable(
    _$TipoValorEnumMap,
    json['tipoValor'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  tempoMedioMin: (json['tempoMedioMin'] as num?)?.toDouble(),
  tempoMedioLabel: json['tempoMedioLabel'] as String? ?? '',
  observacaoTecnica: json['observacaoTecnica'] as String?,
  checklistPadrao:
      (json['checklistPadrao'] as List<dynamic>?)
          ?.map(
            (e) => ChecklistTemplateItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <ChecklistTemplateItem>[],
  orientacoesPreServico: json['orientacoesPreServico'] as String?,
  orientacoesPosServico: json['orientacoesPosServico'] as String?,
  capturedAt: json['capturedAt'] as String? ?? '',
);

Map<String, dynamic> _$$ServiceSnapshotImplToJson(
  _$ServiceSnapshotImpl instance,
) => <String, dynamic>{
  'serviceId': instance.serviceId,
  'nome': instance.nome,
  'categoria': _$CategoriaEnumMap[instance.categoria],
  'grupo': _$GrupoEnumMap[instance.grupo],
  'valorBase': instance.valorBase,
  'valorBaseMax': instance.valorBaseMax,
  'tipoValor': _$TipoValorEnumMap[instance.tipoValor],
  'tempoMedioMin': instance.tempoMedioMin,
  'tempoMedioLabel': instance.tempoMedioLabel,
  'observacaoTecnica': instance.observacaoTecnica,
  'checklistPadrao': instance.checklistPadrao.map((e) => e.toJson()).toList(),
  'orientacoesPreServico': instance.orientacoesPreServico,
  'orientacoesPosServico': instance.orientacoesPosServico,
  'capturedAt': instance.capturedAt,
};

const _$CategoriaEnumMap = {
  Categoria.veicular: 'veicular',
  Categoria.residencial: 'residencial',
};

const _$GrupoEnumMap = {
  Grupo.plano: 'plano',
  Grupo.promocao: 'promocao',
  Grupo.adicional: 'adicional',
  Grupo.avulsos: 'avulsos',
  Grupo.sofa: 'sofa',
  Grupo.colchao: 'colchao',
  Grupo.outros: 'outros',
};

const _$TipoValorEnumMap = {
  TipoValor.fixo: 'fixo',
  TipoValor.faixa: 'faixa',
  TipoValor.variavel: 'variavel',
};

_$ServicoPBImpl _$$ServicoPBImplFromJson(Map<String, dynamic> json) =>
    _$ServicoPBImpl(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      categoria: $enumDecodeNullable(
        _$CategoriaEnumMap,
        json['categoria'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      grupo: $enumDecodeNullable(
        _$GrupoEnumMap,
        json['grupo'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      nome: json['nome'] as String? ?? '',
      descricao: json['descricao'] as String?,
      valorBase: (json['valor_base'] as num?)?.toDouble() ?? 0,
      valorBaseMax: (json['valor_base_max'] as num?)?.toDouble(),
      tipoValor: $enumDecodeNullable(
        _$TipoValorEnumMap,
        json['tipo_valor'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      tempoMedioMin: (json['tempo_medio_min'] as num?)?.toDouble(),
      tempoMedioLabel: json['tempo_medio_label'] as String?,
      status: $enumDecodeNullable(
        _$ServicoStatusEnumMap,
        json['status'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      observacao: json['observacao'] as String?,
      checklistPadrao:
          (json['checklist_padrao'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ChecklistTemplateItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <ChecklistTemplateItem>[],
      orientacoesPre: json['orientacoes_pre'] as String?,
      orientacoesPos: json['orientacoes_pos'] as String?,
      adicionaisRelacionados:
          (json['adicionais_relacionados'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      precoBase: (json['preco_base'] as num?)?.toDouble() ?? 0,
      ativo: json['ativo'] as bool? ?? false,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$ServicoPBImplToJson(
  _$ServicoPBImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'slug': instance.slug,
  'categoria': _$CategoriaEnumMap[instance.categoria],
  'grupo': _$GrupoEnumMap[instance.grupo],
  'nome': instance.nome,
  'descricao': instance.descricao,
  'valor_base': instance.valorBase,
  'valor_base_max': instance.valorBaseMax,
  'tipo_valor': _$TipoValorEnumMap[instance.tipoValor],
  'tempo_medio_min': instance.tempoMedioMin,
  'tempo_medio_label': instance.tempoMedioLabel,
  'status': _$ServicoStatusEnumMap[instance.status],
  'observacao': instance.observacao,
  'checklist_padrao': instance.checklistPadrao.map((e) => e.toJson()).toList(),
  'orientacoes_pre': instance.orientacoesPre,
  'orientacoes_pos': instance.orientacoesPos,
  'adicionais_relacionados': instance.adicionaisRelacionados,
  'preco_base': instance.precoBase,
  'ativo': instance.ativo,
  'created': instance.created,
  'updated': instance.updated,
};

const _$ServicoStatusEnumMap = {
  ServicoStatus.ativo: 'ativo',
  ServicoStatus.inativo: 'inativo',
};
