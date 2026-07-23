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

import '../../core/formatters/formatters.dart' show kBrtOffset, parsePbUtc;
import '../../core/models/collections.dart';
import '../../core/models/financeiro.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../../profissional/financeiro/prof_estimativa.dart';
import '../../profissional/financeiro/prof_pagamento.dart';

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

/// Lançamento REALIZADO: status `pago`.
///
/// **Receita do mês** = só estes:
/// - `via_os` pago (OS **concluída** com pagamento — o hook promove previsto→pago)
/// - receita **manual** paga
///
/// Receita `previsto` de OS atribuída/em andamento **não** entra no mês
/// realizado (fica em contas a receber / KPI "Previstas").
bool isLancamentoRealizado(FinLancamento l) =>
    l.status == LancamentoStatus.pago;

/// Receita ainda não realizada (previsto/pendente/em atraso) — OS aberta ou
/// conta a receber manual.
bool isReceitaPrevista(FinLancamento l) =>
    l.tipo == TipoLancamento.receita &&
    l.status != LancamentoStatus.pago;

/// Σ receitas **pagas** / Σ despesas **pagas** / saldo do período.
///
/// Ignora previsto/pendente/em_atraso — em especial receita prevista de OS
/// ainda não concluída. Os lançamentos JÁ devem estar filtrados pelo período.
ResumoPeriodo resumoPeriodo(List<FinLancamento> lancs) {
  var entradas = 0, saidas = 0;
  for (final l in lancs) {
    if (!isLancamentoRealizado(l)) continue;
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

/// Balanço de **competência** do mês: Σ receitas − Σ despesas **independente
/// do status** (pago / pendente / previsto / em atraso).
///
/// Usado no Extrato ("Balanço mensal") — o dono quer ver o resultado do mês
/// incluindo OS ainda em aberto e comissões a pagar. Os lançamentos JÁ devem
/// estar filtrados pelo período.
ResumoPeriodo resumoPeriodoCompetencia(List<FinLancamento> lancs) {
  var entradas = 0, saidas = 0;
  for (final l in lancs) {
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

/// Σ receitas previstas (não pagas) do conjunto — OS atribuídas + a receber.
double totalReceitasPrevistas(List<FinLancamento> lancs) {
  var cents = 0;
  for (final l in lancs) {
    if (isReceitaPrevista(l)) cents += _cents(l.valor);
  }
  return _reais(cents);
}

/// Σ despesas ainda não pagas (contas a pagar manuais / em atraso).
double totalDespesasEmAberto(List<FinLancamento> lancs) {
  var cents = 0;
  for (final l in lancs) {
    if (l.tipo != TipoLancamento.despesa) continue;
    if (l.status == LancamentoStatus.pago) continue;
    cents += _cents(l.valor);
  }
  return _reais(cents);
}

/// Compromissos (ainda não são caixa) + projeção simples.
///
/// - [aReceber]: receitas previstas (OS futuras + a receber manual)
/// - [comissoesAPagar]: comissões pendentes da equipe
/// - [contasAPagar]: despesas em aberto (não comissão, se já nos lancs)
/// - [resultadoProjetado] = saldo realizado do mês + a receber − comissões − contas
class CompromissosResumo {
  const CompromissosResumo({
    required this.aReceber,
    required this.comissoesAPagar,
    required this.contasAPagar,
    required this.resultadoRealizado,
  });

  final double aReceber;
  final double comissoesAPagar;
  final double contasAPagar;
  final double resultadoRealizado;

  double get totalAPagar => comissoesAPagar + contasAPagar;

  /// Se tudo se confirmar: realizado + a receber − obrigações.
  double get resultadoProjetado =>
      resultadoRealizado + aReceber - totalAPagar;

  static const zero = CompromissosResumo(
    aReceber: 0,
    comissoesAPagar: 0,
    contasAPagar: 0,
    resultadoRealizado: 0,
  );
}

/// Monta [CompromissosResumo] a partir dos lançamentos do período + total de
/// comissões pendentes (vindas de `prof_comissoes`).
CompromissosResumo compromissosResumo({
  required List<FinLancamento> lancsPeriodo,
  required double comissoesPendentes,
  ResumoPeriodo? realizado,
}) {
  final r = realizado ?? resumoPeriodo(lancsPeriodo);
  return CompromissosResumo(
    aReceber: totalReceitasPrevistas(lancsPeriodo),
    comissoesAPagar: comissoesPendentes < 0 ? 0 : comissoesPendentes,
    contasAPagar: totalDespesasEmAberto(lancsPeriodo),
    resultadoRealizado: r.saldoMes,
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

/// Consolida receitas `via_os` do **mesmo os_id** em uma linha com o valor
/// **total da OS** (soma das linhas principal + extras).
///
/// Na movimentação/Transações o dono vê 1 entrada por OS (ex.: R$ 400), não
/// N linhas de R$ 200. Lançamentos manuais e comissão ficam 1:1.
///
/// Ordem de primeira aparição é preservada. Função PURA (testável).
List<FinLancamento> consolidarViaOsPorOs(List<FinLancamento> lancs) {
  if (lancs.isEmpty) return const [];

  final buckets = <String, List<FinLancamento>>{};
  final order = <String>[];
  for (final l in lancs) {
    final oid = (l.osId ?? '').trim();
    final viaOsMulti = !isLancamentoComissao(l) &&
        (l.origem == OrigemLancamento.viaOs || oid.isNotEmpty) &&
        oid.isNotEmpty;
    final key = viaOsMulti ? 'os:$oid' : 'one:${l.id}';
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = <FinLancamento>[];
    }
    buckets[key]!.add(l);
  }

  final out = <FinLancamento>[];
  for (final k in order) {
    final group = buckets[k]!;
    if (group.length == 1) {
      out.add(group.first);
      continue;
    }
    var cents = 0;
    final nomes = <String>[];
    for (final l in group) {
      cents += _cents(l.valor);
      final s = (l.servicoNome ?? '').trim();
      if (s.isNotEmpty && !nomes.contains(s)) nomes.add(s);
    }
    final first = group.first;
    final n = group.length;
    final servicoLabel = nomes.isEmpty
        ? '$n serviços'
        : (nomes.length == 1 ? nomes.first : nomes.join(' + '));
    var desc = first.descricao.trim();
    final mid = desc.indexOf(' · ');
    if (mid > 0) {
      desc = '${desc.substring(0, mid)} · $n serviços';
    } else if (desc.isNotEmpty) {
      desc = '$desc · $n serviços';
    } else {
      desc = 'OS · $n serviços';
    }
    out.add(
      first.copyWith(
        valor: _reais(cents),
        descricao: desc,
        servicoNome: servicoLabel,
      ),
    );
  }
  return out;
}

/// Agrupa por dia, do mais recente ao mais antigo.
///
/// `totalDia` = só lançamentos **realizados** (pago), com sinal. Itens
/// previstos continuam na lista do dia, mas **não** entram no total do dia
/// (regra: receita do mês = OS concluída + manual paga).
///
/// Por padrão consolida `via_os` multi-linha no **total da OS** ([consolidarViaOs]).
List<GrupoPorData> agruparPorData(
  List<FinLancamento> lancs, {
  bool consolidarViaOs = true,
}) {
  final fonte = consolidarViaOs ? consolidarViaOsPorOs(lancs) : lancs;
  final map = <String, List<FinLancamento>>{};
  for (final l in fonte) {
    (map[dateOnly(l.data)] ??= []).add(l);
  }
  final grupos = map.entries.map((e) {
    final cents = e.value.fold<int>(0, (s, l) {
      if (!isLancamentoRealizado(l)) return s;
      return s +
          (l.tipo == TipoLancamento.receita
              ? _cents(l.valor)
              : -_cents(l.valor));
    });
    return GrupoPorData(data: e.key, itens: e.value, totalDia: _reais(cents));
  }).toList();
  grupos.sort((a, b) => b.data.compareTo(a.data));
  return grupos;
}

/* ─────────────────────── saldo previsto final do dia ─────────────────────── */

/// Saldo (previsto) ao **final** de cada data 'YYYY-MM-DD'.
///
/// Partindo de [saldoAtual] (Σ contas, só caixa realizado):
/// - desfaz pagamentos **depois** do dia D
/// - soma lançamentos **em aberto** com data ≤ D (projeção)
///
/// Assim dias passados com tudo pago batem o saldo real daquele dia, e dias
/// futuros/pendentes mostram o caixa se os compromissos se confirmarem.
Map<String, double> saldoPrevistoPorDia({
  required double saldoAtual,
  required List<FinLancamento> lancs,
}) {
  final byDay = <String, List<FinLancamento>>{};
  for (final l in lancs) {
    (byDay[dateOnly(l.data)] ??= []).add(l);
  }
  final days = byDay.keys.toList()..sort(); // antigo → novo
  final out = <String, double>{};
  for (final day in days) {
    var cents = _cents(saldoAtual);
    for (final l in lancs) {
      final d = dateOnly(l.data);
      final signed = l.tipo == TipoLancamento.receita
          ? _cents(l.valor)
          : -_cents(l.valor);
      if (isLancamentoRealizado(l) && d.compareTo(day) > 0) {
        cents -= signed; // rebobina pagos após o dia
      } else if (!isLancamentoRealizado(l) && d.compareTo(day) <= 0) {
        cents += signed; // projeta abertos até o dia
      }
    }
    out[day] = _reais(cents);
  }
  return out;
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

/// Data de referência para atraso: vencimento se houver, senão data do lançamento.
String dataRefLancamento(FinLancamento l) {
  if (l.vencimento != null && l.vencimento!.isNotEmpty) {
    return dateOnly(l.vencimento!);
  }
  return dateOnly(l.data);
}

/// Não pago e a data de referência já passou de [hoje] ('YYYY-MM-DD').
/// Status `em_atraso` no PB também conta — UI pinta de vermelho.
bool isLancamentoAtrasado(FinLancamento l, String hoje) {
  if (l.status == LancamentoStatus.pago) return false;
  if (l.status == LancamentoStatus.emAtraso) return true;
  return dataRefLancamento(l).compareTo(dateOnly(hoje)) < 0;
}

ContaPendente _toPendente(FinLancamento l, String ref) {
  final hoje = dateOnly(ref);
  final venc = dataRefLancamento(l);
  return ContaPendente(
    lancamento: l,
    vencendoHoje: venc == hoje,
    emAtraso:
        l.status == LancamentoStatus.emAtraso || venc.compareTo(hoje) < 0,
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

/* ─────────────────────── comissões no relatório ─────────────────────── */

/// IDs da categoria canônica de comissão da equipe.
///
/// Preferência (igual ao hook `acharCategoriaComissao`):
///   1) Equipe → Profissionais
///   2) Equipe → Comissões/Comissão
///   3) só Equipe
class FinCatComissaoIds {
  const FinCatComissaoIds({required this.categoriaId, this.subcategoriaId});
  final String categoriaId;
  final String? subcategoriaId;
}

/// Resolve Equipe/Profissionais a partir do catálogo de categorias.
FinCatComissaoIds? finCategoriaComissaoIds(List<FinCategoria> cats) {
  final despesas = cats.where((c) => !c.arquivada && c.tipo == TipoLancamento.despesa);
  FinCategoria? equipe;
  for (final c in despesas) {
    if (c.parentId == null && c.nome.trim().toLowerCase() == 'equipe') {
      equipe = c;
      break;
    }
  }
  if (equipe != null) {
    FinCategoria? prof;
    FinCategoria? comiss;
    for (final c in despesas) {
      if (c.parentId != equipe.id) continue;
      final n = c.nome.trim().toLowerCase();
      if (n == 'profissionais') prof = c;
      if (n == 'comissões' || n == 'comissão' || n == 'comissoes' || n == 'comissao') {
        comiss = c;
      }
    }
    final sub = prof ?? comiss;
    return FinCatComissaoIds(
      categoriaId: equipe.id,
      subcategoriaId: sub?.id,
    );
  }
  // Fallback: sub "Profissionais" com qualquer parent.
  for (final c in despesas) {
    if (c.parentId != null && c.nome.trim().toLowerCase() == 'profissionais') {
      return FinCatComissaoIds(categoriaId: c.parentId!, subcategoriaId: c.id);
    }
  }
  return null;
}

/// Prefix de id sintético — não colide com ids PB e permite detectar no UI.
///
/// Formato: `comissao-previsto-prof-<profissionalId>` (1 linha por profissional).
const kFinComissaoPrevistoIdPrefix = 'comissao-previsto-';
const kFinComissaoPrevistoProfPrefix = '${kFinComissaoPrevistoIdPrefix}prof-';

/// Extrai o id do profissional de um id sintético de comissão agregada.
String? finComissaoPrevistoProfId(String lancamentoId) {
  if (!lancamentoId.startsWith(kFinComissaoPrevistoProfPrefix)) return null;
  final id = lancamentoId.substring(kFinComissaoPrevistoProfPrefix.length);
  return id.isEmpty ? null : id;
}

/// Comissão (linha sintética do ciclo ou repasse gerado ao pagar em Equipe).
/// Status pago/pendente depende de **Equipe / comissões**, não da movimentação.
bool isLancamentoComissao(FinLancamento l) {
  if (finComissaoPrevistoProfId(l.id) != null) return true;
  final obs = (l.observacao ?? '').trim();
  if (obs.startsWith('repasse_ciclo:')) return true;
  final d = l.descricao.trim().toLowerCase();
  if (d.startsWith('comissão ·') || d.startsWith('comissao ·')) return true;
  if (d.startsWith('comissão -') || d.startsWith('comissao -')) return true;
  if (d.startsWith('repasse comiss')) return true;
  return false;
}

/// Receita/despesa gerada por OS (`via_os` ou vínculo `os_id`).
/// Status pago depende da **própria OS** (conclusão/pagamento), não da lista.
bool isLancamentoViaOs(FinLancamento l) {
  if (l.origem == OrigemLancamento.viaOs) return true;
  final osId = (l.osId ?? '').trim();
  if (osId.isNotEmpty) return true;
  return false;
}

/// Não editar / não alternar pago↔pendente na movimentação.
bool isLancamentoDependenteExterno(FinLancamento l) =>
    isLancamentoComissao(l) || isLancamentoViaOs(l);

String _ymdFromDateTime(DateTime d) {
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p2(d.month)}-${p2(d.day)}';
}

/// Comissão prevista de OS **atribuídas / em andamento** (ainda não concluídas).
///
/// [ate]: se informado (data de parede BRT do próximo pagamento), só entram OS
/// com dia BRT `<= ate` (inclusivo). Caso contrário, todas as abertas do prof.
({double valor, int qtdOs}) comissaoPrevistaAtribuidas({
  required User prof,
  required List<OrdemServico> osAbertas,
  DateTime? ate,
}) {
  if (!prof.hasComissaoAtiva) return (valor: 0.0, qtdOs: 0);

  final limiteYmd = ate == null ? null : _ymdFromDateTime(ate);

  final minhas = <OrdemServico>[];
  for (final o in osAbertas) {
    if (o.profissional != prof.id) continue;
    if (o.status != OSStatus.atribuida && o.status != OSStatus.emAndamento) {
      continue;
    }
    if (limiteYmd != null) {
      final ymd = _ymdBrtOs(o.dataHora);
      if (ymd.isEmpty || ymd.compareTo(limiteYmd) > 0) continue;
    }
    minhas.add(o);
  }
  if (minhas.isEmpty) return (valor: 0.0, qtdOs: 0);

  if (prof.comissaoTipo == ComissaoTipo.diaria) {
    final dias = <String>{};
    for (final o in minhas) {
      final ymd = _ymdBrtOs(o.dataHora);
      if (ymd.isNotEmpty) dias.add(ymd);
    }
    final nDias = dias.isEmpty ? 1 : dias.length;
    final v = ((prof.comissaoValor * nDias) * 100).roundToDouble() / 100;
    return (valor: v, qtdOs: minhas.length);
  }

  var cents = 0;
  for (final o in minhas) {
    cents += (estimarComissaoOs(prof, o) * 100).round();
  }
  return (valor: cents / 100.0, qtdOs: minhas.length);
}

String _ymdBrtOs(String dataHora) {
  final utc = parsePbUtc(dataHora);
  if (utc == null) {
    return dataHora.length >= 10 ? dataHora.substring(0, 10) : '';
  }
  final brt = utc.subtract(kBrtOffset);
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${brt.year.toString().padLeft(4, '0')}-${p2(brt.month)}-${p2(brt.day)}';
}

/// Converte comissões **pendentes** (+ previsto de OS atribuídas) em **1 despesa
/// prevista por profissional** na data de **repasse configurada**.
///
/// - Valor = Σ comissões pendentes (OS concluídas) + estimado das OS abertas
/// - Descrição: `Comissão · João Pedro`
/// - Pagas não entram (viram repasse real no caixa ao marcar paga).
List<FinLancamento> finComissoesPendentesComoLancamentos({
  required List<ProfComissao> comissoes,
  required List<FinCategoria> categorias,
  List<User> profissionais = const [],
  Map<String, String> nomePorProfId = const {},
  /// Extra em centavos reais por profissional (OS atribuídas/em andamento).
  Map<String, double> previstoOsByProf = const {},
  String contaId = '',
  DateTime? now,
}) {
  final cat = finCategoriaComissaoIds(categorias);
  if (cat == null) return const [];

  final byProf = <String, List<ProfComissao>>{};
  for (final c in comissoes) {
    if (c.status != ComissaoStatus.pendente) continue;
    if (!(c.valorComissao > 0)) continue;
    final pid = c.profissional.trim();
    if (pid.isEmpty) continue;
    byProf.putIfAbsent(pid, () => []).add(c);
  }

  final allIds = <String>{...byProf.keys, ...previstoOsByProf.keys};
  if (allIds.isEmpty) return const [];

  final userById = {for (final u in profissionais) u.id: u};
  final clock = now ?? DateTime.now();
  final hoje = brtWallDate(clock);

  final out = <FinLancamento>[];
  for (final pid in allIds) {
    final itens = byProf[pid] ?? const <ProfComissao>[];
    var cents = 0;
    for (final c in itens) {
      cents += (c.valorComissao * 100).round();
    }
    final extra = previstoOsByProf[pid] ?? 0;
    cents += (extra * 100).round();
    if (cents <= 0) continue;
    final total = cents / 100.0;

    final user = userById[pid];
    final next = user != null ? proximaDataPagamento(user, now: clock) : null;
    final payDay = next ?? lastDayOfMonth(hoje.year, hoje.month);
    final ymd = _ymdFromDateTime(payDay);

    final profNome = (nomePorProfId[pid] ?? user?.displayName ?? '').trim();
    // "Comissão · Nome"
    final descricao =
        profNome.isEmpty ? 'Comissão' : 'Comissão · $profNome';

    out.add(
      FinLancamento(
        id: '$kFinComissaoPrevistoProfPrefix$pid',
        tipo: TipoLancamento.despesa,
        descricao: descricao,
        categoriaId: cat.categoriaId,
        subcategoriaId: cat.subcategoriaId,
        valor: total,
        contaId: contaId,
        data: ymd,
        vencimento: ymd,
        status: LancamentoStatus.previsto,
        origem: OrigemLancamento.manual,
        observacao: 'repasse_ciclo:$pid',
      ),
    );
  }

  out.sort((a, b) {
    final byDate = a.data.compareTo(b.data);
    if (byDate != 0) return byDate;
    return a.descricao.compareTo(b.descricao);
  });
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
