/// fin_derivations.dart — Derivações PURAS do módulo Financeiro (Painel).
///
/// Porte 1:1 das funções puras de `web/src/lib/financeiro/store.ts` (resumo do
/// período, saldo geral, agrupamento por data, contas a pagar/receber, gasto por
/// categoria, progresso de limite). Recebem dados por parâmetro e NÃO tocam a
/// rede — 100% testáveis.
///
/// ⚠️ DINHEIRO (F-220..F-223): o core tipa `valor`/`saldo` como `double`; para
/// evitar drift de ponto flutuante, TODA soma é feita em CENTAVOS inteiros
/// ([_cents]) e só então volta a reais. Nunca some `double` direto em laço.
///
/// ⚠️ FUSO BRT: o campo `data`/`vencimento` de um lançamento é uma data de
/// PAREDE ('YYYY-MM-DD', escolhida pelo usuário), sem hora nem fuso. Comparação e
/// exibição usam só os 10 primeiros chars ([dateOnly]) — NUNCA `parsePbUtc`/
/// `formatDate` do core (que aplicariam −3h e jogariam a data pro dia anterior).
library;

import '../../core/models/financeiro.dart';

/* ─────────────────────── dinheiro (centavos) ─────────────────────── */

/// Valor em centavos inteiros (evita erro de ponto flutuante nas somas).
int _cents(double reais) => (reais * 100).round();

/// Centavos → reais.
double _reais(int cents) => cents / 100.0;

/* ─────────────────────── datas de parede (sem fuso) ─────────────────────── */

/// Só a parte 'YYYY-MM-DD' de uma string ISO (date ou datetime). Espelha
/// `dateOnly` do store — comparação lexicográfica de datas ISO é segura.
String dateOnly(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

/// 'YYYY-MM-DD' → 'dd/MM/yyyy' (data de parede — SEM conta de fuso).
String formatDateOnlyBr(String iso) {
  final d = dateOnly(iso);
  if (d.length != 10) return d.isEmpty ? '—' : d;
  return '${d.substring(8, 10)}/${d.substring(5, 7)}/${d.substring(0, 4)}';
}

/* ─────────────────────── período (mês) ─────────────────────── */

/// Janela half-open [start, end) em datas 'YYYY-MM-DD'.
class Periodo {
  const Periodo(this.start, this.end);
  final String start;
  final String end;
}

String _p2(int n) => n.toString().padLeft(2, '0');

/// Período de um mês (1-based) como janela [start, end) em 'YYYY-MM-DD'.
/// Espelha `mesPeriodo` (que usa month 0-based; aqui é 1-based).
Periodo mesPeriodo(int year, int month) {
  final start = '$year-${_p2(month)}-01';
  final end = month == 12 ? '${year + 1}-01-01' : '$year-${_p2(month + 1)}-01';
  return Periodo(start, end);
}

/// Está dentro de [start, end) comparando só a data (ignora a hora)?
bool dentroDoPeriodo(FinLancamento l, Periodo p) {
  final d = dateOnly(l.data);
  return d.compareTo(dateOnly(p.start)) >= 0 &&
      d.compareTo(dateOnly(p.end)) < 0;
}

/// Filtra os lançamentos cujo `data` cai no período.
List<FinLancamento> lancamentosDoPeriodo(
  List<FinLancamento> lancs,
  Periodo p,
) => lancs.where((l) => dentroDoPeriodo(l, p)).toList();

/* ─────────────────────── resumo do período ─────────────────────── */

/// Totais REALIZADOS (status 'pago') de um conjunto de lançamentos.
class ResumoPeriodo {
  const ResumoPeriodo({
    required this.entradas,
    required this.saidas,
    required this.saldoMes,
  });
  final double entradas;
  final double saidas;
  final double saldoMes;

  static const zero = ResumoPeriodo(entradas: 0, saidas: 0, saldoMes: 0);
}

/// Σ receitas pagas / Σ despesas pagas / saldo do período (entradas − saídas).
/// Os lançamentos JÁ devem estar filtrados pelo período desejado.
ResumoPeriodo resumoPeriodo(List<FinLancamento> lancs) {
  var entradas = 0, saidas = 0;
  for (final l in lancs) {
    if (l.status != LancamentoStatus.pago) continue;
    if (l.tipo == TipoLancamento.receita) {
      entradas += _cents(l.valor);
    } else {
      saidas += _cents(l.valor);
    }
  }
  return ResumoPeriodo(
    entradas: _reais(entradas),
    saidas: _reais(saidas),
    saldoMes: _reais(entradas - saidas),
  );
}

/// Saldo geral = Σ `saldoAtual` das contas (some em centavos).
double saldoGeral(List<FinConta> contas) =>
    _reais(contas.fold<int>(0, (s, c) => s + _cents(c.saldoAtual)));

/* ─────────────────────── agrupamento por dia ─────────────────────── */

/// Grupo de lançamentos de um mesmo dia (estilo Organizze).
class GrupoPorData {
  const GrupoPorData({
    required this.data,
    required this.itens,
    required this.totalDia,
  });

  /// Data 'YYYY-MM-DD' do grupo.
  final String data;
  final List<FinLancamento> itens;

  /// Soma COM sinal (receitas − despesas) do dia.
  final double totalDia;
}

/// Agrupa por dia, do mais recente ao mais antigo. `totalDia` = soma com sinal.
List<GrupoPorData> agruparPorData(List<FinLancamento> lancs) {
  final map = <String, List<FinLancamento>>{};
  for (final l in lancs) {
    (map[dateOnly(l.data)] ??= []).add(l);
  }
  final grupos = map.entries.map((e) {
    final cents = e.value.fold<int>(
      0,
      (s, l) =>
          s +
          (l.tipo == TipoLancamento.receita
              ? _cents(l.valor)
              : -_cents(l.valor)),
    );
    return GrupoPorData(data: e.key, itens: e.value, totalDia: _reais(cents));
  }).toList();
  grupos.sort((a, b) => b.data.compareTo(a.data));
  return grupos;
}

/* ─────────────────────── contas a pagar/receber ─────────────────────── */

/// Um lançamento em aberto + flags derivadas vs. uma data de referência.
class ContaPendente {
  const ContaPendente({
    required this.lancamento,
    required this.vencendoHoje,
    required this.emAtraso,
  });
  final FinLancamento lancamento;
  final bool vencendoHoje;
  final bool emAtraso;
}

/// Em aberto = pendente | previsto | em_atraso.
bool emAberto(FinLancamento l) =>
    l.status == LancamentoStatus.pendente ||
    l.status == LancamentoStatus.previsto ||
    l.status == LancamentoStatus.emAtraso;

ContaPendente _toPendente(FinLancamento l, String ref) {
  final hoje = dateOnly(ref);
  final venc = (l.vencimento != null && l.vencimento!.isNotEmpty)
      ? dateOnly(l.vencimento!)
      : null;
  return ContaPendente(
    lancamento: l,
    vencendoHoje: venc == hoje,
    emAtraso:
        l.status == LancamentoStatus.emAtraso ||
        (venc != null && venc.compareTo(hoje) < 0),
  );
}

int _ordVenc(ContaPendente a, ContaPendente b) {
  final va = (a.lancamento.vencimento?.isNotEmpty ?? false)
      ? a.lancamento.vencimento!
      : a.lancamento.data;
  final vb = (b.lancamento.vencimento?.isNotEmpty ?? false)
      ? b.lancamento.vencimento!
      : b.lancamento.data;
  return va.compareTo(vb);
}

/// Despesas em aberto (contas a PAGAR), anotadas vs. `ref` e ordenadas por venc.
List<ContaPendente> contasAPagar(List<FinLancamento> lancs, String ref) {
  final out =
      lancs
          .where((l) => l.tipo == TipoLancamento.despesa && emAberto(l))
          .map((l) => _toPendente(l, ref))
          .toList()
        ..sort(_ordVenc);
  return out;
}

/// Receitas em aberto (contas a RECEBER).
List<ContaPendente> contasAReceber(List<FinLancamento> lancs, String ref) {
  final out =
      lancs
          .where((l) => l.tipo == TipoLancamento.receita && emAberto(l))
          .map((l) => _toPendente(l, ref))
          .toList()
        ..sort(_ordVenc);
  return out;
}

/* ─────────────────────── gasto / limites ─────────────────────── */

/// Total PAGO por `categoriaId` de um dado tipo (receita ou despesa).
Map<String, double> totalPagoPorCategoria(
  List<FinLancamento> lancs,
  TipoLancamento tipo,
) {
  final cents = <String, int>{};
  for (final l in lancs) {
    if (l.tipo != tipo || l.status != LancamentoStatus.pago) continue;
    cents[l.categoriaId] = (cents[l.categoriaId] ?? 0) + _cents(l.valor);
  }
  return cents.map((k, v) => MapEntry(k, _reais(v)));
}

/// Total de DESPESAS PAGAS por `categoriaId` (a categoria-mãe do lançamento).
Map<String, double> gastoPorCategoria(List<FinLancamento> lancs) =>
    totalPagoPorCategoria(lancs, TipoLancamento.despesa);

/// Progresso de um limite: quanto já foi gasto vs. o teto.
class ProgressoLimite {
  const ProgressoLimite({
    required this.gasto,
    required this.limite,
    required this.pct,
  });
  final double gasto;
  final double limite;

  /// gasto / limite, clampado em [0, 1]. 0 quando limite ≤ 0.
  final double pct;
}

/// Soma despesas pagas cuja categoria OU subcategoria casa com a do limite.
ProgressoLimite progressoLimite(FinLimite limite, List<FinLancamento> lancs) {
  var cents = 0;
  for (final l in lancs) {
    if (l.tipo != TipoLancamento.despesa || l.status != LancamentoStatus.pago) {
      continue;
    }
    if (l.categoriaId == limite.categoriaId ||
        l.subcategoriaId == limite.categoriaId) {
      cents += _cents(l.valor);
    }
  }
  final gasto = _reais(cents);
  final pct = limite.limite > 0 ? (gasto / limite.limite).clamp(0.0, 1.0) : 0.0;
  return ProgressoLimite(gasto: gasto, limite: limite.limite, pct: pct);
}

/* ─────────────────────── efeito de saldo (incremental) ─────────────────────── */

/// Efeito de um lançamento no `saldo_atual`: +valor p/ receita paga, −valor p/
/// despesa paga; 0 se não pago. Espelha `efeitoNoSaldo` do store. Usado pela
/// impl PB para manter o saldo consistente no CRUD manual (o hook OS→Financeiro
/// cuida do caminho `via_os` server-side — F-221).
double efeitoNoSaldo(
  TipoLancamento tipo,
  double valor,
  LancamentoStatus status,
) {
  if (status != LancamentoStatus.pago) return 0;
  return tipo == TipoLancamento.receita ? valor : -valor;
}
