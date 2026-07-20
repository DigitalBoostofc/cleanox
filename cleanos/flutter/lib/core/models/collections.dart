/// collections.dart — Contrato CANÔNICO de coleções do PocketBase em Dart.
///
/// Porte 1:1 de `web/src/lib/collections.ts` (`COLLECTIONS`, `FIN_COLLECTIONS`)
/// e dos enums de domínio (Role, OSStatus, FormaPagamento, RepasseStatus).
/// ÚNICO ponto de verdade dos nomes de coleção e papéis no core Flutter.
///
/// Nenhuma feature redefine estes nomes/enums — todos consomem daqui.
library;

import 'package:json_annotation/json_annotation.dart';

/* ---- Nomes das coleções ---- */
class Collections {
  const Collections._();

  static const String users = 'users';
  static const String clientes = 'clientes';
  static const String servicos = 'servicos';
  static const String ordensServico = 'ordens_servico';
  static const String configAtuacao = 'config_atuacao';
  static const String disponibilidade = 'disponibilidade';
  static const String osEvidencias = 'os_evidencias';
  static const String profComissoes = 'prof_comissoes';
}

/* ---- Módulo Financeiro ---- */
class FinCollections {
  const FinCollections._();

  static const String contas = 'fin_contas';
  static const String categorias = 'fin_categorias';
  static const String lancamentos = 'fin_lancamentos';
  static const String limites = 'fin_limites';
  static const String profComissoes = 'prof_comissoes';
}

/* ---- Comissão do profissional ---- */
enum ComissaoTipo {
  @JsonValue('nenhuma')
  nenhuma,
  @JsonValue('percentual')
  percentual,
  @JsonValue('fixo')
  fixo,
  /// R$ fixo por dia civil BRT com ≥1 OS concluída (ex.: Hendrio).
  @JsonValue('diaria')
  diaria;

  String get wire => switch (this) {
    ComissaoTipo.nenhuma => 'nenhuma',
    ComissaoTipo.percentual => 'percentual',
    ComissaoTipo.fixo => 'fixo',
    ComissaoTipo.diaria => 'diaria',
  };

  String get label => switch (this) {
    ComissaoTipo.nenhuma => 'Sem comissão',
    ComissaoTipo.percentual => 'Percentual (%)',
    ComissaoTipo.fixo => 'Valor fixo (R\$ por OS)',
    ComissaoTipo.diaria => 'Diária (R\$ por dia trabalhado)',
  };

  /// Comissão configurada (percentual, fixo ou diária com valor > 0).
  bool get isAtiva =>
      this == ComissaoTipo.percentual ||
      this == ComissaoTipo.fixo ||
      this == ComissaoTipo.diaria;
}

/// Frequência de repasse ao profissional (config em Financeiro → Equipe).
enum PagamentoFrequencia {
  @JsonValue('diario')
  diario,
  @JsonValue('semanal')
  semanal,
  @JsonValue('quinzenal')
  quinzenal,
  @JsonValue('mensal')
  mensal;

  String get wire => switch (this) {
    PagamentoFrequencia.diario => 'diario',
    PagamentoFrequencia.semanal => 'semanal',
    PagamentoFrequencia.quinzenal => 'quinzenal',
    PagamentoFrequencia.mensal => 'mensal',
  };

  String get label => switch (this) {
    PagamentoFrequencia.diario => 'Diário',
    PagamentoFrequencia.semanal => 'Semanal',
    PagamentoFrequencia.quinzenal => 'Quinzenal',
    PagamentoFrequencia.mensal => 'Mensal',
  };
}

enum ComissaoStatus {
  @JsonValue('pendente')
  pendente,
  @JsonValue('paga')
  paga;

  String get wire => switch (this) {
    ComissaoStatus.pendente => 'pendente',
    ComissaoStatus.paga => 'paga',
  };

  String get label => switch (this) {
    ComissaoStatus.pendente => 'Pendente',
    ComissaoStatus.paga => 'Paga',
  };
}

/* ---- Papéis de usuário ---- */
enum Role {
  @JsonValue('admin')
  admin,
  @JsonValue('gerente')
  gerente,
  @JsonValue('profissional')
  profissional;

  /// Valor snake_case gravado no PocketBase.
  String get wire => switch (this) {
    Role.admin => 'admin',
    Role.gerente => 'gerente',
    Role.profissional => 'profissional',
  };

  /// Painel = admin/gerente (Flutter Web). Profissional = app Android.
  bool get isPainel => this == Role.admin || this == Role.gerente;
  bool get isProfissional => this == Role.profissional;
}

/* ---- Status da Ordem de Serviço ---- */
enum OSStatus {
  @JsonValue('agendada')
  agendada,
  @JsonValue('atribuida')
  atribuida,
  @JsonValue('em_andamento')
  emAndamento,
  @JsonValue('concluida')
  concluida,
  @JsonValue('cancelada')
  cancelada;

  String get wire => switch (this) {
    OSStatus.agendada => 'agendada',
    OSStatus.atribuida => 'atribuida',
    OSStatus.emAndamento => 'em_andamento',
    OSStatus.concluida => 'concluida',
    OSStatus.cancelada => 'cancelada',
  };

  String get label => switch (this) {
    OSStatus.agendada => 'Em agendamento',
    OSStatus.atribuida => 'Atribuída',
    OSStatus.emAndamento => 'Em andamento',
    OSStatus.concluida => 'Concluída',
    OSStatus.cancelada => 'Cancelada',
  };

  static const List<OSStatus> all = [
    OSStatus.agendada,
    OSStatus.atribuida,
    OSStatus.emAndamento,
    OSStatus.concluida,
    OSStatus.cancelada,
  ];

  static OSStatus fromWire(String value) => OSStatus.all.firstWhere(
    (s) => s.wire == value,
    orElse: () => OSStatus.agendada,
  );
}

/* ---- Formas de pagamento ---- */
enum FormaPagamento {
  @JsonValue('dinheiro')
  dinheiro,
  @JsonValue('debito')
  debito,
  @JsonValue('credito')
  credito,
  @JsonValue('pix')
  pix,
  @JsonValue('pix_maquininha')
  pixMaquininha,
  @JsonValue('outros')
  outros;

  String get wire => switch (this) {
    FormaPagamento.dinheiro => 'dinheiro',
    FormaPagamento.debito => 'debito',
    FormaPagamento.credito => 'credito',
    FormaPagamento.pix => 'pix',
    FormaPagamento.pixMaquininha => 'pix_maquininha',
    FormaPagamento.outros => 'outros',
  };

  String get label => switch (this) {
    FormaPagamento.dinheiro => 'Dinheiro em espécie',
    FormaPagamento.debito => 'Débito',
    FormaPagamento.credito => 'Crédito',
    FormaPagamento.pix => 'Pix',
    FormaPagamento.pixMaquininha => 'Pix (maquininha)',
    FormaPagamento.outros => 'Outros',
  };

  /// Opções oferecidas ao registrar um pagamento NOVO.
  /// `pix_maquininha` fica de fora: é legado (OS antigas seguem exibindo o
  /// label normalmente, mas pagamentos novos usam o `pix` genérico).
  static const List<FormaPagamento> selecionaveis = [
    FormaPagamento.dinheiro,
    FormaPagamento.debito,
    FormaPagamento.credito,
    FormaPagamento.pix,
    FormaPagamento.outros,
  ];
}

/* ---- Status do repasse ---- */
enum RepasseStatus {
  @JsonValue('pendente')
  pendente,
  @JsonValue('pago')
  pago;

  String get wire => this == RepasseStatus.pago ? 'pago' : 'pendente';
  String get label => this == RepasseStatus.pago ? 'Repassado' : 'Pendente';
}
