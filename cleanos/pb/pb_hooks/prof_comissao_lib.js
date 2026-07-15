/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — gera comissão do profissional ao concluir OS.
 *
 * Best-effort (nunca lança). Idempotente por os_id único em prof_comissoes.
 * Só cria se o profissional tiver comissao_tipo percentual|fixo e valor > 0.
 *
 * Chamado DEPOIS de e.next() (mesmo padrão de os_financeiro_lib.js).
 */

/**
 * "Agora" no fuso BRT (UTC-3), no formato que o PB grava.
 *
 * O processo do PocketBase roda em UTC na VPS. `new Date().toISOString()` puro
 * faz uma conclusão às 21:30 BRT gravar como 00:30 do DIA SEGUINTE — e os
 * relatórios bucketizam pela parte-data 'YYYY-MM-DD'.
 *
 * Preferir [dataParedeDaOs] (data_hora da OS) ao criar comissão/despesa —
 * "agora" só como fallback (sem data_hora / OS sumida).
 */
function dataBrtAgora() {
  var BRT_OFFSET_MS = 3 * 60 * 60 * 1000;
  return (
    new Date(Date.now() - BRT_OFFSET_MS)
      .toISOString()
      .replace("T", " ")
      .slice(0, 23) + "Z"
  );
}

/**
 * Parte-data parede BRT da OS (`data_hora`), igual à receita via_os.
 * Assim a comissão e a entrada da OS caem no MESMO dia em Movimentações.
 * Fallback: dia BRT de agora.
 */
function dataParedeDaOs(osRecord) {
  try {
    return require(`${__hooks}/os_financeiro_lib.js`).dataParedeBrtDaOs(
      osRecord,
    );
  } catch (_) {
    return String(dataBrtAgora()).slice(0, 10);
  }
}

/**
 * Ponto único OS → comissão (chamar DEPOIS de e.next()):
 *   - concluida → cria comissão (se configurada)
 *   - qualquer outro status → remove comissões da OS
 *     (pendente: delete; paga: apaga despesa + comissão)
 *
 * Assim OS reaberta (atribuida) ou cancelada não deixa comissão fantasma.
 */
function sincronizarComissaoOs(app, record, origStatus) {
  const status = String(record.get("status") || "");
  if (status === "concluida") {
    criarComissaoProfissional(app, record, origStatus);
    return;
  }
  removerComissoesDaOs(app, record.id);
}

/**
 * Remove todas as comissões ligadas à OS.
 * Pendente: delete direto.
 * Paga: apaga o lançamento de despesa (via lib) e a comissão.
 */
function removerComissoesDaOs(app, osId) {
  if (!osId) return;
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "os = {:id}",
      "",
      50,
      0,
      { id: osId },
    );
  } catch (_) {
    list = [];
  }
  if (!list || list.length === 0) return;

  const pagoLib = require(`${__hooks}/prof_comissao_pago_lib.js`);
  for (let i = 0; i < list.length; i++) {
    const rec = list[i];
    try {
      // Sempre remove a despesa (pendente ou paga) antes da comissão.
      try {
        pagoLib.apagarLancamentoDaComissao(app, rec.id);
      } catch (err) {
        console.error(
          "[comissao] remoção despesa falhou (segue delete): " + err,
        );
      }
      app.delete(rec);
      console.log(
        "[comissao] removida " +
          rec.id +
          " (OS " +
          osId +
          " não está concluída)",
      );
    } catch (err) {
      console.error("[comissao] falha ao remover " + rec.id + ": " + err);
    }
  }
}

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
  // Idempotente: se já concluída, não recria (anti-duplicata abaixo cobre).
  // Ainda assim, se a comissão foi apagada manualmente, permite recriar?
  // Mantém: só na transição para concluida (prev !== concluida).
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
  // F-225: nome DESNORMALIZADO. A relação `profissional` é opcional justamente
  // para o extrato sobreviver à exclusão do profissional — mas sem o nome em
  // texto o histórico ficaria anônimo ("comissão de R$60 pra ninguém").
  rec.set("profissional_nome", String(prof.get("name") || ""));
  rec.set("os", osId);
  rec.set("valor_os", valorPago);
  rec.set("valor_comissao", valorComissao);
  rec.set("tipo_aplicado", tipo);
  rec.set("base_valor", base);
  rec.set("status", "pendente");
  // Data = dia parede BRT da OS (data_hora), IGUAL à receita via_os.
  // NÃO usar "agora": backfill ou conclusão em lote colocaria todas as
  // comissões no mesmo dia (ex.: 15) e sumiria da sequência de cada OS.
  rec.set("data", dataParedeDaOs(record));

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

module.exports = {
  sincronizarComissaoOs,
  criarComissaoProfissional,
  removerComissoesDaOs,
  dataBrtAgora,
  dataParedeDaOs,
};
