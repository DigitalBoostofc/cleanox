// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'os_execucao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChecklistExecItemImpl _$$ChecklistExecItemImplFromJson(
  Map<String, dynamic> json,
) => _$ChecklistExecItemImpl(
  id: json['id'] as String? ?? '',
  titulo: json['titulo'] as String? ?? '',
  status:
      $enumDecodeNullable(
        _$ChecklistExecStatusEnumMap,
        json['status'],
        unknownValue: ChecklistExecStatus.pendente,
      ) ??
      ChecklistExecStatus.pendente,
  observacao: json['observacao'] as String?,
  concluidoEm: json['concluidoEm'] as String?,
  concluidoPor: json['concluidoPor'] as String?,
  fotosIds:
      (json['fotosIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  obrigatorio: json['obrigatorio'] as bool? ?? false,
);

Map<String, dynamic> _$$ChecklistExecItemImplToJson(
  _$ChecklistExecItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'titulo': instance.titulo,
  'status': _$ChecklistExecStatusEnumMap[instance.status]!,
  'observacao': instance.observacao,
  'concluidoEm': instance.concluidoEm,
  'concluidoPor': instance.concluidoPor,
  'fotosIds': instance.fotosIds,
  'obrigatorio': instance.obrigatorio,
};

const _$ChecklistExecStatusEnumMap = {
  ChecklistExecStatus.pendente: 'pendente',
  ChecklistExecStatus.concluido: 'concluido',
};

_$ServicoAdicionalOSImpl _$$ServicoAdicionalOSImplFromJson(
  Map<String, dynamic> json,
) => _$ServicoAdicionalOSImpl(
  id: json['id'] as String? ?? '',
  serviceId: json['serviceId'] as String?,
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
  valor: (json['valor'] as num?)?.toDouble() ?? 0,
  tipoValor: $enumDecodeNullable(
    _$TipoValorEnumMap,
    json['tipoValor'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  quantidade: (json['quantidade'] as num?)?.toInt() ?? 1,
  motivo: json['motivo'] as String?,
  observacao: json['observacao'] as String?,
  aprovacao:
      $enumDecodeNullable(
        _$AprovacaoStatusEnumMap,
        json['aprovacao'],
        unknownValue: AprovacaoStatus.naoRequer,
      ) ??
      AprovacaoStatus.naoRequer,
);

Map<String, dynamic> _$$ServicoAdicionalOSImplToJson(
  _$ServicoAdicionalOSImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'serviceId': instance.serviceId,
  'nome': instance.nome,
  'categoria': _$CategoriaEnumMap[instance.categoria],
  'grupo': _$GrupoEnumMap[instance.grupo],
  'valor': instance.valor,
  'tipoValor': _$TipoValorEnumMap[instance.tipoValor],
  'quantidade': instance.quantidade,
  'motivo': instance.motivo,
  'observacao': instance.observacao,
  'aprovacao': _$AprovacaoStatusEnumMap[instance.aprovacao]!,
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

const _$AprovacaoStatusEnumMap = {
  AprovacaoStatus.naoRequer: 'nao_requer',
  AprovacaoStatus.aguardando: 'aguardando',
  AprovacaoStatus.aprovado: 'aprovado',
  AprovacaoStatus.recusado: 'recusado',
};

_$ObservacaoProfissionalImpl _$$ObservacaoProfissionalImplFromJson(
  Map<String, dynamic> json,
) => _$ObservacaoProfissionalImpl(
  id: json['id'] as String? ?? '',
  texto: json['texto'] as String? ?? '',
  visivelCliente: json['visivelCliente'] as bool? ?? false,
  tipo: $enumDecodeNullable(
    _$ObservacaoTipoEnumMap,
    json['tipo'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  criadoPor: json['criadoPor'] as String?,
  criadoEm: json['criadoEm'] as String? ?? '',
  fotosIds:
      (json['fotosIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$$ObservacaoProfissionalImplToJson(
  _$ObservacaoProfissionalImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'texto': instance.texto,
  'visivelCliente': instance.visivelCliente,
  'tipo': _$ObservacaoTipoEnumMap[instance.tipo],
  'criadoPor': instance.criadoPor,
  'criadoEm': instance.criadoEm,
  'fotosIds': instance.fotosIds,
};

const _$ObservacaoTipoEnumMap = {
  ObservacaoTipo.geral: 'geral',
  ObservacaoTipo.ponto: 'ponto',
  ObservacaoTipo.limitacao: 'limitacao',
  ObservacaoTipo.recomendacao: 'recomendacao',
  ObservacaoTipo.intercorrencia: 'intercorrencia',
  ObservacaoTipo.revisao: 'revisao',
};

_$EvidenciaFotoImpl _$$EvidenciaFotoImplFromJson(Map<String, dynamic> json) =>
    _$EvidenciaFotoImpl(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      fase:
          $enumDecodeNullable(
            _$FaseFotoEnumMap,
            json['fase'],
            unknownValue: FaseFoto.antes,
          ) ??
          FaseFoto.antes,
      legenda: json['legenda'] as String?,
      criadoEm: json['criadoEm'] as String? ?? '',
      enviadoPor: json['enviadoPor'] as String?,
      checklistItemId: json['checklistItemId'] as String?,
      observacaoId: json['observacaoId'] as String?,
      adicionalId: json['adicionalId'] as String?,
    );

Map<String, dynamic> _$$EvidenciaFotoImplToJson(_$EvidenciaFotoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'fase': _$FaseFotoEnumMap[instance.fase]!,
      'legenda': instance.legenda,
      'criadoEm': instance.criadoEm,
      'enviadoPor': instance.enviadoPor,
      'checklistItemId': instance.checklistItemId,
      'observacaoId': instance.observacaoId,
      'adicionalId': instance.adicionalId,
    };

const _$FaseFotoEnumMap = {
  FaseFoto.antes: 'antes',
  FaseFoto.durante: 'durante',
  FaseFoto.depois: 'depois',
};

_$OSEvidenciaPBImpl _$$OSEvidenciaPBImplFromJson(Map<String, dynamic> json) =>
    _$OSEvidenciaPBImpl(
      id: json['id'] as String,
      os: json['os'] as String? ?? '',
      foto: json['foto'] as String?,
      fase: $enumDecodeNullable(
        _$FaseFotoEnumMap,
        json['fase'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      legenda: json['legenda'] as String?,
      checklistItemId: json['checklist_item_id'] as String?,
      observacaoId: json['observacao_id'] as String?,
      adicionalId: json['adicional_id'] as String?,
      enviadoPor: json['enviado_por'] as String?,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$OSEvidenciaPBImplToJson(_$OSEvidenciaPBImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'os': instance.os,
      'foto': instance.foto,
      'fase': _$FaseFotoEnumMap[instance.fase],
      'legenda': instance.legenda,
      'checklist_item_id': instance.checklistItemId,
      'observacao_id': instance.observacaoId,
      'adicional_id': instance.adicionalId,
      'enviado_por': instance.enviadoPor,
      'created': instance.created,
      'updated': instance.updated,
    };
