// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config_atuacao.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ConfigAtuacaoCidade _$ConfigAtuacaoCidadeFromJson(Map<String, dynamic> json) {
  return _ConfigAtuacaoCidade.fromJson(json);
}

/// @nodoc
mixin _$ConfigAtuacaoCidade {
  String get nome => throw _privateConstructorUsedError;
  bool get principal => throw _privateConstructorUsedError;
  List<String> get bairros => throw _privateConstructorUsedError;

  /// Serializes this ConfigAtuacaoCidade to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConfigAtuacaoCidade
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConfigAtuacaoCidadeCopyWith<ConfigAtuacaoCidade> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConfigAtuacaoCidadeCopyWith<$Res> {
  factory $ConfigAtuacaoCidadeCopyWith(
    ConfigAtuacaoCidade value,
    $Res Function(ConfigAtuacaoCidade) then,
  ) = _$ConfigAtuacaoCidadeCopyWithImpl<$Res, ConfigAtuacaoCidade>;
  @useResult
  $Res call({String nome, bool principal, List<String> bairros});
}

/// @nodoc
class _$ConfigAtuacaoCidadeCopyWithImpl<$Res, $Val extends ConfigAtuacaoCidade>
    implements $ConfigAtuacaoCidadeCopyWith<$Res> {
  _$ConfigAtuacaoCidadeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConfigAtuacaoCidade
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nome = null,
    Object? principal = null,
    Object? bairros = null,
  }) {
    return _then(
      _value.copyWith(
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            principal: null == principal
                ? _value.principal
                : principal // ignore: cast_nullable_to_non_nullable
                      as bool,
            bairros: null == bairros
                ? _value.bairros
                : bairros // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConfigAtuacaoCidadeImplCopyWith<$Res>
    implements $ConfigAtuacaoCidadeCopyWith<$Res> {
  factory _$$ConfigAtuacaoCidadeImplCopyWith(
    _$ConfigAtuacaoCidadeImpl value,
    $Res Function(_$ConfigAtuacaoCidadeImpl) then,
  ) = __$$ConfigAtuacaoCidadeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String nome, bool principal, List<String> bairros});
}

/// @nodoc
class __$$ConfigAtuacaoCidadeImplCopyWithImpl<$Res>
    extends _$ConfigAtuacaoCidadeCopyWithImpl<$Res, _$ConfigAtuacaoCidadeImpl>
    implements _$$ConfigAtuacaoCidadeImplCopyWith<$Res> {
  __$$ConfigAtuacaoCidadeImplCopyWithImpl(
    _$ConfigAtuacaoCidadeImpl _value,
    $Res Function(_$ConfigAtuacaoCidadeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConfigAtuacaoCidade
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nome = null,
    Object? principal = null,
    Object? bairros = null,
  }) {
    return _then(
      _$ConfigAtuacaoCidadeImpl(
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        principal: null == principal
            ? _value.principal
            : principal // ignore: cast_nullable_to_non_nullable
                  as bool,
        bairros: null == bairros
            ? _value._bairros
            : bairros // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConfigAtuacaoCidadeImpl implements _ConfigAtuacaoCidade {
  const _$ConfigAtuacaoCidadeImpl({
    this.nome = '',
    this.principal = false,
    final List<String> bairros = const <String>[],
  }) : _bairros = bairros;

  factory _$ConfigAtuacaoCidadeImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConfigAtuacaoCidadeImplFromJson(json);

  @override
  @JsonKey()
  final String nome;
  @override
  @JsonKey()
  final bool principal;
  final List<String> _bairros;
  @override
  @JsonKey()
  List<String> get bairros {
    if (_bairros is EqualUnmodifiableListView) return _bairros;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bairros);
  }

  @override
  String toString() {
    return 'ConfigAtuacaoCidade(nome: $nome, principal: $principal, bairros: $bairros)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConfigAtuacaoCidadeImpl &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.principal, principal) ||
                other.principal == principal) &&
            const DeepCollectionEquality().equals(other._bairros, _bairros));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    nome,
    principal,
    const DeepCollectionEquality().hash(_bairros),
  );

  /// Create a copy of ConfigAtuacaoCidade
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConfigAtuacaoCidadeImplCopyWith<_$ConfigAtuacaoCidadeImpl> get copyWith =>
      __$$ConfigAtuacaoCidadeImplCopyWithImpl<_$ConfigAtuacaoCidadeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConfigAtuacaoCidadeImplToJson(this);
  }
}

abstract class _ConfigAtuacaoCidade implements ConfigAtuacaoCidade {
  const factory _ConfigAtuacaoCidade({
    final String nome,
    final bool principal,
    final List<String> bairros,
  }) = _$ConfigAtuacaoCidadeImpl;

  factory _ConfigAtuacaoCidade.fromJson(Map<String, dynamic> json) =
      _$ConfigAtuacaoCidadeImpl.fromJson;

  @override
  String get nome;
  @override
  bool get principal;
  @override
  List<String> get bairros;

  /// Create a copy of ConfigAtuacaoCidade
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConfigAtuacaoCidadeImplCopyWith<_$ConfigAtuacaoCidadeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConfigAtuacao _$ConfigAtuacaoFromJson(Map<String, dynamic> json) {
  return _ConfigAtuacao.fromJson(json);
}

/// @nodoc
mixin _$ConfigAtuacao {
  String get id => throw _privateConstructorUsedError;
  String get estado => throw _privateConstructorUsedError;
  List<ConfigAtuacaoCidade> get cidades => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this ConfigAtuacao to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConfigAtuacao
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConfigAtuacaoCopyWith<ConfigAtuacao> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConfigAtuacaoCopyWith<$Res> {
  factory $ConfigAtuacaoCopyWith(
    ConfigAtuacao value,
    $Res Function(ConfigAtuacao) then,
  ) = _$ConfigAtuacaoCopyWithImpl<$Res, ConfigAtuacao>;
  @useResult
  $Res call({
    String id,
    String estado,
    List<ConfigAtuacaoCidade> cidades,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$ConfigAtuacaoCopyWithImpl<$Res, $Val extends ConfigAtuacao>
    implements $ConfigAtuacaoCopyWith<$Res> {
  _$ConfigAtuacaoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConfigAtuacao
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? estado = null,
    Object? cidades = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            estado: null == estado
                ? _value.estado
                : estado // ignore: cast_nullable_to_non_nullable
                      as String,
            cidades: null == cidades
                ? _value.cidades
                : cidades // ignore: cast_nullable_to_non_nullable
                      as List<ConfigAtuacaoCidade>,
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
abstract class _$$ConfigAtuacaoImplCopyWith<$Res>
    implements $ConfigAtuacaoCopyWith<$Res> {
  factory _$$ConfigAtuacaoImplCopyWith(
    _$ConfigAtuacaoImpl value,
    $Res Function(_$ConfigAtuacaoImpl) then,
  ) = __$$ConfigAtuacaoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String estado,
    List<ConfigAtuacaoCidade> cidades,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$ConfigAtuacaoImplCopyWithImpl<$Res>
    extends _$ConfigAtuacaoCopyWithImpl<$Res, _$ConfigAtuacaoImpl>
    implements _$$ConfigAtuacaoImplCopyWith<$Res> {
  __$$ConfigAtuacaoImplCopyWithImpl(
    _$ConfigAtuacaoImpl _value,
    $Res Function(_$ConfigAtuacaoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConfigAtuacao
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? estado = null,
    Object? cidades = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$ConfigAtuacaoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        estado: null == estado
            ? _value.estado
            : estado // ignore: cast_nullable_to_non_nullable
                  as String,
        cidades: null == cidades
            ? _value._cidades
            : cidades // ignore: cast_nullable_to_non_nullable
                  as List<ConfigAtuacaoCidade>,
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
class _$ConfigAtuacaoImpl extends _ConfigAtuacao {
  const _$ConfigAtuacaoImpl({
    required this.id,
    this.estado = '',
    final List<ConfigAtuacaoCidade> cidades = const <ConfigAtuacaoCidade>[],
    this.created,
    this.updated,
  }) : _cidades = cidades,
       super._();

  factory _$ConfigAtuacaoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConfigAtuacaoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String estado;
  final List<ConfigAtuacaoCidade> _cidades;
  @override
  @JsonKey()
  List<ConfigAtuacaoCidade> get cidades {
    if (_cidades is EqualUnmodifiableListView) return _cidades;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_cidades);
  }

  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'ConfigAtuacao(id: $id, estado: $estado, cidades: $cidades, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConfigAtuacaoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.estado, estado) || other.estado == estado) &&
            const DeepCollectionEquality().equals(other._cidades, _cidades) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    estado,
    const DeepCollectionEquality().hash(_cidades),
    created,
    updated,
  );

  /// Create a copy of ConfigAtuacao
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConfigAtuacaoImplCopyWith<_$ConfigAtuacaoImpl> get copyWith =>
      __$$ConfigAtuacaoImplCopyWithImpl<_$ConfigAtuacaoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConfigAtuacaoImplToJson(this);
  }
}

abstract class _ConfigAtuacao extends ConfigAtuacao {
  const factory _ConfigAtuacao({
    required final String id,
    final String estado,
    final List<ConfigAtuacaoCidade> cidades,
    final String? created,
    final String? updated,
  }) = _$ConfigAtuacaoImpl;
  const _ConfigAtuacao._() : super._();

  factory _ConfigAtuacao.fromJson(Map<String, dynamic> json) =
      _$ConfigAtuacaoImpl.fromJson;

  @override
  String get id;
  @override
  String get estado;
  @override
  List<ConfigAtuacaoCidade> get cidades;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of ConfigAtuacao
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConfigAtuacaoImplCopyWith<_$ConfigAtuacaoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
