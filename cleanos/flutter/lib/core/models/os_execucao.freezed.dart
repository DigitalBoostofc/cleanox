// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'os_execucao.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChecklistExecItem _$ChecklistExecItemFromJson(Map<String, dynamic> json) {
  return _ChecklistExecItem.fromJson(json);
}

/// @nodoc
mixin _$ChecklistExecItem {
  String get id => throw _privateConstructorUsedError;
  String get titulo => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
  ChecklistExecStatus get status => throw _privateConstructorUsedError;
  String? get observacao => throw _privateConstructorUsedError;

  /// ISO datetime de conclusão.
  String? get concluidoEm => throw _privateConstructorUsedError;
  String? get concluidoPor => throw _privateConstructorUsedError;

  /// IDs de EvidenciaFoto vinculadas a este item.
  List<String> get fotosIds => throw _privateConstructorUsedError;

  /// Propagado do template: bloqueia conclusão da OS enquanto pendente.
  bool get obrigatorio => throw _privateConstructorUsedError;

  /// Serializes this ChecklistExecItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistExecItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistExecItemCopyWith<ChecklistExecItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistExecItemCopyWith<$Res> {
  factory $ChecklistExecItemCopyWith(
    ChecklistExecItem value,
    $Res Function(ChecklistExecItem) then,
  ) = _$ChecklistExecItemCopyWithImpl<$Res, ChecklistExecItem>;
  @useResult
  $Res call({
    String id,
    String titulo,
    @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
    ChecklistExecStatus status,
    String? observacao,
    String? concluidoEm,
    String? concluidoPor,
    List<String> fotosIds,
    bool obrigatorio,
  });
}

/// @nodoc
class _$ChecklistExecItemCopyWithImpl<$Res, $Val extends ChecklistExecItem>
    implements $ChecklistExecItemCopyWith<$Res> {
  _$ChecklistExecItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistExecItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? titulo = null,
    Object? status = null,
    Object? observacao = freezed,
    Object? concluidoEm = freezed,
    Object? concluidoPor = freezed,
    Object? fotosIds = null,
    Object? obrigatorio = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            titulo: null == titulo
                ? _value.titulo
                : titulo // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ChecklistExecStatus,
            observacao: freezed == observacao
                ? _value.observacao
                : observacao // ignore: cast_nullable_to_non_nullable
                      as String?,
            concluidoEm: freezed == concluidoEm
                ? _value.concluidoEm
                : concluidoEm // ignore: cast_nullable_to_non_nullable
                      as String?,
            concluidoPor: freezed == concluidoPor
                ? _value.concluidoPor
                : concluidoPor // ignore: cast_nullable_to_non_nullable
                      as String?,
            fotosIds: null == fotosIds
                ? _value.fotosIds
                : fotosIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            obrigatorio: null == obrigatorio
                ? _value.obrigatorio
                : obrigatorio // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChecklistExecItemImplCopyWith<$Res>
    implements $ChecklistExecItemCopyWith<$Res> {
  factory _$$ChecklistExecItemImplCopyWith(
    _$ChecklistExecItemImpl value,
    $Res Function(_$ChecklistExecItemImpl) then,
  ) = __$$ChecklistExecItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String titulo,
    @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
    ChecklistExecStatus status,
    String? observacao,
    String? concluidoEm,
    String? concluidoPor,
    List<String> fotosIds,
    bool obrigatorio,
  });
}

/// @nodoc
class __$$ChecklistExecItemImplCopyWithImpl<$Res>
    extends _$ChecklistExecItemCopyWithImpl<$Res, _$ChecklistExecItemImpl>
    implements _$$ChecklistExecItemImplCopyWith<$Res> {
  __$$ChecklistExecItemImplCopyWithImpl(
    _$ChecklistExecItemImpl _value,
    $Res Function(_$ChecklistExecItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChecklistExecItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? titulo = null,
    Object? status = null,
    Object? observacao = freezed,
    Object? concluidoEm = freezed,
    Object? concluidoPor = freezed,
    Object? fotosIds = null,
    Object? obrigatorio = null,
  }) {
    return _then(
      _$ChecklistExecItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        titulo: null == titulo
            ? _value.titulo
            : titulo // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ChecklistExecStatus,
        observacao: freezed == observacao
            ? _value.observacao
            : observacao // ignore: cast_nullable_to_non_nullable
                  as String?,
        concluidoEm: freezed == concluidoEm
            ? _value.concluidoEm
            : concluidoEm // ignore: cast_nullable_to_non_nullable
                  as String?,
        concluidoPor: freezed == concluidoPor
            ? _value.concluidoPor
            : concluidoPor // ignore: cast_nullable_to_non_nullable
                  as String?,
        fotosIds: null == fotosIds
            ? _value._fotosIds
            : fotosIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        obrigatorio: null == obrigatorio
            ? _value.obrigatorio
            : obrigatorio // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistExecItemImpl extends _ChecklistExecItem {
  const _$ChecklistExecItemImpl({
    this.id = '',
    this.titulo = '',
    @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
    this.status = ChecklistExecStatus.pendente,
    this.observacao,
    this.concluidoEm,
    this.concluidoPor,
    final List<String> fotosIds = const <String>[],
    this.obrigatorio = false,
  }) : _fotosIds = fotosIds,
       super._();

  factory _$ChecklistExecItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistExecItemImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String titulo;
  @override
  @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
  final ChecklistExecStatus status;
  @override
  final String? observacao;

  /// ISO datetime de conclusão.
  @override
  final String? concluidoEm;
  @override
  final String? concluidoPor;

  /// IDs de EvidenciaFoto vinculadas a este item.
  final List<String> _fotosIds;

  /// IDs de EvidenciaFoto vinculadas a este item.
  @override
  @JsonKey()
  List<String> get fotosIds {
    if (_fotosIds is EqualUnmodifiableListView) return _fotosIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fotosIds);
  }

  /// Propagado do template: bloqueia conclusão da OS enquanto pendente.
  @override
  @JsonKey()
  final bool obrigatorio;

  @override
  String toString() {
    return 'ChecklistExecItem(id: $id, titulo: $titulo, status: $status, observacao: $observacao, concluidoEm: $concluidoEm, concluidoPor: $concluidoPor, fotosIds: $fotosIds, obrigatorio: $obrigatorio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistExecItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.titulo, titulo) || other.titulo == titulo) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.observacao, observacao) ||
                other.observacao == observacao) &&
            (identical(other.concluidoEm, concluidoEm) ||
                other.concluidoEm == concluidoEm) &&
            (identical(other.concluidoPor, concluidoPor) ||
                other.concluidoPor == concluidoPor) &&
            const DeepCollectionEquality().equals(other._fotosIds, _fotosIds) &&
            (identical(other.obrigatorio, obrigatorio) ||
                other.obrigatorio == obrigatorio));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    titulo,
    status,
    observacao,
    concluidoEm,
    concluidoPor,
    const DeepCollectionEquality().hash(_fotosIds),
    obrigatorio,
  );

  /// Create a copy of ChecklistExecItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistExecItemImplCopyWith<_$ChecklistExecItemImpl> get copyWith =>
      __$$ChecklistExecItemImplCopyWithImpl<_$ChecklistExecItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistExecItemImplToJson(this);
  }
}

abstract class _ChecklistExecItem extends ChecklistExecItem {
  const factory _ChecklistExecItem({
    final String id,
    final String titulo,
    @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
    final ChecklistExecStatus status,
    final String? observacao,
    final String? concluidoEm,
    final String? concluidoPor,
    final List<String> fotosIds,
    final bool obrigatorio,
  }) = _$ChecklistExecItemImpl;
  const _ChecklistExecItem._() : super._();

  factory _ChecklistExecItem.fromJson(Map<String, dynamic> json) =
      _$ChecklistExecItemImpl.fromJson;

  @override
  String get id;
  @override
  String get titulo;
  @override
  @JsonKey(unknownEnumValue: ChecklistExecStatus.pendente)
  ChecklistExecStatus get status;
  @override
  String? get observacao;

  /// ISO datetime de conclusão.
  @override
  String? get concluidoEm;
  @override
  String? get concluidoPor;

  /// IDs de EvidenciaFoto vinculadas a este item.
  @override
  List<String> get fotosIds;

  /// Propagado do template: bloqueia conclusão da OS enquanto pendente.
  @override
  bool get obrigatorio;

  /// Create a copy of ChecklistExecItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistExecItemImplCopyWith<_$ChecklistExecItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ServicoAdicionalOS _$ServicoAdicionalOSFromJson(Map<String, dynamic> json) {
  return _ServicoAdicionalOS.fromJson(json);
}

/// @nodoc
mixin _$ServicoAdicionalOS {
  String get id => throw _privateConstructorUsedError;

  /// Presente quando o adicional veio do catálogo de serviços.
  String? get serviceId => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Categoria? get categoria => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Grupo? get grupo => throw _privateConstructorUsedError;
  double get valor => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  TipoValor? get tipoValor => throw _privateConstructorUsedError;
  int get quantidade => throw _privateConstructorUsedError;
  String? get motivo => throw _privateConstructorUsedError;
  String? get observacao => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
  AprovacaoStatus get aprovacao => throw _privateConstructorUsedError;

  /// Serializes this ServicoAdicionalOS to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ServicoAdicionalOS
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServicoAdicionalOSCopyWith<ServicoAdicionalOS> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServicoAdicionalOSCopyWith<$Res> {
  factory $ServicoAdicionalOSCopyWith(
    ServicoAdicionalOS value,
    $Res Function(ServicoAdicionalOS) then,
  ) = _$ServicoAdicionalOSCopyWithImpl<$Res, ServicoAdicionalOS>;
  @useResult
  $Res call({
    String id,
    String? serviceId,
    String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    double valor,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TipoValor? tipoValor,
    int quantidade,
    String? motivo,
    String? observacao,
    @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
    AprovacaoStatus aprovacao,
  });
}

/// @nodoc
class _$ServicoAdicionalOSCopyWithImpl<$Res, $Val extends ServicoAdicionalOS>
    implements $ServicoAdicionalOSCopyWith<$Res> {
  _$ServicoAdicionalOSCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ServicoAdicionalOS
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? serviceId = freezed,
    Object? nome = null,
    Object? categoria = freezed,
    Object? grupo = freezed,
    Object? valor = null,
    Object? tipoValor = freezed,
    Object? quantidade = null,
    Object? motivo = freezed,
    Object? observacao = freezed,
    Object? aprovacao = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            serviceId: freezed == serviceId
                ? _value.serviceId
                : serviceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            categoria: freezed == categoria
                ? _value.categoria
                : categoria // ignore: cast_nullable_to_non_nullable
                      as Categoria?,
            grupo: freezed == grupo
                ? _value.grupo
                : grupo // ignore: cast_nullable_to_non_nullable
                      as Grupo?,
            valor: null == valor
                ? _value.valor
                : valor // ignore: cast_nullable_to_non_nullable
                      as double,
            tipoValor: freezed == tipoValor
                ? _value.tipoValor
                : tipoValor // ignore: cast_nullable_to_non_nullable
                      as TipoValor?,
            quantidade: null == quantidade
                ? _value.quantidade
                : quantidade // ignore: cast_nullable_to_non_nullable
                      as int,
            motivo: freezed == motivo
                ? _value.motivo
                : motivo // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacao: freezed == observacao
                ? _value.observacao
                : observacao // ignore: cast_nullable_to_non_nullable
                      as String?,
            aprovacao: null == aprovacao
                ? _value.aprovacao
                : aprovacao // ignore: cast_nullable_to_non_nullable
                      as AprovacaoStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ServicoAdicionalOSImplCopyWith<$Res>
    implements $ServicoAdicionalOSCopyWith<$Res> {
  factory _$$ServicoAdicionalOSImplCopyWith(
    _$ServicoAdicionalOSImpl value,
    $Res Function(_$ServicoAdicionalOSImpl) then,
  ) = __$$ServicoAdicionalOSImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? serviceId,
    String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    double valor,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TipoValor? tipoValor,
    int quantidade,
    String? motivo,
    String? observacao,
    @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
    AprovacaoStatus aprovacao,
  });
}

/// @nodoc
class __$$ServicoAdicionalOSImplCopyWithImpl<$Res>
    extends _$ServicoAdicionalOSCopyWithImpl<$Res, _$ServicoAdicionalOSImpl>
    implements _$$ServicoAdicionalOSImplCopyWith<$Res> {
  __$$ServicoAdicionalOSImplCopyWithImpl(
    _$ServicoAdicionalOSImpl _value,
    $Res Function(_$ServicoAdicionalOSImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ServicoAdicionalOS
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? serviceId = freezed,
    Object? nome = null,
    Object? categoria = freezed,
    Object? grupo = freezed,
    Object? valor = null,
    Object? tipoValor = freezed,
    Object? quantidade = null,
    Object? motivo = freezed,
    Object? observacao = freezed,
    Object? aprovacao = null,
  }) {
    return _then(
      _$ServicoAdicionalOSImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        serviceId: freezed == serviceId
            ? _value.serviceId
            : serviceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        categoria: freezed == categoria
            ? _value.categoria
            : categoria // ignore: cast_nullable_to_non_nullable
                  as Categoria?,
        grupo: freezed == grupo
            ? _value.grupo
            : grupo // ignore: cast_nullable_to_non_nullable
                  as Grupo?,
        valor: null == valor
            ? _value.valor
            : valor // ignore: cast_nullable_to_non_nullable
                  as double,
        tipoValor: freezed == tipoValor
            ? _value.tipoValor
            : tipoValor // ignore: cast_nullable_to_non_nullable
                  as TipoValor?,
        quantidade: null == quantidade
            ? _value.quantidade
            : quantidade // ignore: cast_nullable_to_non_nullable
                  as int,
        motivo: freezed == motivo
            ? _value.motivo
            : motivo // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacao: freezed == observacao
            ? _value.observacao
            : observacao // ignore: cast_nullable_to_non_nullable
                  as String?,
        aprovacao: null == aprovacao
            ? _value.aprovacao
            : aprovacao // ignore: cast_nullable_to_non_nullable
                  as AprovacaoStatus,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ServicoAdicionalOSImpl implements _ServicoAdicionalOS {
  const _$ServicoAdicionalOSImpl({
    this.id = '',
    this.serviceId,
    this.nome = '',
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    this.categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.grupo,
    this.valor = 0,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    this.tipoValor,
    this.quantidade = 1,
    this.motivo,
    this.observacao,
    @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
    this.aprovacao = AprovacaoStatus.naoRequer,
  });

  factory _$ServicoAdicionalOSImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServicoAdicionalOSImplFromJson(json);

  @override
  @JsonKey()
  final String id;

  /// Presente quando o adicional veio do catálogo de serviços.
  @override
  final String? serviceId;
  @override
  @JsonKey()
  final String nome;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final Categoria? categoria;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final Grupo? grupo;
  @override
  @JsonKey()
  final double valor;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final TipoValor? tipoValor;
  @override
  @JsonKey()
  final int quantidade;
  @override
  final String? motivo;
  @override
  final String? observacao;
  @override
  @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
  final AprovacaoStatus aprovacao;

  @override
  String toString() {
    return 'ServicoAdicionalOS(id: $id, serviceId: $serviceId, nome: $nome, categoria: $categoria, grupo: $grupo, valor: $valor, tipoValor: $tipoValor, quantidade: $quantidade, motivo: $motivo, observacao: $observacao, aprovacao: $aprovacao)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServicoAdicionalOSImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.serviceId, serviceId) ||
                other.serviceId == serviceId) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.categoria, categoria) ||
                other.categoria == categoria) &&
            (identical(other.grupo, grupo) || other.grupo == grupo) &&
            (identical(other.valor, valor) || other.valor == valor) &&
            (identical(other.tipoValor, tipoValor) ||
                other.tipoValor == tipoValor) &&
            (identical(other.quantidade, quantidade) ||
                other.quantidade == quantidade) &&
            (identical(other.motivo, motivo) || other.motivo == motivo) &&
            (identical(other.observacao, observacao) ||
                other.observacao == observacao) &&
            (identical(other.aprovacao, aprovacao) ||
                other.aprovacao == aprovacao));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    serviceId,
    nome,
    categoria,
    grupo,
    valor,
    tipoValor,
    quantidade,
    motivo,
    observacao,
    aprovacao,
  );

  /// Create a copy of ServicoAdicionalOS
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServicoAdicionalOSImplCopyWith<_$ServicoAdicionalOSImpl> get copyWith =>
      __$$ServicoAdicionalOSImplCopyWithImpl<_$ServicoAdicionalOSImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ServicoAdicionalOSImplToJson(this);
  }
}

abstract class _ServicoAdicionalOS implements ServicoAdicionalOS {
  const factory _ServicoAdicionalOS({
    final String id,
    final String? serviceId,
    final String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final Grupo? grupo,
    final double valor,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final TipoValor? tipoValor,
    final int quantidade,
    final String? motivo,
    final String? observacao,
    @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
    final AprovacaoStatus aprovacao,
  }) = _$ServicoAdicionalOSImpl;

  factory _ServicoAdicionalOS.fromJson(Map<String, dynamic> json) =
      _$ServicoAdicionalOSImpl.fromJson;

  @override
  String get id;

  /// Presente quando o adicional veio do catálogo de serviços.
  @override
  String? get serviceId;
  @override
  String get nome;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Categoria? get categoria;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Grupo? get grupo;
  @override
  double get valor;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  TipoValor? get tipoValor;
  @override
  int get quantidade;
  @override
  String? get motivo;
  @override
  String? get observacao;
  @override
  @JsonKey(unknownEnumValue: AprovacaoStatus.naoRequer)
  AprovacaoStatus get aprovacao;

  /// Create a copy of ServicoAdicionalOS
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServicoAdicionalOSImplCopyWith<_$ServicoAdicionalOSImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ObservacaoProfissional _$ObservacaoProfissionalFromJson(
  Map<String, dynamic> json,
) {
  return _ObservacaoProfissional.fromJson(json);
}

/// @nodoc
mixin _$ObservacaoProfissional {
  String get id => throw _privateConstructorUsedError;
  String get texto => throw _privateConstructorUsedError;

  /// Se true, aparece no relatório final ao cliente.
  bool get visivelCliente => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ObservacaoTipo? get tipo => throw _privateConstructorUsedError;
  String? get criadoPor => throw _privateConstructorUsedError;

  /// ISO datetime.
  String get criadoEm => throw _privateConstructorUsedError;
  List<String> get fotosIds => throw _privateConstructorUsedError;

  /// Serializes this ObservacaoProfissional to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ObservacaoProfissional
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ObservacaoProfissionalCopyWith<ObservacaoProfissional> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ObservacaoProfissionalCopyWith<$Res> {
  factory $ObservacaoProfissionalCopyWith(
    ObservacaoProfissional value,
    $Res Function(ObservacaoProfissional) then,
  ) = _$ObservacaoProfissionalCopyWithImpl<$Res, ObservacaoProfissional>;
  @useResult
  $Res call({
    String id,
    String texto,
    bool visivelCliente,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ObservacaoTipo? tipo,
    String? criadoPor,
    String criadoEm,
    List<String> fotosIds,
  });
}

/// @nodoc
class _$ObservacaoProfissionalCopyWithImpl<
  $Res,
  $Val extends ObservacaoProfissional
>
    implements $ObservacaoProfissionalCopyWith<$Res> {
  _$ObservacaoProfissionalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ObservacaoProfissional
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? texto = null,
    Object? visivelCliente = null,
    Object? tipo = freezed,
    Object? criadoPor = freezed,
    Object? criadoEm = null,
    Object? fotosIds = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            texto: null == texto
                ? _value.texto
                : texto // ignore: cast_nullable_to_non_nullable
                      as String,
            visivelCliente: null == visivelCliente
                ? _value.visivelCliente
                : visivelCliente // ignore: cast_nullable_to_non_nullable
                      as bool,
            tipo: freezed == tipo
                ? _value.tipo
                : tipo // ignore: cast_nullable_to_non_nullable
                      as ObservacaoTipo?,
            criadoPor: freezed == criadoPor
                ? _value.criadoPor
                : criadoPor // ignore: cast_nullable_to_non_nullable
                      as String?,
            criadoEm: null == criadoEm
                ? _value.criadoEm
                : criadoEm // ignore: cast_nullable_to_non_nullable
                      as String,
            fotosIds: null == fotosIds
                ? _value.fotosIds
                : fotosIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ObservacaoProfissionalImplCopyWith<$Res>
    implements $ObservacaoProfissionalCopyWith<$Res> {
  factory _$$ObservacaoProfissionalImplCopyWith(
    _$ObservacaoProfissionalImpl value,
    $Res Function(_$ObservacaoProfissionalImpl) then,
  ) = __$$ObservacaoProfissionalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String texto,
    bool visivelCliente,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ObservacaoTipo? tipo,
    String? criadoPor,
    String criadoEm,
    List<String> fotosIds,
  });
}

/// @nodoc
class __$$ObservacaoProfissionalImplCopyWithImpl<$Res>
    extends
        _$ObservacaoProfissionalCopyWithImpl<$Res, _$ObservacaoProfissionalImpl>
    implements _$$ObservacaoProfissionalImplCopyWith<$Res> {
  __$$ObservacaoProfissionalImplCopyWithImpl(
    _$ObservacaoProfissionalImpl _value,
    $Res Function(_$ObservacaoProfissionalImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ObservacaoProfissional
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? texto = null,
    Object? visivelCliente = null,
    Object? tipo = freezed,
    Object? criadoPor = freezed,
    Object? criadoEm = null,
    Object? fotosIds = null,
  }) {
    return _then(
      _$ObservacaoProfissionalImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        texto: null == texto
            ? _value.texto
            : texto // ignore: cast_nullable_to_non_nullable
                  as String,
        visivelCliente: null == visivelCliente
            ? _value.visivelCliente
            : visivelCliente // ignore: cast_nullable_to_non_nullable
                  as bool,
        tipo: freezed == tipo
            ? _value.tipo
            : tipo // ignore: cast_nullable_to_non_nullable
                  as ObservacaoTipo?,
        criadoPor: freezed == criadoPor
            ? _value.criadoPor
            : criadoPor // ignore: cast_nullable_to_non_nullable
                  as String?,
        criadoEm: null == criadoEm
            ? _value.criadoEm
            : criadoEm // ignore: cast_nullable_to_non_nullable
                  as String,
        fotosIds: null == fotosIds
            ? _value._fotosIds
            : fotosIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ObservacaoProfissionalImpl implements _ObservacaoProfissional {
  const _$ObservacaoProfissionalImpl({
    this.id = '',
    this.texto = '',
    this.visivelCliente = false,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.tipo,
    this.criadoPor,
    this.criadoEm = '',
    final List<String> fotosIds = const <String>[],
  }) : _fotosIds = fotosIds;

  factory _$ObservacaoProfissionalImpl.fromJson(Map<String, dynamic> json) =>
      _$$ObservacaoProfissionalImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String texto;

  /// Se true, aparece no relatório final ao cliente.
  @override
  @JsonKey()
  final bool visivelCliente;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final ObservacaoTipo? tipo;
  @override
  final String? criadoPor;

  /// ISO datetime.
  @override
  @JsonKey()
  final String criadoEm;
  final List<String> _fotosIds;
  @override
  @JsonKey()
  List<String> get fotosIds {
    if (_fotosIds is EqualUnmodifiableListView) return _fotosIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fotosIds);
  }

  @override
  String toString() {
    return 'ObservacaoProfissional(id: $id, texto: $texto, visivelCliente: $visivelCliente, tipo: $tipo, criadoPor: $criadoPor, criadoEm: $criadoEm, fotosIds: $fotosIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ObservacaoProfissionalImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.texto, texto) || other.texto == texto) &&
            (identical(other.visivelCliente, visivelCliente) ||
                other.visivelCliente == visivelCliente) &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.criadoPor, criadoPor) ||
                other.criadoPor == criadoPor) &&
            (identical(other.criadoEm, criadoEm) ||
                other.criadoEm == criadoEm) &&
            const DeepCollectionEquality().equals(other._fotosIds, _fotosIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    texto,
    visivelCliente,
    tipo,
    criadoPor,
    criadoEm,
    const DeepCollectionEquality().hash(_fotosIds),
  );

  /// Create a copy of ObservacaoProfissional
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ObservacaoProfissionalImplCopyWith<_$ObservacaoProfissionalImpl>
  get copyWith =>
      __$$ObservacaoProfissionalImplCopyWithImpl<_$ObservacaoProfissionalImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ObservacaoProfissionalImplToJson(this);
  }
}

abstract class _ObservacaoProfissional implements ObservacaoProfissional {
  const factory _ObservacaoProfissional({
    final String id,
    final String texto,
    final bool visivelCliente,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final ObservacaoTipo? tipo,
    final String? criadoPor,
    final String criadoEm,
    final List<String> fotosIds,
  }) = _$ObservacaoProfissionalImpl;

  factory _ObservacaoProfissional.fromJson(Map<String, dynamic> json) =
      _$ObservacaoProfissionalImpl.fromJson;

  @override
  String get id;
  @override
  String get texto;

  /// Se true, aparece no relatório final ao cliente.
  @override
  bool get visivelCliente;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ObservacaoTipo? get tipo;
  @override
  String? get criadoPor;

  /// ISO datetime.
  @override
  String get criadoEm;
  @override
  List<String> get fotosIds;

  /// Create a copy of ObservacaoProfissional
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ObservacaoProfissionalImplCopyWith<_$ObservacaoProfissionalImpl>
  get copyWith => throw _privateConstructorUsedError;
}

EvidenciaFoto _$EvidenciaFotoFromJson(Map<String, dynamic> json) {
  return _EvidenciaFoto.fromJson(json);
}

/// @nodoc
mixin _$EvidenciaFoto {
  String get id => throw _privateConstructorUsedError;

  /// URL do arquivo protegido no PB (precisa de file token na query).
  String get url => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: FaseFoto.antes)
  FaseFoto get fase => throw _privateConstructorUsedError;
  String? get legenda => throw _privateConstructorUsedError;

  /// ISO datetime do envio.
  String get criadoEm => throw _privateConstructorUsedError;
  String? get enviadoPor => throw _privateConstructorUsedError;
  String? get checklistItemId => throw _privateConstructorUsedError;
  String? get observacaoId => throw _privateConstructorUsedError;
  String? get adicionalId => throw _privateConstructorUsedError;

  /// Serializes this EvidenciaFoto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EvidenciaFoto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EvidenciaFotoCopyWith<EvidenciaFoto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EvidenciaFotoCopyWith<$Res> {
  factory $EvidenciaFotoCopyWith(
    EvidenciaFoto value,
    $Res Function(EvidenciaFoto) then,
  ) = _$EvidenciaFotoCopyWithImpl<$Res, EvidenciaFoto>;
  @useResult
  $Res call({
    String id,
    String url,
    @JsonKey(unknownEnumValue: FaseFoto.antes) FaseFoto fase,
    String? legenda,
    String criadoEm,
    String? enviadoPor,
    String? checklistItemId,
    String? observacaoId,
    String? adicionalId,
  });
}

/// @nodoc
class _$EvidenciaFotoCopyWithImpl<$Res, $Val extends EvidenciaFoto>
    implements $EvidenciaFotoCopyWith<$Res> {
  _$EvidenciaFotoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EvidenciaFoto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? fase = null,
    Object? legenda = freezed,
    Object? criadoEm = null,
    Object? enviadoPor = freezed,
    Object? checklistItemId = freezed,
    Object? observacaoId = freezed,
    Object? adicionalId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            fase: null == fase
                ? _value.fase
                : fase // ignore: cast_nullable_to_non_nullable
                      as FaseFoto,
            legenda: freezed == legenda
                ? _value.legenda
                : legenda // ignore: cast_nullable_to_non_nullable
                      as String?,
            criadoEm: null == criadoEm
                ? _value.criadoEm
                : criadoEm // ignore: cast_nullable_to_non_nullable
                      as String,
            enviadoPor: freezed == enviadoPor
                ? _value.enviadoPor
                : enviadoPor // ignore: cast_nullable_to_non_nullable
                      as String?,
            checklistItemId: freezed == checklistItemId
                ? _value.checklistItemId
                : checklistItemId // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacaoId: freezed == observacaoId
                ? _value.observacaoId
                : observacaoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            adicionalId: freezed == adicionalId
                ? _value.adicionalId
                : adicionalId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EvidenciaFotoImplCopyWith<$Res>
    implements $EvidenciaFotoCopyWith<$Res> {
  factory _$$EvidenciaFotoImplCopyWith(
    _$EvidenciaFotoImpl value,
    $Res Function(_$EvidenciaFotoImpl) then,
  ) = __$$EvidenciaFotoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String url,
    @JsonKey(unknownEnumValue: FaseFoto.antes) FaseFoto fase,
    String? legenda,
    String criadoEm,
    String? enviadoPor,
    String? checklistItemId,
    String? observacaoId,
    String? adicionalId,
  });
}

/// @nodoc
class __$$EvidenciaFotoImplCopyWithImpl<$Res>
    extends _$EvidenciaFotoCopyWithImpl<$Res, _$EvidenciaFotoImpl>
    implements _$$EvidenciaFotoImplCopyWith<$Res> {
  __$$EvidenciaFotoImplCopyWithImpl(
    _$EvidenciaFotoImpl _value,
    $Res Function(_$EvidenciaFotoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EvidenciaFoto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? fase = null,
    Object? legenda = freezed,
    Object? criadoEm = null,
    Object? enviadoPor = freezed,
    Object? checklistItemId = freezed,
    Object? observacaoId = freezed,
    Object? adicionalId = freezed,
  }) {
    return _then(
      _$EvidenciaFotoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        fase: null == fase
            ? _value.fase
            : fase // ignore: cast_nullable_to_non_nullable
                  as FaseFoto,
        legenda: freezed == legenda
            ? _value.legenda
            : legenda // ignore: cast_nullable_to_non_nullable
                  as String?,
        criadoEm: null == criadoEm
            ? _value.criadoEm
            : criadoEm // ignore: cast_nullable_to_non_nullable
                  as String,
        enviadoPor: freezed == enviadoPor
            ? _value.enviadoPor
            : enviadoPor // ignore: cast_nullable_to_non_nullable
                  as String?,
        checklistItemId: freezed == checklistItemId
            ? _value.checklistItemId
            : checklistItemId // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacaoId: freezed == observacaoId
            ? _value.observacaoId
            : observacaoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        adicionalId: freezed == adicionalId
            ? _value.adicionalId
            : adicionalId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EvidenciaFotoImpl implements _EvidenciaFoto {
  const _$EvidenciaFotoImpl({
    this.id = '',
    this.url = '',
    @JsonKey(unknownEnumValue: FaseFoto.antes) this.fase = FaseFoto.antes,
    this.legenda,
    this.criadoEm = '',
    this.enviadoPor,
    this.checklistItemId,
    this.observacaoId,
    this.adicionalId,
  });

  factory _$EvidenciaFotoImpl.fromJson(Map<String, dynamic> json) =>
      _$$EvidenciaFotoImplFromJson(json);

  @override
  @JsonKey()
  final String id;

  /// URL do arquivo protegido no PB (precisa de file token na query).
  @override
  @JsonKey()
  final String url;
  @override
  @JsonKey(unknownEnumValue: FaseFoto.antes)
  final FaseFoto fase;
  @override
  final String? legenda;

  /// ISO datetime do envio.
  @override
  @JsonKey()
  final String criadoEm;
  @override
  final String? enviadoPor;
  @override
  final String? checklistItemId;
  @override
  final String? observacaoId;
  @override
  final String? adicionalId;

  @override
  String toString() {
    return 'EvidenciaFoto(id: $id, url: $url, fase: $fase, legenda: $legenda, criadoEm: $criadoEm, enviadoPor: $enviadoPor, checklistItemId: $checklistItemId, observacaoId: $observacaoId, adicionalId: $adicionalId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EvidenciaFotoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.fase, fase) || other.fase == fase) &&
            (identical(other.legenda, legenda) || other.legenda == legenda) &&
            (identical(other.criadoEm, criadoEm) ||
                other.criadoEm == criadoEm) &&
            (identical(other.enviadoPor, enviadoPor) ||
                other.enviadoPor == enviadoPor) &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.observacaoId, observacaoId) ||
                other.observacaoId == observacaoId) &&
            (identical(other.adicionalId, adicionalId) ||
                other.adicionalId == adicionalId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    url,
    fase,
    legenda,
    criadoEm,
    enviadoPor,
    checklistItemId,
    observacaoId,
    adicionalId,
  );

  /// Create a copy of EvidenciaFoto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EvidenciaFotoImplCopyWith<_$EvidenciaFotoImpl> get copyWith =>
      __$$EvidenciaFotoImplCopyWithImpl<_$EvidenciaFotoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EvidenciaFotoImplToJson(this);
  }
}

abstract class _EvidenciaFoto implements EvidenciaFoto {
  const factory _EvidenciaFoto({
    final String id,
    final String url,
    @JsonKey(unknownEnumValue: FaseFoto.antes) final FaseFoto fase,
    final String? legenda,
    final String criadoEm,
    final String? enviadoPor,
    final String? checklistItemId,
    final String? observacaoId,
    final String? adicionalId,
  }) = _$EvidenciaFotoImpl;

  factory _EvidenciaFoto.fromJson(Map<String, dynamic> json) =
      _$EvidenciaFotoImpl.fromJson;

  @override
  String get id;

  /// URL do arquivo protegido no PB (precisa de file token na query).
  @override
  String get url;
  @override
  @JsonKey(unknownEnumValue: FaseFoto.antes)
  FaseFoto get fase;
  @override
  String? get legenda;

  /// ISO datetime do envio.
  @override
  String get criadoEm;
  @override
  String? get enviadoPor;
  @override
  String? get checklistItemId;
  @override
  String? get observacaoId;
  @override
  String? get adicionalId;

  /// Create a copy of EvidenciaFoto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EvidenciaFotoImplCopyWith<_$EvidenciaFotoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OSEvidenciaPB _$OSEvidenciaPBFromJson(Map<String, dynamic> json) {
  return _OSEvidenciaPB.fromJson(json);
}

/// @nodoc
mixin _$OSEvidenciaPB {
  String get id => throw _privateConstructorUsedError;
  String get os => throw _privateConstructorUsedError;
  String? get foto => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  FaseFoto? get fase => throw _privateConstructorUsedError;
  String? get legenda => throw _privateConstructorUsedError;
  @JsonKey(name: 'checklist_item_id')
  String? get checklistItemId => throw _privateConstructorUsedError;
  @JsonKey(name: 'observacao_id')
  String? get observacaoId => throw _privateConstructorUsedError;
  @JsonKey(name: 'adicional_id')
  String? get adicionalId => throw _privateConstructorUsedError;
  @JsonKey(name: 'enviado_por')
  String? get enviadoPor => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this OSEvidenciaPB to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OSEvidenciaPB
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OSEvidenciaPBCopyWith<OSEvidenciaPB> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OSEvidenciaPBCopyWith<$Res> {
  factory $OSEvidenciaPBCopyWith(
    OSEvidenciaPB value,
    $Res Function(OSEvidenciaPB) then,
  ) = _$OSEvidenciaPBCopyWithImpl<$Res, OSEvidenciaPB>;
  @useResult
  $Res call({
    String id,
    String os,
    String? foto,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    FaseFoto? fase,
    String? legenda,
    @JsonKey(name: 'checklist_item_id') String? checklistItemId,
    @JsonKey(name: 'observacao_id') String? observacaoId,
    @JsonKey(name: 'adicional_id') String? adicionalId,
    @JsonKey(name: 'enviado_por') String? enviadoPor,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$OSEvidenciaPBCopyWithImpl<$Res, $Val extends OSEvidenciaPB>
    implements $OSEvidenciaPBCopyWith<$Res> {
  _$OSEvidenciaPBCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OSEvidenciaPB
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? os = null,
    Object? foto = freezed,
    Object? fase = freezed,
    Object? legenda = freezed,
    Object? checklistItemId = freezed,
    Object? observacaoId = freezed,
    Object? adicionalId = freezed,
    Object? enviadoPor = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            os: null == os
                ? _value.os
                : os // ignore: cast_nullable_to_non_nullable
                      as String,
            foto: freezed == foto
                ? _value.foto
                : foto // ignore: cast_nullable_to_non_nullable
                      as String?,
            fase: freezed == fase
                ? _value.fase
                : fase // ignore: cast_nullable_to_non_nullable
                      as FaseFoto?,
            legenda: freezed == legenda
                ? _value.legenda
                : legenda // ignore: cast_nullable_to_non_nullable
                      as String?,
            checklistItemId: freezed == checklistItemId
                ? _value.checklistItemId
                : checklistItemId // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacaoId: freezed == observacaoId
                ? _value.observacaoId
                : observacaoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            adicionalId: freezed == adicionalId
                ? _value.adicionalId
                : adicionalId // ignore: cast_nullable_to_non_nullable
                      as String?,
            enviadoPor: freezed == enviadoPor
                ? _value.enviadoPor
                : enviadoPor // ignore: cast_nullable_to_non_nullable
                      as String?,
            created: freezed == created
                ? _value.created
                : created // ignore: cast_nullable_to_non_nullable
                      as String?,
            updated: freezed == updated
                ? _value.updated
                : updated // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OSEvidenciaPBImplCopyWith<$Res>
    implements $OSEvidenciaPBCopyWith<$Res> {
  factory _$$OSEvidenciaPBImplCopyWith(
    _$OSEvidenciaPBImpl value,
    $Res Function(_$OSEvidenciaPBImpl) then,
  ) = __$$OSEvidenciaPBImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String os,
    String? foto,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    FaseFoto? fase,
    String? legenda,
    @JsonKey(name: 'checklist_item_id') String? checklistItemId,
    @JsonKey(name: 'observacao_id') String? observacaoId,
    @JsonKey(name: 'adicional_id') String? adicionalId,
    @JsonKey(name: 'enviado_por') String? enviadoPor,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$OSEvidenciaPBImplCopyWithImpl<$Res>
    extends _$OSEvidenciaPBCopyWithImpl<$Res, _$OSEvidenciaPBImpl>
    implements _$$OSEvidenciaPBImplCopyWith<$Res> {
  __$$OSEvidenciaPBImplCopyWithImpl(
    _$OSEvidenciaPBImpl _value,
    $Res Function(_$OSEvidenciaPBImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OSEvidenciaPB
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? os = null,
    Object? foto = freezed,
    Object? fase = freezed,
    Object? legenda = freezed,
    Object? checklistItemId = freezed,
    Object? observacaoId = freezed,
    Object? adicionalId = freezed,
    Object? enviadoPor = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$OSEvidenciaPBImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        os: null == os
            ? _value.os
            : os // ignore: cast_nullable_to_non_nullable
                  as String,
        foto: freezed == foto
            ? _value.foto
            : foto // ignore: cast_nullable_to_non_nullable
                  as String?,
        fase: freezed == fase
            ? _value.fase
            : fase // ignore: cast_nullable_to_non_nullable
                  as FaseFoto?,
        legenda: freezed == legenda
            ? _value.legenda
            : legenda // ignore: cast_nullable_to_non_nullable
                  as String?,
        checklistItemId: freezed == checklistItemId
            ? _value.checklistItemId
            : checklistItemId // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacaoId: freezed == observacaoId
            ? _value.observacaoId
            : observacaoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        adicionalId: freezed == adicionalId
            ? _value.adicionalId
            : adicionalId // ignore: cast_nullable_to_non_nullable
                  as String?,
        enviadoPor: freezed == enviadoPor
            ? _value.enviadoPor
            : enviadoPor // ignore: cast_nullable_to_non_nullable
                  as String?,
        created: freezed == created
            ? _value.created
            : created // ignore: cast_nullable_to_non_nullable
                  as String?,
        updated: freezed == updated
            ? _value.updated
            : updated // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OSEvidenciaPBImpl extends _OSEvidenciaPB {
  const _$OSEvidenciaPBImpl({
    required this.id,
    this.os = '',
    this.foto,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.fase,
    this.legenda,
    @JsonKey(name: 'checklist_item_id') this.checklistItemId,
    @JsonKey(name: 'observacao_id') this.observacaoId,
    @JsonKey(name: 'adicional_id') this.adicionalId,
    @JsonKey(name: 'enviado_por') this.enviadoPor,
    this.created,
    this.updated,
  }) : super._();

  factory _$OSEvidenciaPBImpl.fromJson(Map<String, dynamic> json) =>
      _$$OSEvidenciaPBImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String os;
  @override
  final String? foto;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final FaseFoto? fase;
  @override
  final String? legenda;
  @override
  @JsonKey(name: 'checklist_item_id')
  final String? checklistItemId;
  @override
  @JsonKey(name: 'observacao_id')
  final String? observacaoId;
  @override
  @JsonKey(name: 'adicional_id')
  final String? adicionalId;
  @override
  @JsonKey(name: 'enviado_por')
  final String? enviadoPor;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'OSEvidenciaPB(id: $id, os: $os, foto: $foto, fase: $fase, legenda: $legenda, checklistItemId: $checklistItemId, observacaoId: $observacaoId, adicionalId: $adicionalId, enviadoPor: $enviadoPor, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OSEvidenciaPBImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.os, os) || other.os == os) &&
            (identical(other.foto, foto) || other.foto == foto) &&
            (identical(other.fase, fase) || other.fase == fase) &&
            (identical(other.legenda, legenda) || other.legenda == legenda) &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.observacaoId, observacaoId) ||
                other.observacaoId == observacaoId) &&
            (identical(other.adicionalId, adicionalId) ||
                other.adicionalId == adicionalId) &&
            (identical(other.enviadoPor, enviadoPor) ||
                other.enviadoPor == enviadoPor) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    os,
    foto,
    fase,
    legenda,
    checklistItemId,
    observacaoId,
    adicionalId,
    enviadoPor,
    created,
    updated,
  );

  /// Create a copy of OSEvidenciaPB
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OSEvidenciaPBImplCopyWith<_$OSEvidenciaPBImpl> get copyWith =>
      __$$OSEvidenciaPBImplCopyWithImpl<_$OSEvidenciaPBImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OSEvidenciaPBImplToJson(this);
  }
}

abstract class _OSEvidenciaPB extends OSEvidenciaPB {
  const factory _OSEvidenciaPB({
    required final String id,
    final String os,
    final String? foto,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final FaseFoto? fase,
    final String? legenda,
    @JsonKey(name: 'checklist_item_id') final String? checklistItemId,
    @JsonKey(name: 'observacao_id') final String? observacaoId,
    @JsonKey(name: 'adicional_id') final String? adicionalId,
    @JsonKey(name: 'enviado_por') final String? enviadoPor,
    final String? created,
    final String? updated,
  }) = _$OSEvidenciaPBImpl;
  const _OSEvidenciaPB._() : super._();

  factory _OSEvidenciaPB.fromJson(Map<String, dynamic> json) =
      _$OSEvidenciaPBImpl.fromJson;

  @override
  String get id;
  @override
  String get os;
  @override
  String? get foto;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  FaseFoto? get fase;
  @override
  String? get legenda;
  @override
  @JsonKey(name: 'checklist_item_id')
  String? get checklistItemId;
  @override
  @JsonKey(name: 'observacao_id')
  String? get observacaoId;
  @override
  @JsonKey(name: 'adicional_id')
  String? get adicionalId;
  @override
  @JsonKey(name: 'enviado_por')
  String? get enviadoPor;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of OSEvidenciaPB
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OSEvidenciaPBImplCopyWith<_$OSEvidenciaPBImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
