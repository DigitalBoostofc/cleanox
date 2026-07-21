// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'financeiro.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Anexo _$AnexoFromJson(Map<String, dynamic> json) {
  return _Anexo.fromJson(json);
}

/// @nodoc
mixin _$Anexo {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  int? get tamanho => throw _privateConstructorUsedError;

  /// Serializes this Anexo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Anexo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnexoCopyWith<Anexo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnexoCopyWith<$Res> {
  factory $AnexoCopyWith(Anexo value, $Res Function(Anexo) then) =
      _$AnexoCopyWithImpl<$Res, Anexo>;
  @useResult
  $Res call({String id, String nome, String url, int? tamanho});
}

/// @nodoc
class _$AnexoCopyWithImpl<$Res, $Val extends Anexo>
    implements $AnexoCopyWith<$Res> {
  _$AnexoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Anexo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? url = null,
    Object? tamanho = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            tamanho: freezed == tamanho
                ? _value.tamanho
                : tamanho // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnexoImplCopyWith<$Res> implements $AnexoCopyWith<$Res> {
  factory _$$AnexoImplCopyWith(
    _$AnexoImpl value,
    $Res Function(_$AnexoImpl) then,
  ) = __$$AnexoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String nome, String url, int? tamanho});
}

/// @nodoc
class __$$AnexoImplCopyWithImpl<$Res>
    extends _$AnexoCopyWithImpl<$Res, _$AnexoImpl>
    implements _$$AnexoImplCopyWith<$Res> {
  __$$AnexoImplCopyWithImpl(
    _$AnexoImpl _value,
    $Res Function(_$AnexoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Anexo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? url = null,
    Object? tamanho = freezed,
  }) {
    return _then(
      _$AnexoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        tamanho: freezed == tamanho
            ? _value.tamanho
            : tamanho // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnexoImpl implements _Anexo {
  const _$AnexoImpl({
    this.id = '',
    this.nome = '',
    this.url = '',
    this.tamanho,
  });

  factory _$AnexoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnexoImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String nome;
  @override
  @JsonKey()
  final String url;
  @override
  final int? tamanho;

  @override
  String toString() {
    return 'Anexo(id: $id, nome: $nome, url: $url, tamanho: $tamanho)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnexoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.tamanho, tamanho) || other.tamanho == tamanho));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, nome, url, tamanho);

  /// Create a copy of Anexo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnexoImplCopyWith<_$AnexoImpl> get copyWith =>
      __$$AnexoImplCopyWithImpl<_$AnexoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnexoImplToJson(this);
  }
}

abstract class _Anexo implements Anexo {
  const factory _Anexo({
    final String id,
    final String nome,
    final String url,
    final int? tamanho,
  }) = _$AnexoImpl;

  factory _Anexo.fromJson(Map<String, dynamic> json) = _$AnexoImpl.fromJson;

  @override
  String get id;
  @override
  String get nome;
  @override
  String get url;
  @override
  int? get tamanho;

  /// Create a copy of Anexo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnexoImplCopyWith<_$AnexoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinConta _$FinContaFromJson(Map<String, dynamic> json) {
  return _FinConta.fromJson(json);
}

/// @nodoc
mixin _$FinConta {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: ContaTipo.carteira)
  ContaTipo get tipo => throw _privateConstructorUsedError;
  @JsonKey(name: 'saldo_inicial')
  double get saldoInicial => throw _privateConstructorUsedError;
  @JsonKey(name: 'saldo_atual')
  double get saldoAtual => throw _privateConstructorUsedError;
  bool get ativo => throw _privateConstructorUsedError;
  String? get cor => throw _privateConstructorUsedError;
  String? get icone => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this FinConta to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinConta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinContaCopyWith<FinConta> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinContaCopyWith<$Res> {
  factory $FinContaCopyWith(FinConta value, $Res Function(FinConta) then) =
      _$FinContaCopyWithImpl<$Res, FinConta>;
  @useResult
  $Res call({
    String id,
    String nome,
    @JsonKey(unknownEnumValue: ContaTipo.carteira) ContaTipo tipo,
    @JsonKey(name: 'saldo_inicial') double saldoInicial,
    @JsonKey(name: 'saldo_atual') double saldoAtual,
    bool ativo,
    String? cor,
    String? icone,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$FinContaCopyWithImpl<$Res, $Val extends FinConta>
    implements $FinContaCopyWith<$Res> {
  _$FinContaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinConta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? tipo = null,
    Object? saldoInicial = null,
    Object? saldoAtual = null,
    Object? ativo = null,
    Object? cor = freezed,
    Object? icone = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            tipo: null == tipo
                ? _value.tipo
                : tipo // ignore: cast_nullable_to_non_nullable
                      as ContaTipo,
            saldoInicial: null == saldoInicial
                ? _value.saldoInicial
                : saldoInicial // ignore: cast_nullable_to_non_nullable
                      as double,
            saldoAtual: null == saldoAtual
                ? _value.saldoAtual
                : saldoAtual // ignore: cast_nullable_to_non_nullable
                      as double,
            ativo: null == ativo
                ? _value.ativo
                : ativo // ignore: cast_nullable_to_non_nullable
                      as bool,
            cor: freezed == cor
                ? _value.cor
                : cor // ignore: cast_nullable_to_non_nullable
                      as String?,
            icone: freezed == icone
                ? _value.icone
                : icone // ignore: cast_nullable_to_non_nullable
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
abstract class _$$FinContaImplCopyWith<$Res>
    implements $FinContaCopyWith<$Res> {
  factory _$$FinContaImplCopyWith(
    _$FinContaImpl value,
    $Res Function(_$FinContaImpl) then,
  ) = __$$FinContaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    @JsonKey(unknownEnumValue: ContaTipo.carteira) ContaTipo tipo,
    @JsonKey(name: 'saldo_inicial') double saldoInicial,
    @JsonKey(name: 'saldo_atual') double saldoAtual,
    bool ativo,
    String? cor,
    String? icone,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$FinContaImplCopyWithImpl<$Res>
    extends _$FinContaCopyWithImpl<$Res, _$FinContaImpl>
    implements _$$FinContaImplCopyWith<$Res> {
  __$$FinContaImplCopyWithImpl(
    _$FinContaImpl _value,
    $Res Function(_$FinContaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FinConta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? tipo = null,
    Object? saldoInicial = null,
    Object? saldoAtual = null,
    Object? ativo = null,
    Object? cor = freezed,
    Object? icone = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$FinContaImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        tipo: null == tipo
            ? _value.tipo
            : tipo // ignore: cast_nullable_to_non_nullable
                  as ContaTipo,
        saldoInicial: null == saldoInicial
            ? _value.saldoInicial
            : saldoInicial // ignore: cast_nullable_to_non_nullable
                  as double,
        saldoAtual: null == saldoAtual
            ? _value.saldoAtual
            : saldoAtual // ignore: cast_nullable_to_non_nullable
                  as double,
        ativo: null == ativo
            ? _value.ativo
            : ativo // ignore: cast_nullable_to_non_nullable
                  as bool,
        cor: freezed == cor
            ? _value.cor
            : cor // ignore: cast_nullable_to_non_nullable
                  as String?,
        icone: freezed == icone
            ? _value.icone
            : icone // ignore: cast_nullable_to_non_nullable
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
class _$FinContaImpl extends _FinConta {
  const _$FinContaImpl({
    required this.id,
    this.nome = '',
    @JsonKey(unknownEnumValue: ContaTipo.carteira)
    this.tipo = ContaTipo.carteira,
    @JsonKey(name: 'saldo_inicial') this.saldoInicial = 0,
    @JsonKey(name: 'saldo_atual') this.saldoAtual = 0,
    this.ativo = true,
    this.cor,
    this.icone,
    this.created,
    this.updated,
  }) : super._();

  factory _$FinContaImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinContaImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String nome;
  @override
  @JsonKey(unknownEnumValue: ContaTipo.carteira)
  final ContaTipo tipo;
  @override
  @JsonKey(name: 'saldo_inicial')
  final double saldoInicial;
  @override
  @JsonKey(name: 'saldo_atual')
  final double saldoAtual;
  @override
  @JsonKey()
  final bool ativo;
  @override
  final String? cor;
  @override
  final String? icone;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'FinConta(id: $id, nome: $nome, tipo: $tipo, saldoInicial: $saldoInicial, saldoAtual: $saldoAtual, ativo: $ativo, cor: $cor, icone: $icone, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinContaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.saldoInicial, saldoInicial) ||
                other.saldoInicial == saldoInicial) &&
            (identical(other.saldoAtual, saldoAtual) ||
                other.saldoAtual == saldoAtual) &&
            (identical(other.ativo, ativo) || other.ativo == ativo) &&
            (identical(other.cor, cor) || other.cor == cor) &&
            (identical(other.icone, icone) || other.icone == icone) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    tipo,
    saldoInicial,
    saldoAtual,
    ativo,
    cor,
    icone,
    created,
    updated,
  );

  /// Create a copy of FinConta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinContaImplCopyWith<_$FinContaImpl> get copyWith =>
      __$$FinContaImplCopyWithImpl<_$FinContaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinContaImplToJson(this);
  }
}

abstract class _FinConta extends FinConta {
  const factory _FinConta({
    required final String id,
    final String nome,
    @JsonKey(unknownEnumValue: ContaTipo.carteira) final ContaTipo tipo,
    @JsonKey(name: 'saldo_inicial') final double saldoInicial,
    @JsonKey(name: 'saldo_atual') final double saldoAtual,
    final bool ativo,
    final String? cor,
    final String? icone,
    final String? created,
    final String? updated,
  }) = _$FinContaImpl;
  const _FinConta._() : super._();

  factory _FinConta.fromJson(Map<String, dynamic> json) =
      _$FinContaImpl.fromJson;

  @override
  String get id;
  @override
  String get nome;
  @override
  @JsonKey(unknownEnumValue: ContaTipo.carteira)
  ContaTipo get tipo;
  @override
  @JsonKey(name: 'saldo_inicial')
  double get saldoInicial;
  @override
  @JsonKey(name: 'saldo_atual')
  double get saldoAtual;
  @override
  bool get ativo;
  @override
  String? get cor;
  @override
  String? get icone;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of FinConta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinContaImplCopyWith<_$FinContaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinCategoria _$FinCategoriaFromJson(Map<String, dynamic> json) {
  return _FinCategoria.fromJson(json);
}

/// @nodoc
mixin _$FinCategoria {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: TipoLancamento.despesa)
  TipoLancamento get tipo => throw _privateConstructorUsedError;
  String? get icone => throw _privateConstructorUsedError;
  String? get cor => throw _privateConstructorUsedError;

  /// ID da categoria-mãe quando este registro é uma subcategoria.
  @JsonKey(name: 'parent_id')
  String? get parentId => throw _privateConstructorUsedError;
  bool get arquivada => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this FinCategoria to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinCategoria
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinCategoriaCopyWith<FinCategoria> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinCategoriaCopyWith<$Res> {
  factory $FinCategoriaCopyWith(
    FinCategoria value,
    $Res Function(FinCategoria) then,
  ) = _$FinCategoriaCopyWithImpl<$Res, FinCategoria>;
  @useResult
  $Res call({
    String id,
    String nome,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa) TipoLancamento tipo,
    String? icone,
    String? cor,
    @JsonKey(name: 'parent_id') String? parentId,
    bool arquivada,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$FinCategoriaCopyWithImpl<$Res, $Val extends FinCategoria>
    implements $FinCategoriaCopyWith<$Res> {
  _$FinCategoriaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinCategoria
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? tipo = null,
    Object? icone = freezed,
    Object? cor = freezed,
    Object? parentId = freezed,
    Object? arquivada = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            tipo: null == tipo
                ? _value.tipo
                : tipo // ignore: cast_nullable_to_non_nullable
                      as TipoLancamento,
            icone: freezed == icone
                ? _value.icone
                : icone // ignore: cast_nullable_to_non_nullable
                      as String?,
            cor: freezed == cor
                ? _value.cor
                : cor // ignore: cast_nullable_to_non_nullable
                      as String?,
            parentId: freezed == parentId
                ? _value.parentId
                : parentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            arquivada: null == arquivada
                ? _value.arquivada
                : arquivada // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$FinCategoriaImplCopyWith<$Res>
    implements $FinCategoriaCopyWith<$Res> {
  factory _$$FinCategoriaImplCopyWith(
    _$FinCategoriaImpl value,
    $Res Function(_$FinCategoriaImpl) then,
  ) = __$$FinCategoriaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa) TipoLancamento tipo,
    String? icone,
    String? cor,
    @JsonKey(name: 'parent_id') String? parentId,
    bool arquivada,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$FinCategoriaImplCopyWithImpl<$Res>
    extends _$FinCategoriaCopyWithImpl<$Res, _$FinCategoriaImpl>
    implements _$$FinCategoriaImplCopyWith<$Res> {
  __$$FinCategoriaImplCopyWithImpl(
    _$FinCategoriaImpl _value,
    $Res Function(_$FinCategoriaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FinCategoria
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? tipo = null,
    Object? icone = freezed,
    Object? cor = freezed,
    Object? parentId = freezed,
    Object? arquivada = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$FinCategoriaImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        tipo: null == tipo
            ? _value.tipo
            : tipo // ignore: cast_nullable_to_non_nullable
                  as TipoLancamento,
        icone: freezed == icone
            ? _value.icone
            : icone // ignore: cast_nullable_to_non_nullable
                  as String?,
        cor: freezed == cor
            ? _value.cor
            : cor // ignore: cast_nullable_to_non_nullable
                  as String?,
        parentId: freezed == parentId
            ? _value.parentId
            : parentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        arquivada: null == arquivada
            ? _value.arquivada
            : arquivada // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$FinCategoriaImpl extends _FinCategoria {
  const _$FinCategoriaImpl({
    required this.id,
    this.nome = '',
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    this.tipo = TipoLancamento.despesa,
    this.icone,
    this.cor,
    @JsonKey(name: 'parent_id') this.parentId,
    this.arquivada = false,
    this.created,
    this.updated,
  }) : super._();

  factory _$FinCategoriaImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinCategoriaImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String nome;
  @override
  @JsonKey(unknownEnumValue: TipoLancamento.despesa)
  final TipoLancamento tipo;
  @override
  final String? icone;
  @override
  final String? cor;

  /// ID da categoria-mãe quando este registro é uma subcategoria.
  @override
  @JsonKey(name: 'parent_id')
  final String? parentId;
  @override
  @JsonKey()
  final bool arquivada;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'FinCategoria(id: $id, nome: $nome, tipo: $tipo, icone: $icone, cor: $cor, parentId: $parentId, arquivada: $arquivada, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinCategoriaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.icone, icone) || other.icone == icone) &&
            (identical(other.cor, cor) || other.cor == cor) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.arquivada, arquivada) ||
                other.arquivada == arquivada) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    tipo,
    icone,
    cor,
    parentId,
    arquivada,
    created,
    updated,
  );

  /// Create a copy of FinCategoria
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinCategoriaImplCopyWith<_$FinCategoriaImpl> get copyWith =>
      __$$FinCategoriaImplCopyWithImpl<_$FinCategoriaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinCategoriaImplToJson(this);
  }
}

abstract class _FinCategoria extends FinCategoria {
  const factory _FinCategoria({
    required final String id,
    final String nome,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    final TipoLancamento tipo,
    final String? icone,
    final String? cor,
    @JsonKey(name: 'parent_id') final String? parentId,
    final bool arquivada,
    final String? created,
    final String? updated,
  }) = _$FinCategoriaImpl;
  const _FinCategoria._() : super._();

  factory _FinCategoria.fromJson(Map<String, dynamic> json) =
      _$FinCategoriaImpl.fromJson;

  @override
  String get id;
  @override
  String get nome;
  @override
  @JsonKey(unknownEnumValue: TipoLancamento.despesa)
  TipoLancamento get tipo;
  @override
  String? get icone;
  @override
  String? get cor;

  /// ID da categoria-mãe quando este registro é uma subcategoria.
  @override
  @JsonKey(name: 'parent_id')
  String? get parentId;
  @override
  bool get arquivada;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of FinCategoria
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinCategoriaImplCopyWith<_$FinCategoriaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinLancamento _$FinLancamentoFromJson(Map<String, dynamic> json) {
  return _FinLancamento.fromJson(json);
}

/// @nodoc
mixin _$FinLancamento {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: TipoLancamento.despesa)
  TipoLancamento get tipo => throw _privateConstructorUsedError;
  String get descricao => throw _privateConstructorUsedError;
  @JsonKey(name: 'categoria_id')
  String get categoriaId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subcategoria_id')
  String? get subcategoriaId => throw _privateConstructorUsedError;

  /// SEMPRE positivo. O sinal vem de `tipo`.
  double get valor => throw _privateConstructorUsedError;
  @JsonKey(name: 'conta_id')
  String get contaId => throw _privateConstructorUsedError;
  String get data => throw _privateConstructorUsedError;
  String? get vencimento => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
  LancamentoStatus get status => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
  RecorrenciaTipo get recorrencia => throw _privateConstructorUsedError;

  /// Periodicidade da série (só faz sentido em fixa/recorrente). Vazio no PB → mensal.
  @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
  FrequenciaRecorrencia? get frequencia => throw _privateConstructorUsedError;
  @JsonKey(name: 'parcela_atual')
  int? get parcelaAtual => throw _privateConstructorUsedError;
  @JsonKey(name: 'parcelas_total')
  int? get parcelasTotal => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: OrigemLancamento.manual)
  OrigemLancamento get origem => throw _privateConstructorUsedError;
  @JsonKey(name: 'os_id')
  String? get osId => throw _privateConstructorUsedError;
  @JsonKey(name: 'os_numero')
  String? get osNumero => throw _privateConstructorUsedError;
  @JsonKey(name: 'cliente_nome')
  String? get clienteNome => throw _privateConstructorUsedError;
  @JsonKey(name: 'servico_nome')
  String? get servicoNome => throw _privateConstructorUsedError;
  @JsonKey(name: 'forma_pagamento')
  String? get formaPagamento => throw _privateConstructorUsedError;
  String? get observacao => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;

  /// Pin na lista de Transações (Financeiro v2). PB default false.
  bool get favorito => throw _privateConstructorUsedError;
  List<Anexo> get anexos => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this FinLancamento to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinLancamento
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinLancamentoCopyWith<FinLancamento> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinLancamentoCopyWith<$Res> {
  factory $FinLancamentoCopyWith(
    FinLancamento value,
    $Res Function(FinLancamento) then,
  ) = _$FinLancamentoCopyWithImpl<$Res, FinLancamento>;
  @useResult
  $Res call({
    String id,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa) TipoLancamento tipo,
    String descricao,
    @JsonKey(name: 'categoria_id') String categoriaId,
    @JsonKey(name: 'subcategoria_id') String? subcategoriaId,
    double valor,
    @JsonKey(name: 'conta_id') String contaId,
    String data,
    String? vencimento,
    @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
    LancamentoStatus status,
    @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
    RecorrenciaTipo recorrencia,
    @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
    FrequenciaRecorrencia? frequencia,
    @JsonKey(name: 'parcela_atual') int? parcelaAtual,
    @JsonKey(name: 'parcelas_total') int? parcelasTotal,
    @JsonKey(unknownEnumValue: OrigemLancamento.manual) OrigemLancamento origem,
    @JsonKey(name: 'os_id') String? osId,
    @JsonKey(name: 'os_numero') String? osNumero,
    @JsonKey(name: 'cliente_nome') String? clienteNome,
    @JsonKey(name: 'servico_nome') String? servicoNome,
    @JsonKey(name: 'forma_pagamento') String? formaPagamento,
    String? observacao,
    List<String> tags,
    bool favorito,
    List<Anexo> anexos,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$FinLancamentoCopyWithImpl<$Res, $Val extends FinLancamento>
    implements $FinLancamentoCopyWith<$Res> {
  _$FinLancamentoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinLancamento
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tipo = null,
    Object? descricao = null,
    Object? categoriaId = null,
    Object? subcategoriaId = freezed,
    Object? valor = null,
    Object? contaId = null,
    Object? data = null,
    Object? vencimento = freezed,
    Object? status = null,
    Object? recorrencia = null,
    Object? frequencia = freezed,
    Object? parcelaAtual = freezed,
    Object? parcelasTotal = freezed,
    Object? origem = null,
    Object? osId = freezed,
    Object? osNumero = freezed,
    Object? clienteNome = freezed,
    Object? servicoNome = freezed,
    Object? formaPagamento = freezed,
    Object? observacao = freezed,
    Object? tags = null,
    Object? favorito = null,
    Object? anexos = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            tipo: null == tipo
                ? _value.tipo
                : tipo // ignore: cast_nullable_to_non_nullable
                      as TipoLancamento,
            descricao: null == descricao
                ? _value.descricao
                : descricao // ignore: cast_nullable_to_non_nullable
                      as String,
            categoriaId: null == categoriaId
                ? _value.categoriaId
                : categoriaId // ignore: cast_nullable_to_non_nullable
                      as String,
            subcategoriaId: freezed == subcategoriaId
                ? _value.subcategoriaId
                : subcategoriaId // ignore: cast_nullable_to_non_nullable
                      as String?,
            valor: null == valor
                ? _value.valor
                : valor // ignore: cast_nullable_to_non_nullable
                      as double,
            contaId: null == contaId
                ? _value.contaId
                : contaId // ignore: cast_nullable_to_non_nullable
                      as String,
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as String,
            vencimento: freezed == vencimento
                ? _value.vencimento
                : vencimento // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as LancamentoStatus,
            recorrencia: null == recorrencia
                ? _value.recorrencia
                : recorrencia // ignore: cast_nullable_to_non_nullable
                      as RecorrenciaTipo,
            frequencia: freezed == frequencia
                ? _value.frequencia
                : frequencia // ignore: cast_nullable_to_non_nullable
                      as FrequenciaRecorrencia?,
            parcelaAtual: freezed == parcelaAtual
                ? _value.parcelaAtual
                : parcelaAtual // ignore: cast_nullable_to_non_nullable
                      as int?,
            parcelasTotal: freezed == parcelasTotal
                ? _value.parcelasTotal
                : parcelasTotal // ignore: cast_nullable_to_non_nullable
                      as int?,
            origem: null == origem
                ? _value.origem
                : origem // ignore: cast_nullable_to_non_nullable
                      as OrigemLancamento,
            osId: freezed == osId
                ? _value.osId
                : osId // ignore: cast_nullable_to_non_nullable
                      as String?,
            osNumero: freezed == osNumero
                ? _value.osNumero
                : osNumero // ignore: cast_nullable_to_non_nullable
                      as String?,
            clienteNome: freezed == clienteNome
                ? _value.clienteNome
                : clienteNome // ignore: cast_nullable_to_non_nullable
                      as String?,
            servicoNome: freezed == servicoNome
                ? _value.servicoNome
                : servicoNome // ignore: cast_nullable_to_non_nullable
                      as String?,
            formaPagamento: freezed == formaPagamento
                ? _value.formaPagamento
                : formaPagamento // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacao: freezed == observacao
                ? _value.observacao
                : observacao // ignore: cast_nullable_to_non_nullable
                      as String?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            favorito: null == favorito
                ? _value.favorito
                : favorito // ignore: cast_nullable_to_non_nullable
                      as bool,
            anexos: null == anexos
                ? _value.anexos
                : anexos // ignore: cast_nullable_to_non_nullable
                      as List<Anexo>,
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
abstract class _$$FinLancamentoImplCopyWith<$Res>
    implements $FinLancamentoCopyWith<$Res> {
  factory _$$FinLancamentoImplCopyWith(
    _$FinLancamentoImpl value,
    $Res Function(_$FinLancamentoImpl) then,
  ) = __$$FinLancamentoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa) TipoLancamento tipo,
    String descricao,
    @JsonKey(name: 'categoria_id') String categoriaId,
    @JsonKey(name: 'subcategoria_id') String? subcategoriaId,
    double valor,
    @JsonKey(name: 'conta_id') String contaId,
    String data,
    String? vencimento,
    @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
    LancamentoStatus status,
    @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
    RecorrenciaTipo recorrencia,
    @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
    FrequenciaRecorrencia? frequencia,
    @JsonKey(name: 'parcela_atual') int? parcelaAtual,
    @JsonKey(name: 'parcelas_total') int? parcelasTotal,
    @JsonKey(unknownEnumValue: OrigemLancamento.manual) OrigemLancamento origem,
    @JsonKey(name: 'os_id') String? osId,
    @JsonKey(name: 'os_numero') String? osNumero,
    @JsonKey(name: 'cliente_nome') String? clienteNome,
    @JsonKey(name: 'servico_nome') String? servicoNome,
    @JsonKey(name: 'forma_pagamento') String? formaPagamento,
    String? observacao,
    List<String> tags,
    bool favorito,
    List<Anexo> anexos,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$FinLancamentoImplCopyWithImpl<$Res>
    extends _$FinLancamentoCopyWithImpl<$Res, _$FinLancamentoImpl>
    implements _$$FinLancamentoImplCopyWith<$Res> {
  __$$FinLancamentoImplCopyWithImpl(
    _$FinLancamentoImpl _value,
    $Res Function(_$FinLancamentoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FinLancamento
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tipo = null,
    Object? descricao = null,
    Object? categoriaId = null,
    Object? subcategoriaId = freezed,
    Object? valor = null,
    Object? contaId = null,
    Object? data = null,
    Object? vencimento = freezed,
    Object? status = null,
    Object? recorrencia = null,
    Object? frequencia = freezed,
    Object? parcelaAtual = freezed,
    Object? parcelasTotal = freezed,
    Object? origem = null,
    Object? osId = freezed,
    Object? osNumero = freezed,
    Object? clienteNome = freezed,
    Object? servicoNome = freezed,
    Object? formaPagamento = freezed,
    Object? observacao = freezed,
    Object? tags = null,
    Object? favorito = null,
    Object? anexos = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$FinLancamentoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        tipo: null == tipo
            ? _value.tipo
            : tipo // ignore: cast_nullable_to_non_nullable
                  as TipoLancamento,
        descricao: null == descricao
            ? _value.descricao
            : descricao // ignore: cast_nullable_to_non_nullable
                  as String,
        categoriaId: null == categoriaId
            ? _value.categoriaId
            : categoriaId // ignore: cast_nullable_to_non_nullable
                  as String,
        subcategoriaId: freezed == subcategoriaId
            ? _value.subcategoriaId
            : subcategoriaId // ignore: cast_nullable_to_non_nullable
                  as String?,
        valor: null == valor
            ? _value.valor
            : valor // ignore: cast_nullable_to_non_nullable
                  as double,
        contaId: null == contaId
            ? _value.contaId
            : contaId // ignore: cast_nullable_to_non_nullable
                  as String,
        data: null == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as String,
        vencimento: freezed == vencimento
            ? _value.vencimento
            : vencimento // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as LancamentoStatus,
        recorrencia: null == recorrencia
            ? _value.recorrencia
            : recorrencia // ignore: cast_nullable_to_non_nullable
                  as RecorrenciaTipo,
        frequencia: freezed == frequencia
            ? _value.frequencia
            : frequencia // ignore: cast_nullable_to_non_nullable
                  as FrequenciaRecorrencia?,
        parcelaAtual: freezed == parcelaAtual
            ? _value.parcelaAtual
            : parcelaAtual // ignore: cast_nullable_to_non_nullable
                  as int?,
        parcelasTotal: freezed == parcelasTotal
            ? _value.parcelasTotal
            : parcelasTotal // ignore: cast_nullable_to_non_nullable
                  as int?,
        origem: null == origem
            ? _value.origem
            : origem // ignore: cast_nullable_to_non_nullable
                  as OrigemLancamento,
        osId: freezed == osId
            ? _value.osId
            : osId // ignore: cast_nullable_to_non_nullable
                  as String?,
        osNumero: freezed == osNumero
            ? _value.osNumero
            : osNumero // ignore: cast_nullable_to_non_nullable
                  as String?,
        clienteNome: freezed == clienteNome
            ? _value.clienteNome
            : clienteNome // ignore: cast_nullable_to_non_nullable
                  as String?,
        servicoNome: freezed == servicoNome
            ? _value.servicoNome
            : servicoNome // ignore: cast_nullable_to_non_nullable
                  as String?,
        formaPagamento: freezed == formaPagamento
            ? _value.formaPagamento
            : formaPagamento // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacao: freezed == observacao
            ? _value.observacao
            : observacao // ignore: cast_nullable_to_non_nullable
                  as String?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        favorito: null == favorito
            ? _value.favorito
            : favorito // ignore: cast_nullable_to_non_nullable
                  as bool,
        anexos: null == anexos
            ? _value._anexos
            : anexos // ignore: cast_nullable_to_non_nullable
                  as List<Anexo>,
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
class _$FinLancamentoImpl extends _FinLancamento {
  const _$FinLancamentoImpl({
    required this.id,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    this.tipo = TipoLancamento.despesa,
    this.descricao = '',
    @JsonKey(name: 'categoria_id') this.categoriaId = '',
    @JsonKey(name: 'subcategoria_id') this.subcategoriaId,
    this.valor = 0,
    @JsonKey(name: 'conta_id') this.contaId = '',
    this.data = '',
    this.vencimento,
    @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
    this.status = LancamentoStatus.pendente,
    @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
    this.recorrencia = RecorrenciaTipo.unica,
    @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal) this.frequencia,
    @JsonKey(name: 'parcela_atual') this.parcelaAtual,
    @JsonKey(name: 'parcelas_total') this.parcelasTotal,
    @JsonKey(unknownEnumValue: OrigemLancamento.manual)
    this.origem = OrigemLancamento.manual,
    @JsonKey(name: 'os_id') this.osId,
    @JsonKey(name: 'os_numero') this.osNumero,
    @JsonKey(name: 'cliente_nome') this.clienteNome,
    @JsonKey(name: 'servico_nome') this.servicoNome,
    @JsonKey(name: 'forma_pagamento') this.formaPagamento,
    this.observacao,
    final List<String> tags = const <String>[],
    this.favorito = false,
    final List<Anexo> anexos = const <Anexo>[],
    this.created,
    this.updated,
  }) : _tags = tags,
       _anexos = anexos,
       super._();

  factory _$FinLancamentoImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinLancamentoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(unknownEnumValue: TipoLancamento.despesa)
  final TipoLancamento tipo;
  @override
  @JsonKey()
  final String descricao;
  @override
  @JsonKey(name: 'categoria_id')
  final String categoriaId;
  @override
  @JsonKey(name: 'subcategoria_id')
  final String? subcategoriaId;

  /// SEMPRE positivo. O sinal vem de `tipo`.
  @override
  @JsonKey()
  final double valor;
  @override
  @JsonKey(name: 'conta_id')
  final String contaId;
  @override
  @JsonKey()
  final String data;
  @override
  final String? vencimento;
  @override
  @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
  final LancamentoStatus status;
  @override
  @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
  final RecorrenciaTipo recorrencia;

  /// Periodicidade da série (só faz sentido em fixa/recorrente). Vazio no PB → mensal.
  @override
  @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
  final FrequenciaRecorrencia? frequencia;
  @override
  @JsonKey(name: 'parcela_atual')
  final int? parcelaAtual;
  @override
  @JsonKey(name: 'parcelas_total')
  final int? parcelasTotal;
  @override
  @JsonKey(unknownEnumValue: OrigemLancamento.manual)
  final OrigemLancamento origem;
  @override
  @JsonKey(name: 'os_id')
  final String? osId;
  @override
  @JsonKey(name: 'os_numero')
  final String? osNumero;
  @override
  @JsonKey(name: 'cliente_nome')
  final String? clienteNome;
  @override
  @JsonKey(name: 'servico_nome')
  final String? servicoNome;
  @override
  @JsonKey(name: 'forma_pagamento')
  final String? formaPagamento;
  @override
  final String? observacao;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  /// Pin na lista de Transações (Financeiro v2). PB default false.
  @override
  @JsonKey()
  final bool favorito;
  final List<Anexo> _anexos;
  @override
  @JsonKey()
  List<Anexo> get anexos {
    if (_anexos is EqualUnmodifiableListView) return _anexos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_anexos);
  }

  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'FinLancamento(id: $id, tipo: $tipo, descricao: $descricao, categoriaId: $categoriaId, subcategoriaId: $subcategoriaId, valor: $valor, contaId: $contaId, data: $data, vencimento: $vencimento, status: $status, recorrencia: $recorrencia, frequencia: $frequencia, parcelaAtual: $parcelaAtual, parcelasTotal: $parcelasTotal, origem: $origem, osId: $osId, osNumero: $osNumero, clienteNome: $clienteNome, servicoNome: $servicoNome, formaPagamento: $formaPagamento, observacao: $observacao, tags: $tags, favorito: $favorito, anexos: $anexos, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinLancamentoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tipo, tipo) || other.tipo == tipo) &&
            (identical(other.descricao, descricao) ||
                other.descricao == descricao) &&
            (identical(other.categoriaId, categoriaId) ||
                other.categoriaId == categoriaId) &&
            (identical(other.subcategoriaId, subcategoriaId) ||
                other.subcategoriaId == subcategoriaId) &&
            (identical(other.valor, valor) || other.valor == valor) &&
            (identical(other.contaId, contaId) || other.contaId == contaId) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.vencimento, vencimento) ||
                other.vencimento == vencimento) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.recorrencia, recorrencia) ||
                other.recorrencia == recorrencia) &&
            (identical(other.frequencia, frequencia) ||
                other.frequencia == frequencia) &&
            (identical(other.parcelaAtual, parcelaAtual) ||
                other.parcelaAtual == parcelaAtual) &&
            (identical(other.parcelasTotal, parcelasTotal) ||
                other.parcelasTotal == parcelasTotal) &&
            (identical(other.origem, origem) || other.origem == origem) &&
            (identical(other.osId, osId) || other.osId == osId) &&
            (identical(other.osNumero, osNumero) ||
                other.osNumero == osNumero) &&
            (identical(other.clienteNome, clienteNome) ||
                other.clienteNome == clienteNome) &&
            (identical(other.servicoNome, servicoNome) ||
                other.servicoNome == servicoNome) &&
            (identical(other.formaPagamento, formaPagamento) ||
                other.formaPagamento == formaPagamento) &&
            (identical(other.observacao, observacao) ||
                other.observacao == observacao) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.favorito, favorito) ||
                other.favorito == favorito) &&
            const DeepCollectionEquality().equals(other._anexos, _anexos) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    tipo,
    descricao,
    categoriaId,
    subcategoriaId,
    valor,
    contaId,
    data,
    vencimento,
    status,
    recorrencia,
    frequencia,
    parcelaAtual,
    parcelasTotal,
    origem,
    osId,
    osNumero,
    clienteNome,
    servicoNome,
    formaPagamento,
    observacao,
    const DeepCollectionEquality().hash(_tags),
    favorito,
    const DeepCollectionEquality().hash(_anexos),
    created,
    updated,
  ]);

  /// Create a copy of FinLancamento
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinLancamentoImplCopyWith<_$FinLancamentoImpl> get copyWith =>
      __$$FinLancamentoImplCopyWithImpl<_$FinLancamentoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinLancamentoImplToJson(this);
  }
}

abstract class _FinLancamento extends FinLancamento {
  const factory _FinLancamento({
    required final String id,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    final TipoLancamento tipo,
    final String descricao,
    @JsonKey(name: 'categoria_id') final String categoriaId,
    @JsonKey(name: 'subcategoria_id') final String? subcategoriaId,
    final double valor,
    @JsonKey(name: 'conta_id') final String contaId,
    final String data,
    final String? vencimento,
    @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
    final LancamentoStatus status,
    @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
    final RecorrenciaTipo recorrencia,
    @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
    final FrequenciaRecorrencia? frequencia,
    @JsonKey(name: 'parcela_atual') final int? parcelaAtual,
    @JsonKey(name: 'parcelas_total') final int? parcelasTotal,
    @JsonKey(unknownEnumValue: OrigemLancamento.manual)
    final OrigemLancamento origem,
    @JsonKey(name: 'os_id') final String? osId,
    @JsonKey(name: 'os_numero') final String? osNumero,
    @JsonKey(name: 'cliente_nome') final String? clienteNome,
    @JsonKey(name: 'servico_nome') final String? servicoNome,
    @JsonKey(name: 'forma_pagamento') final String? formaPagamento,
    final String? observacao,
    final List<String> tags,
    final bool favorito,
    final List<Anexo> anexos,
    final String? created,
    final String? updated,
  }) = _$FinLancamentoImpl;
  const _FinLancamento._() : super._();

  factory _FinLancamento.fromJson(Map<String, dynamic> json) =
      _$FinLancamentoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(unknownEnumValue: TipoLancamento.despesa)
  TipoLancamento get tipo;
  @override
  String get descricao;
  @override
  @JsonKey(name: 'categoria_id')
  String get categoriaId;
  @override
  @JsonKey(name: 'subcategoria_id')
  String? get subcategoriaId;

  /// SEMPRE positivo. O sinal vem de `tipo`.
  @override
  double get valor;
  @override
  @JsonKey(name: 'conta_id')
  String get contaId;
  @override
  String get data;
  @override
  String? get vencimento;
  @override
  @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
  LancamentoStatus get status;
  @override
  @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
  RecorrenciaTipo get recorrencia;

  /// Periodicidade da série (só faz sentido em fixa/recorrente). Vazio no PB → mensal.
  @override
  @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
  FrequenciaRecorrencia? get frequencia;
  @override
  @JsonKey(name: 'parcela_atual')
  int? get parcelaAtual;
  @override
  @JsonKey(name: 'parcelas_total')
  int? get parcelasTotal;
  @override
  @JsonKey(unknownEnumValue: OrigemLancamento.manual)
  OrigemLancamento get origem;
  @override
  @JsonKey(name: 'os_id')
  String? get osId;
  @override
  @JsonKey(name: 'os_numero')
  String? get osNumero;
  @override
  @JsonKey(name: 'cliente_nome')
  String? get clienteNome;
  @override
  @JsonKey(name: 'servico_nome')
  String? get servicoNome;
  @override
  @JsonKey(name: 'forma_pagamento')
  String? get formaPagamento;
  @override
  String? get observacao;
  @override
  List<String> get tags;

  /// Pin na lista de Transações (Financeiro v2). PB default false.
  @override
  bool get favorito;
  @override
  List<Anexo> get anexos;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of FinLancamento
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinLancamentoImplCopyWith<_$FinLancamentoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinLimite _$FinLimiteFromJson(Map<String, dynamic> json) {
  return _FinLimite.fromJson(json);
}

/// @nodoc
mixin _$FinLimite {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'categoria_id')
  String get categoriaId => throw _privateConstructorUsedError;
  double get limite => throw _privateConstructorUsedError;

  /// Mês civil do orçamento: 'YYYY-MM' (BRT). Vazio em legado pré-mig 30.
  @JsonKey(name: 'ano_mes')
  String get anoMes => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this FinLimite to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinLimite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinLimiteCopyWith<FinLimite> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinLimiteCopyWith<$Res> {
  factory $FinLimiteCopyWith(FinLimite value, $Res Function(FinLimite) then) =
      _$FinLimiteCopyWithImpl<$Res, FinLimite>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'categoria_id') String categoriaId,
    double limite,
    @JsonKey(name: 'ano_mes') String anoMes,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$FinLimiteCopyWithImpl<$Res, $Val extends FinLimite>
    implements $FinLimiteCopyWith<$Res> {
  _$FinLimiteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinLimite
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoriaId = null,
    Object? limite = null,
    Object? anoMes = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            categoriaId: null == categoriaId
                ? _value.categoriaId
                : categoriaId // ignore: cast_nullable_to_non_nullable
                      as String,
            limite: null == limite
                ? _value.limite
                : limite // ignore: cast_nullable_to_non_nullable
                      as double,
            anoMes: null == anoMes
                ? _value.anoMes
                : anoMes // ignore: cast_nullable_to_non_nullable
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
abstract class _$$FinLimiteImplCopyWith<$Res>
    implements $FinLimiteCopyWith<$Res> {
  factory _$$FinLimiteImplCopyWith(
    _$FinLimiteImpl value,
    $Res Function(_$FinLimiteImpl) then,
  ) = __$$FinLimiteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'categoria_id') String categoriaId,
    double limite,
    @JsonKey(name: 'ano_mes') String anoMes,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$FinLimiteImplCopyWithImpl<$Res>
    extends _$FinLimiteCopyWithImpl<$Res, _$FinLimiteImpl>
    implements _$$FinLimiteImplCopyWith<$Res> {
  __$$FinLimiteImplCopyWithImpl(
    _$FinLimiteImpl _value,
    $Res Function(_$FinLimiteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FinLimite
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoriaId = null,
    Object? limite = null,
    Object? anoMes = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$FinLimiteImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        categoriaId: null == categoriaId
            ? _value.categoriaId
            : categoriaId // ignore: cast_nullable_to_non_nullable
                  as String,
        limite: null == limite
            ? _value.limite
            : limite // ignore: cast_nullable_to_non_nullable
                  as double,
        anoMes: null == anoMes
            ? _value.anoMes
            : anoMes // ignore: cast_nullable_to_non_nullable
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
class _$FinLimiteImpl extends _FinLimite {
  const _$FinLimiteImpl({
    required this.id,
    @JsonKey(name: 'categoria_id') this.categoriaId = '',
    this.limite = 0,
    @JsonKey(name: 'ano_mes') this.anoMes = '',
    this.created,
    this.updated,
  }) : super._();

  factory _$FinLimiteImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinLimiteImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'categoria_id')
  final String categoriaId;
  @override
  @JsonKey()
  final double limite;

  /// Mês civil do orçamento: 'YYYY-MM' (BRT). Vazio em legado pré-mig 30.
  @override
  @JsonKey(name: 'ano_mes')
  final String anoMes;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'FinLimite(id: $id, categoriaId: $categoriaId, limite: $limite, anoMes: $anoMes, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinLimiteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.categoriaId, categoriaId) ||
                other.categoriaId == categoriaId) &&
            (identical(other.limite, limite) || other.limite == limite) &&
            (identical(other.anoMes, anoMes) || other.anoMes == anoMes) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    categoriaId,
    limite,
    anoMes,
    created,
    updated,
  );

  /// Create a copy of FinLimite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinLimiteImplCopyWith<_$FinLimiteImpl> get copyWith =>
      __$$FinLimiteImplCopyWithImpl<_$FinLimiteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinLimiteImplToJson(this);
  }
}

abstract class _FinLimite extends FinLimite {
  const factory _FinLimite({
    required final String id,
    @JsonKey(name: 'categoria_id') final String categoriaId,
    final double limite,
    @JsonKey(name: 'ano_mes') final String anoMes,
    final String? created,
    final String? updated,
  }) = _$FinLimiteImpl;
  const _FinLimite._() : super._();

  factory _FinLimite.fromJson(Map<String, dynamic> json) =
      _$FinLimiteImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'categoria_id')
  String get categoriaId;
  @override
  double get limite;

  /// Mês civil do orçamento: 'YYYY-MM' (BRT). Vazio em legado pré-mig 30.
  @override
  @JsonKey(name: 'ano_mes')
  String get anoMes;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of FinLimite
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinLimiteImplCopyWith<_$FinLimiteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinObjetivo _$FinObjetivoFromJson(Map<String, dynamic> json) {
  return _FinObjetivo.fromJson(json);
}

/// @nodoc
mixin _$FinObjetivo {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  @JsonKey(name: 'meta_valor')
  double get metaValor => throw _privateConstructorUsedError;
  @JsonKey(name: 'valor_atual')
  double get valorAtual => throw _privateConstructorUsedError;
  @JsonKey(name: 'data_limite')
  String? get dataLimite => throw _privateConstructorUsedError;
  bool get ativo => throw _privateConstructorUsedError;
  String? get cor => throw _privateConstructorUsedError;
  String? get icone => throw _privateConstructorUsedError;
  String? get observacao => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this FinObjetivo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinObjetivo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinObjetivoCopyWith<FinObjetivo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinObjetivoCopyWith<$Res> {
  factory $FinObjetivoCopyWith(
    FinObjetivo value,
    $Res Function(FinObjetivo) then,
  ) = _$FinObjetivoCopyWithImpl<$Res, FinObjetivo>;
  @useResult
  $Res call({
    String id,
    String nome,
    @JsonKey(name: 'meta_valor') double metaValor,
    @JsonKey(name: 'valor_atual') double valorAtual,
    @JsonKey(name: 'data_limite') String? dataLimite,
    bool ativo,
    String? cor,
    String? icone,
    String? observacao,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$FinObjetivoCopyWithImpl<$Res, $Val extends FinObjetivo>
    implements $FinObjetivoCopyWith<$Res> {
  _$FinObjetivoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinObjetivo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? metaValor = null,
    Object? valorAtual = null,
    Object? dataLimite = freezed,
    Object? ativo = null,
    Object? cor = freezed,
    Object? icone = freezed,
    Object? observacao = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            metaValor: null == metaValor
                ? _value.metaValor
                : metaValor // ignore: cast_nullable_to_non_nullable
                      as double,
            valorAtual: null == valorAtual
                ? _value.valorAtual
                : valorAtual // ignore: cast_nullable_to_non_nullable
                      as double,
            dataLimite: freezed == dataLimite
                ? _value.dataLimite
                : dataLimite // ignore: cast_nullable_to_non_nullable
                      as String?,
            ativo: null == ativo
                ? _value.ativo
                : ativo // ignore: cast_nullable_to_non_nullable
                      as bool,
            cor: freezed == cor
                ? _value.cor
                : cor // ignore: cast_nullable_to_non_nullable
                      as String?,
            icone: freezed == icone
                ? _value.icone
                : icone // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacao: freezed == observacao
                ? _value.observacao
                : observacao // ignore: cast_nullable_to_non_nullable
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
abstract class _$$FinObjetivoImplCopyWith<$Res>
    implements $FinObjetivoCopyWith<$Res> {
  factory _$$FinObjetivoImplCopyWith(
    _$FinObjetivoImpl value,
    $Res Function(_$FinObjetivoImpl) then,
  ) = __$$FinObjetivoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    @JsonKey(name: 'meta_valor') double metaValor,
    @JsonKey(name: 'valor_atual') double valorAtual,
    @JsonKey(name: 'data_limite') String? dataLimite,
    bool ativo,
    String? cor,
    String? icone,
    String? observacao,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$FinObjetivoImplCopyWithImpl<$Res>
    extends _$FinObjetivoCopyWithImpl<$Res, _$FinObjetivoImpl>
    implements _$$FinObjetivoImplCopyWith<$Res> {
  __$$FinObjetivoImplCopyWithImpl(
    _$FinObjetivoImpl _value,
    $Res Function(_$FinObjetivoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FinObjetivo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? metaValor = null,
    Object? valorAtual = null,
    Object? dataLimite = freezed,
    Object? ativo = null,
    Object? cor = freezed,
    Object? icone = freezed,
    Object? observacao = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$FinObjetivoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        metaValor: null == metaValor
            ? _value.metaValor
            : metaValor // ignore: cast_nullable_to_non_nullable
                  as double,
        valorAtual: null == valorAtual
            ? _value.valorAtual
            : valorAtual // ignore: cast_nullable_to_non_nullable
                  as double,
        dataLimite: freezed == dataLimite
            ? _value.dataLimite
            : dataLimite // ignore: cast_nullable_to_non_nullable
                  as String?,
        ativo: null == ativo
            ? _value.ativo
            : ativo // ignore: cast_nullable_to_non_nullable
                  as bool,
        cor: freezed == cor
            ? _value.cor
            : cor // ignore: cast_nullable_to_non_nullable
                  as String?,
        icone: freezed == icone
            ? _value.icone
            : icone // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacao: freezed == observacao
            ? _value.observacao
            : observacao // ignore: cast_nullable_to_non_nullable
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
class _$FinObjetivoImpl extends _FinObjetivo {
  const _$FinObjetivoImpl({
    required this.id,
    this.nome = '',
    @JsonKey(name: 'meta_valor') this.metaValor = 0,
    @JsonKey(name: 'valor_atual') this.valorAtual = 0,
    @JsonKey(name: 'data_limite') this.dataLimite,
    this.ativo = true,
    this.cor,
    this.icone,
    this.observacao,
    this.created,
    this.updated,
  }) : super._();

  factory _$FinObjetivoImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinObjetivoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String nome;
  @override
  @JsonKey(name: 'meta_valor')
  final double metaValor;
  @override
  @JsonKey(name: 'valor_atual')
  final double valorAtual;
  @override
  @JsonKey(name: 'data_limite')
  final String? dataLimite;
  @override
  @JsonKey()
  final bool ativo;
  @override
  final String? cor;
  @override
  final String? icone;
  @override
  final String? observacao;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'FinObjetivo(id: $id, nome: $nome, metaValor: $metaValor, valorAtual: $valorAtual, dataLimite: $dataLimite, ativo: $ativo, cor: $cor, icone: $icone, observacao: $observacao, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinObjetivoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.metaValor, metaValor) ||
                other.metaValor == metaValor) &&
            (identical(other.valorAtual, valorAtual) ||
                other.valorAtual == valorAtual) &&
            (identical(other.dataLimite, dataLimite) ||
                other.dataLimite == dataLimite) &&
            (identical(other.ativo, ativo) || other.ativo == ativo) &&
            (identical(other.cor, cor) || other.cor == cor) &&
            (identical(other.icone, icone) || other.icone == icone) &&
            (identical(other.observacao, observacao) ||
                other.observacao == observacao) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    metaValor,
    valorAtual,
    dataLimite,
    ativo,
    cor,
    icone,
    observacao,
    created,
    updated,
  );

  /// Create a copy of FinObjetivo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinObjetivoImplCopyWith<_$FinObjetivoImpl> get copyWith =>
      __$$FinObjetivoImplCopyWithImpl<_$FinObjetivoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinObjetivoImplToJson(this);
  }
}

abstract class _FinObjetivo extends FinObjetivo {
  const factory _FinObjetivo({
    required final String id,
    final String nome,
    @JsonKey(name: 'meta_valor') final double metaValor,
    @JsonKey(name: 'valor_atual') final double valorAtual,
    @JsonKey(name: 'data_limite') final String? dataLimite,
    final bool ativo,
    final String? cor,
    final String? icone,
    final String? observacao,
    final String? created,
    final String? updated,
  }) = _$FinObjetivoImpl;
  const _FinObjetivo._() : super._();

  factory _FinObjetivo.fromJson(Map<String, dynamic> json) =
      _$FinObjetivoImpl.fromJson;

  @override
  String get id;
  @override
  String get nome;
  @override
  @JsonKey(name: 'meta_valor')
  double get metaValor;
  @override
  @JsonKey(name: 'valor_atual')
  double get valorAtual;
  @override
  @JsonKey(name: 'data_limite')
  String? get dataLimite;
  @override
  bool get ativo;
  @override
  String? get cor;
  @override
  String? get icone;
  @override
  String? get observacao;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of FinObjetivo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinObjetivoImplCopyWith<_$FinObjetivoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
