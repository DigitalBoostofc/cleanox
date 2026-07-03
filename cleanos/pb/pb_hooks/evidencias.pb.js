/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — dedupe idempotente na criação de evidências (os_evidencias).
 *
 * CONTRATO COM O APP (doc 09 / checklist): o app do profissional envia, no
 * multipart de criação de `os_evidencias`, um campo `idempotency_key` (uuid,
 * string). Se a resposta do POST se perde e o app refaz o retry, a MESMA
 * (os, idempotency_key) NÃO pode gerar uma evidência duplicada.
 *
 * ESTRATÉGIA (duas camadas, ambas ADITIVAS):
 *   1) Curto-circuito de request (este hook): ANTES de criar, se já existir uma
 *      evidência com a mesma (os, idempotency_key), responde 200 com o registro
 *      EXISTENTE e NÃO cria nada (nem processa o arquivo reenviado). É o caminho
 *      do retry sequencial — o app recebe sucesso idempotente, com o mesmo id.
 *   2) Índice único parcial (migration 18): backstop de banco para a corrida de
 *      2 POSTs concorrentes que passem os dois pelo check acima — o 2º viola o
 *      índice e é barrado (nenhuma duplicata é persistida).
 *
 * SEM `idempotency_key` (vazio) → comportamento atual TOTALMENTE inalterado:
 * segue o fluxo normal de create (várias fotos por OS continuam permitidas).
 *
 * Autorização: o curto-circuito só ocorre para quem PODE ver a evidência (mesma
 * regra COFRE de os_evidencias: admin/gerente, ou o profissional dono da OS).
 * Caller não-autorizado cai no fluxo padrão de create, que a createRule rejeita —
 * assim este hook nunca vira um oráculo de existência para terceiros.
 */
onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/os_logic.js`);

  const key = String(e.record.get("idempotency_key") || "").trim();
  if (!key) return e.next(); // sem chave → fluxo de create inalterado

  const osId = lib.relId(e.record.get("os"));
  if (!osId) return e.next(); // sem OS → deixa a validação padrão agir

  // Precisa estar autenticado; senão o fluxo padrão exige auth/rejeita.
  const auth = e.auth;
  if (!auth) return e.next();

  // Autorização espelhando a regra COFRE (admin/gerente ou dono da OS).
  const role = String(auth.get("role"));
  let autorizado = role === "admin" || role === "gerente";
  if (!autorizado) {
    try {
      const os = $app.findRecordById("ordens_servico", osId);
      autorizado = lib.relId(os.get("profissional")) === String(auth.id);
    } catch (_) {
      autorizado = false;
    }
  }
  if (!autorizado) return e.next(); // não é dono → createRule decide (rejeita)

  // Já existe evidência com a MESMA (os, idempotency_key)? → sucesso idempotente.
  let existente = null;
  try {
    existente = $app.findFirstRecordByFilter(
      "os_evidencias",
      "os = {:os} && idempotency_key = {:k}",
      { os: osId, k: key }
    );
  } catch (_) {
    existente = null; // não achou — segue para o create normal
  }

  if (existente) {
    // NÃO cria duplicado nem processa o arquivo reenviado: devolve o existente.
    return e.json(200, existente);
  }

  e.next();
}, "os_evidencias");
