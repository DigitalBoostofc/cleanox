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

/// Periodicidade de uma série fixa/recorrente (campo `frequencia` no PB).
enum FrequenciaRecorrencia {
  @JsonValue('diario')
  diario,
  @JsonValue('semanal')
  semanal,
  @JsonValue('quinzenal')
  quinzenal,
  @JsonValue('mensal')
  mensal,
  @JsonValue('bimestral')
  bimestral,
  @JsonValue('trimestral')
  trimestral,
  @JsonValue('semestral')
  semestral,
  @JsonValue('anual')
  anual;

  String get wire => name;

  /// Rótulo singular (dropdown "é uma despesa fixa").
  String get labelSingular => switch (this) {
        diario => 'Diário',
        semanal => 'Semanal',
        quinzenal => 'Quinzenal',
        mensal => 'Mensal',
        bimestral => 'Bimestral',
        trimestral => 'Trimestral',
        semestral => 'Semestral',
        anual => 'Anual',
      };
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

/// Estado da regra de cobrança fixa (`fin_series.status`).
enum FinSerieStatus {
  @JsonValue('ativa')
  ativa,
  @JsonValue('pausada')
  pausada,
  @JsonValue('encerrada')
  encerrada;

  String get wire => name;

  String get label => switch (this) {
        FinSerieStatus.ativa => 'Ativa',
        FinSerieStatus.pausada => 'Pausada',
        FinSerieStatus.encerrada => 'Encerrada',
      };
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

  /// `parent_id` é um `TextField` (não `RelationField`, de propósito — ver a
  /// migration 14) e o PocketBase grava campo de texto vazio como `""`, nunca
  /// `null`. Toda categoria-RAIZ (a maioria) chega do servidor com
  /// `parent_id: ""`, mas o app inteiro decide "é raiz?" com
  /// `c.parentId == null` (Categorias, Relatórios, Contas a pagar/receber,
  /// formulários de categoria/lançamento) — sem essa normalização nenhuma
  /// categoria-raiz nunca bate nesse teste, e a árvore de Categorias fica
  /// permanentemente vazia mesmo com dezenas de categorias no banco.
  factory FinCategoria.fromRecord(RecordModel record) {
    final json = record.toJson();
    if (json['parent_id'] == '') json['parent_id'] = null;
    return FinCategoria.fromJson(json);
  }
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
    /// Periodicidade da série (só faz sentido em fixa/recorrente). Vazio no PB → mensal.
    @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
    FrequenciaRecorrencia? frequencia,
    /// ID da regra em `fin_series` ("" no PB → null). Liga ocorrências à série.
    @JsonKey(name: 'serie_id') String? serieId,
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
    /// Pin na lista de Transações (Financeiro v2). PB default false.
    @Default(false) bool favorito,
    @Default(<Anexo>[]) List<Anexo> anexos,
    String? created,
    String? updated,
  }) = _FinLancamento;

  const FinLancamento._();

  factory FinLancamento.fromJson(Map<String, dynamic> json) =>
      _$FinLancamentoFromJson(json);

  /// `subcategoria_id` é um `RelationField` OPCIONAL (migration 14) — o
  /// PocketBase grava relação vazia como `""`, nunca `null`. O form de edição
  /// usa `FinDropdown<String?>` com `items: [null, ...subs]`; se o valor
  /// chegar como `""` (não normalizado), ele não bate em nenhum item da
  /// lista e o assert do `DropdownButtonFormField` derruba a tela ao editar
  /// QUALQUER lançamento sem subcategoria — mesmo bug "" vs null do
  /// `parent_id` de `FinCategoria` (05e2388), aqui no boundary de Lançamento.
  factory FinLancamento.fromRecord(RecordModel record) {
    final json = record.toJson();
    if (json['subcategoria_id'] == '') json['subcategoria_id'] = null;
    // Select opcional: PB manda "" quando vazio → trata como null (default mensal na geração).
    if (json['frequencia'] == '') json['frequencia'] = null;
    if (json['serie_id'] == '') json['serie_id'] = null;
    // Bool pode vir 0/1 em alguns caminhos SQLite/export.
    json['favorito'] = json['favorito'] == true || json['favorito'] == 1;
    // anexos: lista ou ausente; nunca string.
    final anex = json['anexos'];
    if (anex is! List) json['anexos'] = <dynamic>[];
    final tags = json['tags'];
    if (tags is! List) json['tags'] = <dynamic>[];
    return FinLancamento.fromJson(json);
  }

  /// Frequência efetiva da série (mensal se não definida).
  FrequenciaRecorrencia get frequenciaEfetiva =>
      frequencia ?? FrequenciaRecorrencia.mensal;

  /// Valor COM sinal (receita +, despesa −).
  double get valorComSinal => tipo == TipoLancamento.receita ? valor : -valor;

  /// Pertence a uma regra fixa/recorrente/parcelada (série ou tipo de ciclo).
  bool get isDaSerie =>
      (serieId != null && serieId!.isNotEmpty) ||
      recorrencia == RecorrenciaTipo.fixa ||
      recorrencia == RecorrenciaTipo.recorrente ||
      recorrencia == RecorrenciaTipo.parcelada;

  /// Ciclo visual (ícone ⟳): fixa, recorrente ou parcelada N×.
  bool get isCiclico =>
      isDaSerie ||
      (parcelasTotal != null && parcelasTotal! >= 2);

  /// Rótulo curto da parcela, ex. `1/10`. Null se não for parcelada.
  String? get parcelaRotulo {
    if (recorrencia != RecorrenciaTipo.parcelada &&
        (parcelasTotal == null || parcelasTotal! < 2)) {
      return null;
    }
    final total = parcelasTotal;
    if (total == null || total < 1) return null;
    final atual = parcelaAtual ?? 1;
    return '$atual/$total';
  }
}

/* ---- Série (regra de despesa/receita fixa) ---- */
@freezed
class FinSerie with _$FinSerie {
  const factory FinSerie({
    required String id,
    @JsonKey(unknownEnumValue: TipoLancamento.despesa)
    @Default(TipoLancamento.despesa)
    TipoLancamento tipo,
    @Default('') String descricao,
    @JsonKey(name: 'categoria_id') @Default('') String categoriaId,
    @JsonKey(name: 'subcategoria_id') String? subcategoriaId,
    @Default(0) double valor,
    @JsonKey(name: 'conta_id') @Default('') String contaId,
    @JsonKey(unknownEnumValue: RecorrenciaTipo.fixa)
    @Default(RecorrenciaTipo.fixa)
    RecorrenciaTipo recorrencia,
    @JsonKey(unknownEnumValue: FrequenciaRecorrencia.mensal)
    FrequenciaRecorrencia? frequencia,
    @JsonKey(unknownEnumValue: FinSerieStatus.ativa)
    @Default(FinSerieStatus.ativa)
    FinSerieStatus status,
    @JsonKey(name: 'data_inicio') @Default('') String dataInicio,
    @JsonKey(name: 'data_fim') String? dataFim,
    /// Total de parcelas quando [recorrencia] == parcelada (mig ≥ 54).
    @JsonKey(name: 'parcelas_total') int? parcelasTotal,
    @JsonKey(name: 'forma_pagamento') String? formaPagamento,
    String? observacao,
    @Default(<String>[]) List<String> tags,
    String? created,
    String? updated,
  }) = _FinSerie;

  const FinSerie._();

  factory FinSerie.fromJson(Map<String, dynamic> json) =>
      _$FinSerieFromJson(json);

  factory FinSerie.fromRecord(RecordModel record) {
    final json = record.toJson();
    if (json['subcategoria_id'] == '') json['subcategoria_id'] = null;
    if (json['data_fim'] == '') json['data_fim'] = null;
    if (json['forma_pagamento'] == '') json['forma_pagamento'] = null;
    if (json['observacao'] == '') json['observacao'] = null;
    if (json['frequencia'] == '') json['frequencia'] = null;
    final tags = json['tags'];
    if (tags is! List) json['tags'] = <dynamic>[];
    return FinSerie.fromJson(json);
  }

  FrequenciaRecorrencia get frequenciaEfetiva =>
      frequencia ?? FrequenciaRecorrencia.mensal;

  bool get isParcelada => recorrencia == RecorrenciaTipo.parcelada;

  bool get isAtiva => status == FinSerieStatus.ativa;
  bool get isPausada => status == FinSerieStatus.pausada;
  bool get isEncerrada => status == FinSerieStatus.encerrada;
}

/* ---- Limite de gastos por categoria + mês ---- */
@freezed
class FinLimite with _$FinLimite {
  const factory FinLimite({
    required String id,
    @JsonKey(name: 'categoria_id') @Default('') String categoriaId,
    @Default(0) double limite,
    /// Mês civil do orçamento: 'YYYY-MM' (BRT). Vazio em legado pré-mig 30.
    @JsonKey(name: 'ano_mes') @Default('') String anoMes,
    String? created,
    String? updated,
  }) = _FinLimite;

  const FinLimite._();

  factory FinLimite.fromJson(Map<String, dynamic> json) =>
      _$FinLimiteFromJson(json);

  factory FinLimite.fromRecord(RecordModel record) =>
      FinLimite.fromJson(record.toJson());
}

/* ---- Objetivo de caixa (fin_objetivos) ---- */
@freezed
class FinObjetivo with _$FinObjetivo {
  const factory FinObjetivo({
    required String id,
    @Default('') String nome,
    @JsonKey(name: 'meta_valor') @Default(0) double metaValor,
    @JsonKey(name: 'valor_atual') @Default(0) double valorAtual,
    @JsonKey(name: 'data_limite') String? dataLimite,
    @Default(true) bool ativo,
    String? cor,
    String? icone,
    String? observacao,
    String? created,
    String? updated,
  }) = _FinObjetivo;

  const FinObjetivo._();

  factory FinObjetivo.fromJson(Map<String, dynamic> json) =>
      _$FinObjetivoFromJson(json);

  factory FinObjetivo.fromRecord(RecordModel record) {
    final json = record.toJson();
    if (json['data_limite'] == '') json['data_limite'] = null;
    if (json['ativo'] == null || json['ativo'] == '') json['ativo'] = true;
    json['valor_atual'] = json['valor_atual'] ?? 0;
    return FinObjetivo.fromJson(json);
  }

  /// Progresso 0..1 (clamp).
  double get progresso {
    if (metaValor <= 0) return 0;
    final p = valorAtual / metaValor;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }
}
