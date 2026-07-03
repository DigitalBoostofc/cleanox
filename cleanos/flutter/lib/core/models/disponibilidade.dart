/// disponibilidade.dart — Porte de `Disponibilidade`/`DisponibilidadeDia` de
/// `web/src/lib/collections.ts` (coleção `disponibilidade`, snake_case).
///
/// Consumido pelo Painel (Fase 2 — agenda por profissional).
///
/// ⚠️ NÃO confundir com `DisponibilidadeDia` de core/formatters: aquele é um
/// helper de geração de slots 'HH:MM' (outro conceito). Este é o REGISTRO PB;
/// por isso o dia do registro chama-se `DisponibilidadeDiaPB`.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'disponibilidade.freezed.dart';
part 'disponibilidade.g.dart';

/// Config de um dia da semana no registro PB (0 = Dom … 6 = Sáb).
@freezed
class DisponibilidadeDiaPB with _$DisponibilidadeDiaPB {
  const factory DisponibilidadeDiaPB({
    @Default(false) bool ativo,

    /// 'HH:MM'
    @Default('') String inicio,

    /// 'HH:MM'
    @Default('') String fim,
  }) = _DisponibilidadeDiaPB;

  factory DisponibilidadeDiaPB.fromJson(Map<String, dynamic> json) =>
      _$DisponibilidadeDiaPBFromJson(json);
}

@freezed
class Disponibilidade with _$Disponibilidade {
  const factory Disponibilidade({
    required String id,

    /// Relation → users.
    @Default('') String profissional,
    @JsonKey(name: 'duracao_min') @Default(0) int duracaoMin,

    /// Array de 7 itens: índice 0 = Dom … 6 = Sáb.
    @Default(<DisponibilidadeDiaPB>[]) List<DisponibilidadeDiaPB> dias,
    String? created,
    String? updated,
  }) = _Disponibilidade;

  const Disponibilidade._();

  factory Disponibilidade.fromJson(Map<String, dynamic> json) =>
      _$DisponibilidadeFromJson(json);

  factory Disponibilidade.fromRecord(RecordModel record) =>
      Disponibilidade.fromJson(record.toJson());
}
