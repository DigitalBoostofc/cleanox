// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'servico.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChecklistTemplateItem _$ChecklistTemplateItemFromJson(
  Map<String, dynamic> json,
) {
  return _ChecklistTemplateItem.fromJson(json);
}

/// @nodoc
mixin _$ChecklistTemplateItem {
  String get id => throw _privateConstructorUsedError;
  String get titulo => throw _privateConstructorUsedError;

  /// Ordem de exibição/execução (1-based).
  int get ordem => throw _privateConstructorUsedError;

  /// Se true, DEVE estar concluído antes de concluir a OS.
  bool get obrigatorio => throw _privateConstructorUsedError;

  /// Serializes this ChecklistTemplateItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistTemplateItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistTemplateItemCopyWith<ChecklistTemplateItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistTemplateItemCopyWith<$Res> {
  factory $ChecklistTemplateItemCopyWith(
    ChecklistTemplateItem value,
    $Res Function(ChecklistTemplateItem) then,
  ) = _$ChecklistTemplateItemCopyWithImpl<$Res, ChecklistTemplateItem>;
  @useResult
  $Res call({String id, String titulo, int ordem, bool obrigatorio});
}

/// @nodoc
class _$ChecklistTemplateItemCopyWithImpl<
  $Res,
  $Val extends ChecklistTemplateItem
>
    implements $ChecklistTemplateItemCopyWith<$Res> {
  _$ChecklistTemplateItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistTemplateItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? titulo = null,
    Object? ordem = null,
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
            ordem: null == ordem
                ? _value.ordem
                : ordem // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$ChecklistTemplateItemImplCopyWith<$Res>
    implements $ChecklistTemplateItemCopyWith<$Res> {
  factory _$$ChecklistTemplateItemImplCopyWith(
    _$ChecklistTemplateItemImpl value,
    $Res Function(_$ChecklistTemplateItemImpl) then,
  ) = __$$ChecklistTemplateItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String titulo, int ordem, bool obrigatorio});
}

/// @nodoc
class __$$ChecklistTemplateItemImplCopyWithImpl<$Res>
    extends
        _$ChecklistTemplateItemCopyWithImpl<$Res, _$ChecklistTemplateItemImpl>
    implements _$$ChecklistTemplateItemImplCopyWith<$Res> {
  __$$ChecklistTemplateItemImplCopyWithImpl(
    _$ChecklistTemplateItemImpl _value,
    $Res Function(_$ChecklistTemplateItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChecklistTemplateItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? titulo = null,
    Object? ordem = null,
    Object? obrigatorio = null,
  }) {
    return _then(
      _$ChecklistTemplateItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        titulo: null == titulo
            ? _value.titulo
            : titulo // ignore: cast_nullable_to_non_nullable
                  as String,
        ordem: null == ordem
            ? _value.ordem
            : ordem // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$ChecklistTemplateItemImpl implements _ChecklistTemplateItem {
  const _$ChecklistTemplateItemImpl({
    this.id = '',
    this.titulo = '',
    this.ordem = 0,
    this.obrigatorio = false,
  });

  factory _$ChecklistTemplateItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistTemplateItemImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String titulo;

  /// Ordem de exibição/execução (1-based).
  @override
  @JsonKey()
  final int ordem;

  /// Se true, DEVE estar concluído antes de concluir a OS.
  @override
  @JsonKey()
  final bool obrigatorio;

  @override
  String toString() {
    return 'ChecklistTemplateItem(id: $id, titulo: $titulo, ordem: $ordem, obrigatorio: $obrigatorio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistTemplateItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.titulo, titulo) || other.titulo == titulo) &&
            (identical(other.ordem, ordem) || other.ordem == ordem) &&
            (identical(other.obrigatorio, obrigatorio) ||
                other.obrigatorio == obrigatorio));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, titulo, ordem, obrigatorio);

  /// Create a copy of ChecklistTemplateItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistTemplateItemImplCopyWith<_$ChecklistTemplateItemImpl>
  get copyWith =>
      __$$ChecklistTemplateItemImplCopyWithImpl<_$ChecklistTemplateItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistTemplateItemImplToJson(this);
  }
}

abstract class _ChecklistTemplateItem implements ChecklistTemplateItem {
  const factory _ChecklistTemplateItem({
    final String id,
    final String titulo,
    final int ordem,
    final bool obrigatorio,
  }) = _$ChecklistTemplateItemImpl;

  factory _ChecklistTemplateItem.fromJson(Map<String, dynamic> json) =
      _$ChecklistTemplateItemImpl.fromJson;

  @override
  String get id;
  @override
  String get titulo;

  /// Ordem de exibição/execução (1-based).
  @override
  int get ordem;

  /// Se true, DEVE estar concluído antes de concluir a OS.
  @override
  bool get obrigatorio;

  /// Create a copy of ChecklistTemplateItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistTemplateItemImplCopyWith<_$ChecklistTemplateItemImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ServiceSnapshot _$ServiceSnapshotFromJson(Map<String, dynamic> json) {
  return _ServiceSnapshot.fromJson(json);
}

/// @nodoc
mixin _$ServiceSnapshot {
  String get serviceId => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Categoria? get categoria => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Grupo? get grupo => throw _privateConstructorUsedError;
  double get valorBase => throw _privateConstructorUsedError;
  double? get valorBaseMax => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  TipoValor? get tipoValor => throw _privateConstructorUsedError;
  double? get tempoMedioMin => throw _privateConstructorUsedError;
  String get tempoMedioLabel => throw _privateConstructorUsedError;

  /// Equivale a Servico.observacao no instante da captura.
  String? get observacaoTecnica => throw _privateConstructorUsedError;
  List<ChecklistTemplateItem> get checklistPadrao =>
      throw _privateConstructorUsedError;
  String? get orientacoesPreServico => throw _privateConstructorUsedError;
  String? get orientacoesPosServico => throw _privateConstructorUsedError;

  /// ISO datetime de quando o snapshot foi capturado.
  String get capturedAt => throw _privateConstructorUsedError;

  /// Serializes this ServiceSnapshot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ServiceSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServiceSnapshotCopyWith<ServiceSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServiceSnapshotCopyWith<$Res> {
  factory $ServiceSnapshotCopyWith(
    ServiceSnapshot value,
    $Res Function(ServiceSnapshot) then,
  ) = _$ServiceSnapshotCopyWithImpl<$Res, ServiceSnapshot>;
  @useResult
  $Res call({
    String serviceId,
    String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    double valorBase,
    double? valorBaseMax,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TipoValor? tipoValor,
    double? tempoMedioMin,
    String tempoMedioLabel,
    String? observacaoTecnica,
    List<ChecklistTemplateItem> checklistPadrao,
    String? orientacoesPreServico,
    String? orientacoesPosServico,
    String capturedAt,
  });
}

/// @nodoc
class _$ServiceSnapshotCopyWithImpl<$Res, $Val extends ServiceSnapshot>
    implements $ServiceSnapshotCopyWith<$Res> {
  _$ServiceSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ServiceSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serviceId = null,
    Object? nome = null,
    Object? categoria = freezed,
    Object? grupo = freezed,
    Object? valorBase = null,
    Object? valorBaseMax = freezed,
    Object? tipoValor = freezed,
    Object? tempoMedioMin = freezed,
    Object? tempoMedioLabel = null,
    Object? observacaoTecnica = freezed,
    Object? checklistPadrao = null,
    Object? orientacoesPreServico = freezed,
    Object? orientacoesPosServico = freezed,
    Object? capturedAt = null,
  }) {
    return _then(
      _value.copyWith(
            serviceId: null == serviceId
                ? _value.serviceId
                : serviceId // ignore: cast_nullable_to_non_nullable
                      as String,
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
            valorBase: null == valorBase
                ? _value.valorBase
                : valorBase // ignore: cast_nullable_to_non_nullable
                      as double,
            valorBaseMax: freezed == valorBaseMax
                ? _value.valorBaseMax
                : valorBaseMax // ignore: cast_nullable_to_non_nullable
                      as double?,
            tipoValor: freezed == tipoValor
                ? _value.tipoValor
                : tipoValor // ignore: cast_nullable_to_non_nullable
                      as TipoValor?,
            tempoMedioMin: freezed == tempoMedioMin
                ? _value.tempoMedioMin
                : tempoMedioMin // ignore: cast_nullable_to_non_nullable
                      as double?,
            tempoMedioLabel: null == tempoMedioLabel
                ? _value.tempoMedioLabel
                : tempoMedioLabel // ignore: cast_nullable_to_non_nullable
                      as String,
            observacaoTecnica: freezed == observacaoTecnica
                ? _value.observacaoTecnica
                : observacaoTecnica // ignore: cast_nullable_to_non_nullable
                      as String?,
            checklistPadrao: null == checklistPadrao
                ? _value.checklistPadrao
                : checklistPadrao // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistTemplateItem>,
            orientacoesPreServico: freezed == orientacoesPreServico
                ? _value.orientacoesPreServico
                : orientacoesPreServico // ignore: cast_nullable_to_non_nullable
                      as String?,
            orientacoesPosServico: freezed == orientacoesPosServico
                ? _value.orientacoesPosServico
                : orientacoesPosServico // ignore: cast_nullable_to_non_nullable
                      as String?,
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ServiceSnapshotImplCopyWith<$Res>
    implements $ServiceSnapshotCopyWith<$Res> {
  factory _$$ServiceSnapshotImplCopyWith(
    _$ServiceSnapshotImpl value,
    $Res Function(_$ServiceSnapshotImpl) then,
  ) = __$$ServiceSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String serviceId,
    String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    double valorBase,
    double? valorBaseMax,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TipoValor? tipoValor,
    double? tempoMedioMin,
    String tempoMedioLabel,
    String? observacaoTecnica,
    List<ChecklistTemplateItem> checklistPadrao,
    String? orientacoesPreServico,
    String? orientacoesPosServico,
    String capturedAt,
  });
}

/// @nodoc
class __$$ServiceSnapshotImplCopyWithImpl<$Res>
    extends _$ServiceSnapshotCopyWithImpl<$Res, _$ServiceSnapshotImpl>
    implements _$$ServiceSnapshotImplCopyWith<$Res> {
  __$$ServiceSnapshotImplCopyWithImpl(
    _$ServiceSnapshotImpl _value,
    $Res Function(_$ServiceSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ServiceSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serviceId = null,
    Object? nome = null,
    Object? categoria = freezed,
    Object? grupo = freezed,
    Object? valorBase = null,
    Object? valorBaseMax = freezed,
    Object? tipoValor = freezed,
    Object? tempoMedioMin = freezed,
    Object? tempoMedioLabel = null,
    Object? observacaoTecnica = freezed,
    Object? checklistPadrao = null,
    Object? orientacoesPreServico = freezed,
    Object? orientacoesPosServico = freezed,
    Object? capturedAt = null,
  }) {
    return _then(
      _$ServiceSnapshotImpl(
        serviceId: null == serviceId
            ? _value.serviceId
            : serviceId // ignore: cast_nullable_to_non_nullable
                  as String,
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
        valorBase: null == valorBase
            ? _value.valorBase
            : valorBase // ignore: cast_nullable_to_non_nullable
                  as double,
        valorBaseMax: freezed == valorBaseMax
            ? _value.valorBaseMax
            : valorBaseMax // ignore: cast_nullable_to_non_nullable
                  as double?,
        tipoValor: freezed == tipoValor
            ? _value.tipoValor
            : tipoValor // ignore: cast_nullable_to_non_nullable
                  as TipoValor?,
        tempoMedioMin: freezed == tempoMedioMin
            ? _value.tempoMedioMin
            : tempoMedioMin // ignore: cast_nullable_to_non_nullable
                  as double?,
        tempoMedioLabel: null == tempoMedioLabel
            ? _value.tempoMedioLabel
            : tempoMedioLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        observacaoTecnica: freezed == observacaoTecnica
            ? _value.observacaoTecnica
            : observacaoTecnica // ignore: cast_nullable_to_non_nullable
                  as String?,
        checklistPadrao: null == checklistPadrao
            ? _value._checklistPadrao
            : checklistPadrao // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistTemplateItem>,
        orientacoesPreServico: freezed == orientacoesPreServico
            ? _value.orientacoesPreServico
            : orientacoesPreServico // ignore: cast_nullable_to_non_nullable
                  as String?,
        orientacoesPosServico: freezed == orientacoesPosServico
            ? _value.orientacoesPosServico
            : orientacoesPosServico // ignore: cast_nullable_to_non_nullable
                  as String?,
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ServiceSnapshotImpl implements _ServiceSnapshot {
  const _$ServiceSnapshotImpl({
    this.serviceId = '',
    this.nome = '',
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    this.categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.grupo,
    this.valorBase = 0,
    this.valorBaseMax,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    this.tipoValor,
    this.tempoMedioMin,
    this.tempoMedioLabel = '',
    this.observacaoTecnica,
    final List<ChecklistTemplateItem> checklistPadrao =
        const <ChecklistTemplateItem>[],
    this.orientacoesPreServico,
    this.orientacoesPosServico,
    this.capturedAt = '',
  }) : _checklistPadrao = checklistPadrao;

  factory _$ServiceSnapshotImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServiceSnapshotImplFromJson(json);

  @override
  @JsonKey()
  final String serviceId;
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
  final double valorBase;
  @override
  final double? valorBaseMax;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final TipoValor? tipoValor;
  @override
  final double? tempoMedioMin;
  @override
  @JsonKey()
  final String tempoMedioLabel;

  /// Equivale a Servico.observacao no instante da captura.
  @override
  final String? observacaoTecnica;
  final List<ChecklistTemplateItem> _checklistPadrao;
  @override
  @JsonKey()
  List<ChecklistTemplateItem> get checklistPadrao {
    if (_checklistPadrao is EqualUnmodifiableListView) return _checklistPadrao;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklistPadrao);
  }

  @override
  final String? orientacoesPreServico;
  @override
  final String? orientacoesPosServico;

  /// ISO datetime de quando o snapshot foi capturado.
  @override
  @JsonKey()
  final String capturedAt;

  @override
  String toString() {
    return 'ServiceSnapshot(serviceId: $serviceId, nome: $nome, categoria: $categoria, grupo: $grupo, valorBase: $valorBase, valorBaseMax: $valorBaseMax, tipoValor: $tipoValor, tempoMedioMin: $tempoMedioMin, tempoMedioLabel: $tempoMedioLabel, observacaoTecnica: $observacaoTecnica, checklistPadrao: $checklistPadrao, orientacoesPreServico: $orientacoesPreServico, orientacoesPosServico: $orientacoesPosServico, capturedAt: $capturedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServiceSnapshotImpl &&
            (identical(other.serviceId, serviceId) ||
                other.serviceId == serviceId) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.categoria, categoria) ||
                other.categoria == categoria) &&
            (identical(other.grupo, grupo) || other.grupo == grupo) &&
            (identical(other.valorBase, valorBase) ||
                other.valorBase == valorBase) &&
            (identical(other.valorBaseMax, valorBaseMax) ||
                other.valorBaseMax == valorBaseMax) &&
            (identical(other.tipoValor, tipoValor) ||
                other.tipoValor == tipoValor) &&
            (identical(other.tempoMedioMin, tempoMedioMin) ||
                other.tempoMedioMin == tempoMedioMin) &&
            (identical(other.tempoMedioLabel, tempoMedioLabel) ||
                other.tempoMedioLabel == tempoMedioLabel) &&
            (identical(other.observacaoTecnica, observacaoTecnica) ||
                other.observacaoTecnica == observacaoTecnica) &&
            const DeepCollectionEquality().equals(
              other._checklistPadrao,
              _checklistPadrao,
            ) &&
            (identical(other.orientacoesPreServico, orientacoesPreServico) ||
                other.orientacoesPreServico == orientacoesPreServico) &&
            (identical(other.orientacoesPosServico, orientacoesPosServico) ||
                other.orientacoesPosServico == orientacoesPosServico) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    serviceId,
    nome,
    categoria,
    grupo,
    valorBase,
    valorBaseMax,
    tipoValor,
    tempoMedioMin,
    tempoMedioLabel,
    observacaoTecnica,
    const DeepCollectionEquality().hash(_checklistPadrao),
    orientacoesPreServico,
    orientacoesPosServico,
    capturedAt,
  );

  /// Create a copy of ServiceSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServiceSnapshotImplCopyWith<_$ServiceSnapshotImpl> get copyWith =>
      __$$ServiceSnapshotImplCopyWithImpl<_$ServiceSnapshotImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ServiceSnapshotImplToJson(this);
  }
}

abstract class _ServiceSnapshot implements ServiceSnapshot {
  const factory _ServiceSnapshot({
    final String serviceId,
    final String nome,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final Grupo? grupo,
    final double valorBase,
    final double? valorBaseMax,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final TipoValor? tipoValor,
    final double? tempoMedioMin,
    final String tempoMedioLabel,
    final String? observacaoTecnica,
    final List<ChecklistTemplateItem> checklistPadrao,
    final String? orientacoesPreServico,
    final String? orientacoesPosServico,
    final String capturedAt,
  }) = _$ServiceSnapshotImpl;

  factory _ServiceSnapshot.fromJson(Map<String, dynamic> json) =
      _$ServiceSnapshotImpl.fromJson;

  @override
  String get serviceId;
  @override
  String get nome;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Categoria? get categoria;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Grupo? get grupo;
  @override
  double get valorBase;
  @override
  double? get valorBaseMax;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  TipoValor? get tipoValor;
  @override
  double? get tempoMedioMin;
  @override
  String get tempoMedioLabel;

  /// Equivale a Servico.observacao no instante da captura.
  @override
  String? get observacaoTecnica;
  @override
  List<ChecklistTemplateItem> get checklistPadrao;
  @override
  String? get orientacoesPreServico;
  @override
  String? get orientacoesPosServico;

  /// ISO datetime de quando o snapshot foi capturado.
  @override
  String get capturedAt;

  /// Create a copy of ServiceSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServiceSnapshotImplCopyWith<_$ServiceSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ServicoPB _$ServicoPBFromJson(Map<String, dynamic> json) {
  return _ServicoPB.fromJson(json);
}

/// @nodoc
mixin _$ServicoPB {
  String get id => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Categoria? get categoria => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Grupo? get grupo => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  String? get descricao => throw _privateConstructorUsedError;
  @JsonKey(name: 'valor_base')
  double get valorBase => throw _privateConstructorUsedError;
  @JsonKey(name: 'valor_base_max')
  double? get valorBaseMax => throw _privateConstructorUsedError;
  @JsonKey(
    name: 'tipo_valor',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  TipoValor? get tipoValor => throw _privateConstructorUsedError;
  @JsonKey(name: 'tempo_medio_min')
  double? get tempoMedioMin => throw _privateConstructorUsedError;
  @JsonKey(name: 'tempo_medio_label')
  String? get tempoMedioLabel => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ServicoStatus? get status => throw _privateConstructorUsedError;
  String? get observacao => throw _privateConstructorUsedError;
  @JsonKey(name: 'checklist_padrao')
  List<ChecklistTemplateItem> get checklistPadrao =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'orientacoes_pre')
  String? get orientacoesPre => throw _privateConstructorUsedError;
  @JsonKey(name: 'orientacoes_pos')
  String? get orientacoesPos => throw _privateConstructorUsedError;
  @JsonKey(name: 'adicionais_relacionados')
  List<String> get adicionaisRelacionados => throw _privateConstructorUsedError;

  /// 🔁 legado sincronizado = valor_base.
  @JsonKey(name: 'preco_base')
  double get precoBase => throw _privateConstructorUsedError;

  /// 🔁 legado sincronizado = (status === 'ativo').
  bool get ativo => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get updated => throw _privateConstructorUsedError;

  /// Serializes this ServicoPB to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ServicoPB
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServicoPBCopyWith<ServicoPB> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServicoPBCopyWith<$Res> {
  factory $ServicoPBCopyWith(ServicoPB value, $Res Function(ServicoPB) then) =
      _$ServicoPBCopyWithImpl<$Res, ServicoPB>;
  @useResult
  $Res call({
    String id,
    String slug,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    String nome,
    String? descricao,
    @JsonKey(name: 'valor_base') double valorBase,
    @JsonKey(name: 'valor_base_max') double? valorBaseMax,
    @JsonKey(
      name: 'tipo_valor',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    TipoValor? tipoValor,
    @JsonKey(name: 'tempo_medio_min') double? tempoMedioMin,
    @JsonKey(name: 'tempo_medio_label') String? tempoMedioLabel,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ServicoStatus? status,
    String? observacao,
    @JsonKey(name: 'checklist_padrao')
    List<ChecklistTemplateItem> checklistPadrao,
    @JsonKey(name: 'orientacoes_pre') String? orientacoesPre,
    @JsonKey(name: 'orientacoes_pos') String? orientacoesPos,
    @JsonKey(name: 'adicionais_relacionados')
    List<String> adicionaisRelacionados,
    @JsonKey(name: 'preco_base') double precoBase,
    bool ativo,
    String? created,
    String? updated,
  });
}

/// @nodoc
class _$ServicoPBCopyWithImpl<$Res, $Val extends ServicoPB>
    implements $ServicoPBCopyWith<$Res> {
  _$ServicoPBCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ServicoPB
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? categoria = freezed,
    Object? grupo = freezed,
    Object? nome = null,
    Object? descricao = freezed,
    Object? valorBase = null,
    Object? valorBaseMax = freezed,
    Object? tipoValor = freezed,
    Object? tempoMedioMin = freezed,
    Object? tempoMedioLabel = freezed,
    Object? status = freezed,
    Object? observacao = freezed,
    Object? checklistPadrao = null,
    Object? orientacoesPre = freezed,
    Object? orientacoesPos = freezed,
    Object? adicionaisRelacionados = null,
    Object? precoBase = null,
    Object? ativo = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String,
            categoria: freezed == categoria
                ? _value.categoria
                : categoria // ignore: cast_nullable_to_non_nullable
                      as Categoria?,
            grupo: freezed == grupo
                ? _value.grupo
                : grupo // ignore: cast_nullable_to_non_nullable
                      as Grupo?,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            descricao: freezed == descricao
                ? _value.descricao
                : descricao // ignore: cast_nullable_to_non_nullable
                      as String?,
            valorBase: null == valorBase
                ? _value.valorBase
                : valorBase // ignore: cast_nullable_to_non_nullable
                      as double,
            valorBaseMax: freezed == valorBaseMax
                ? _value.valorBaseMax
                : valorBaseMax // ignore: cast_nullable_to_non_nullable
                      as double?,
            tipoValor: freezed == tipoValor
                ? _value.tipoValor
                : tipoValor // ignore: cast_nullable_to_non_nullable
                      as TipoValor?,
            tempoMedioMin: freezed == tempoMedioMin
                ? _value.tempoMedioMin
                : tempoMedioMin // ignore: cast_nullable_to_non_nullable
                      as double?,
            tempoMedioLabel: freezed == tempoMedioLabel
                ? _value.tempoMedioLabel
                : tempoMedioLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ServicoStatus?,
            observacao: freezed == observacao
                ? _value.observacao
                : observacao // ignore: cast_nullable_to_non_nullable
                      as String?,
            checklistPadrao: null == checklistPadrao
                ? _value.checklistPadrao
                : checklistPadrao // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistTemplateItem>,
            orientacoesPre: freezed == orientacoesPre
                ? _value.orientacoesPre
                : orientacoesPre // ignore: cast_nullable_to_non_nullable
                      as String?,
            orientacoesPos: freezed == orientacoesPos
                ? _value.orientacoesPos
                : orientacoesPos // ignore: cast_nullable_to_non_nullable
                      as String?,
            adicionaisRelacionados: null == adicionaisRelacionados
                ? _value.adicionaisRelacionados
                : adicionaisRelacionados // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            precoBase: null == precoBase
                ? _value.precoBase
                : precoBase // ignore: cast_nullable_to_non_nullable
                      as double,
            ativo: null == ativo
                ? _value.ativo
                : ativo // ignore: cast_nullable_to_non_nullable
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
abstract class _$$ServicoPBImplCopyWith<$Res>
    implements $ServicoPBCopyWith<$Res> {
  factory _$$ServicoPBImplCopyWith(
    _$ServicoPBImpl value,
    $Res Function(_$ServicoPBImpl) then,
  ) = __$$ServicoPBImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String slug,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) Grupo? grupo,
    String nome,
    String? descricao,
    @JsonKey(name: 'valor_base') double valorBase,
    @JsonKey(name: 'valor_base_max') double? valorBaseMax,
    @JsonKey(
      name: 'tipo_valor',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    TipoValor? tipoValor,
    @JsonKey(name: 'tempo_medio_min') double? tempoMedioMin,
    @JsonKey(name: 'tempo_medio_label') String? tempoMedioLabel,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ServicoStatus? status,
    String? observacao,
    @JsonKey(name: 'checklist_padrao')
    List<ChecklistTemplateItem> checklistPadrao,
    @JsonKey(name: 'orientacoes_pre') String? orientacoesPre,
    @JsonKey(name: 'orientacoes_pos') String? orientacoesPos,
    @JsonKey(name: 'adicionais_relacionados')
    List<String> adicionaisRelacionados,
    @JsonKey(name: 'preco_base') double precoBase,
    bool ativo,
    String? created,
    String? updated,
  });
}

/// @nodoc
class __$$ServicoPBImplCopyWithImpl<$Res>
    extends _$ServicoPBCopyWithImpl<$Res, _$ServicoPBImpl>
    implements _$$ServicoPBImplCopyWith<$Res> {
  __$$ServicoPBImplCopyWithImpl(
    _$ServicoPBImpl _value,
    $Res Function(_$ServicoPBImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ServicoPB
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? categoria = freezed,
    Object? grupo = freezed,
    Object? nome = null,
    Object? descricao = freezed,
    Object? valorBase = null,
    Object? valorBaseMax = freezed,
    Object? tipoValor = freezed,
    Object? tempoMedioMin = freezed,
    Object? tempoMedioLabel = freezed,
    Object? status = freezed,
    Object? observacao = freezed,
    Object? checklistPadrao = null,
    Object? orientacoesPre = freezed,
    Object? orientacoesPos = freezed,
    Object? adicionaisRelacionados = null,
    Object? precoBase = null,
    Object? ativo = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(
      _$ServicoPBImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String,
        categoria: freezed == categoria
            ? _value.categoria
            : categoria // ignore: cast_nullable_to_non_nullable
                  as Categoria?,
        grupo: freezed == grupo
            ? _value.grupo
            : grupo // ignore: cast_nullable_to_non_nullable
                  as Grupo?,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        descricao: freezed == descricao
            ? _value.descricao
            : descricao // ignore: cast_nullable_to_non_nullable
                  as String?,
        valorBase: null == valorBase
            ? _value.valorBase
            : valorBase // ignore: cast_nullable_to_non_nullable
                  as double,
        valorBaseMax: freezed == valorBaseMax
            ? _value.valorBaseMax
            : valorBaseMax // ignore: cast_nullable_to_non_nullable
                  as double?,
        tipoValor: freezed == tipoValor
            ? _value.tipoValor
            : tipoValor // ignore: cast_nullable_to_non_nullable
                  as TipoValor?,
        tempoMedioMin: freezed == tempoMedioMin
            ? _value.tempoMedioMin
            : tempoMedioMin // ignore: cast_nullable_to_non_nullable
                  as double?,
        tempoMedioLabel: freezed == tempoMedioLabel
            ? _value.tempoMedioLabel
            : tempoMedioLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ServicoStatus?,
        observacao: freezed == observacao
            ? _value.observacao
            : observacao // ignore: cast_nullable_to_non_nullable
                  as String?,
        checklistPadrao: null == checklistPadrao
            ? _value._checklistPadrao
            : checklistPadrao // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistTemplateItem>,
        orientacoesPre: freezed == orientacoesPre
            ? _value.orientacoesPre
            : orientacoesPre // ignore: cast_nullable_to_non_nullable
                  as String?,
        orientacoesPos: freezed == orientacoesPos
            ? _value.orientacoesPos
            : orientacoesPos // ignore: cast_nullable_to_non_nullable
                  as String?,
        adicionaisRelacionados: null == adicionaisRelacionados
            ? _value._adicionaisRelacionados
            : adicionaisRelacionados // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        precoBase: null == precoBase
            ? _value.precoBase
            : precoBase // ignore: cast_nullable_to_non_nullable
                  as double,
        ativo: null == ativo
            ? _value.ativo
            : ativo // ignore: cast_nullable_to_non_nullable
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
class _$ServicoPBImpl extends _ServicoPB {
  const _$ServicoPBImpl({
    required this.id,
    this.slug = '',
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    this.categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.grupo,
    this.nome = '',
    this.descricao,
    @JsonKey(name: 'valor_base') this.valorBase = 0,
    @JsonKey(name: 'valor_base_max') this.valorBaseMax,
    @JsonKey(
      name: 'tipo_valor',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    this.tipoValor,
    @JsonKey(name: 'tempo_medio_min') this.tempoMedioMin,
    @JsonKey(name: 'tempo_medio_label') this.tempoMedioLabel,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.status,
    this.observacao,
    @JsonKey(name: 'checklist_padrao')
    final List<ChecklistTemplateItem> checklistPadrao =
        const <ChecklistTemplateItem>[],
    @JsonKey(name: 'orientacoes_pre') this.orientacoesPre,
    @JsonKey(name: 'orientacoes_pos') this.orientacoesPos,
    @JsonKey(name: 'adicionais_relacionados')
    final List<String> adicionaisRelacionados = const <String>[],
    @JsonKey(name: 'preco_base') this.precoBase = 0,
    this.ativo = false,
    this.created,
    this.updated,
  }) : _checklistPadrao = checklistPadrao,
       _adicionaisRelacionados = adicionaisRelacionados,
       super._();

  factory _$ServicoPBImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServicoPBImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String slug;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final Categoria? categoria;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final Grupo? grupo;
  @override
  @JsonKey()
  final String nome;
  @override
  final String? descricao;
  @override
  @JsonKey(name: 'valor_base')
  final double valorBase;
  @override
  @JsonKey(name: 'valor_base_max')
  final double? valorBaseMax;
  @override
  @JsonKey(
    name: 'tipo_valor',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final TipoValor? tipoValor;
  @override
  @JsonKey(name: 'tempo_medio_min')
  final double? tempoMedioMin;
  @override
  @JsonKey(name: 'tempo_medio_label')
  final String? tempoMedioLabel;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final ServicoStatus? status;
  @override
  final String? observacao;
  final List<ChecklistTemplateItem> _checklistPadrao;
  @override
  @JsonKey(name: 'checklist_padrao')
  List<ChecklistTemplateItem> get checklistPadrao {
    if (_checklistPadrao is EqualUnmodifiableListView) return _checklistPadrao;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklistPadrao);
  }

  @override
  @JsonKey(name: 'orientacoes_pre')
  final String? orientacoesPre;
  @override
  @JsonKey(name: 'orientacoes_pos')
  final String? orientacoesPos;
  final List<String> _adicionaisRelacionados;
  @override
  @JsonKey(name: 'adicionais_relacionados')
  List<String> get adicionaisRelacionados {
    if (_adicionaisRelacionados is EqualUnmodifiableListView)
      return _adicionaisRelacionados;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_adicionaisRelacionados);
  }

  /// 🔁 legado sincronizado = valor_base.
  @override
  @JsonKey(name: 'preco_base')
  final double precoBase;

  /// 🔁 legado sincronizado = (status === 'ativo').
  @override
  @JsonKey()
  final bool ativo;
  @override
  final String? created;
  @override
  final String? updated;

  @override
  String toString() {
    return 'ServicoPB(id: $id, slug: $slug, categoria: $categoria, grupo: $grupo, nome: $nome, descricao: $descricao, valorBase: $valorBase, valorBaseMax: $valorBaseMax, tipoValor: $tipoValor, tempoMedioMin: $tempoMedioMin, tempoMedioLabel: $tempoMedioLabel, status: $status, observacao: $observacao, checklistPadrao: $checklistPadrao, orientacoesPre: $orientacoesPre, orientacoesPos: $orientacoesPos, adicionaisRelacionados: $adicionaisRelacionados, precoBase: $precoBase, ativo: $ativo, created: $created, updated: $updated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServicoPBImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.categoria, categoria) ||
                other.categoria == categoria) &&
            (identical(other.grupo, grupo) || other.grupo == grupo) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.descricao, descricao) ||
                other.descricao == descricao) &&
            (identical(other.valorBase, valorBase) ||
                other.valorBase == valorBase) &&
            (identical(other.valorBaseMax, valorBaseMax) ||
                other.valorBaseMax == valorBaseMax) &&
            (identical(other.tipoValor, tipoValor) ||
                other.tipoValor == tipoValor) &&
            (identical(other.tempoMedioMin, tempoMedioMin) ||
                other.tempoMedioMin == tempoMedioMin) &&
            (identical(other.tempoMedioLabel, tempoMedioLabel) ||
                other.tempoMedioLabel == tempoMedioLabel) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.observacao, observacao) ||
                other.observacao == observacao) &&
            const DeepCollectionEquality().equals(
              other._checklistPadrao,
              _checklistPadrao,
            ) &&
            (identical(other.orientacoesPre, orientacoesPre) ||
                other.orientacoesPre == orientacoesPre) &&
            (identical(other.orientacoesPos, orientacoesPos) ||
                other.orientacoesPos == orientacoesPos) &&
            const DeepCollectionEquality().equals(
              other._adicionaisRelacionados,
              _adicionaisRelacionados,
            ) &&
            (identical(other.precoBase, precoBase) ||
                other.precoBase == precoBase) &&
            (identical(other.ativo, ativo) || other.ativo == ativo) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    slug,
    categoria,
    grupo,
    nome,
    descricao,
    valorBase,
    valorBaseMax,
    tipoValor,
    tempoMedioMin,
    tempoMedioLabel,
    status,
    observacao,
    const DeepCollectionEquality().hash(_checklistPadrao),
    orientacoesPre,
    orientacoesPos,
    const DeepCollectionEquality().hash(_adicionaisRelacionados),
    precoBase,
    ativo,
    created,
    updated,
  ]);

  /// Create a copy of ServicoPB
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServicoPBImplCopyWith<_$ServicoPBImpl> get copyWith =>
      __$$ServicoPBImplCopyWithImpl<_$ServicoPBImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ServicoPBImplToJson(this);
  }
}

abstract class _ServicoPB extends ServicoPB {
  const factory _ServicoPB({
    required final String id,
    final String slug,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final Categoria? categoria,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final Grupo? grupo,
    final String nome,
    final String? descricao,
    @JsonKey(name: 'valor_base') final double valorBase,
    @JsonKey(name: 'valor_base_max') final double? valorBaseMax,
    @JsonKey(
      name: 'tipo_valor',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    final TipoValor? tipoValor,
    @JsonKey(name: 'tempo_medio_min') final double? tempoMedioMin,
    @JsonKey(name: 'tempo_medio_label') final String? tempoMedioLabel,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    final ServicoStatus? status,
    final String? observacao,
    @JsonKey(name: 'checklist_padrao')
    final List<ChecklistTemplateItem> checklistPadrao,
    @JsonKey(name: 'orientacoes_pre') final String? orientacoesPre,
    @JsonKey(name: 'orientacoes_pos') final String? orientacoesPos,
    @JsonKey(name: 'adicionais_relacionados')
    final List<String> adicionaisRelacionados,
    @JsonKey(name: 'preco_base') final double precoBase,
    final bool ativo,
    final String? created,
    final String? updated,
  }) = _$ServicoPBImpl;
  const _ServicoPB._() : super._();

  factory _ServicoPB.fromJson(Map<String, dynamic> json) =
      _$ServicoPBImpl.fromJson;

  @override
  String get id;
  @override
  String get slug;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Categoria? get categoria;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  Grupo? get grupo;
  @override
  String get nome;
  @override
  String? get descricao;
  @override
  @JsonKey(name: 'valor_base')
  double get valorBase;
  @override
  @JsonKey(name: 'valor_base_max')
  double? get valorBaseMax;
  @override
  @JsonKey(
    name: 'tipo_valor',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  TipoValor? get tipoValor;
  @override
  @JsonKey(name: 'tempo_medio_min')
  double? get tempoMedioMin;
  @override
  @JsonKey(name: 'tempo_medio_label')
  String? get tempoMedioLabel;
  @override
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ServicoStatus? get status;
  @override
  String? get observacao;
  @override
  @JsonKey(name: 'checklist_padrao')
  List<ChecklistTemplateItem> get checklistPadrao;
  @override
  @JsonKey(name: 'orientacoes_pre')
  String? get orientacoesPre;
  @override
  @JsonKey(name: 'orientacoes_pos')
  String? get orientacoesPos;
  @override
  @JsonKey(name: 'adicionais_relacionados')
  List<String> get adicionaisRelacionados;

  /// 🔁 legado sincronizado = valor_base.
  @override
  @JsonKey(name: 'preco_base')
  double get precoBase;

  /// 🔁 legado sincronizado = (status === 'ativo').
  @override
  bool get ativo;
  @override
  String? get created;
  @override
  String? get updated;

  /// Create a copy of ServicoPB
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServicoPBImplCopyWith<_$ServicoPBImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
