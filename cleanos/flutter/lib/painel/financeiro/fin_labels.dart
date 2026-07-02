/// fin_labels.dart — Rótulos PT-BR + helpers de exibição do módulo Financeiro.
///
/// Porte de `web/src/lib/financeiro/labels.ts`. O texto/sinal vive aqui; a COR
/// (verde receita / vermelho despesa / tom do chip de status) é resolvida pela
/// UI a partir do [StatusTone] + do `CleanoxColors` (paleta `fin*`).
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';

/* ─────────────────────── rótulos de unions ─────────────────────── */

String tipoLancamentoLabel(TipoLancamento t) =>
    t == TipoLancamento.receita ? 'Receita' : 'Despesa';

String recorrenciaLabel(RecorrenciaTipo r) => switch (r) {
  RecorrenciaTipo.unica => 'Única',
  RecorrenciaTipo.fixa => 'Fixa',
  RecorrenciaTipo.recorrente => 'Recorrente',
  RecorrenciaTipo.parcelada => 'Parcelada',
};

String statusLancamentoLabel(LancamentoStatus s) => switch (s) {
  LancamentoStatus.pago => 'Pago',
  LancamentoStatus.pendente => 'Pendente',
  LancamentoStatus.previsto => 'Previsto',
  LancamentoStatus.emAtraso => 'Em atraso',
};

String origemLabel(OrigemLancamento o) =>
    o == OrigemLancamento.viaOs ? 'Via OS' : 'Manual';

String contaTipoLabel(ContaTipo t) => switch (t) {
  ContaTipo.carteira => 'Carteira',
  ContaTipo.banco => 'Banco',
  ContaTipo.cartao => 'Cartão',
  ContaTipo.caixa => 'Caixa',
};

IconData contaTipoIcon(ContaTipo t) => switch (t) {
  ContaTipo.carteira => Icons.account_balance_wallet_outlined,
  ContaTipo.banco => Icons.account_balance_outlined,
  ContaTipo.cartao => Icons.credit_card_outlined,
  ContaTipo.caixa => Icons.savings_outlined,
};

/* ─────────────────────── valor com sinal ─────────────────────── */

/// Valor COM sinal: receita → +valor, despesa → −valor.
double signedValue(FinLancamento l) =>
    l.tipo == TipoLancamento.receita ? l.valor : -l.valor;

/// Formata o valor JÁ com sinal explícito (+/−) em BRL. A COR é da UI.
/// Ex.: receita 300 → "+R\$ 300,00" · despesa 980 → "−R\$ 980,00".
String formatSigned(FinLancamento l) {
  final sinal = l.tipo == TipoLancamento.receita ? '+' : '−';
  return '$sinal${formatCurrency(l.valor)}';
}

/// Formata um total COM sinal a partir de um número (para `totalDia`, saldos).
String formatSignedValue(double v) {
  final sinal = v < 0 ? '−' : '+';
  return '$sinal${formatCurrency(v.abs())}';
}

/* ─────────────────────── tom semântico do status ─────────────────────── */

enum StatusTone { success, warning, info, error }

StatusTone statusTone(LancamentoStatus s) => switch (s) {
  LancamentoStatus.pago => StatusTone.success,
  LancamentoStatus.pendente => StatusTone.warning,
  LancamentoStatus.previsto => StatusTone.info,
  LancamentoStatus.emAtraso => StatusTone.error,
};

/// Cor do texto/realce de um tom (a partir da paleta de feedback do tema).
Color toneColor(CleanoxColors clx, StatusTone tone) => switch (tone) {
  StatusTone.success => clx.success,
  StatusTone.warning => clx.warning,
  StatusTone.info => clx.info,
  StatusTone.error => clx.error,
};

/// Fundo do chip de um tom.
Color toneBg(CleanoxColors clx, StatusTone tone) => switch (tone) {
  StatusTone.success => clx.successBg,
  StatusTone.warning => clx.warningBg,
  StatusTone.info => clx.infoBg,
  StatusTone.error => clx.errorBg,
};

/// Cor de um tipo de lançamento (receita=verde, despesa=vermelho).
Color tipoColor(CleanoxColors clx, TipoLancamento t) =>
    t == TipoLancamento.receita ? clx.finIncome : clx.finExpense;

/* ─────────────────────── ícones de categoria ─────────────────────── */

/// Escolhas de ícone de categoria (chave lógica → ícone Material). A chave é o
/// que se grava em `fin_categorias.icone` (compatível com nomes livres do web).
const Map<String, IconData> kFinCategoriaIcons = {
  'tag': Icons.sell_outlined,
  'cash': Icons.payments_outlined,
  'card': Icons.credit_card_outlined,
  'cart': Icons.shopping_cart_outlined,
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
  'tools': Icons.build_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'people': Icons.groups_outlined,
  'megaphone': Icons.campaign_outlined,
  'chart': Icons.insights_outlined,
  'gift': Icons.card_giftcard_outlined,
  'health': Icons.favorite_outline_rounded,
  'food': Icons.restaurant_outlined,
  'bolt': Icons.bolt_outlined,
};

/// Ícone de uma categoria a partir da chave gravada (fallback: etiqueta).
IconData finCategoriaIcon(String? key) =>
    kFinCategoriaIcons[key] ?? Icons.sell_outlined;

/// Chip de status pronto (label + cores do tom).
class StatusLancamentoChip extends StatelessWidget {
  const StatusLancamentoChip({
    super.key,
    required this.status,
    this.dense = false,
  });

  final LancamentoStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tone = statusTone(status);
    return ClxChip(
      label: statusLancamentoLabel(status),
      color: toneColor(clx, tone),
      background: toneBg(clx, tone),
      dense: dense,
    );
  }
}
