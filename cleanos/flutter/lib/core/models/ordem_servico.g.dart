// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ordem_servico.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrdemServicoImpl _$$OrdemServicoImplFromJson(
  Map<String, dynamic> json,
) => _$OrdemServicoImpl(
  id: json['id'] as String,
  cliente: json['cliente'] as String? ?? '',
  nomeCurto: json['nome_curto'] as String? ?? '',
  bairro: json['bairro'] as String? ?? '',
  servico: json['servico'] as String?,
  tipoServicoNome: json['tipo_servico_nome'] as String?,
  dataHora: json['data_hora'] as String? ?? '',
  duracaoMin: _duracaoMinFromJson(json['duracao_min']),
  profissional: json['profissional'] as String?,
  status:
      $enumDecodeNullable(
        _$OSStatusEnumMap,
        json['status'],
        unknownValue: OSStatus.agendada,
      ) ??
      OSStatus.agendada,
  valorServico: (json['valor_servico'] as num?)?.toDouble(),
  enderecoLiberado: json['endereco_liberado'] as String?,
  valorPago: (json['valor_pago'] as num?)?.toDouble(),
  formaPagamento: $enumDecodeNullable(
    _$FormaPagamentoEnumMap,
    json['forma_pagamento'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  formaPagamentoOutro: json['forma_pagamento_outro'] as String?,
  repasseStatus: $enumDecodeNullable(
    _$RepasseStatusEnumMap,
    json['repasse_status'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  repasseValor: (json['repasse_valor'] as num?)?.toDouble(),
  avisoACaminhoEm: _emptyDateToNull(json['aviso_a_caminho_em']),
  chegueiEm: _emptyDateToNull(json['cheguei_em']),
  motivoCancelamento: json['motivo_cancelamento'] as String?,
  canceladoPor: json['cancelado_por'] as String?,
  canceladoPorNome: json['cancelado_por_nome'] as String?,
  canceladoEm: _emptyDateToNull(json['cancelado_em']),
  avaliacaoNota: (json['avaliacao_nota'] as num?)?.toDouble(),
  avaliacaoMotivo: json['avaliacao_motivo'] as String?,
  avaliacaoEm: json['avaliacao_em'] as String?,
  avaliacaoSolicitadaEm: json['avaliacao_solicitada_em'] as String?,
  observacoes: json['observacoes'] as String?,
  serviceSnapshot: json['service_snapshot'] == null
      ? null
      : ServiceSnapshot.fromJson(
          json['service_snapshot'] as Map<String, dynamic>,
        ),
  checklistExec:
      (json['checklist_exec'] as List<dynamic>?)
          ?.map((e) => ChecklistExecItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ChecklistExecItem>[],
  adicionais:
      (json['adicionais'] as List<dynamic>?)
          ?.map((e) => ServicoAdicionalOS.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ServicoAdicionalOS>[],
  observacoesProf:
      (json['observacoes_prof'] as List<dynamic>?)
          ?.map(
            (e) => ObservacaoProfissional.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <ObservacaoProfissional>[],
  descontos: (json['descontos'] as num?)?.toDouble() ?? 0,
  relatorioEnviadoEm: json['relatorio_enviado_em'] as String?,
  created: json['created'] as String?,
  updated: json['updated'] as String?,
);

Map<String, dynamic> _$$OrdemServicoImplToJson(
  _$OrdemServicoImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'cliente': instance.cliente,
  'nome_curto': instance.nomeCurto,
  'bairro': instance.bairro,
  'servico': instance.servico,
  'tipo_servico_nome': instance.tipoServicoNome,
  'data_hora': instance.dataHora,
  'duracao_min': instance.duracaoMin,
  'profissional': instance.profissional,
  'status': _$OSStatusEnumMap[instance.status]!,
  'valor_servico': instance.valorServico,
  'endereco_liberado': instance.enderecoLiberado,
  'valor_pago': instance.valorPago,
  'forma_pagamento': _$FormaPagamentoEnumMap[instance.formaPagamento],
  'forma_pagamento_outro': instance.formaPagamentoOutro,
  'repasse_status': _$RepasseStatusEnumMap[instance.repasseStatus],
  'repasse_valor': instance.repasseValor,
  'aviso_a_caminho_em': instance.avisoACaminhoEm,
  'cheguei_em': instance.chegueiEm,
  'motivo_cancelamento': instance.motivoCancelamento,
  'cancelado_por': instance.canceladoPor,
  'cancelado_por_nome': instance.canceladoPorNome,
  'cancelado_em': instance.canceladoEm,
  'avaliacao_nota': instance.avaliacaoNota,
  'avaliacao_motivo': instance.avaliacaoMotivo,
  'avaliacao_em': instance.avaliacaoEm,
  'avaliacao_solicitada_em': instance.avaliacaoSolicitadaEm,
  'observacoes': instance.observacoes,
  'service_snapshot': instance.serviceSnapshot?.toJson(),
  'checklist_exec': instance.checklistExec.map((e) => e.toJson()).toList(),
  'adicionais': instance.adicionais.map((e) => e.toJson()).toList(),
  'observacoes_prof': instance.observacoesProf.map((e) => e.toJson()).toList(),
  'descontos': instance.descontos,
  'relatorio_enviado_em': instance.relatorioEnviadoEm,
  'created': instance.created,
  'updated': instance.updated,
};

const _$OSStatusEnumMap = {
  OSStatus.agendada: 'agendada',
  OSStatus.atribuida: 'atribuida',
  OSStatus.emAndamento: 'em_andamento',
  OSStatus.concluida: 'concluida',
  OSStatus.cancelada: 'cancelada',
};

const _$FormaPagamentoEnumMap = {
  FormaPagamento.dinheiro: 'dinheiro',
  FormaPagamento.debito: 'debito',
  FormaPagamento.credito: 'credito',
  FormaPagamento.pix: 'pix',
  FormaPagamento.pixMaquininha: 'pix_maquininha',
  FormaPagamento.outros: 'outros',
};

const _$RepasseStatusEnumMap = {
  RepasseStatus.pendente: 'pendente',
  RepasseStatus.pago: 'pago',
};
