/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 10: torna PROTEGIDA a foto das evidências de OS.
 *
 * SA-ALTO (segurança): na Migration 8, o FileField `foto` de `os_evidencias` foi
 * criado SEM `protected`, deixando as imagens públicas (qualquer um com a URL
 * acessa). A Migration 8 já passou a criar o campo com `protected: true` para
 * bases NOVAS, mas o PocketBase NÃO re-executa uma migration já aplicada — então
 * bases existentes (dev/produção, onde a Migration 8 já rodou) continuariam com a
 * foto pública. Esta migration FORWARD conserta exatamente esse caso: vira a flag
 * `protected` do campo `foto` para `true` nas bases que já têm a coleção.
 *
 * IDEMPOTENTE: só salva se o campo existir e ainda não estiver protegido.
 * REVERSÍVEL: o DOWN volta a flag para `false` (re-expõe — só p/ rollback).
 *
 * Frontend correspondente (cleanos/web/src/lib/os/osStore.ts) passa a servir as
 * URLs com um file token (pb.files.getToken), pois arquivo protegido exige token.
 */
migrate(
  (app) => {
    let evid = null;
    try { evid = app.findCollectionByNameOrId("osevidenc000001"); } catch (_) { evid = null; }
    if (!evid) return; // coleção ainda não existe (base muito antiga) — nada a fazer

    const foto = evid.fields.getByName("foto");
    if (foto && foto.protected !== true) {
      foto.protected = true;
      app.save(evid);
    }
  },

  (app) => {
    let evid = null;
    try { evid = app.findCollectionByNameOrId("osevidenc000001"); } catch (_) { evid = null; }
    if (!evid) return;

    const foto = evid.fields.getByName("foto");
    if (foto && foto.protected !== false) {
      foto.protected = false;
      app.save(evid);
    }
  }
);
