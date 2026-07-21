// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financeiro.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnexoImpl _$$AnexoImplFromJson(Map<String, dynamic> json) => _$AnexoImpl(
  id: json['id'] as String? ?? '',
  nome: json['nome'] as String? ?? '',
  url: json['url'] as String? ?? '',
  tamanho: (json['tamanho'] as num?)?.toInt(),
);

Map<String, dynamic> _$$AnexoImplToJson(_$AnexoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'url': instance.url,
      'tamanho': instance.tamanho,
    };

_$FinContaImpl _$$FinContaImplFromJson(Map<String, dynamic> json) =>
    _$FinContaImpl(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? '',
      tipo:
          $enumDecodeNullable(
            _$ContaTipoEnumMap,
            json['tipo'],
            unknownValue: ContaTipo.carteira,
          ) ??
          ContaTipo.carteira,
      saldoInicial: (json['saldo_inicial'] as num?)?.toDouble() ?? 0,
      saldoAtual: (json['saldo_atual'] as num?)?.toDouble() ?? 0,
      ativo: json['ativo'] as bool? ?? true,
      cor: json['cor'] as String?,
      icone: json['icone'] as String?,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$FinContaImplToJson(_$FinContaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'tipo': _$ContaTipoEnumMap[instance.tipo]!,
      'saldo_inicial': instance.saldoInicial,
      'saldo_atual': instance.saldoAtual,
      'ativo': instance.ativo,
      'cor': instance.cor,
      'icone': instance.icone,
      'created': instance.created,
      'updated': instance.updated,
    };

const _$ContaTipoEnumMap = {
  ContaTipo.carteira: 'carteira',
  ContaTipo.banco: 'banco',
  ContaTipo.cartao: 'cartao',
  ContaTipo.caixa: 'caixa',
};

_$FinCategoriaImpl _$$FinCategoriaImplFromJson(Map<String, dynamic> json) =>
    _$FinCategoriaImpl(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? '',
      tipo:
          $enumDecodeNullable(
            _$TipoLancamentoEnumMap,
            json['tipo'],
            unknownValue: TipoLancamento.despesa,
          ) ??
          TipoLancamento.despesa,
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      parentId: json['parent_id'] as String?,
      arquivada: json['arquivada'] as bool? ?? false,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$FinCategoriaImplToJson(_$FinCategoriaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'tipo': _$TipoLancamentoEnumMap[instance.tipo]!,
      'icone': instance.icone,
      'cor': instance.cor,
      'parent_id': instance.parentId,
      'arquivada': instance.arquivada,
      'created': instance.created,
      'updated': instance.updated,
    };

const _$TipoLancamentoEnumMap = {
  TipoLancamento.receita: 'receita',
  TipoLancamento.despesa: 'despesa',
};

_$FinLancamentoImpl _$$FinLancamentoImplFromJson(Map<String, dynamic> json) =>
    _$FinLancamentoImpl(
      id: json['id'] as String,
      tipo:
          $enumDecodeNullable(
            _$TipoLancamentoEnumMap,
            json['tipo'],
            unknownValue: TipoLancamento.despesa,
          ) ??
          TipoLancamento.despesa,
      descricao: json['descricao'] as String? ?? '',
      categoriaId: json['categoria_id'] as String? ?? '',
      subcategoriaId: json['subcategoria_id'] as String?,
      valor: (json['valor'] as num?)?.toDouble() ?? 0,
      contaId: json['conta_id'] as String? ?? '',
      data: json['data'] as String? ?? '',
      vencimento: json['vencimento'] as String?,
      status:
          $enumDecodeNullable(
            _$LancamentoStatusEnumMap,
            json['status'],
            unknownValue: LancamentoStatus.pendente,
          ) ??
          LancamentoStatus.pendente,
      recorrencia:
          $enumDecodeNullable(
            _$RecorrenciaTipoEnumMap,
            json['recorrencia'],
            unknownValue: RecorrenciaTipo.unica,
          ) ??
          RecorrenciaTipo.unica,
      frequencia: $enumDecodeNullable(
        _$FrequenciaRecorrenciaEnumMap,
        json['frequencia'],
        unknownValue: FrequenciaRecorrencia.mensal,
      ),
      parcelaAtual: (json['parcela_atual'] as num?)?.toInt(),
      parcelasTotal: (json['parcelas_total'] as num?)?.toInt(),
      origem:
          $enumDecodeNullable(
            _$OrigemLancamentoEnumMap,
            json['origem'],
            unknownValue: OrigemLancamento.manual,
          ) ??
          OrigemLancamento.manual,
      osId: json['os_id'] as String?,
      osNumero: json['os_numero'] as String?,
      clienteNome: json['cliente_nome'] as String?,
      servicoNome: json['servico_nome'] as String?,
      formaPagamento: json['forma_pagamento'] as String?,
      observacao: json['observacao'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      favorito: json['favorito'] as bool? ?? false,
      anexos:
          (json['anexos'] as List<dynamic>?)
              ?.map((e) => Anexo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Anexo>[],
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$FinLancamentoImplToJson(_$FinLancamentoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tipo': _$TipoLancamentoEnumMap[instance.tipo]!,
      'descricao': instance.descricao,
      'categoria_id': instance.categoriaId,
      'subcategoria_id': instance.subcategoriaId,
      'valor': instance.valor,
      'conta_id': instance.contaId,
      'data': instance.data,
      'vencimento': instance.vencimento,
      'status': _$LancamentoStatusEnumMap[instance.status]!,
      'recorrencia': _$RecorrenciaTipoEnumMap[instance.recorrencia]!,
      'frequencia': _$FrequenciaRecorrenciaEnumMap[instance.frequencia],
      'parcela_atual': instance.parcelaAtual,
      'parcelas_total': instance.parcelasTotal,
      'origem': _$OrigemLancamentoEnumMap[instance.origem]!,
      'os_id': instance.osId,
      'os_numero': instance.osNumero,
      'cliente_nome': instance.clienteNome,
      'servico_nome': instance.servicoNome,
      'forma_pagamento': instance.formaPagamento,
      'observacao': instance.observacao,
      'tags': instance.tags,
      'favorito': instance.favorito,
      'anexos': instance.anexos.map((e) => e.toJson()).toList(),
      'created': instance.created,
      'updated': instance.updated,
    };

const _$LancamentoStatusEnumMap = {
  LancamentoStatus.pago: 'pago',
  LancamentoStatus.pendente: 'pendente',
  LancamentoStatus.previsto: 'previsto',
  LancamentoStatus.emAtraso: 'em_atraso',
};

const _$RecorrenciaTipoEnumMap = {
  RecorrenciaTipo.unica: 'unica',
  RecorrenciaTipo.fixa: 'fixa',
  RecorrenciaTipo.recorrente: 'recorrente',
  RecorrenciaTipo.parcelada: 'parcelada',
};

const _$FrequenciaRecorrenciaEnumMap = {
  FrequenciaRecorrencia.diario: 'diario',
  FrequenciaRecorrencia.semanal: 'semanal',
  FrequenciaRecorrencia.quinzenal: 'quinzenal',
  FrequenciaRecorrencia.mensal: 'mensal',
  FrequenciaRecorrencia.bimestral: 'bimestral',
  FrequenciaRecorrencia.trimestral: 'trimestral',
  FrequenciaRecorrencia.semestral: 'semestral',
  FrequenciaRecorrencia.anual: 'anual',
};

const _$OrigemLancamentoEnumMap = {
  OrigemLancamento.manual: 'manual',
  OrigemLancamento.viaOs: 'via_os',
};

_$FinLimiteImpl _$$FinLimiteImplFromJson(Map<String, dynamic> json) =>
    _$FinLimiteImpl(
      id: json['id'] as String,
      categoriaId: json['categoria_id'] as String? ?? '',
      limite: (json['limite'] as num?)?.toDouble() ?? 0,
      anoMes: json['ano_mes'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$FinLimiteImplToJson(_$FinLimiteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'categoria_id': instance.categoriaId,
      'limite': instance.limite,
      'ano_mes': instance.anoMes,
      'created': instance.created,
      'updated': instance.updated,
    };

_$FinObjetivoImpl _$$FinObjetivoImplFromJson(Map<String, dynamic> json) =>
    _$FinObjetivoImpl(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? '',
      metaValor: (json['meta_valor'] as num?)?.toDouble() ?? 0,
      valorAtual: (json['valor_atual'] as num?)?.toDouble() ?? 0,
      dataLimite: json['data_limite'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      cor: json['cor'] as String?,
      icone: json['icone'] as String?,
      observacao: json['observacao'] as String?,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );

Map<String, dynamic> _$$FinObjetivoImplToJson(_$FinObjetivoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'meta_valor': instance.metaValor,
      'valor_atual': instance.valorAtual,
      'data_limite': instance.dataLimite,
      'ativo': instance.ativo,
      'cor': instance.cor,
      'icone': instance.icone,
      'observacao': instance.observacao,
      'created': instance.created,
      'updated': instance.updated,
    };
