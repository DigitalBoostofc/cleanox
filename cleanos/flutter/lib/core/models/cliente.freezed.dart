// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cliente.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Cliente _$ClienteFromJson(Map<String, dynamic> json) {
  return _Cliente.fromJson(json);
}

/// @nodoc
mixin _$Cliente {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  String? get sobrenome => throw _privateConstructorUsedError;

  /// SENSÍVEL — nunca exposto ao profissional.
  String get telefone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'endereco_rua')
  String? get enderecoRua => throw _privateConstructorUsedError;
  @JsonKey(name: 'endereco_numero')
  String? get enderecoNumero => throw _privateConstructorUsedError;
  @JsonKey(name: 'endereco_complemento')
  String? get enderecoComplemento => throw _privateConstructorUsedError;

  /// Seguro — vira `bairro` na OS via hook.
  @JsonKey(name: 'endereco_bairro')
  String get enderecoBairro => throw _privateConstructorUsedError;
  @JsonKey(name: 'endereco_cidade')
  String? get enderecoCidade => throw _privateConstructorUsedError;
  @JsonKey(name: 'endereco_estado')
  String? get enderecoEstado => throw _privateConstructorUsedError;
  @JsonKey(name: 'endereco_cep')
  String? get enderecoCep => throw _privateConstructorUsedError;
  bool get ativo => throw _privateConstructorUsedError;

  /// Origem do lead (Instagram, Facebook, Indicação…). Opcional; "" = não
  /// informado. Alimenta relatório de origem e a atribuição do Meta CAPI.
  String? get origem => throw _privateConstructorUsedError;
  String? get observacoes => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this Cliente to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Cliente
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClienteCopyWith<Cliente> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClienteCopyWith<$Res> {
  factory $ClienteCopyWith(Cliente value, $Res Function(Cliente) then) =
      _$ClienteCopyWithImpl<$Res, Cliente>;
  @useResult
  $Res call({
    String id,
    String nome,
    String? sobrenome,
    String telefone,
    String? email,
    @JsonKey(name: 'endereco_rua') String? enderecoRua,
    @JsonKey(name: 'endereco_numero') String? enderecoNumero,
    @JsonKey(name: 'endereco_complemento') String? enderecoComplemento,
    @JsonKey(name: 'endereco_bairro') String enderecoBairro,
    @JsonKey(name: 'endereco_cidade') String? enderecoCidade,
    @JsonKey(name: 'endereco_estado') String? enderecoEstado,
    @JsonKey(name: 'endereco_cep') String? enderecoCep,
    bool ativo,
    String? origem,
    String? observacoes,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$ClienteCopyWithImpl<$Res, $Val extends Cliente>
    implements $ClienteCopyWith<$Res> {
  _$ClienteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Cliente
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? sobrenome = freezed,
    Object? telefone = null,
    Object? email = freezed,
    Object? enderecoRua = freezed,
    Object? enderecoNumero = freezed,
    Object? enderecoComplemento = freezed,
    Object? enderecoBairro = null,
    Object? enderecoCidade = freezed,
    Object? enderecoEstado = freezed,
    Object? enderecoCep = freezed,
    Object? ativo = null,
    Object? origem = freezed,
    Object? observacoes = freezed,
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
            sobrenome: freezed == sobrenome
                ? _value.sobrenome
                : sobrenome // ignore: cast_nullable_to_non_nullable
                      as String?,
            telefone: null == telefone
                ? _value.telefone
                : telefone // ignore: cast_nullable_to_non_nullable
                      as String,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            enderecoRua: freezed == enderecoRua
                ? _value.enderecoRua
                : enderecoRua // ignore: cast_nullable_to_non_nullable
                      as String?,
            enderecoNumero: freezed == enderecoNumero
                ? _value.enderecoNumero
                : enderecoNumero // ignore: cast_nullable_to_non_nullable
                      as String?,
            enderecoComplemento: freezed == enderecoComplemento
                ? _value.enderecoComplemento
                : enderecoComplemento // ignore: cast_nullable_to_non_nullable
                      as String?,
            enderecoBairro: null == enderecoBairro
                ? _value.enderecoBairro
                : enderecoBairro // ignore: cast_nullable_to_non_nullable
                      as String,
            enderecoCidade: freezed == enderecoCidade
                ? _value.enderecoCidade
                : enderecoCidade // ignore: cast_nullable_to_non_nullable
                      as String?,
            enderecoEstado: freezed == enderecoEstado
                ? _value.enderecoEstado
                : enderecoEstado // ignore: cast_nullable_to_non_nullable
                      as String?,
            enderecoCep: freezed == enderecoCep
                ? _value.enderecoCep
                : enderecoCep // ignore: cast_nullable_to_non_nullable
                      as String?,
            ativo: null == ativo
                ? _value.ativo
                : ativo // ignore: cast_nullable_to_non_nullable
                      as bool,
            origem: freezed == origem
                ? _value.origem
                : origem // ignore: cast_nullable_to_non_nullable
                      as String?,
            observacoes: freezed == observacoes
                ? _value.observacoes
                : observacoes // ignore: cast_nullable_to_non_nullable
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
abstract class _$$ClienteImplCopyWith<$Res> implements $ClienteCopyWith<$Res> {
  factory _$$ClienteImplCopyWith(
    _$ClienteImpl value,
    $Res Function(_$ClienteImpl) then,
  ) = __$$ClienteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    String? sobrenome,
    String telefone,
    String? email,
    @JsonKey(name: 'endereco_rua') String? enderecoRua,
    @JsonKey(name: 'endereco_numero') String? enderecoNumero,
    @JsonKey(name: 'endereco_complemento') String? enderecoComplemento,
    @JsonKey(name: 'endereco_bairro') String enderecoBairro,
    @JsonKey(name: 'endereco_cidade') String? enderecoCidade,
    @JsonKey(name: 'endereco_estado') String? enderecoEstado,
    @JsonKey(name: 'endereco_cep') String? enderecoCep,
    bool ativo,
    String? origem,
    String? observacoes,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$ClienteImplCopyWithImpl<$Res>
    extends _$ClienteCopyWithImpl<$Res, _$ClienteImpl>
    implements _$$ClienteImplCopyWith<$Res> {
  __$$ClienteImplCopyWithImpl(
    _$ClienteImpl _value,
    $Res Function(_$ClienteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Cliente
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? sobrenome = freezed,
    Object? telefone = null,
    Object? email = freezed,
    Object? enderecoRua = freezed,
    Object? enderecoNumero = freezed,
    Object? enderecoComplemento = freezed,
    Object? enderecoBairro = null,
    Object? enderecoCidade = freezed,
    Object? enderecoEstado = freezed,
    Object? enderecoCep = freezed,
    Object? ativo = null,
    Object? origem = freezed,
    Object? observacoes = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$ClienteImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        sobrenome: freezed == sobrenome
            ? _value.sobrenome
            : sobrenome // ignore: cast_nullable_to_non_nullable
                  as String?,
        telefone: null == telefone
            ? _value.telefone
            : telefone // ignore: cast_nullable_to_non_nullable
                  as String,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        enderecoRua: freezed == enderecoRua
            ? _value.enderecoRua
            : enderecoRua // ignore: cast_nullable_to_non_nullable
                  as String?,
        enderecoNumero: freezed == enderecoNumero
            ? _value.enderecoNumero
            : enderecoNumero // ignore: cast_nullable_to_non_nullable
                  as String?,
        enderecoComplemento: freezed == enderecoComplemento
            ? _value.enderecoComplemento
            : enderecoComplemento // ignore: cast_nullable_to_non_nullable
                  as String?,
        enderecoBairro: null == enderecoBairro
            ? _value.enderecoBairro
            : enderecoBairro // ignore: cast_nullable_to_non_nullable
                  as String,
        enderecoCidade: freezed == enderecoCidade
            ? _value.enderecoCidade
            : enderecoCidade // ignore: cast_nullable_to_non_nullable
                  as String?,
        enderecoEstado: freezed == enderecoEstado
            ? _value.enderecoEstado
            : enderecoEstado // ignore: cast_nullable_to_non_nullable
                  as String?,
        enderecoCep: freezed == enderecoCep
            ? _value.enderecoCep
            : enderecoCep // ignore: cast_nullable_to_non_nullable
                  as String?,
        ativo: null == ativo
            ? _value.ativo
            : ativo // ignore: cast_nullable_to_non_nullable
                  as bool,
        origem: freezed == origem
            ? _value.origem
            : origem // ignore: cast_nullable_to_non_nullable
                  as String?,
        observacoes: freezed == observacoes
            ? _value.observacoes
            : observacoes // ignore: cast_nullable_to_non_nullable
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
class _$ClienteImpl extends _Cliente {
  const _$ClienteImpl({
    required this.id,
    this.nome = '',
    this.sobrenome,
    this.telefone = '',
    this.email,
    @JsonKey(name: 'endereco_rua') this.enderecoRua,
    @JsonKey(name: 'endereco_numero') this.enderecoNumero,
    @JsonKey(name: 'endereco_complemento') this.enderecoComplemento,
    @JsonKey(name: 'endereco_bairro') this.enderecoBairro = '',
    @JsonKey(name: 'endereco_cidade') this.enderecoCidade,
    @JsonKey(name: 'endereco_estado') this.enderecoEstado,
    @JsonKey(name: 'endereco_cep') this.enderecoCep,
    this.ativo = true,
    this.origem,
    this.observacoes,
    this.created,
    this.updated,
  }) : super._();

  factory _$ClienteImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClienteImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String nome;
  @override
  final String? sobrenome;

  /// SENSÍVEL — nunca exposto ao profissional.
  @override
  @JsonKey()
  final String telefone;
  @override
  final String? email;
  @override
  @JsonKey(name: 'endereco_rua')
  final String? enderecoRua;
  @override
  @JsonKey(name: 'endereco_numero')
  final String? enderecoNumero;
  @override
  @JsonKey(name: 'endereco_complemento')
  final String? enderecoComplemento;

  /// Seguro — vira `bairro` na OS via hook.
  @override
  @JsonKey(name: 'endereco_bairro')
  final String enderecoBairro;
  @override
  @JsonKey(name: 'endereco_cidade')
  final String? enderecoCidade;
  @override
  @JsonKey(name: 'endereco_estado')
  final String? enderecoEstado;
  @override
  @JsonKey(name: 'endereco_cep')
  final String? enderecoCep;
  @override
  @JsonKey()
  final bool ativo;

  /// Origem do lead (Instagram, Facebook, Indicação…). Opcional; "" = não
  /// informado. Alimenta relatório de origem e a atribuição do Meta CAPI.
  @override
  final String? origem;
  @override
  final String? observacoes;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'Cliente(id: $id, nome: $nome, sobrenome: $sobrenome, telefone: $telefone, email: $email, enderecoRua: $enderecoRua, enderecoNumero: $enderecoNumero, enderecoComplemento: $enderecoComplemento, enderecoBairro: $enderecoBairro, enderecoCidade: $enderecoCidade, enderecoEstado: $enderecoEstado, enderecoCep: $enderecoCep, ativo: $ativo, origem: $origem, observacoes: $observacoes, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClienteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.sobrenome, sobrenome) ||
                other.sobrenome == sobrenome) &&
            (identical(other.telefone, telefone) ||
                other.telefone == telefone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.enderecoRua, enderecoRua) ||
                other.enderecoRua == enderecoRua) &&
            (identical(other.enderecoNumero, enderecoNumero) ||
                other.enderecoNumero == enderecoNumero) &&
            (identical(other.enderecoComplemento, enderecoComplemento) ||
                other.enderecoComplemento == enderecoComplemento) &&
            (identical(other.enderecoBairro, enderecoBairro) ||
                other.enderecoBairro == enderecoBairro) &&
            (identical(other.enderecoCidade, enderecoCidade) ||
                other.enderecoCidade == enderecoCidade) &&
            (identical(other.enderecoEstado, enderecoEstado) ||
                other.enderecoEstado == enderecoEstado) &&
            (identical(other.enderecoCep, enderecoCep) ||
                other.enderecoCep == enderecoCep) &&
            (identical(other.ativo, ativo) || other.ativo == ativo) &&
            (identical(other.origem, origem) || other.origem == origem) &&
            (identical(other.observacoes, observacoes) ||
                other.observacoes == observacoes) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    sobrenome,
    telefone,
    email,
    enderecoRua,
    enderecoNumero,
    enderecoComplemento,
    enderecoBairro,
    enderecoCidade,
    enderecoEstado,
    enderecoCep,
    ativo,
    origem,
    observacoes,
    created,
    updated,
  );

  /// Create a copy of Cliente
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClienteImplCopyWith<_$ClienteImpl> get copyWith =>
      __$$ClienteImplCopyWithImpl<_$ClienteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClienteImplToJson(this);
  }
}

abstract class _Cliente extends Cliente {
  const factory _Cliente({
    required final String id,
    final String nome,
    final String? sobrenome,
    final String telefone,
    final String? email,
    @JsonKey(name: 'endereco_rua') final String? enderecoRua,
    @JsonKey(name: 'endereco_numero') final String? enderecoNumero,
    @JsonKey(name: 'endereco_complemento') final String? enderecoComplemento,
    @JsonKey(name: 'endereco_bairro') final String enderecoBairro,
    @JsonKey(name: 'endereco_cidade') final String? enderecoCidade,
    @JsonKey(name: 'endereco_estado') final String? enderecoEstado,
    @JsonKey(name: 'endereco_cep') final String? enderecoCep,
    final bool ativo,
    final String? origem,
    final String? observacoes,
    final String? created,
    final String? updated,
  }) = _$ClienteImpl;
  const _Cliente._() : super._();

  factory _Cliente.fromJson(Map<String, dynamic> json) = _$ClienteImpl.fromJson;

  @override
  String get id;
  @override
  String get nome;
  @override
  String? get sobrenome;

  /// SENSÍVEL — nunca exposto ao profissional.
  @override
  String get telefone;
  @override
  String? get email;
  @override
  @JsonKey(name: 'endereco_rua')
  String? get enderecoRua;
  @override
  @JsonKey(name: 'endereco_numero')
  String? get enderecoNumero;
  @override
  @JsonKey(name: 'endereco_complemento')
  String? get enderecoComplemento;

  /// Seguro — vira `bairro` na OS via hook.
  @override
  @JsonKey(name: 'endereco_bairro')
  String get enderecoBairro;
  @override
  @JsonKey(name: 'endereco_cidade')
  String? get enderecoCidade;
  @override
  @JsonKey(name: 'endereco_estado')
  String? get enderecoEstado;
  @override
  @JsonKey(name: 'endereco_cep')
  String? get enderecoCep;
  @override
  bool get ativo;

  /// Origem do lead (Instagram, Facebook, Indicação…). Opcional; "" = não
  /// informado. Alimenta relatório de origem e a atribuição do Meta CAPI.
  @override
  String? get origem;
  @override
  String? get observacoes;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of Cliente
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClienteImplCopyWith<_$ClienteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
