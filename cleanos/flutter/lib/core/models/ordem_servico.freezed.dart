// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ordem_servico.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$OSExpand {
  User? get profissional => throw _privateConstructorUsedError;
  ServicoPB? get servico => throw _privateConstructorUsedError;
  Cliente? get cliente => throw _privateConstructorUsedError;

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OSExpandCopyWith<OSExpand> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OSExpandCopyWith<$Res> {
  factory $OSExpandCopyWith(OSExpand value, $Res Function(OSExpand) then) =
      _$OSExpandCopyWithImpl<$Res, OSExpand>;
  @useResult
  $Res call({User? profissional, ServicoPB? servico, Cliente? cliente});

  $UserCopyWith<$Res>? get profissional;
  $ServicoPBCopyWith<$Res>? get servico;
  $ClienteCopyWith<$Res>? get cliente;
}

/// @nodoc
class _$OSExpandCopyWithImpl<$Res, $Val extends OSExpand>
    implements $OSExpandCopyWith<$Res> {
  _$OSExpandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profissional = freezed,
    Object? servico = freezed,
    Object? cliente = freezed,
  }) {
    return _then(
      _value.copyWith(
            profissional: freezed == profissional
                ? _value.profissional
                : profissional // ignore: cast_nullable_to_non_nullable
                      as User?,
            servico: freezed == servico
                ? _value.servico
                : servico // ignore: cast_nullable_to_non_nullable
                      as ServicoPB?,
            cliente: freezed == cliente
                ? _value.cliente
                : cliente // ignore: cast_nullable_to_non_nullable
                      as Cliente?,
          )
          as $Val,
    );
  }

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserCopyWith<$Res>? get profissional {
    if (_value.profissional == null) {
      return null;
    }

    return $UserCopyWith<$Res>(_value.profissional!, (value) {
      return _then(_value.copyWith(profissional: value) as $Val);
    });
  }

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ServicoPBCopyWith<$Res>? get servico {
    if (_value.servico == null) {
      return null;
    }

    return $ServicoPBCopyWith<$Res>(_value.servico!, (value) {
      return _then(_value.copyWith(servico: value) as $Val);
    });
  }

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ClienteCopyWith<$Res>? get cliente {
    if (_value.cliente == null) {
      return null;
    }

    return $ClienteCopyWith<$Res>(_value.cliente!, (value) {
      return _then(_value.copyWith(cliente: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OSExpandImplCopyWith<$Res>
    implements $OSExpandCopyWith<$Res> {
  factory _$$OSExpandImplCopyWith(
    _$OSExpandImpl value,
    $Res Function(_$OSExpandImpl) then,
  ) = __$$OSExpandImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({User? profissional, ServicoPB? servico, Cliente? cliente});

  @override
  $UserCopyWith<$Res>? get profissional;
  @override
  $ServicoPBCopyWith<$Res>? get servico;
  @override
  $ClienteCopyWith<$Res>? get cliente;
}

/// @nodoc
class __$$OSExpandImplCopyWithImpl<$Res>
    extends _$OSExpandCopyWithImpl<$Res, _$OSExpandImpl>
    implements _$$OSExpandImplCopyWith<$Res> {
  __$$OSExpandImplCopyWithImpl(
    _$OSExpandImpl _value,
    $Res Function(_$OSExpandImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profissional = freezed,
    Object? servico = freezed,
    Object? cliente = freezed,
  }) {
    return _then(
      _$OSExpandImpl(
        profissional: freezed == profissional
            ? _value.profissional
            : profissional // ignore: cast_nullable_to_non_nullable
                  as User?,
        servico: freezed == servico
            ? _value.servico
            : servico // ignore: cast_nullable_to_non_nullable
                  as ServicoPB?,
        cliente: freezed == cliente
            ? _value.cliente
            : cliente // ignore: cast_nullable_to_non_nullable
                  as Cliente?,
      ),
    );
  }
}

/// @nodoc

class _$OSExpandImpl implements _OSExpand {
  const _$OSExpandImpl({this.profissional, this.servico, this.cliente});

  @override
  final User? profissional;
  @override
  final ServicoPB? servico;
  @override
  final Cliente? cliente;

  @override
  String toString() {
    return 'OSExpand(profissional: $profissional, servico: $servico, cliente: $cliente)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OSExpandImpl &&
            (identical(other.profissional, profissional) ||
                other.profissional == profissional) &&
            (identical(other.servico, servico) || other.servico == servico) &&
            (identical(other.cliente, cliente) || other.cliente == cliente));
  }

  @override
  int get hashCode => Object.hash(runtimeType, profissional, servico, cliente);

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OSExpandImplCopyWith<_$OSExpandImpl> get copyWith =>
      __$$OSExpandImplCopyWithImpl<_$OSExpandImpl>(this, _$identity);
}

abstract class _OSExpand implements OSExpand {
  const factory _OSExpand({
    final User? profissional,
    final ServicoPB? servico,
    final Cliente? cliente,
  }) = _$OSExpandImpl;

  @override
  User? get profissional;
  @override
  ServicoPB? get servico;
  @override
  Cliente? get cliente;

  /// Create a copy of OSExpand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OSExpandImplCopyWith<_$OSExpandImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrdemServico _$OrdemServicoFromJson(Map<String, dynamic> json) {
  return _OrdemServico.fromJson(json);
}

/// @nodoc
mixin _$OrdemServico {
  String get id => throw _privateConstructorUsedError;

  /// Relation → clientes (ID opaco). O profissional recebe só o ID, nunca o expand.
  String get cliente => throw _privateConstructorUsedError;

  /// "Carlos S." — denormalizado por hook.
  @JsonKey(name: 'nome_curto')
  String get nomeCurto => throw _privateConstructorUsedError;

  /// endereco_bairro do cliente — denormalizado por hook.
  String get bairro => throw _privateConstructorUsedError;

  /// Relation → servicos (ID).
  String? get servico => throw _privateConstructorUsedError;
  @JsonKey(name: 'tipo_servico_nome')
  String? get tipoServicoNome => throw _privateConstructorUsedError;

  /// ISO datetime UTC.
  @JsonKey(name: 'data_hora')
  String get dataHora => throw _privateConstructorUsedError;

  /// Duração do atendimento em minutos (fim = [dataHora] + [duracaoMin]).
  ///
  /// ⚠️ R2 (variante NUMÉRICA): NumberField opcional do PB volta como **0**
  /// quando vazio — nunca `null`. Toda OS anterior à migration 27 chega com
  /// `"duracao_min": 0`. [_duracaoMinFromJson] normaliza `<= 0 → null` já no
  /// parse (fromJson e fromRecord), para o resto do app poder confiar em
  /// `null == sem duração própria` e cair no fallback do
  /// `duracaoEfetivaMin` (OS > profissional > 60).
  @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
  int? get duracaoMin => throw _privateConstructorUsedError;

  /// Relation → users (ID).
  String? get profissional => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: OSStatus.agendada)
  OSStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'valor_servico')
  double? get valorServico => throw _privateConstructorUsedError;

  /// Endereço completo — só preenchido quando status === 'em_andamento'.
  @JsonKey(name: 'endereco_liberado')
  String? get enderecoLiberado => throw _privateConstructorUsedError;

  /// Pagamento (preenchido pelo profissional ao concluir).
  @JsonKey(name: 'valor_pago')
  double? get valorPago => throw _privateConstructorUsedError;
  @JsonKey(
    name: 'forma_pagamento',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  FormaPagamento? get formaPagamento => throw _privateConstructorUsedError;

  /// Detalhe livre quando [formaPagamento] é [FormaPagamento.outros]
  /// (ex.: "Transferência", "Cortesia"). "" no PB vira null aqui (R2).
  @JsonKey(name: 'forma_pagamento_outro')
  String? get formaPagamentoOutro => throw _privateConstructorUsedError;

  /// Repasse — gerenciado manualmente pelo admin.
  @JsonKey(
    name: 'repasse_status',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  RepasseStatus? get repasseStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'repasse_valor')
  double? get repasseValor => throw _privateConstructorUsedError;
  @JsonKey(name: 'aviso_a_caminho_em')
  String? get avisoACaminhoEm => throw _privateConstructorUsedError;

  /// Avaliação (preenchida pelo backend após pesquisa).
  @JsonKey(name: 'avaliacao_nota')
  double? get avaliacaoNota => throw _privateConstructorUsedError;
  @JsonKey(name: 'avaliacao_motivo')
  String? get avaliacaoMotivo => throw _privateConstructorUsedError;
  @JsonKey(name: 'avaliacao_em')
  String? get avaliacaoEm => throw _privateConstructorUsedError;
  @JsonKey(name: 'avaliacao_solicitada_em')
  String? get avaliacaoSolicitadaEm => throw _privateConstructorUsedError;
  String? get observacoes =>
      throw _privateConstructorUsedError; /* ---- campos RICOS do módulo Serviços/OS (JSON) ---- */
  @JsonKey(name: 'service_snapshot')
  ServiceSnapshot? get serviceSnapshot => throw _privateConstructorUsedError;
  @JsonKey(name: 'checklist_exec')
  List<ChecklistExecItem> get checklistExec =>
      throw _privateConstructorUsedError;
  List<ServicoAdicionalOS> get adicionais => throw _privateConstructorUsedError;
  @JsonKey(name: 'observacoes_prof')
  List<ObservacaoProfissional> get observacoesProf =>
      throw _privateConstructorUsedError;

  /// Desconto (R$) aplicado no resumo da execução.
  double get descontos => throw _privateConstructorUsedError;
  @JsonKey(name: 'relatorio_enviado_em')
  String? get relatorioEnviadoEm => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Preenchido só em [fromRecord] a partir de `?expand=...`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  OSExpand? get expand => throw _privateConstructorUsedError;

  /// Serializes this OrdemServico to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrdemServicoCopyWith<OrdemServico> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrdemServicoCopyWith<$Res> {
  factory $OrdemServicoCopyWith(
    OrdemServico value,
    $Res Function(OrdemServico) then,
  ) = _$OrdemServicoCopyWithImpl<$Res, OrdemServico>;
  @useResult
  $Res call({
    String id,
    String cliente,
    @JsonKey(name: 'nome_curto') String nomeCurto,
    String bairro,
    String? servico,
    @JsonKey(name: 'tipo_servico_nome') String? tipoServicoNome,
    @JsonKey(name: 'data_hora') String dataHora,
    @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
    int? duracaoMin,
    String? profissional,
    @JsonKey(unknownEnumValue: OSStatus.agendada) OSStatus status,
    @JsonKey(name: 'valor_servico') double? valorServico,
    @JsonKey(name: 'endereco_liberado') String? enderecoLiberado,
    @JsonKey(name: 'valor_pago') double? valorPago,
    @JsonKey(
      name: 'forma_pagamento',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    FormaPagamento? formaPagamento,
    @JsonKey(name: 'forma_pagamento_outro') String? formaPagamentoOutro,
    @JsonKey(
      name: 'repasse_status',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    RepasseStatus? repasseStatus,
    @JsonKey(name: 'repasse_valor') double? repasseValor,
    @JsonKey(name: 'aviso_a_caminho_em') String? avisoACaminhoEm,
    @JsonKey(name: 'avaliacao_nota') double? avaliacaoNota,
    @JsonKey(name: 'avaliacao_motivo') String? avaliacaoMotivo,
    @JsonKey(name: 'avaliacao_em') String? avaliacaoEm,
    @JsonKey(name: 'avaliacao_solicitada_em') String? avaliacaoSolicitadaEm,
    String? observacoes,
    @JsonKey(name: 'service_snapshot') ServiceSnapshot? serviceSnapshot,
    @JsonKey(name: 'checklist_exec') List<ChecklistExecItem> checklistExec,
    List<ServicoAdicionalOS> adicionais,
    @JsonKey(name: 'observacoes_prof')
    List<ObservacaoProfissional> observacoesProf,
    double descontos,
    @JsonKey(name: 'relatorio_enviado_em') String? relatorioEnviadoEm,
    String? created,
    String? updated,
    @JsonKey(includeFromJson: false, includeToJson: false) OSExpand? expand,
  });

  $ServiceSnapshotCopyWith<$Res>? get serviceSnapshot;
  $OSExpandCopyWith<$Res>? get expand;
}

/// @nodoc
class _$OrdemServicoCopyWithImpl<$Res, $Val extends OrdemServico>
    implements $OrdemServicoCopyWith<$Res> {
  _$OrdemServicoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cliente = null,
    Object? nomeCurto = null,
    Object? bairro = null,
    Object? servico = freezed,
    Object? tipoServicoNome = freezed,
    Object? dataHora = null,
    Object? duracaoMin = freezed,
    Object? profissional = freezed,
    Object? status = null,
    Object? valorServico = freezed,
    Object? enderecoLiberado = freezed,
    Object? valorPago = freezed,
    Object? formaPagamento = freezed,
    Object? formaPagamentoOutro = freezed,
    Object? repasseStatus = freezed,
    Object? repasseValor = freezed,
    Object? avisoACaminhoEm = freezed,
    Object? avaliacaoNota = freezed,
    Object? avaliacaoMotivo = freezed,
    Object? avaliacaoEm = freezed,
    Object? avaliacaoSolicitadaEm = freezed,
    Object? observacoes = freezed,
    Object? serviceSnapshot = freezed,
    Object? checklistExec = null,
    Object? adicionais = null,
    Object? observacoesProf = null,
    Object? descontos = null,
    Object? relatorioEnviadoEm = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? expand = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            cliente: null == cliente
                ? _value.cliente
                : cliente // ignore: cast_nullable_to_non_nullable
                      as String,
            nomeCurto: null == nomeCurto
                ? _value.nomeCurto
                : nomeCurto // ignore: cast_nullable_to_non_nullable
                      as String,
            bairro: null == bairro
                ? _value.bairro
                : bairro // ignore: cast_nullable_to_non_nullable
                      as String,
            servico: freezed == servico
                ? _value.servico
                : servico // ignore: cast_nullable_to_non_nullable
                      as String?,
            tipoServicoNome: freezed == tipoServicoNome
                ? _value.tipoServicoNome
                : tipoServicoNome // ignore: cast_nullable_to_non_nullable
                      as String?,
            dataHora: null == dataHora
                ? _value.dataHora
                : dataHora // ignore: cast_nullable_to_non_nullable
                      as String,
            duracaoMin: freezed == duracaoMin
                ? _value.duracaoMin
                : duracaoMin // ignore: cast_nullable_to_non_nullable
                      as int?,
            profissional: freezed == profissional
                ? _value.profissional
                : profissional // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OSStatus,
            valorServico: freezed == valorServico
                ? _value.valorServico
                : valorServico // ignore: cast_nullable_to_non_nullable
                      as double?,
            enderecoLiberado: freezed == enderecoLiberado
                ? _value.enderecoLiberado
                : enderecoLiberado // ignore: cast_nullable_to_non_nullable
                      as String?,
            valorPago: freezed == valorPago
                ? _value.valorPago
                : valorPago // ignore: cast_nullable_to_non_nullable
                      as double?,
            formaPagamento: freezed == formaPagamento
                ? _value.formaPagamento
                : formaPagamento // ignore: cast_nullable_to_non_nullable
                      as FormaPagamento?,
            formaPagamentoOutro: freezed == formaPagamentoOutro
                ? _value.formaPagamentoOutro
                : formaPagamentoOutro // ignore: cast_nullable_to_non_nullable
                      as String?,
            repasseStatus: freezed == repasseStatus
                ? _value.repasseStatus
                : repasseStatus // ignore: cast_nullable_to_non_nullable
                      as RepasseStatus?,
            repasseValor: freezed == repasseValor
                ? _value.repasseValor
                : repasseValor // ignore: cast_nullable_to_non_nullable
                      as double?,
            avisoACaminhoEm: freezed == avisoACaminhoEm
                ? _value.avisoACaminhoEm
                : avisoACaminhoEm // ignore: cast_nullable_to_non_nullable
                      as String?,
            avaliacaoNota: freezed == avaliacaoNota
                ? _value.avaliacaoNota
                : avaliacaoNota // ignore: cast_nullable_to_non_nullable
                      as double?,
            avaliacaoMotivo: freezed == avaliacaoMotivo
                ? _value.avaliacaoMotivo
                : avaliacaoMotivo // ignore: cast_nullable_to_non_nullable
                      as String?,
            avaliacaoEm: freezed == avaliacaoEm
                ? _value.avaliacaoEm
                : avaliacaoEm // ignore: cast_nullable_to_non_nullable
                      as String?,
            avaliacaoSolicitadaEm: freezed == avaliacaoSolicitadaEm
                ? _value.avaliacaoSolicitadaEm
                : avaliacaoSolicitadaEm // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacoes: freezed == observacoes
                ? _value.observacoes
                : observacoes // ignore: cast_nullable_to_non_nullable
                      as String?,
            serviceSnapshot: freezed == serviceSnapshot
                ? _value.serviceSnapshot
                : serviceSnapshot // ignore: cast_nullable_to_non_nullable
                      as ServiceSnapshot?,
            checklistExec: null == checklistExec
                ? _value.checklistExec
                : checklistExec // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistExecItem>,
            adicionais: null == adicionais
                ? _value.adicionais
                : adicionais // ignore: cast_nullable_to_non_nullable
                      as List<ServicoAdicionalOS>,
            observacoesProf: null == observacoesProf
                ? _value.observacoesProf
                : observacoesProf // ignore: cast_nullable_to_non_nullable
                      as List<ObservacaoProfissional>,
            descontos: null == descontos
                ? _value.descontos
                : descontos // ignore: cast_nullable_to_non_nullable
                      as double,
            relatorioEnviadoEm: freezed == relatorioEnviadoEm
                ? _value.relatorioEnviadoEm
                : relatorioEnviadoEm // ignore: cast_nullable_to_non_nullable
                      as String?,
            created: freezed == created
                ? _value.created
                : created // ignore: cast_nullable_to_non_nullable
                      as String?,
            updated: freezed == updated
                ? _value.updated
                : updated // ignore: cast_nullable_to_non_nullable
                      as String?,
            expand: freezed == expand
                ? _value.expand
                : expand // ignore: cast_nullable_to_non_nullable
                      as OSExpand?,
          )
          as $Val,
    );
  }

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ServiceSnapshotCopyWith<$Res>? get serviceSnapshot {
    if (_value.serviceSnapshot == null) {
      return null;
    }

    return $ServiceSnapshotCopyWith<$Res>(_value.serviceSnapshot!, (value) {
      return _then(_value.copyWith(serviceSnapshot: value) as $Val);
    });
  }

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OSExpandCopyWith<$Res>? get expand {
    if (_value.expand == null) {
      return null;
    }

    return $OSExpandCopyWith<$Res>(_value.expand!, (value) {
      return _then(_value.copyWith(expand: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OrdemServicoImplCopyWith<$Res>
    implements $OrdemServicoCopyWith<$Res> {
  factory _$$OrdemServicoImplCopyWith(
    _$OrdemServicoImpl value,
    $Res Function(_$OrdemServicoImpl) then,
  ) = __$$OrdemServicoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String cliente,
    @JsonKey(name: 'nome_curto') String nomeCurto,
    String bairro,
    String? servico,
    @JsonKey(name: 'tipo_servico_nome') String? tipoServicoNome,
    @JsonKey(name: 'data_hora') String dataHora,
    @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
    int? duracaoMin,
    String? profissional,
    @JsonKey(unknownEnumValue: OSStatus.agendada) OSStatus status,
    @JsonKey(name: 'valor_servico') double? valorServico,
    @JsonKey(name: 'endereco_liberado') String? enderecoLiberado,
    @JsonKey(name: 'valor_pago') double? valorPago,
    @JsonKey(
      name: 'forma_pagamento',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    FormaPagamento? formaPagamento,
    @JsonKey(name: 'forma_pagamento_outro') String? formaPagamentoOutro,
    @JsonKey(
      name: 'repasse_status',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    RepasseStatus? repasseStatus,
    @JsonKey(name: 'repasse_valor') double? repasseValor,
    @JsonKey(name: 'aviso_a_caminho_em') String? avisoACaminhoEm,
    @JsonKey(name: 'avaliacao_nota') double? avaliacaoNota,
    @JsonKey(name: 'avaliacao_motivo') String? avaliacaoMotivo,
    @JsonKey(name: 'avaliacao_em') String? avaliacaoEm,
    @JsonKey(name: 'avaliacao_solicitada_em') String? avaliacaoSolicitadaEm,
    String? observacoes,
    @JsonKey(name: 'service_snapshot') ServiceSnapshot? serviceSnapshot,
    @JsonKey(name: 'checklist_exec') List<ChecklistExecItem> checklistExec,
    List<ServicoAdicionalOS> adicionais,
    @JsonKey(name: 'observacoes_prof')
    List<ObservacaoProfissional> observacoesProf,
    double descontos,
    @JsonKey(name: 'relatorio_enviado_em') String? relatorioEnviadoEm,
    String? created,
    String? updated,
    @JsonKey(includeFromJson: false, includeToJson: false) OSExpand? expand,
  });

  @override
  $ServiceSnapshotCopyWith<$Res>? get serviceSnapshot;
  @override
  $OSExpandCopyWith<$Res>? get expand;
}

/// @nodoc
class __$$OrdemServicoImplCopyWithImpl<$Res>
    extends _$OrdemServicoCopyWithImpl<$Res, _$OrdemServicoImpl>
    implements _$$OrdemServicoImplCopyWith<$Res> {
  __$$OrdemServicoImplCopyWithImpl(
    _$OrdemServicoImpl _value,
    $Res Function(_$OrdemServicoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cliente = null,
    Object? nomeCurto = null,
    Object? bairro = null,
    Object? servico = freezed,
    Object? tipoServicoNome = freezed,
    Object? dataHora = null,
    Object? duracaoMin = freezed,
    Object? profissional = freezed,
    Object? status = null,
    Object? valorServico = freezed,
    Object? enderecoLiberado = freezed,
    Object? valorPago = freezed,
    Object? formaPagamento = freezed,
    Object? formaPagamentoOutro = freezed,
    Object? repasseStatus = freezed,
    Object? repasseValor = freezed,
    Object? avisoACaminhoEm = freezed,
    Object? avaliacaoNota = freezed,
    Object? avaliacaoMotivo = freezed,
    Object? avaliacaoEm = freezed,
    Object? avaliacaoSolicitadaEm = freezed,
    Object? observacoes = freezed,
    Object? serviceSnapshot = freezed,
    Object? checklistExec = null,
    Object? adicionais = null,
    Object? observacoesProf = null,
    Object? descontos = null,
    Object? relatorioEnviadoEm = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? expand = freezed,
  }) {
    return _then(
      _$OrdemServicoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        cliente: null == cliente
            ? _value.cliente
            : cliente // ignore: cast_nullable_to_non_nullable
                  as String,
        nomeCurto: null == nomeCurto
            ? _value.nomeCurto
            : nomeCurto // ignore: cast_nullable_to_non_nullable
                  as String,
        bairro: null == bairro
            ? _value.bairro
            : bairro // ignore: cast_nullable_to_non_nullable
                  as String,
        servico: freezed == servico
            ? _value.servico
            : servico // ignore: cast_nullable_to_non_nullable
                  as String?,
        tipoServicoNome: freezed == tipoServicoNome
            ? _value.tipoServicoNome
            : tipoServicoNome // ignore: cast_nullable_to_non_nullable
                  as String?,
        dataHora: null == dataHora
            ? _value.dataHora
            : dataHora // ignore: cast_nullable_to_non_nullable
                  as String,
        duracaoMin: freezed == duracaoMin
            ? _value.duracaoMin
            : duracaoMin // ignore: cast_nullable_to_non_nullable
                  as int?,
        profissional: freezed == profissional
            ? _value.profissional
            : profissional // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OSStatus,
        valorServico: freezed == valorServico
            ? _value.valorServico
            : valorServico // ignore: cast_nullable_to_non_nullable
                  as double?,
        enderecoLiberado: freezed == enderecoLiberado
            ? _value.enderecoLiberado
            : enderecoLiberado // ignore: cast_nullable_to_non_nullable
                  as String?,
        valorPago: freezed == valorPago
            ? _value.valorPago
            : valorPago // ignore: cast_nullable_to_non_nullable
                  as double?,
        formaPagamento: freezed == formaPagamento
            ? _value.formaPagamento
            : formaPagamento // ignore: cast_nullable_to_non_nullable
                  as FormaPagamento?,
        formaPagamentoOutro: freezed == formaPagamentoOutro
            ? _value.formaPagamentoOutro
            : formaPagamentoOutro // ignore: cast_nullable_to_non_nullable
                  as String?,
        repasseStatus: freezed == repasseStatus
            ? _value.repasseStatus
            : repasseStatus // ignore: cast_nullable_to_non_nullable
                  as RepasseStatus?,
        repasseValor: freezed == repasseValor
            ? _value.repasseValor
            : repasseValor // ignore: cast_nullable_to_non_nullable
                  as double?,
        avisoACaminhoEm: freezed == avisoACaminhoEm
            ? _value.avisoACaminhoEm
            : avisoACaminhoEm // ignore: cast_nullable_to_non_nullable
                  as String?,
        avaliacaoNota: freezed == avaliacaoNota
            ? _value.avaliacaoNota
            : avaliacaoNota // ignore: cast_nullable_to_non_nullable
                  as double?,
        avaliacaoMotivo: freezed == avaliacaoMotivo
            ? _value.avaliacaoMotivo
            : avaliacaoMotivo // ignore: cast_nullable_to_non_nullable
                  as String?,
        avaliacaoEm: freezed == avaliacaoEm
            ? _value.avaliacaoEm
            : avaliacaoEm // ignore: cast_nullable_to_non_nullable
                  as String?,
        avaliacaoSolicitadaEm: freezed == avaliacaoSolicitadaEm
            ? _value.avaliacaoSolicitadaEm
            : avaliacaoSolicitadaEm // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacoes: freezed == observacoes
            ? _value.observacoes
            : observacoes // ignore: cast_nullable_to_non_nullable
                  as String?,
        serviceSnapshot: freezed == serviceSnapshot
            ? _value.serviceSnapshot
            : serviceSnapshot // ignore: cast_nullable_to_non_nullable
                  as ServiceSnapshot?,
        checklistExec: null == checklistExec
            ? _value._checklistExec
            : checklistExec // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistExecItem>,
        adicionais: null == adicionais
            ? _value._adicionais
            : adicionais // ignore: cast_nullable_to_non_nullable
                  as List<ServicoAdicionalOS>,
        observacoesProf: null == observacoesProf
            ? _value._observacoesProf
            : observacoesProf // ignore: cast_nullable_to_non_nullable
                  as List<ObservacaoProfissional>,
        descontos: null == descontos
            ? _value.descontos
            : descontos // ignore: cast_nullable_to_non_nullable
                  as double,
        relatorioEnviadoEm: freezed == relatorioEnviadoEm
            ? _value.relatorioEnviadoEm
            : relatorioEnviadoEm // ignore: cast_nullable_to_non_nullable
                  as String?,
        created: freezed == created
            ? _value.created
            : created // ignore: cast_nullable_to_non_nullable
                  as String?,
        updated: freezed == updated
            ? _value.updated
            : updated // ignore: cast_nullable_to_non_nullable
                  as String?,
        expand: freezed == expand
            ? _value.expand
            : expand // ignore: cast_nullable_to_non_nullable
                  as OSExpand?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrdemServicoImpl extends _OrdemServico {
  const _$OrdemServicoImpl({
    required this.id,
    this.cliente = '',
    @JsonKey(name: 'nome_curto') this.nomeCurto = '',
    this.bairro = '',
    this.servico,
    @JsonKey(name: 'tipo_servico_nome') this.tipoServicoNome,
    @JsonKey(name: 'data_hora') this.dataHora = '',
    @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
    this.duracaoMin,
    this.profissional,
    @JsonKey(unknownEnumValue: OSStatus.agendada)
    this.status = OSStatus.agendada,
    @JsonKey(name: 'valor_servico') this.valorServico,
    @JsonKey(name: 'endereco_liberado') this.enderecoLiberado,
    @JsonKey(name: 'valor_pago') this.valorPago,
    @JsonKey(
      name: 'forma_pagamento',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    this.formaPagamento,
    @JsonKey(name: 'forma_pagamento_outro') this.formaPagamentoOutro,
    @JsonKey(
      name: 'repasse_status',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    this.repasseStatus,
    @JsonKey(name: 'repasse_valor') this.repasseValor,
    @JsonKey(name: 'aviso_a_caminho_em') this.avisoACaminhoEm,
    @JsonKey(name: 'avaliacao_nota') this.avaliacaoNota,
    @JsonKey(name: 'avaliacao_motivo') this.avaliacaoMotivo,
    @JsonKey(name: 'avaliacao_em') this.avaliacaoEm,
    @JsonKey(name: 'avaliacao_solicitada_em') this.avaliacaoSolicitadaEm,
    this.observacoes,
    @JsonKey(name: 'service_snapshot') this.serviceSnapshot,
    @JsonKey(name: 'checklist_exec')
    final List<ChecklistExecItem> checklistExec = const <ChecklistExecItem>[],
    final List<ServicoAdicionalOS> adicionais = const <ServicoAdicionalOS>[],
    @JsonKey(name: 'observacoes_prof')
    final List<ObservacaoProfissional> observacoesProf =
        const <ObservacaoProfissional>[],
    this.descontos = 0,
    @JsonKey(name: 'relatorio_enviado_em') this.relatorioEnviadoEm,
    this.created,
    this.updated,
    @JsonKey(includeFromJson: false, includeToJson: false) this.expand,
  }) : _checklistExec = checklistExec,
       _adicionais = adicionais,
       _observacoesProf = observacoesProf,
       super._();

  factory _$OrdemServicoImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrdemServicoImplFromJson(json);

  @override
  final String id;

  /// Relation → clientes (ID opaco). O profissional recebe só o ID, nunca o expand.
  @override
  @JsonKey()
  final String cliente;

  /// "Carlos S." — denormalizado por hook.
  @override
  @JsonKey(name: 'nome_curto')
  final String nomeCurto;

  /// endereco_bairro do cliente — denormalizado por hook.
  @override
  @JsonKey()
  final String bairro;

  /// Relation → servicos (ID).
  @override
  final String? servico;
  @override
  @JsonKey(name: 'tipo_servico_nome')
  final String? tipoServicoNome;

  /// ISO datetime UTC.
  @override
  @JsonKey(name: 'data_hora')
  final String dataHora;

  /// Duração do atendimento em minutos (fim = [dataHora] + [duracaoMin]).
  ///
  /// ⚠️ R2 (variante NUMÉRICA): NumberField opcional do PB volta como **0**
  /// quando vazio — nunca `null`. Toda OS anterior à migration 27 chega com
  /// `"duracao_min": 0`. [_duracaoMinFromJson] normaliza `<= 0 → null` já no
  /// parse (fromJson e fromRecord), para o resto do app poder confiar em
  /// `null == sem duração própria` e cair no fallback do
  /// `duracaoEfetivaMin` (OS > profissional > 60).
  @override
  @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
  final int? duracaoMin;

  /// Relation → users (ID).
  @override
  final String? profissional;
  @override
  @JsonKey(unknownEnumValue: OSStatus.agendada)
  final OSStatus status;
  @override
  @JsonKey(name: 'valor_servico')
  final double? valorServico;

  /// Endereço completo — só preenchido quando status === 'em_andamento'.
  @override
  @JsonKey(name: 'endereco_liberado')
  final String? enderecoLiberado;

  /// Pagamento (preenchido pelo profissional ao concluir).
  @override
  @JsonKey(name: 'valor_pago')
  final double? valorPago;
  @override
  @JsonKey(
    name: 'forma_pagamento',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final FormaPagamento? formaPagamento;

  /// Detalhe livre quando [formaPagamento] é [FormaPagamento.outros]
  /// (ex.: "Transferência", "Cortesia"). "" no PB vira null aqui (R2).
  @override
  @JsonKey(name: 'forma_pagamento_outro')
  final String? formaPagamentoOutro;

  /// Repasse — gerenciado manualmente pelo admin.
  @override
  @JsonKey(
    name: 'repasse_status',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final RepasseStatus? repasseStatus;
  @override
  @JsonKey(name: 'repasse_valor')
  final double? repasseValor;
  @override
  @JsonKey(name: 'aviso_a_caminho_em')
  final String? avisoACaminhoEm;

  /// Avaliação (preenchida pelo backend após pesquisa).
  @override
  @JsonKey(name: 'avaliacao_nota')
  final double? avaliacaoNota;
  @override
  @JsonKey(name: 'avaliacao_motivo')
  final String? avaliacaoMotivo;
  @override
  @JsonKey(name: 'avaliacao_em')
  final String? avaliacaoEm;
  @override
  @JsonKey(name: 'avaliacao_solicitada_em')
  final String? avaliacaoSolicitadaEm;
  @override
  final String? observacoes;
  /* ---- campos RICOS do módulo Serviços/OS (JSON) ---- */
  @override
  @JsonKey(name: 'service_snapshot')
  final ServiceSnapshot? serviceSnapshot;
  final List<ChecklistExecItem> _checklistExec;
  @override
  @JsonKey(name: 'checklist_exec')
  List<ChecklistExecItem> get checklistExec {
    if (_checklistExec is EqualUnmodifiableListView) return _checklistExec;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklistExec);
  }

  final List<ServicoAdicionalOS> _adicionais;
  @override
  @JsonKey()
  List<ServicoAdicionalOS> get adicionais {
    if (_adicionais is EqualUnmodifiableListView) return _adicionais;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_adicionais);
  }

  final List<ObservacaoProfissional> _observacoesProf;
  @override
  @JsonKey(name: 'observacoes_prof')
  List<ObservacaoProfissional> get observacoesProf {
    if (_observacoesProf is EqualUnmodifiableListView) return _observacoesProf;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_observacoesProf);
  }

  /// Desconto (R$) aplicado no resumo da execução.
  @override
  @JsonKey()
  final double descontos;
  @override
  @JsonKey(name: 'relatorio_enviado_em')
  final String? relatorioEnviadoEm;
  @override
  final String? created;
  @override
  final String? updated;

  /// Preenchido só em [fromRecord] a partir de `?expand=...`.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final OSExpand? expand;

  @override
  String toString() {
    return 'OrdemServico(id: $id, cliente: $cliente, nomeCurto: $nomeCurto, bairro: $bairro, servico: $servico, tipoServicoNome: $tipoServicoNome, dataHora: $dataHora, duracaoMin: $duracaoMin, profissional: $profissional, status: $status, valorServico: $valorServico, enderecoLiberado: $enderecoLiberado, valorPago: $valorPago, formaPagamento: $formaPagamento, formaPagamentoOutro: $formaPagamentoOutro, repasseStatus: $repasseStatus, repasseValor: $repasseValor, avisoACaminhoEm: $avisoACaminhoEm, avaliacaoNota: $avaliacaoNota, avaliacaoMotivo: $avaliacaoMotivo, avaliacaoEm: $avaliacaoEm, avaliacaoSolicitadaEm: $avaliacaoSolicitadaEm, observacoes: $observacoes, serviceSnapshot: $serviceSnapshot, checklistExec: $checklistExec, adicionais: $adicionais, observacoesProf: $observacoesProf, descontos: $descontos, relatorioEnviadoEm: $relatorioEnviadoEm, created: $created, updated: $updated, expand: $expand)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrdemServicoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.cliente, cliente) || other.cliente == cliente) &&
            (identical(other.nomeCurto, nomeCurto) ||
                other.nomeCurto == nomeCurto) &&
            (identical(other.bairro, bairro) || other.bairro == bairro) &&
            (identical(other.servico, servico) || other.servico == servico) &&
            (identical(other.tipoServicoNome, tipoServicoNome) ||
                other.tipoServicoNome == tipoServicoNome) &&
            (identical(other.dataHora, dataHora) ||
                other.dataHora == dataHora) &&
            (identical(other.duracaoMin, duracaoMin) ||
                other.duracaoMin == duracaoMin) &&
            (identical(other.profissional, profissional) ||
                other.profissional == profissional) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.valorServico, valorServico) ||
                other.valorServico == valorServico) &&
            (identical(other.enderecoLiberado, enderecoLiberado) ||
                other.enderecoLiberado == enderecoLiberado) &&
            (identical(other.valorPago, valorPago) ||
                other.valorPago == valorPago) &&
            (identical(other.formaPagamento, formaPagamento) ||
                other.formaPagamento == formaPagamento) &&
            (identical(other.formaPagamentoOutro, formaPagamentoOutro) ||
                other.formaPagamentoOutro == formaPagamentoOutro) &&
            (identical(other.repasseStatus, repasseStatus) ||
                other.repasseStatus == repasseStatus) &&
            (identical(other.repasseValor, repasseValor) ||
                other.repasseValor == repasseValor) &&
            (identical(other.avisoACaminhoEm, avisoACaminhoEm) ||
                other.avisoACaminhoEm == avisoACaminhoEm) &&
            (identical(other.avaliacaoNota, avaliacaoNota) ||
                other.avaliacaoNota == avaliacaoNota) &&
            (identical(other.avaliacaoMotivo, avaliacaoMotivo) ||
                other.avaliacaoMotivo == avaliacaoMotivo) &&
            (identical(other.avaliacaoEm, avaliacaoEm) ||
                other.avaliacaoEm == avaliacaoEm) &&
            (identical(other.avaliacaoSolicitadaEm, avaliacaoSolicitadaEm) ||
                other.avaliacaoSolicitadaEm == avaliacaoSolicitadaEm) &&
            (identical(other.observacoes, observacoes) ||
                other.observacoes == observacoes) &&
            (identical(other.serviceSnapshot, serviceSnapshot) ||
                other.serviceSnapshot == serviceSnapshot) &&
            const DeepCollectionEquality().equals(
              other._checklistExec,
              _checklistExec,
            ) &&
            const DeepCollectionEquality().equals(
              other._adicionais,
              _adicionais,
            ) &&
            const DeepCollectionEquality().equals(
              other._observacoesProf,
              _observacoesProf,
            ) &&
            (identical(other.descontos, descontos) ||
                other.descontos == descontos) &&
            (identical(other.relatorioEnviadoEm, relatorioEnviadoEm) ||
                other.relatorioEnviadoEm == relatorioEnviadoEm) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.expand, expand) || other.expand == expand));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    cliente,
    nomeCurto,
    bairro,
    servico,
    tipoServicoNome,
    dataHora,
    duracaoMin,
    profissional,
    status,
    valorServico,
    enderecoLiberado,
    valorPago,
    formaPagamento,
    formaPagamentoOutro,
    repasseStatus,
    repasseValor,
    avisoACaminhoEm,
    avaliacaoNota,
    avaliacaoMotivo,
    avaliacaoEm,
    avaliacaoSolicitadaEm,
    observacoes,
    serviceSnapshot,
    const DeepCollectionEquality().hash(_checklistExec),
    const DeepCollectionEquality().hash(_adicionais),
    const DeepCollectionEquality().hash(_observacoesProf),
    descontos,
    relatorioEnviadoEm,
    created,
    updated,
    expand,
  ]);

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrdemServicoImplCopyWith<_$OrdemServicoImpl> get copyWith =>
      __$$OrdemServicoImplCopyWithImpl<_$OrdemServicoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrdemServicoImplToJson(this);
  }
}

abstract class _OrdemServico extends OrdemServico {
  const factory _OrdemServico({
    required final String id,
    final String cliente,
    @JsonKey(name: 'nome_curto') final String nomeCurto,
    final String bairro,
    final String? servico,
    @JsonKey(name: 'tipo_servico_nome') final String? tipoServicoNome,
    @JsonKey(name: 'data_hora') final String dataHora,
    @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
    final int? duracaoMin,
    final String? profissional,
    @JsonKey(unknownEnumValue: OSStatus.agendada) final OSStatus status,
    @JsonKey(name: 'valor_servico') final double? valorServico,
    @JsonKey(name: 'endereco_liberado') final String? enderecoLiberado,
    @JsonKey(name: 'valor_pago') final double? valorPago,
    @JsonKey(
      name: 'forma_pagamento',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    final FormaPagamento? formaPagamento,
    @JsonKey(name: 'forma_pagamento_outro') final String? formaPagamentoOutro,
    @JsonKey(
      name: 'repasse_status',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    final RepasseStatus? repasseStatus,
    @JsonKey(name: 'repasse_valor') final double? repasseValor,
    @JsonKey(name: 'aviso_a_caminho_em') final String? avisoACaminhoEm,
    @JsonKey(name: 'avaliacao_nota') final double? avaliacaoNota,
    @JsonKey(name: 'avaliacao_motivo') final String? avaliacaoMotivo,
    @JsonKey(name: 'avaliacao_em') final String? avaliacaoEm,
    @JsonKey(name: 'avaliacao_solicitada_em')
    final String? avaliacaoSolicitadaEm,
    final String? observacoes,
    @JsonKey(name: 'service_snapshot') final ServiceSnapshot? serviceSnapshot,
    @JsonKey(name: 'checklist_exec')
    final List<ChecklistExecItem> checklistExec,
    final List<ServicoAdicionalOS> adicionais,
    @JsonKey(name: 'observacoes_prof')
    final List<ObservacaoProfissional> observacoesProf,
    final double descontos,
    @JsonKey(name: 'relatorio_enviado_em') final String? relatorioEnviadoEm,
    final String? created,
    final String? updated,
    @JsonKey(includeFromJson: false, includeToJson: false)
    final OSExpand? expand,
  }) = _$OrdemServicoImpl;
  const _OrdemServico._() : super._();

  factory _OrdemServico.fromJson(Map<String, dynamic> json) =
      _$OrdemServicoImpl.fromJson;

  @override
  String get id;

  /// Relation → clientes (ID opaco). O profissional recebe só o ID, nunca o expand.
  @override
  String get cliente;

  /// "Carlos S." — denormalizado por hook.
  @override
  @JsonKey(name: 'nome_curto')
  String get nomeCurto;

  /// endereco_bairro do cliente — denormalizado por hook.
  @override
  String get bairro;

  /// Relation → servicos (ID).
  @override
  String? get servico;
  @override
  @JsonKey(name: 'tipo_servico_nome')
  String? get tipoServicoNome;

  /// ISO datetime UTC.
  @override
  @JsonKey(name: 'data_hora')
  String get dataHora;

  /// Duração do atendimento em minutos (fim = [dataHora] + [duracaoMin]).
  ///
  /// ⚠️ R2 (variante NUMÉRICA): NumberField opcional do PB volta como **0**
  /// quando vazio — nunca `null`. Toda OS anterior à migration 27 chega com
  /// `"duracao_min": 0`. [_duracaoMinFromJson] normaliza `<= 0 → null` já no
  /// parse (fromJson e fromRecord), para o resto do app poder confiar em
  /// `null == sem duração própria` e cair no fallback do
  /// `duracaoEfetivaMin` (OS > profissional > 60).
  @override
  @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson)
  int? get duracaoMin;

  /// Relation → users (ID).
  @override
  String? get profissional;
  @override
  @JsonKey(unknownEnumValue: OSStatus.agendada)
  OSStatus get status;
  @override
  @JsonKey(name: 'valor_servico')
  double? get valorServico;

  /// Endereço completo — só preenchido quando status === 'em_andamento'.
  @override
  @JsonKey(name: 'endereco_liberado')
  String? get enderecoLiberado;

  /// Pagamento (preenchido pelo profissional ao concluir).
  @override
  @JsonKey(name: 'valor_pago')
  double? get valorPago;
  @override
  @JsonKey(
    name: 'forma_pagamento',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  FormaPagamento? get formaPagamento;

  /// Detalhe livre quando [formaPagamento] é [FormaPagamento.outros]
  /// (ex.: "Transferência", "Cortesia"). "" no PB vira null aqui (R2).
  @override
  @JsonKey(name: 'forma_pagamento_outro')
  String? get formaPagamentoOutro;

  /// Repasse — gerenciado manualmente pelo admin.
  @override
  @JsonKey(
    name: 'repasse_status',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  RepasseStatus? get repasseStatus;
  @override
  @JsonKey(name: 'repasse_valor')
  double? get repasseValor;
  @override
  @JsonKey(name: 'aviso_a_caminho_em')
  String? get avisoACaminhoEm;

  /// Avaliação (preenchida pelo backend após pesquisa).
  @override
  @JsonKey(name: 'avaliacao_nota')
  double? get avaliacaoNota;
  @override
  @JsonKey(name: 'avaliacao_motivo')
  String? get avaliacaoMotivo;
  @override
  @JsonKey(name: 'avaliacao_em')
  String? get avaliacaoEm;
  @override
  @JsonKey(name: 'avaliacao_solicitada_em')
  String? get avaliacaoSolicitadaEm;
  @override
  String? get observacoes; /* ---- campos RICOS do módulo Serviços/OS (JSON) ---- */
  @override
  @JsonKey(name: 'service_snapshot')
  ServiceSnapshot? get serviceSnapshot;
  @override
  @JsonKey(name: 'checklist_exec')
  List<ChecklistExecItem> get checklistExec;
  @override
  List<ServicoAdicionalOS> get adicionais;
  @override
  @JsonKey(name: 'observacoes_prof')
  List<ObservacaoProfissional> get observacoesProf;

  /// Desconto (R$) aplicado no resumo da execução.
  @override
  double get descontos;
  @override
  @JsonKey(name: 'relatorio_enviado_em')
  String? get relatorioEnviadoEm;
  @override
  String? get created;
  @override
  String? get updated;

  /// Preenchido só em [fromRecord] a partir de `?expand=...`.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  OSExpand? get expand;

  /// Create a copy of OrdemServico
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrdemServicoImplCopyWith<_$OrdemServicoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
