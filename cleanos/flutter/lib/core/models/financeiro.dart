/// financeiro.dart — Porte do módulo Financeiro.
///
/// Fonte: `web/src/lib/financeiro/types.ts` (unions) + os shapes PB `FinContaPB`,
/// `FinCategoriaPB`, `FinLancamentoPB`, `FinLimitePB` de collections.ts (snake_case).
/// Só o Painel (admin/gerente) consome — a coleção é negada ao profissional.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'financeiro.freezed.dart';
part 'financeiro.g.dart';

/* ---- Unions de domínio ---- */

/// Natureza do lançamento. O SINAL do valor deriva daqui (receita=+, despesa=−).
enum TipoLancamento {
  @JsonValue('receita')
  receita,
  @JsonValue('despesa')
  despesa;

  String get wire => name;
}

enum RecorrenciaTipo {
  @JsonValue('unica')
  unica,
  @JsonValue('fixa')
  fixa,
  @JsonValue('recorrente')
  recorrente,
  @JsonValue('parcelada')
  parcelada;

  String get wire => name;
}

enum LancamentoStatus {
  @JsonValue('pago')
  pago,
  @JsonValue('pendente')
  pendente,
  @JsonValue('previsto')
  previsto,
  @JsonValue('em_atraso')
  emAtraso;

  String get wire => this == LancamentoStatus.emAtraso ? 'em_atraso' : name;
}

enum OrigemLancamento {
  @JsonValue('manual')
  manual,
  @JsonValue('via_os')
  viaOs;

  String get wire => this == OrigemLancamento.viaOs ? 'via_os' : 'manual';
}

enum ContaTipo {
  @JsonValue('carteira')
  carteira,
  @JsonValue('banco')
  banco,
  @JsonValue('cartao')
  cartao,
  @JsonValue('caixa')
  caixa;

  String get wire => name;
}

/* ---- Anexo (comprovante) ---- */
@freezed
class Anexo with _$Anexo {
  const factory Anexo({
    @Default('') String id,
    @Default('') String nome,
    @Default('') String url,
    int? tamanho,
  }) = _Anexo;

  factory Anexo.fromJson(Map<String, dynamic> json) => _$AnexoFromJson(json);
}

/* ---- Conta / Carteira ---- */
@freezed
class FinConta with _$FinConta {
  const factory FinConta({
    required String id,
    @Default('') String nome,
    @JsonKey(unknownEnumValue: ContaTipo.carteira)
    @Default(ContaTipo.carteira)
    ContaTipo tipo,
    @JsonKey(name: 'saldo_inicial') @Default(0) double saldoInicial,
    @JsonKey(name: 'saldo_atual') @Default(0) double saldoAtual,
    @Default(true) bool ativo,
    String? cor,
    String? icone,
    String? created,
    String? updated,
  }) = _FinConta;

  const FinConta._();

  factory FinConta.fromJson(Map<String, dynamic> json) =>
      _$FinContaFromJson(json);

  factory FinConta.fromRecord(RecordModel record) =>
      FinConta.fromJson(record.toJson());
}

/* ---- Categoria (subcategoria via parentId) ---- */
@freezed
class FinCategoria with _$FinCategoria {
  const factory FinCategoria({
    required String id,
    @Default('') String nome,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    @Default(TipoLancamento.despesa)
    TipoLancamento tipo,
    String? icone,
    String? cor,

    /// ID da categoria-mãe quando este registro é uma subcategoria.
    @JsonKey(name: 'parent_id') String? parentId,
    @Default(false) bool arquivada,
    String? created,
    String? updated,
  }) = _FinCategoria;

  const FinCategoria._();

  factory FinCategoria.fromJson(Map<String, dynamic> json) =>
      _$FinCategoriaFromJson(json);

  factory FinCategoria.fromRecord(RecordModel record) =>
      FinCategoria.fromJson(record.toJson());
}

/* ---- Lançamento (receita ou despesa) ---- */
@freezed
class FinLancamento with _$FinLancamento {
  const factory FinLancamento({
    required String id,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    @Default(TipoLancamento.despesa)
    TipoLancamento tipo,
    @Default('') String descricao,
    @JsonKey(name: 'categoria_id') @Default('') String categoriaId,
    @JsonKey(name: 'subcategoria_id') String? subcategoriaId,

    /// SEMPRE positivo. O sinal vem de `tipo`.
    @Default(0) double valor,
    @JsonKey(name: 'conta_id') @Default('') String contaId,
    @Default('') String data,
    String? vencimento,
    @JsonKey(unknownEnumValue: LancamentoStatus.pendente)
    @Default(LancamentoStatus.pendente)
    LancamentoStatus status,
    @JsonKey(unknownEnumValue: RecorrenciaTipo.unica)
    @Default(RecorrenciaTipo.unica)
    RecorrenciaTipo recorrencia,
    @JsonKey(name: 'parcela_atual') int? parcelaAtual,
    @JsonKey(name: 'parcelas_total') int? parcelasTotal,
    @JsonKey(unknownEnumValue: OrigemLancamento.manual)
    @Default(OrigemLancamento.manual)
    OrigemLancamento origem,
    @JsonKey(name: 'os_id') String? osId,
    @JsonKey(name: 'os_numero') String? osNumero,
    @JsonKey(name: 'cliente_nome') String? clienteNome,
    @JsonKey(name: 'servico_nome') String? servicoNome,
    @JsonKey(name: 'forma_pagamento') String? formaPagamento,
    String? observacao,
    @Default(<String>[]) List<String> tags,
    @Default(<Anexo>[]) List<Anexo> anexos,
    String? created,
    String? updated,
  }) = _FinLancamento;

  const FinLancamento._();

  factory FinLancamento.fromJson(Map<String, dynamic> json) =>
      _$FinLancamentoFromJson(json);

  factory FinLancamento.fromRecord(RecordModel record) =>
      FinLancamento.fromJson(record.toJson());

  /// Valor COM sinal (receita +, despesa −).
  double get valorComSinal => tipo == TipoLancamento.receita ? valor : -valor;
}

/* ---- Limite de gastos por categoria ---- */
@freezed
class FinLimite with _$FinLimite {
  const factory FinLimite({
    required String id,
    @JsonKey(name: 'categoria_id') @Default('') String categoriaId,
    @Default(0) double limite,
    String? created,
    String? updated,
  }) = _FinLimite;

  const FinLimite._();

  factory FinLimite.fromJson(Map<String, dynamic> json) =>
      _$FinLimiteFromJson(json);

  factory FinLimite.fromRecord(RecordModel record) =>
      FinLimite.fromJson(record.toJson());
}
