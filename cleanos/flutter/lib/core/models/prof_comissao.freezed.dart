// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prof_comissao.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProfComissao _$ProfComissaoFromJson(Map<String, dynamic> json) {
  return _ProfComissao.fromJson(json);
}

/// @nodoc
mixin _$ProfComissao {
  String get id => throw _privateConstructorUsedError;
  String get profissional => throw _privateConstructorUsedError;
  String get os => throw _privateConstructorUsedError;
  @JsonKey(name: 'valor_os')
  double get valorOs => throw _privateConstructorUsedError;
  @JsonKey(name: 'valor_comissao')
  double get valorComissao => throw _privateConstructorUsedError;
  @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
  ComissaoTipo get tipoAplicado => throw _privateConstructorUsedError;
  @JsonKey(name: 'base_valor')
  double get baseValor => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: ComissaoStatus.pendente)
  ComissaoStatus get status => throw _privateConstructorUsedError;
  String? get data => throw _privateConstructorUsedError;
  String get descricao => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this ProfComissao to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProfComissao
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfComissaoCopyWith<ProfComissao> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfComissaoCopyWith<$Res> {
  factory $ProfComissaoCopyWith(
    ProfComissao value,
    $Res Function(ProfComissao) then,
  ) = _$ProfComissaoCopyWithImpl<$Res, ProfComissao>;
  @useResult
  $Res call({
    String id,
    String profissional,
    String os,
    @JsonKey(name: 'valor_os') double valorOs,
    @JsonKey(name: 'valor_comissao') double valorComissao,
    @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
    ComissaoTipo tipoAplicado,
    @JsonKey(name: 'base_valor') double baseValor,
    @JsonKey(unknownEnumValue: ComissaoStatus.pendente) ComissaoStatus status,
    String? data,
    String descricao,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$ProfComissaoCopyWithImpl<$Res, $Val extends ProfComissao>
    implements $ProfComissaoCopyWith<$Res> {
  _$ProfComissaoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfComissao
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? profissional = null,
    Object? os = null,
    Object? valorOs = null,
    Object? valorComissao = null,
    Object? tipoAplicado = null,
    Object? baseValor = null,
    Object? status = null,
    Object? data = freezed,
    Object? descricao = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            profissional: null == profissional
                ? _value.profissional
                : profissional // ignore: cast_nullable_to_non_nullable
                      as String,
            os: null == os
                ? _value.os
                : os // ignore: cast_nullable_to_non_nullable
                      as String,
            valorOs: null == valorOs
                ? _value.valorOs
                : valorOs // ignore: cast_nullable_to_non_nullable
                      as double,
            valorComissao: null == valorComissao
                ? _value.valorComissao
                : valorComissao // ignore: cast_nullable_to_non_nullable
                      as double,
            tipoAplicado: null == tipoAplicado
                ? _value.tipoAplicado
                : tipoAplicado // ignore: cast_nullable_to_non_nullable
                      as ComissaoTipo,
            baseValor: null == baseValor
                ? _value.baseValor
                : baseValor // ignore: cast_nullable_to_non_nullable
                      as double,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ComissaoStatus,
            data: freezed == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as String?,
            descricao: null == descricao
                ? _value.descricao
                : descricao // ignore: cast_nullable_to_non_nullable
                      as String,
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
abstract class _$$ProfComissaoImplCopyWith<$Res>
    implements $ProfComissaoCopyWith<$Res> {
  factory _$$ProfComissaoImplCopyWith(
    _$ProfComissaoImpl value,
    $Res Function(_$ProfComissaoImpl) then,
  ) = __$$ProfComissaoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String profissional,
    String os,
    @JsonKey(name: 'valor_os') double valorOs,
    @JsonKey(name: 'valor_comissao') double valorComissao,
    @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
    ComissaoTipo tipoAplicado,
    @JsonKey(name: 'base_valor') double baseValor,
    @JsonKey(unknownEnumValue: ComissaoStatus.pendente) ComissaoStatus status,
    String? data,
    String descricao,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$ProfComissaoImplCopyWithImpl<$Res>
    extends _$ProfComissaoCopyWithImpl<$Res, _$ProfComissaoImpl>
    implements _$$ProfComissaoImplCopyWith<$Res> {
  __$$ProfComissaoImplCopyWithImpl(
    _$ProfComissaoImpl _value,
    $Res Function(_$ProfComissaoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfComissao
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? profissional = null,
    Object? os = null,
    Object? valorOs = null,
    Object? valorComissao = null,
    Object? tipoAplicado = null,
    Object? baseValor = null,
    Object? status = null,
    Object? data = freezed,
    Object? descricao = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$ProfComissaoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        profissional: null == profissional
            ? _value.profissional
            : profissional // ignore: cast_nullable_to_non_nullable
                  as String,
        os: null == os
            ? _value.os
            : os // ignore: cast_nullable_to_non_nullable
                  as String,
        valorOs: null == valorOs
            ? _value.valorOs
            : valorOs // ignore: cast_nullable_to_non_nullable
                  as double,
        valorComissao: null == valorComissao
            ? _value.valorComissao
            : valorComissao // ignore: cast_nullable_to_non_nullable
                  as double,
        tipoAplicado: null == tipoAplicado
            ? _value.tipoAplicado
            : tipoAplicado // ignore: cast_nullable_to_non_nullable
                  as ComissaoTipo,
        baseValor: null == baseValor
            ? _value.baseValor
            : baseValor // ignore: cast_nullable_to_non_nullable
                  as double,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ComissaoStatus,
        data: freezed == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as String?,
        descricao: null == descricao
            ? _value.descricao
            : descricao // ignore: cast_nullable_to_non_nullable
                  as String,
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
class _$ProfComissaoImpl extends _ProfComissao {
  const _$ProfComissaoImpl({
    required this.id,
    required this.profissional,
    required this.os,
    @JsonKey(name: 'valor_os') this.valorOs = 0,
    @JsonKey(name: 'valor_comissao') this.valorComissao = 0,
    @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
    this.tipoAplicado = ComissaoTipo.percentual,
    @JsonKey(name: 'base_valor') this.baseValor = 0,
    @JsonKey(unknownEnumValue: ComissaoStatus.pendente)
    this.status = ComissaoStatus.pendente,
    this.data,
    this.descricao = '',
    this.created,
    this.updated,
  }) : super._();

  factory _$ProfComissaoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfComissaoImplFromJson(json);

  @override
  final String id;
  @override
  final String profissional;
  @override
  final String os;
  @override
  @JsonKey(name: 'valor_os')
  final double valorOs;
  @override
  @JsonKey(name: 'valor_comissao')
  final double valorComissao;
  @override
  @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
  final ComissaoTipo tipoAplicado;
  @override
  @JsonKey(name: 'base_valor')
  final double baseValor;
  @override
  @JsonKey(unknownEnumValue: ComissaoStatus.pendente)
  final ComissaoStatus status;
  @override
  final String? data;
  @override
  @JsonKey()
  final String descricao;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'ProfComissao(id: $id, profissional: $profissional, os: $os, valorOs: $valorOs, valorComissao: $valorComissao, tipoAplicado: $tipoAplicado, baseValor: $baseValor, status: $status, data: $data, descricao: $descricao, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfComissaoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.profissional, profissional) ||
                other.profissional == profissional) &&
            (identical(other.os, os) || other.os == os) &&
            (identical(other.valorOs, valorOs) || other.valorOs == valorOs) &&
            (identical(other.valorComissao, valorComissao) ||
                other.valorComissao == valorComissao) &&
            (identical(other.tipoAplicado, tipoAplicado) ||
                other.tipoAplicado == tipoAplicado) &&
            (identical(other.baseValor, baseValor) ||
                other.baseValor == baseValor) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.descricao, descricao) ||
                other.descricao == descricao) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    profissional,
    os,
    valorOs,
    valorComissao,
    tipoAplicado,
    baseValor,
    status,
    data,
    descricao,
    created,
    updated,
  );

  /// Create a copy of ProfComissao
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfComissaoImplCopyWith<_$ProfComissaoImpl> get copyWith =>
      __$$ProfComissaoImplCopyWithImpl<_$ProfComissaoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfComissaoImplToJson(this);
  }
}

abstract class _ProfComissao extends ProfComissao {
  const factory _ProfComissao({
    required final String id,
    required final String profissional,
    required final String os,
    @JsonKey(name: 'valor_os') final double valorOs,
    @JsonKey(name: 'valor_comissao') final double valorComissao,
    @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
    final ComissaoTipo tipoAplicado,
    @JsonKey(name: 'base_valor') final double baseValor,
    @JsonKey(unknownEnumValue: ComissaoStatus.pendente)
    final ComissaoStatus status,
    final String? data,
    final String descricao,
    final String? created,
    final String? updated,
  }) = _$ProfComissaoImpl;
  const _ProfComissao._() : super._();

  factory _ProfComissao.fromJson(Map<String, dynamic> json) =
      _$ProfComissaoImpl.fromJson;

  @override
  String get id;
  @override
  String get profissional;
  @override
  String get os;
  @override
  @JsonKey(name: 'valor_os')
  double get valorOs;
  @override
  @JsonKey(name: 'valor_comissao')
  double get valorComissao;
  @override
  @JsonKey(name: 'tipo_aplicado', unknownEnumValue: ComissaoTipo.percentual)
  ComissaoTipo get tipoAplicado;
  @override
  @JsonKey(name: 'base_valor')
  double get baseValor;
  @override
  @JsonKey(unknownEnumValue: ComissaoStatus.pendente)
  ComissaoStatus get status;
  @override
  String? get data;
  @override
  String get descricao;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of ProfComissao
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfComissaoImplCopyWith<_$ProfComissaoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
