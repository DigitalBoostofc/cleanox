/// config_atuacao.dart — Porte de `ConfigAtuacao`/`ConfigAtuacaoCidade` de
/// `web/src/lib/collections.ts` (coleção `config_atuacao`, snake_case).
///
/// Singleton (admin/gerente): estado + lista de cidades de atuação. Consumido
/// pelo Painel (Fase 2 — config de área de atuação).
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'config_atuacao.freezed.dart';
part 'config_atuacao.g.dart';

@freezed
class ConfigAtuacaoCidade with _$ConfigAtuacaoCidade {
  const factory ConfigAtuacaoCidade({
    @Default('') String nome,
    @Default(false) bool principal,
    @Default(<String>[]) List<String> bairros,
  }) = _ConfigAtuacaoCidade;

  factory ConfigAtuacaoCidade.fromJson(Map<String, dynamic> json) =>
      _$ConfigAtuacaoCidadeFromJson(json);
}

@freezed
class ConfigAtuacao with _$ConfigAtuacao {
  const factory ConfigAtuacao({
    required String id,
    @Default('') String estado,
    @Default(<ConfigAtuacaoCidade>[]) List<ConfigAtuacaoCidade> cidades,
    String? created,
    String? updated,
  }) = _ConfigAtuacao;

  const ConfigAtuacao._();

  factory ConfigAtuacao.fromJson(Map<String, dynamic> json) =>
      _$ConfigAtuacaoFromJson(json);

  factory ConfigAtuacao.fromRecord(RecordModel record) =>
      ConfigAtuacao.fromJson(record.toJson());
}
