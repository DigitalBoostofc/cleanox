// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: Role.profissional)
  Role get role => throw _privateConstructorUsedError;

  /// Nome de exibição do colaborador (campo extra do CleanOS).
  String? get nome => throw _privateConstructorUsedError;

  /// WhatsApp do PRÓPRIO colaborador (contato, não é PII de cliente). Usado
  /// para o aviso "Nova OS" ao profissional. Cadastrado pelo admin.
  String? get whatsapp => throw _privateConstructorUsedError;

  /// Comissão: `nenhuma` | `percentual` | `fixo` (migration 23).
  @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
  ComissaoTipo get comissaoTipo => throw _privateConstructorUsedError;

  /// % (0–100) ou valor fixo em R$, conforme [comissaoTipo].
  @JsonKey(name: 'comissao_valor')
  double get comissaoValor => throw _privateConstructorUsedError;
  bool get verified => throw _privateConstructorUsedError;
  @JsonKey(name: 'emailVisibility')
  bool get emailVisibility => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call({
    String id,
    String name,
    String email,
    @JsonKey(unknownEnumValue: Role.profissional) Role role,
    String? nome,
    String? whatsapp,
    @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
    ComissaoTipo comissaoTipo,
    @JsonKey(name: 'comissao_valor') double comissaoValor,
    bool verified,
    @JsonKey(name: 'emailVisibility') bool emailVisibility,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? email = null,
    Object? role = null,
    Object? nome = freezed,
    Object? whatsapp = freezed,
    Object? comissaoTipo = null,
    Object? comissaoValor = null,
    Object? verified = null,
    Object? emailVisibility = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as Role,
            nome: freezed == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String?,
            whatsapp: freezed == whatsapp
                ? _value.whatsapp
                : whatsapp // ignore: cast_nullable_to_non_nullable
                      as String?,
            comissaoTipo: null == comissaoTipo
                ? _value.comissaoTipo
                : comissaoTipo // ignore: cast_nullable_to_non_nullable
                      as ComissaoTipo,
            comissaoValor: null == comissaoValor
                ? _value.comissaoValor
                : comissaoValor // ignore: cast_nullable_to_non_nullable
                      as double,
            verified: null == verified
                ? _value.verified
                : verified // ignore: cast_nullable_to_non_nullable
                      as bool,
            emailVisibility: null == emailVisibility
                ? _value.emailVisibility
                : emailVisibility // ignore: cast_nullable_to_non_nullable
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
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
    _$UserImpl value,
    $Res Function(_$UserImpl) then,
  ) = __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String email,
    @JsonKey(unknownEnumValue: Role.profissional) Role role,
    String? nome,
    String? whatsapp,
    @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
    ComissaoTipo comissaoTipo,
    @JsonKey(name: 'comissao_valor') double comissaoValor,
    bool verified,
    @JsonKey(name: 'emailVisibility') bool emailVisibility,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
    : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? email = null,
    Object? role = null,
    Object? nome = freezed,
    Object? whatsapp = freezed,
    Object? comissaoTipo = null,
    Object? comissaoValor = null,
    Object? verified = null,
    Object? emailVisibility = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$UserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as Role,
        nome: freezed == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String?,
        whatsapp: freezed == whatsapp
            ? _value.whatsapp
            : whatsapp // ignore: cast_nullable_to_non_nullable
                  as String?,
        comissaoTipo: null == comissaoTipo
            ? _value.comissaoTipo
            : comissaoTipo // ignore: cast_nullable_to_non_nullable
                  as ComissaoTipo,
        comissaoValor: null == comissaoValor
            ? _value.comissaoValor
            : comissaoValor // ignore: cast_nullable_to_non_nullable
                  as double,
        verified: null == verified
            ? _value.verified
            : verified // ignore: cast_nullable_to_non_nullable
                  as bool,
        emailVisibility: null == emailVisibility
            ? _value.emailVisibility
            : emailVisibility // ignore: cast_nullable_to_non_nullable
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
class _$UserImpl extends _User {
  const _$UserImpl({
    required this.id,
    this.name = '',
    this.email = '',
    @JsonKey(unknownEnumValue: Role.profissional) this.role = Role.profissional,
    this.nome,
    this.whatsapp,
    @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
    this.comissaoTipo = ComissaoTipo.nenhuma,
    @JsonKey(name: 'comissao_valor') this.comissaoValor = 0,
    this.verified = false,
    @JsonKey(name: 'emailVisibility') this.emailVisibility = false,
    this.created,
    this.updated,
  }) : super._();

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String email;
  @override
  @JsonKey(unknownEnumValue: Role.profissional)
  final Role role;

  /// Nome de exibição do colaborador (campo extra do CleanOS).
  @override
  final String? nome;

  /// WhatsApp do PRÓPRIO colaborador (contato, não é PII de cliente). Usado
  /// para o aviso "Nova OS" ao profissional. Cadastrado pelo admin.
  @override
  final String? whatsapp;

  /// Comissão: `nenhuma` | `percentual` | `fixo` (migration 23).
  @override
  @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
  final ComissaoTipo comissaoTipo;

  /// % (0–100) ou valor fixo em R$, conforme [comissaoTipo].
  @override
  @JsonKey(name: 'comissao_valor')
  final double comissaoValor;
  @override
  @JsonKey()
  final bool verified;
  @override
  @JsonKey(name: 'emailVisibility')
  final bool emailVisibility;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, role: $role, nome: $nome, whatsapp: $whatsapp, comissaoTipo: $comissaoTipo, comissaoValor: $comissaoValor, verified: $verified, emailVisibility: $emailVisibility, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.whatsapp, whatsapp) ||
                other.whatsapp == whatsapp) &&
            (identical(other.comissaoTipo, comissaoTipo) ||
                other.comissaoTipo == comissaoTipo) &&
            (identical(other.comissaoValor, comissaoValor) ||
                other.comissaoValor == comissaoValor) &&
            (identical(other.verified, verified) ||
                other.verified == verified) &&
            (identical(other.emailVisibility, emailVisibility) ||
                other.emailVisibility == emailVisibility) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    email,
    role,
    nome,
    whatsapp,
    comissaoTipo,
    comissaoValor,
    verified,
    emailVisibility,
    created,
    updated,
  );

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(this);
  }
}

abstract class _User extends User {
  const factory _User({
    required final String id,
    final String name,
    final String email,
    @JsonKey(unknownEnumValue: Role.profissional) final Role role,
    final String? nome,
    final String? whatsapp,
    @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
    final ComissaoTipo comissaoTipo,
    @JsonKey(name: 'comissao_valor') final double comissaoValor,
    final bool verified,
    @JsonKey(name: 'emailVisibility') final bool emailVisibility,
    final String? created,
    final String? updated,
  }) = _$UserImpl;
  const _User._() : super._();

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get email;
  @override
  @JsonKey(unknownEnumValue: Role.profissional)
  Role get role;

  /// Nome de exibição do colaborador (campo extra do CleanOS).
  @override
  String? get nome;

  /// WhatsApp do PRÓPRIO colaborador (contato, não é PII de cliente). Usado
  /// para o aviso "Nova OS" ao profissional. Cadastrado pelo admin.
  @override
  String? get whatsapp;

  /// Comissão: `nenhuma` | `percentual` | `fixo` (migration 23).
  @override
  @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
  ComissaoTipo get comissaoTipo;

  /// % (0–100) ou valor fixo em R$, conforme [comissaoTipo].
  @override
  @JsonKey(name: 'comissao_valor')
  double get comissaoValor;
  @override
  bool get verified;
  @override
  @JsonKey(name: 'emailVisibility')
  bool get emailVisibility;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
