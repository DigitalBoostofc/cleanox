/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — lógica da integração OS → Financeiro (módulo CommonJS).
 *
 * Ciclo de vida do(s) lançamento(s) `via_os`:
 *   - atribuida | em_andamento → receitas status=previsto (1 por serviço)
 *   - concluida + valor_pago > 0 → promove/cria pago (credita saldo via fin_saldo)
 *   - cancelada | agendada → remove só previstos (não toca pago histórico)
 *
 * Multi-serviço (2026-07):
 *   Serviço principal (valor_servico + tipo_servico_nome / snapshot) + cada
 *   item cobrável de `adicionais` geram **lançamentos separados**, cada um
 *   com valor, servico_nome e categoria (Automotivo/Residencial) próprios.
 *   Chave estável em observacao: `via_os_line:principal` | `via_os_line:add_<id>`.
 *
 * Best-effort: NUNCA lança — erros logados e engolidos pelo caller.
 */

var FORMA_MAP = {
  debito: "Débito",
  credito: "Crédito",
  pix_maquininha: "Pix",
  pix: "Pix",
  dinheiro: "Dinheiro em espécie",
  outros: "Outros",
};

var LINE_PREFIX = "via_os_line:";

/**
 * Ponto único chamado pelos hooks create/update DEPOIS de e.next().
 */
function sincronizarReceitaOs(app, record, origStatus) {
  const status = String(record.get("status") || "");
  if (status === "concluida") {
    criarLancamentoFinanceiro(app, record, origStatus);
    return;
  }
  if (status === "atribuida" || status === "em_andamento") {
    upsertReceitaPrevista(app, record);
    return;
  }
  if (status === "agendada" || status === "cancelada") {
    removeReceitaPrevista(app, record.id);
  }
}

/* ─────────────────────── previsto ─────────────────────── */

function upsertReceitaPrevista(app, record) {
  const osId = record.id;
  const linhas = _linhasReceitaOs(record, false);
  if (!linhas.length) {
    removeReceitaPrevista(app, osId);
    return;
  }
  _sincronizarLinhas(app, record, linhas, {
    status: "previsto",
    formaPagamento: "",
    permitirApagarPago: false,
  });
}

/**
 * Remove TODOS os via_os ainda previstos/pendentes/em_atraso da OS.
 * Não remove receita já paga.
 */
function removeReceitaPrevista(app, osId) {
  if (!osId) return;
  const list = _listViaOs(app, osId);
  for (var i = 0; i < list.length; i++) {
    const st = String(list[i].get("status") || "");
    if (st === "pago") continue;
    try {
      app.delete(list[i]);
      console.log(
        "[fin] Receita prevista removida — OS " +
          osId +
          " lanc=" +
          list[i].id,
      );
    } catch (err) {
      console.log(
        "[fin] falha ao remover previsto " + list[i].id + ": " + err,
      );
    }
  }
}

/* ─────────────────────── pago ─────────────────────── */

/**
 * OS já paga/concluída regravada: re-sincroniza linhas via_os (split multi-serviço).
 */
function atualizarReceitaPagaDaOs(app, record) {
  const osId = record.id;
  if (!osId) return;

  const valorPago = Number(record.get("valor_pago") || 0);
  if (!(valorPago > 0)) {
    console.log(
      "[fin] OS " + osId + " concluída regravada sem valor_pago > 0; skip.",
    );
    return;
  }

  const linhas = _linhasReceitaOs(record, true);
  if (!linhas.length) {
    console.log("[fin] OS " + osId + " sem linhas de receita; skip.");
    return;
  }

  const formaPagamento = _formaPagamentoDaOs(record);
  _sincronizarLinhas(app, record, linhas, {
    status: "pago",
    formaPagamento: formaPagamento,
    permitirApagarPago: false,
  });
}

/**
 * Cria/promove receitas pagas na transição → concluida.
 */
function criarLancamentoFinanceiro(app, record, origStatus) {
  const newStatus = String(record.get("status") || "");
  if (newStatus !== "concluida") return;

  let prevStatus;
  if (arguments.length >= 3) {
    prevStatus = String(origStatus || "");
  } else {
    const orig = record.original ? record.original() : null;
    prevStatus = orig ? String(orig.get("status") || "") : "";
  }
  if (prevStatus === "concluida") {
    atualizarReceitaPagaDaOs(app, record);
    return;
  }

  const valorPago = Number(record.get("valor_pago") || 0);
  if (!(valorPago > 0)) {
    console.log("[fin] OS concluída sem valor_pago > 0; lançamento não criado.");
    return;
  }

  const linhas = _linhasReceitaOs(record, true);
  if (!linhas.length) {
    console.log("[fin] OS concluída sem linhas de receita; skip.");
    return;
  }

  const formaPagamento = _formaPagamentoDaOs(record);
  _sincronizarLinhas(app, record, linhas, {
    status: "pago",
    formaPagamento: formaPagamento,
    permitirApagarPago: false,
  });
}

/* ─────────────────────── core multi-linha ─────────────────────── */

/**
 * Sincroniza lançamentos via_os da OS com a lista desejada de linhas.
 * @param {{status:string, formaPagamento:string, permitirApagarPago:boolean}} opts
 */
function _sincronizarLinhas(app, record, linhas, opts) {
  const osId = record.id;
  const base = _metaBase(app, record);
  if (!base) return;

  const status = opts.status || "previsto";
  const formaPagamento = opts.formaPagamento || "";
  const existentes = _listViaOs(app, osId);
  const byKey = _indexByLineKey(existentes);
  const desired = {};

  for (var i = 0; i < linhas.length; i++) {
    const line = linhas[i];
    desired[line.key] = true;
    const catId = _resolveCategoriaId(app, line.catNome);
    if (!catId) {
      console.log(
        "[fin] sem categoria para " +
          line.catNome +
          " (OS " +
          osId +
          " line " +
          line.key +
          "); skip linha.",
      );
      continue;
    }
    const desc =
      base.descricao +
      (line.servicoNome ? " · " + line.servicoNome : "");
    const obs = LINE_PREFIX + line.key;
    let rec = byKey[line.key];

    if (rec) {
      const st = String(rec.get("status") || "");
      // Não rebaixa pago → previsto.
      if (status !== "pago" && st === "pago") {
        console.log(
          "[fin] via_os pago " +
            rec.id +
            " (OS " +
            osId +
            " " +
            line.key +
            "); skip previsto.",
        );
        continue;
      }
      rec.set("tipo", "receita");
      rec.set("descricao", desc);
      rec.set("categoria_id", catId);
      rec.set("valor", line.valor);
      rec.set("conta_id", base.contaId);
      rec.set("data", base.dataParede);
      rec.set("status", status);
      rec.set("recorrencia", "unica");
      rec.set("origem", "via_os");
      rec.set("os_id", osId);
      rec.set("os_numero", base.osNumero);
      rec.set("cliente_nome", base.clienteNome);
      rec.set("servico_nome", line.servicoNome || "");
      rec.set("forma_pagamento", formaPagamento);
      rec.set("observacao", obs);
      app.save(rec);
      console.log(
        "[fin] via_os " +
          status +
          " atualizado — OS " +
          osId +
          " " +
          line.key +
          " R$ " +
          line.valor +
          " · " +
          (line.servicoNome || ""),
      );
    } else {
      const col = app.findCollectionByNameOrId("fin_lancamentos");
      const lanc = new Record(col);
      lanc.set("tipo", "receita");
      lanc.set("descricao", desc);
      lanc.set("categoria_id", catId);
      lanc.set("valor", line.valor);
      lanc.set("conta_id", base.contaId);
      lanc.set("data", base.dataParede);
      lanc.set("status", status);
      lanc.set("recorrencia", "unica");
      lanc.set("origem", "via_os");
      lanc.set("os_id", osId);
      lanc.set("os_numero", base.osNumero);
      lanc.set("cliente_nome", base.clienteNome);
      lanc.set("servico_nome", line.servicoNome || "");
      lanc.set("forma_pagamento", formaPagamento);
      lanc.set("observacao", obs);
      app.save(lanc);
      console.log(
        "[fin] via_os " +
          status +
          " criado — OS " +
          osId +
          " " +
          line.key +
          " R$ " +
          line.valor +
          " · " +
          (line.servicoNome || ""),
      );
    }
  }

  // Remove previstos órfãos (extras removidos da OS). Nunca apaga pago.
  for (var j = 0; j < existentes.length; j++) {
    const ex = existentes[j];
    const k = _lineKeyOf(ex);
    if (desired[k]) continue;
    const st = String(ex.get("status") || "");
    if (st === "pago") continue;
    try {
      app.delete(ex);
      console.log(
        "[fin] via_os previsto órfão removido — OS " +
          osId +
          " key=" +
          k +
          " id=" +
          ex.id,
      );
    } catch (_) {}
  }
}

/**
 * Monta linhas de receita da OS.
 * @param {boolean} pago — se true, alinha a soma ao valor_pago.
 * @returns {{key:string, valor:number, servicoNome:string, catNome:string}[]}
 */
function _linhasReceitaOs(record, pago) {
  const principal = Number(record.get("valor_servico") || 0);
  const descontosRaw = Number(record.get("descontos") || 0);
  var descontos = descontosRaw > 0 ? descontosRaw : 0;
  const servicoNome =
    (record.getString
      ? record.getString("tipo_servico_nome")
      : String(record.get("tipo_servico_nome") || "")) || "";

  const lines = [];
  var pValor = principal > 0 ? principal : 0;
  if (descontos > 0 && pValor > 0) {
    const d = Math.min(descontos, pValor);
    pValor = Math.round((pValor - d) * 100) / 100;
    descontos = Math.round((descontos - d) * 100) / 100;
  }

  // Principal sempre entra se > 0 (ou se não houver extras e for o único valor).
  if (pValor > 0) {
    lines.push({
      key: "principal",
      valor: pValor,
      servicoNome: servicoNome,
      catNome: _catNomeFromSnapshot(record),
    });
  }

  const adicionais = _parseAdicionais(record);
  for (var i = 0; i < adicionais.length; i++) {
    const a = adicionais[i];
    if (!_isAdicionalCobravel(a)) continue;
    var v = Number(a.valor || 0) * Number(a.quantidade || 1);
    if (!(v > 0)) continue;
    if (descontos > 0) {
      const d2 = Math.min(descontos, v);
      v = Math.round((v - d2) * 100) / 100;
      descontos = Math.round((descontos - d2) * 100) / 100;
    }
    if (!(v > 0)) continue;
    const addId = String(a.id || i);
    lines.push({
      key: "add_" + addId,
      valor: v,
      servicoNome: String(a.nome || "Serviço extra"),
      catNome: _catNomeFromCategoria(a.categoria),
    });
  }

  // Sem principal no orçamento mas com valor_pago (legado): 1 linha única.
  if (!lines.length && pago) {
    const valorPago = Number(record.get("valor_pago") || 0);
    if (valorPago > 0) {
      lines.push({
        key: "principal",
        valor: valorPago,
        servicoNome: servicoNome,
        catNome: _catNomeFromSnapshot(record),
      });
    }
  }

  if (pago) {
    const valorPago = Number(record.get("valor_pago") || 0);
    if (valorPago > 0) {
      _scaleLinhasToTotal(lines, valorPago);
    }
  }

  return lines.filter(function (l) {
    return l.valor > 0;
  });
}

/** Ajusta linhas para somar exatamente [total] (centavos). */
function _scaleLinhasToTotal(lines, total) {
  if (!lines.length) return;
  var sum = 0;
  for (var i = 0; i < lines.length; i++) sum += lines[i].valor;
  sum = Math.round(sum * 100) / 100;
  total = Math.round(total * 100) / 100;
  if (Math.abs(sum - total) < 0.009) return;
  if (!(sum > 0)) {
    lines[0].valor = total;
    return;
  }
  const factor = total / sum;
  var acc = 0;
  for (var j = 0; j < lines.length; j++) {
    if (j === lines.length - 1) {
      lines[j].valor = Math.round((total - acc) * 100) / 100;
    } else {
      const v = Math.round(lines[j].valor * factor * 100) / 100;
      lines[j].valor = v;
      acc += v;
    }
  }
}

function _parseAdicionais(record) {
  try {
    var raw = record.get("adicionais");
    if (raw == null || raw === "") return [];
    if (typeof raw === "string") {
      if (raw === "null" || raw === "[]") return raw === "[]" ? [] : [];
      raw = JSON.parse(raw);
    }
    // PB JSON field às vezes já vem como array/objeto
    if (Array.isArray(raw)) return raw;
    return [];
  } catch (_) {
    return [];
  }
}

function _isAdicionalCobravel(a) {
  if (!a) return false;
  const ap = String(a.aprovacao || "nao_requer");
  return ap === "aprovado" || ap === "nao_requer" || ap === "";
}

function _catNomeFromCategoria(cat) {
  const c = String(cat || "").toLowerCase();
  if (c === "residencial") return "Serviço Residencial";
  return "Serviço Automotivo";
}

function _catNomeFromSnapshot(record) {
  try {
    const snapStr = record.getString
      ? record.getString("service_snapshot")
      : String(record.get("service_snapshot") || "");
    if (snapStr && snapStr !== "null" && snapStr !== "") {
      const snap = JSON.parse(snapStr);
      if (
        snap &&
        String(snap.categoria || "").toLowerCase() === "residencial"
      ) {
        return "Serviço Residencial";
      }
    }
  } catch (_) {}
  return "Serviço Automotivo";
}

function _listViaOs(app, osId) {
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      "os_id = {:id} && origem = 'via_os'",
      "-created",
      50,
      0,
      { id: osId },
    );
    return list || [];
  } catch (_) {
    try {
      return [
        app.findFirstRecordByFilter(
          "fin_lancamentos",
          "os_id = {:id} && origem = 'via_os'",
          { id: osId },
        ),
      ];
    } catch (_) {
      return [];
    }
  }
}

function _lineKeyOf(lanc) {
  const obs = String(lanc.get("observacao") || "");
  if (obs.indexOf(LINE_PREFIX) === 0) {
    const k = obs.slice(LINE_PREFIX.length).trim();
    if (k) return k;
  }
  // Legado (1 via_os sem chave) = principal
  return "principal";
}

function _indexByLineKey(existentes) {
  const byKey = {};
  const extras = [];
  for (var i = 0; i < existentes.length; i++) {
    const ex = existentes[i];
    const obs = String(ex.get("observacao") || "");
    const hasKey = obs.indexOf(LINE_PREFIX) === 0;
    const k = _lineKeyOf(ex);
    if (!hasKey && byKey[k]) {
      // segundo legado sem chave — trata como órfão a limpar se previsto
      extras.push(ex);
      continue;
    }
    if (byKey[k]) {
      extras.push(ex);
      continue;
    }
    byKey[k] = ex;
  }
  // marca extras como keys únicas temporárias só para não sobrescrever
  for (var j = 0; j < extras.length; j++) {
    byKey["__orphan_" + extras[j].id] = extras[j];
  }
  return byKey;
}

function _formaPagamentoDaOs(record) {
  const formaRaw = record.getString
    ? record.getString("forma_pagamento")
    : String(record.get("forma_pagamento") || "");
  let formaPagamento = FORMA_MAP[formaRaw] || formaRaw;
  if (formaRaw === "outros") {
    const outro = record.getString
      ? record.getString("forma_pagamento_outro").trim()
      : String(record.get("forma_pagamento_outro") || "").trim();
    if (outro) formaPagamento = outro;
  }
  return formaPagamento || "";
}

/**
 * Conta + denorm comuns (sem categoria — cada linha resolve a sua).
 */
function _metaBase(app, record) {
  let contaId = null;
  try {
    const padrao = app.findRecordsByFilter(
      "fin_contas",
      "ativo = true && padrao = true",
      "nome",
      1,
      0,
      {},
    );
    if (padrao && padrao.length > 0) contaId = padrao[0].id;
  } catch (_) {}
  if (!contaId) {
    try {
      const contas = app.findRecordsByFilter(
        "fin_contas",
        "ativo = true",
        "nome",
        1,
        0,
        {},
      );
      if (contas && contas.length > 0) contaId = contas[0].id;
    } catch (_) {}
  }
  if (!contaId) {
    console.log(
      "[fin] Nenhuma conta ativa em fin_contas — lançamento da OS não criado.",
    );
    return null;
  }

  // Garante que existe pelo menos 1 categoria receita (sanity).
  if (!_resolveCategoriaId(app, "Serviço Automotivo") &&
      !_resolveCategoriaId(app, "Serviço Residencial")) {
    // tenta qualquer receita
    try {
      const cats = app.findRecordsByFilter(
        "fin_categorias",
        "tipo = 'receita' && arquivada = false",
        "nome",
        1,
        0,
        {},
      );
      if (!cats || cats.length === 0) {
        console.log(
          "[fin] Nenhuma categoria receita em fin_categorias; lançamento não criado.",
        );
        return null;
      }
    } catch (_) {
      console.log(
        "[fin] Nenhuma categoria receita em fin_categorias; lançamento não criado.",
      );
      return null;
    }
  }

  const clienteNome = record.getString
    ? record.getString("nome_curto") || ""
    : String(record.get("nome_curto") || "");
  const osId = record.id;
  const osNumero = String(osId).slice(-6).toUpperCase();
  const descricao =
    "OS " + osNumero + (clienteNome ? " - " + clienteNome : "");
  const dataParede = dataParedeBrtDaOs(record);

  return {
    contaId: contaId,
    clienteNome: clienteNome,
    osNumero: osNumero,
    descricao: descricao,
    dataParede: dataParede,
  };
}

/** @deprecated prefer _metaBase + _resolveCategoriaId; mantido p/ testes legados */
function _metaLancamento(app, record) {
  const base = _metaBase(app, record);
  if (!base) return null;
  const catNome = _catNomeFromSnapshot(record);
  const categoriaId = _resolveCategoriaId(app, catNome);
  if (!categoriaId) return null;
  const servicoNome = record.getString
    ? record.getString("tipo_servico_nome") || ""
    : String(record.get("tipo_servico_nome") || "");
  return {
    categoriaId: categoriaId,
    contaId: base.contaId,
    servicoNome: servicoNome,
    clienteNome: base.clienteNome,
    osNumero: base.osNumero,
    descricao: base.descricao,
    dataParede: base.dataParede,
  };
}

function _resolveCategoriaId(app, catNomeDesejado) {
  try {
    const cat = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'receita' && nome = {:n}",
      { n: catNomeDesejado },
    );
    return cat.id;
  } catch (_) {}
  try {
    const cats = app.findRecordsByFilter(
      "fin_categorias",
      "tipo = 'receita' && arquivada = false",
      "nome",
      1,
      0,
      {},
    );
    if (cats && cats.length > 0) return cats[0].id;
  } catch (_) {}
  return null;
}

/**
 * Parte-data parede BRT ('YYYY-MM-DD') da OS a partir de `data_hora` (UTC no PB).
 */
function dataParedeBrtDaOs(record) {
  var BRT_OFFSET_MS = 3 * 60 * 60 * 1000;
  var raw = "";
  try {
    raw =
      record && record.getString
        ? String(record.getString("data_hora") || "")
        : "";
  } catch (_) {
    raw = "";
  }
  if (raw) {
    try {
      var iso = raw.indexOf("T") >= 0 ? raw : raw.replace(" ", "T");
      if (!/[zZ]$|[+-]\d{2}:?\d{2}$/.test(iso)) iso += "Z";
      var d = new Date(iso);
      if (!isNaN(d.getTime())) {
        var brt = new Date(d.getTime() - BRT_OFFSET_MS);
        var y = brt.getUTCFullYear();
        var m = String(brt.getUTCMonth() + 1).padStart(2, "0");
        var day = String(brt.getUTCDate()).padStart(2, "0");
        return y + "-" + m + "-" + day;
      }
    } catch (_) {
      /* fallback abaixo */
    }
  }
  var agora = new Date(Date.now() - BRT_OFFSET_MS);
  var ay = agora.getUTCFullYear();
  var am = String(agora.getUTCMonth() + 1).padStart(2, "0");
  var ad = String(agora.getUTCDate()).padStart(2, "0");
  return ay + "-" + am + "-" + ad;
}

module.exports = {
  sincronizarReceitaOs,
  criarLancamentoFinanceiro,
  atualizarReceitaPagaDaOs,
  upsertReceitaPrevista,
  removeReceitaPrevista,
  dataParedeBrtDaOs,
  // helpers exportados p/ testes unitários
  _linhasReceitaOs: _linhasReceitaOs,
  _scaleLinhasToTotal: _scaleLinhasToTotal,
  _parseAdicionais: _parseAdicionais,
  _isAdicionalCobravel: _isAdicionalCobravel,
  _catNomeFromCategoria: _catNomeFromCategoria,
  LINE_PREFIX: LINE_PREFIX,
};
