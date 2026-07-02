// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'disponibilidade.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DisponibilidadeDiaPB _$DisponibilidadeDiaPBFromJson(Map<String, dynamic> json) {
  return _DisponibilidadeDiaPB.fromJson(json);
}

/// @nodoc
mixin _$DisponibilidadeDiaPB {
  bool get ativo => throw _privateConstructorUsedError;

  /// 'HH:MM'
  String get inicio => throw _privateConstructorUsedError;

  /// 'HH:MM'
  String get fim => throw _privateConstructorUsedError;

  /// Serializes this DisponibilidadeDiaPB to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DisponibilidadeDiaPB
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DisponibilidadeDiaPBCopyWith<DisponibilidadeDiaPB> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DisponibilidadeDiaPBCopyWith<$Res> {
  factory $DisponibilidadeDiaPBCopyWith(
    DisponibilidadeDiaPB value,
    $Res Function(DisponibilidadeDiaPB) then,
  ) = _$DisponibilidadeDiaPBCopyWithImpl<$Res, DisponibilidadeDiaPB>;
  @useResult
  $Res call({bool ativo, String inicio, String fim});
}

/// @nodoc
class _$DisponibilidadeDiaPBCopyWithImpl<
  $Res,
  $Val extends DisponibilidadeDiaPB
>
    implements $DisponibilidadeDiaPBCopyWith<$Res> {
  _$DisponibilidadeDiaPBCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DisponibilidadeDiaPB
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? ativo = null, Object? inicio = null, Object? fim = null}) {
    return _then(
      _value.copyWith(
            ativo: null == ativo
                ? _value.ativo
                : ativo // ignore: cast_nullable_to_non_nullable
                      as bool,
            inicio: null == inicio
                ? _value.inicio
                : inicio // ignore: cast_nullable_to_non_nullable
                      as String,
            fim: null == fim
                ? _value.fim
                : fim // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DisponibilidadeDiaPBImplCopyWith<$Res>
    implements $DisponibilidadeDiaPBCopyWith<$Res> {
  factory _$$DisponibilidadeDiaPBImplCopyWith(
    _$DisponibilidadeDiaPBImpl value,
    $Res Function(_$DisponibilidadeDiaPBImpl) then,
  ) = __$$DisponibilidadeDiaPBImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool ativo, String inicio, String fim});
}

/// @nodoc
class __$$DisponibilidadeDiaPBImplCopyWithImpl<$Res>
    extends _$DisponibilidadeDiaPBCopyWithImpl<$Res, _$DisponibilidadeDiaPBImpl>
    implements _$$DisponibilidadeDiaPBImplCopyWith<$Res> {
  __$$DisponibilidadeDiaPBImplCopyWithImpl(
    _$DisponibilidadeDiaPBImpl _value,
    $Res Function(_$DisponibilidadeDiaPBImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DisponibilidadeDiaPB
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? ativo = null, Object? inicio = null, Object? fim = null}) {
    return _then(
      _$DisponibilidadeDiaPBImpl(
        ativo: null == ativo
            ? _value.ativo
            : ativo // ignore: cast_nullable_to_non_nullable
                  as bool,
        inicio: null == inicio
            ? _value.inicio
            : inicio // ignore: cast_nullable_to_non_nullable
                  as String,
        fim: null == fim
            ? _value.fim
            : fim // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DisponibilidadeDiaPBImpl implements _DisponibilidadeDiaPB {
  const _$DisponibilidadeDiaPBImpl({
    this.ativo = false,
    this.inicio = '',
    this.fim = '',
  });

  factory _$DisponibilidadeDiaPBImpl.fromJson(Map<String, dynamic> json) =>
      _$$DisponibilidadeDiaPBImplFromJson(json);

  @override
  @JsonKey()
  final bool ativo;

  /// 'HH:MM'
  @override
  @JsonKey()
  final String inicio;

  /// 'HH:MM'
  @override
  @JsonKey()
  final String fim;

  @override
  String toString() {
    return 'DisponibilidadeDiaPB(ativo: $ativo, inicio: $inicio, fim: $fim)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DisponibilidadeDiaPBImpl &&
            (identical(other.ativo, ativo) || other.ativo == ativo) &&
            (identical(other.inicio, inicio) || other.inicio == inicio) &&
            (identical(other.fim, fim) || other.fim == fim));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, ativo, inicio, fim);

  /// Create a copy of DisponibilidadeDiaPB
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DisponibilidadeDiaPBImplCopyWith<_$DisponibilidadeDiaPBImpl>
  get copyWith =>
      __$$DisponibilidadeDiaPBImplCopyWithImpl<_$DisponibilidadeDiaPBImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DisponibilidadeDiaPBImplToJson(this);
  }
}

abstract class _DisponibilidadeDiaPB implements DisponibilidadeDiaPB {
  const factory _DisponibilidadeDiaPB({
    final bool ativo,
    final String inicio,
    final String fim,
  }) = _$DisponibilidadeDiaPBImpl;

  factory _DisponibilidadeDiaPB.fromJson(Map<String, dynamic> json) =
      _$DisponibilidadeDiaPBImpl.fromJson;

  @override
  bool get ativo;

  /// 'HH:MM'
  @override
  String get inicio;

  /// 'HH:MM'
  @override
  String get fim;

  /// Create a copy of DisponibilidadeDiaPB
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DisponibilidadeDiaPBImplCopyWith<_$DisponibilidadeDiaPBImpl>
  get copyWith => throw _privateConstructorUsedError;
}

Disponibilidade _$DisponibilidadeFromJson(Map<String, dynamic> json) {
  return _Disponibilidade.fromJson(json);
}

/// @nodoc
mixin _$Disponibilidade {
  String get id => throw _privateConstructorUsedError;

  /// Relation → users.
  String get profissional => throw _privateConstructorUsedError;
  @JsonKey(name: 'duracao_min')
  int get duracaoMin => throw _privateConstructorUsedError;

  /// Array de 7 itens: índice 0 = Dom … 6 = Sáb.
  List<DisponibilidadeDiaPB> get dias => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this Disponibilidade to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Disponibilidade
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DisponibilidadeCopyWith<Disponibilidade> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DisponibilidadeCopyWith<$Res> {
  factory $DisponibilidadeCopyWith(
    Disponibilidade value,
    $Res Function(Disponibilidade) then,
  ) = _$DisponibilidadeCopyWithImpl<$Res, Disponibilidade>;
  @useResult
  $Res call({
    String id,
    String profissional,
    @JsonKey(name: 'duracao_min') int duracaoMin,
    List<DisponibilidadeDiaPB> dias,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$DisponibilidadeCopyWithImpl<$Res, $Val extends Disponibilidade>
    implements $DisponibilidadeCopyWith<$Res> {
  _$DisponibilidadeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Disponibilidade
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? profissional = null,
    Object? duracaoMin = null,
    Object? dias = null,
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
            duracaoMin: null == duracaoMin
                ? _value.duracaoMin
                : duracaoMin // ignore: cast_nullable_to_non_nullable
                      as int,
            dias: null == dias
                ? _value.dias
                : dias // ignore: cast_nullable_to_non_nullable
                      as List<DisponibilidadeDiaPB>,
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
abstract class _$$DisponibilidadeImplCopyWith<$Res>
    implements $DisponibilidadeCopyWith<$Res> {
  factory _$$DisponibilidadeImplCopyWith(
    _$DisponibilidadeImpl value,
    $Res Function(_$DisponibilidadeImpl) then,
  ) = __$$DisponibilidadeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String profissional,
    @JsonKey(name: 'duracao_min') int duracaoMin,
    List<DisponibilidadeDiaPB> dias,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$DisponibilidadeImplCopyWithImpl<$Res>
    extends _$DisponibilidadeCopyWithImpl<$Res, _$DisponibilidadeImpl>
    implements _$$DisponibilidadeImplCopyWith<$Res> {
  __$$DisponibilidadeImplCopyWithImpl(
    _$DisponibilidadeImpl _value,
    $Res Function(_$DisponibilidadeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Disponibilidade
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? profissional = null,
    Object? duracaoMin = null,
    Object? dias = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$DisponibilidadeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        profissional: null == profissional
            ? _value.profissional
            : profissional // ignore: cast_nullable_to_non_nullable
                  as String,
        duracaoMin: null == duracaoMin
            ? _value.duracaoMin
            : duracaoMin // ignore: cast_nullable_to_non_nullable
                  as int,
        dias: null == dias
            ? _value._dias
            : dias // ignore: cast_nullable_to_non_nullable
                  as List<DisponibilidadeDiaPB>,
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
class _$DisponibilidadeImpl extends _Disponibilidade {
  const _$DisponibilidadeImpl({
    required this.id,
    this.profissional = '',
    @JsonKey(name: 'duracao_min') this.duracaoMin = 0,
    final List<DisponibilidadeDiaPB> dias = const <DisponibilidadeDiaPB>[],
    this.created,
    this.updated,
  }) : _dias = dias,
       super._();

  factory _$DisponibilidadeImpl.fromJson(Map<String, dynamic> json) =>
      _$$DisponibilidadeImplFromJson(json);

  @override
  final String id;

  /// Relation → users.
  @override
  @JsonKey()
  final String profissional;
  @override
  @JsonKey(name: 'duracao_min')
  final int duracaoMin;

  /// Array de 7 itens: índice 0 = Dom … 6 = Sáb.
  final List<DisponibilidadeDiaPB> _dias;

  /// Array de 7 itens: índice 0 = Dom … 6 = Sáb.
  @override
  @JsonKey()
  List<DisponibilidadeDiaPB> get dias {
    if (_dias is EqualUnmodifiableListView) return _dias;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dias);
  }

  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'Disponibilidade(id: $id, profissional: $profissional, duracaoMin: $duracaoMin, dias: $dias, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DisponibilidadeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.profissional, profissional) ||
                other.profissional == profissional) &&
            (identical(other.duracaoMin, duracaoMin) ||
                other.duracaoMin == duracaoMin) &&
            const DeepCollectionEquality().equals(other._dias, _dias) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    profissional,
    duracaoMin,
    const DeepCollectionEquality().hash(_dias),
    created,
    updated,
  );

  /// Create a copy of Disponibilidade
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DisponibilidadeImplCopyWith<_$DisponibilidadeImpl> get copyWith =>
      __$$DisponibilidadeImplCopyWithImpl<_$DisponibilidadeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DisponibilidadeImplToJson(this);
  }
}

abstract class _Disponibilidade extends Disponibilidade {
  const factory _Disponibilidade({
    required final String id,
    final String profissional,
    @JsonKey(name: 'duracao_min') final int duracaoMin,
    final List<DisponibilidadeDiaPB> dias,
    final String? created,
    final String? updated,
  }) = _$DisponibilidadeImpl;
  const _Disponibilidade._() : super._();

  factory _Disponibilidade.fromJson(Map<String, dynamic> json) =
      _$DisponibilidadeImpl.fromJson;

  @override
  String get id;

  /// Relation → users.
  @override
  String get profissional;
  @override
  @JsonKey(name: 'duracao_min')
  int get duracaoMin;

  /// Array de 7 itens: índice 0 = Dom … 6 = Sáb.
  @override
  List<DisponibilidadeDiaPB> get dias;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of Disponibilidade
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DisponibilidadeImplCopyWith<_$DisponibilidadeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
