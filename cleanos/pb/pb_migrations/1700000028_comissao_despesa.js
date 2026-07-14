/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 28: comissão paga vira DESPESA de verdade (F-231) e o
 * extrato do profissional para de ser apagado quando ele é excluído (F-225).
 *
 * Contexto (QA E2E de 14/07/2026):
 *
 * F-231 — Marcar uma comissão como "paga" NÃO gerava despesa nem debitava saldo.
 * A comissão vivia num silo (`prof_comissoes`) que nunca tocava `fin_lancamentos`.
 * Consequência: o saldo das contas e os relatórios do painel ficavam INFLADOS
 * pelo total pago aos profissionais — o dono via dinheiro que já tinha saído.
 * Esta migration abre o caminho pro hook `prof_comissao_pago.pb.js`:
 *   - `fin_lancamentos.origem` passa a aceitar "via_comissao" (antes: manual|via_os);
 *   - `fin_lancamentos.comissao_id` liga o lançamento à comissão que o gerou, para
 *     que DESmarcar como paga saiba qual lançamento estornar.
 *
 * O link mora no LANÇAMENTO (e não um `lancamento_id` em prof_comissoes) de
 * propósito: o hook roda em `onRecordUpdate` de prof_comissoes, e gravar de volta
 * no próprio registro re-dispararia o hook (recursão).
 *
 * F-225 — `prof_comissoes.profissional` tinha `cascadeDelete: true`: excluir um
 * profissional APAGAVA todo o extrato de comissões dele, incluindo as já PAGAS.
 * Perda silenciosa de histórico financeiro. Agora é `false` — o histórico
 * sobrevive à exclusão de quem recebeu.
 *
 * ADITIVA e IDEMPOTENTE (segue a lição da migration 18/25: nunca `add()` cego).
 */

migrate(
  (app) => {
    // ── F-231.a: origem aceita "via_comissao" ────────────────────────────────
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    const origem = lanc.fields.getByName("origem");
    if (origem && Array.isArray(origem.values)) {
      if (origem.values.indexOf("via_comissao") === -1) {
        origem.values = origem.values.concat(["via_comissao"]);
      }
    }

    // ── F-231.b: link lançamento → comissão (para saber o que estornar) ──────
    let temComissaoId = false;
    try {
      temComissaoId = !!lanc.fields.getByName("comissao_id");
    } catch (_) {
      temComissaoId = false;
    }
    if (!temComissaoId) {
      lanc.fields.add(
        new TextField({ name: "comissao_id", required: false, max: 30 }),
      );
    }
    app.save(lanc);

    // ── F-225: excluir profissional NÃO apaga mais o extrato de comissões ────
    //
    // ⚠️ Só virar `cascadeDelete: false` NÃO basta — e é uma armadilha:
    // com a relação AINDA `required: true`, o PocketBase passa a RECUSAR a
    // exclusão do profissional enquanto existir qualquer comissão dele
    // (HTTP 400 "record is part of a required relation reference" — mesma
    // mecânica que o prof_delete_lib.js já documenta pra `disponibilidade`).
    // Isso trocaria perda de histórico por profissional impossível de excluir.
    //
    // Por isso a relação vira OPCIONAL e o nome do profissional é
    // DESNORMALIZADO em `profissional_nome`: ao excluir o profissional, o PB
    // apenas esvazia a relação, e o extrato financeiro continua existindo E
    // legível ("quem recebeu" preservado em texto).
    const com = app.findCollectionByNameOrId("prof_comissoes");
    let mudouCom = false;

    const prof = com.fields.getByName("profissional");
    if (prof) {
      if (prof.cascadeDelete === true) {
        prof.cascadeDelete = false;
        mudouCom = true;
      }
      if (prof.required === true) {
        prof.required = false;
        mudouCom = true;
      }
    }

    let temNome = false;
    try {
      temNome = !!com.fields.getByName("profissional_nome");
    } catch (_) {
      temNome = false;
    }
    if (!temNome) {
      com.fields.add(
        new TextField({ name: "profissional_nome", required: false, max: 120 }),
      );
      mudouCom = true;
    }

    if (mudouCom) app.save(com);

    // Backfill: comissões já existentes ganham o nome de quem recebeu, senão o
    // histórico antigo ficaria anônimo se o profissional fosse excluído depois.
    try {
      const antigas = app.findRecordsByFilter(
        "prof_comissoes",
        "profissional_nome = ''",
        "",
        500,
        0,
        {},
      );
      for (const c of antigas || []) {
        const pid = String(c.get("profissional") || "");
        if (!pid) continue;
        try {
          const p = app.findRecordById("users", pid);
          c.set("profissional_nome", String(p.get("name") || ""));
          app.save(c);
        } catch (_) {
          /* profissional já não existe — deixa vazio */
        }
      }
    } catch (_) {
      /* nenhuma comissão ainda */
    }
  },
  (app) => {
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    const origem = lanc.fields.getByName("origem");
    if (origem && Array.isArray(origem.values)) {
      origem.values = origem.values.filter((v) => v !== "via_comissao");
    }
    try {
      const f = lanc.fields.getByName("comissao_id");
      if (f) lanc.fields.removeById(f.id);
    } catch (_) {}
    app.save(lanc);

    const com = app.findCollectionByNameOrId("prof_comissoes");
    const prof = com.fields.getByName("profissional");
    if (prof) {
      prof.cascadeDelete = true;
      prof.required = true;
    }
    try {
      const f = com.fields.getByName("profissional_nome");
      if (f) com.fields.removeById(f.id);
    } catch (_) {}
    app.save(com);
  },
);
