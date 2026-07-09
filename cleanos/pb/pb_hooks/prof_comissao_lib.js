/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — gera comissão do profissional ao concluir OS.
 *
 * Best-effort (nunca lança). Idempotente por os_id único em prof_comissoes.
 * Só cria se o profissional tiver comissao_tipo percentual|fixo e valor > 0.
 *
 * Chamado DEPOIS de e.next() (mesmo padrão de os_financeiro_lib.js).
 */

function criarComissaoProfissional(app, record, origStatus) {
  const newStatus = String(record.get("status") || "");
  if (newStatus !== "concluida") return;

  let prevStatus;
  if (arguments.length >= 3) {
    prevStatus = String(origStatus || "");
  } else {
    const orig = record.original ? record.original() : null;
    prevStatus = orig ? String(orig.get("status") || "") : "";
  }
  if (prevStatus === "concluida") return;

  const valorPago = Number(record.get("valor_pago") || 0);
  if (!(valorPago > 0)) {
    console.log("[comissao] OS sem valor_pago > 0; skip.");
    return;
  }

  const profId = String(record.get("profissional") || "");
  if (!profId) {
    console.log("[comissao] OS sem profissional; skip.");
    return;
  }

  const osId = record.id;

  // Anti-duplicata (findFirst lança se não achar)
  try {
    app.findFirstRecordByFilter(
      "prof_comissoes",
      "os = '" + osId.replace(/'/g, "\\'") + "'",
    );
    console.log("[comissao] já existe para OS " + osId + "; skip.");
    return;
  } catch (_) {
    /* not found */
  }

  let prof;
  try {
    prof = app.findRecordById("users", profId);
  } catch (e) {
    console.log("[comissao] profissional não encontrado: " + profId);
    return;
  }

  const tipo = String(prof.get("comissao_tipo") || "nenhuma").toLowerCase();
  if (tipo !== "percentual" && tipo !== "fixo") {
    console.log("[comissao] prof " + profId + " sem comissão configurada.");
    return;
  }

  const base = Number(prof.get("comissao_valor") || 0);
  if (!(base > 0)) {
    console.log("[comissao] comissao_valor inválido; skip.");
    return;
  }

  let valorComissao = 0;
  if (tipo === "percentual") {
    valorComissao = Math.round(((valorPago * base) / 100) * 100) / 100;
  } else {
    valorComissao = Math.round(base * 100) / 100;
  }
  if (!(valorComissao > 0)) return;

  const col = app.findCollectionByNameOrId("prof_comissoes");
  const rec = new Record(col);
  rec.set("profissional", profId);
  rec.set("os", osId);
  rec.set("valor_os", valorPago);
  rec.set("valor_comissao", valorComissao);
  rec.set("tipo_aplicado", tipo);
  rec.set("base_valor", base);
  rec.set("status", "pendente");
  rec.set("data", new Date().toISOString());

  const nomeCurto = String(record.get("nome_curto") || "");
  const servico = String(record.get("tipo_servico_nome") || "");
  rec.set(
    "descricao",
    (servico || "OS") + (nomeCurto ? " · " + nomeCurto : ""),
  );

  try {
    app.save(rec);
    console.log(
      "[comissao] OS " +
        osId +
        " → R$ " +
        valorComissao +
        " (" +
        tipo +
        ") para " +
        profId,
    );
  } catch (e) {
    console.error("[comissao] falha ao salvar: " + e);
  }
}

module.exports = { criarComissaoProfissional };
