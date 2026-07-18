/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — mapa do dia do profissional.
 *
 *   GET /api/cleanos/prof/mapa-hoje
 *
 * Lista as OS do profissional no dia BRT corrente (atribuída + em andamento)
 * com endereço, ordenadas por data_hora (sequência da agenda). Geocodifica
 * dest_lat/dest_lng se ainda faltarem (GOOGLE_MAPS_API_KEY; degrada sem chave).
 *
 * Resposta: { ok, dia, pins: [{ seq, osId, nome, hora, endereco, status, lat, lng }] }
 * Sem PII de telefone.
 */
routerAdd(
  "GET",
  "/api/cleanos/prof/mapa-hoje",
  (e) => {
    const lib = require(`${__hooks}/os_logic.js`);
    const maps = require(`${__hooks}/maps.js`);

    if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
    if (String(e.auth.get("role")) !== "profissional") {
      throw new ForbiddenError("Rota exclusiva para o papel profissional.");
    }
    const profId = String(e.auth.id);

    // Dia BRT corrente [start, end) em string UTC do PB.
    const nowBRT = new Date(Date.now() - 3 * 3600 * 1000);
    const y = nowBRT.getUTCFullYear();
    const m = nowBRT.getUTCMonth();
    const d = nowBRT.getUTCDate();
    // meia-noite BRT = 03:00 UTC
    const startUtc = new Date(Date.UTC(y, m, d, 3, 0, 0));
    const endUtc = new Date(Date.UTC(y, m, d + 1, 3, 0, 0));
    function fmtPb(dt) {
      const p = (n) => String(n).padStart(2, "0");
      return (
        dt.getUTCFullYear() +
        "-" +
        p(dt.getUTCMonth() + 1) +
        "-" +
        p(dt.getUTCDate()) +
        " " +
        p(dt.getUTCHours()) +
        ":" +
        p(dt.getUTCMinutes()) +
        ":" +
        p(dt.getUTCSeconds()) +
        ".000Z"
      );
    }
    const start = fmtPb(startUtc);
    const end = fmtPb(endUtc);
    const dia =
      y +
      "-" +
      String(m + 1).padStart(2, "0") +
      "-" +
      String(d).padStart(2, "0");

    const filter =
      'profissional = "' +
      profId.replace(/"/g, '\\"') +
      '" && data_hora >= "' +
      start +
      '" && data_hora < "' +
      end +
      '" && (status = "atribuida" || status = "em_andamento")';

    let rows = [];
    try {
      rows = $app.findRecordsByFilter(
        "ordens_servico",
        filter,
        "data_hora",
        50,
        0,
      );
    } catch (err) {
      console.error("[mapa-hoje] list: " + err);
      rows = [];
    }

    const pins = [];
    let seq = 0;
    for (let i = 0; i < rows.length; i++) {
      const os = rows[i];
      // Só dono (já filtrado por profissional=auth).
      if (lib.relId(os.get("profissional")) !== profId) continue;

      let endereco = String(os.get("endereco_liberado") || "").trim();
      if (!endereco) {
        // Fallback: monta do cofre se o hook ainda não liberou (defensivo).
        try {
          const cid = lib.relId(os.get("cliente"));
          if (cid) {
            const c = $app.findRecordById("clientes", cid);
            endereco = lib.buildEndereco(c);
            if (endereco) {
              os.set("endereco_liberado", endereco);
              $app.save(os);
            }
          }
        } catch (_) {}
      }
      if (!endereco) continue; // sem endereço → fora do mapa

      seq += 1;
      let lat = Number(os.get("dest_lat") || 0);
      let lng = Number(os.get("dest_lng") || 0);
      if (!lat || !lng) {
        const coord = maps.geocode(endereco);
        if (coord && coord.lat && coord.lng) {
          lat = coord.lat;
          lng = coord.lng;
          try {
            os.set("dest_lat", lat);
            os.set("dest_lng", lng);
            $app.save(os);
          } catch (errSave) {
            console.error("[mapa-hoje] save coords: " + errSave);
          }
        } else {
          lat = 0;
          lng = 0;
        }
      }

      const dataHora = String(os.get("data_hora") || "");
      // Hora BRT a partir do UTC gravado.
      let hora = "—";
      try {
        const brt = new Date(new Date(dataHora).getTime() - 3 * 3600 * 1000);
        const p = (n) => String(n).padStart(2, "0");
        hora = p(brt.getUTCHours()) + ":" + p(brt.getUTCMinutes());
      } catch (_) {}

      pins.push({
        seq: seq,
        osId: String(os.id),
        nome: String(os.get("nome_curto") || "—"),
        hora: hora,
        endereco: endereco,
        status: String(os.get("status") || ""),
        tipoServico: String(os.get("tipo_servico_nome") || ""),
        bairro: String(os.get("bairro") || ""),
        lat: lat || null,
        lng: lng || null,
      });
    }

    return e.json(200, { ok: true, dia: dia, pins: pins });
  },
  $apis.requireAuth(),
);

/**
 * GET /api/cleanos/os/{id}/rota
 *
 * Destino geocodificado da OS (para mapa in-app "Ver rota").
 * Profissional dono da OS ou admin/gerente.
 * Resposta: { ok, osId, nome, endereco, lat, lng, status, bairro, tipoServico }
 * Sem telefone.
 */
routerAdd(
  "GET",
  "/api/cleanos/os/{id}/rota",
  (e) => {
    const lib = require(`${__hooks}/os_logic.js`);
    const maps = require(`${__hooks}/maps.js`);

    if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
    const role = String(e.auth.get("role") || "");
    const authId = String(e.auth.id);
    const osId = String(e.request.pathValue("id") || "");
    if (!osId) throw new BadRequestError("OS inválida.");

    let os;
    try {
      os = $app.findRecordById("ordens_servico", osId);
    } catch (_) {
      throw new NotFoundError("OS não encontrada.");
    }

    const profId = lib.relId(os.get("profissional"));
    if (role === "profissional" && profId !== authId) {
      throw new ForbiddenError("Esta OS não é sua.");
    }
    if (role !== "profissional" && role !== "admin" && role !== "gerente") {
      throw new ForbiddenError("Sem permissão.");
    }

    let endereco = String(os.get("endereco_liberado") || "").trim();
    if (!endereco) {
      try {
        const cid = lib.relId(os.get("cliente"));
        if (cid) {
          const c = $app.findRecordById("clientes", cid);
          endereco = lib.buildEndereco(c);
          if (endereco && role !== "profissional") {
            // Admin/gerente: não grava endereco_liberado aqui.
          } else if (endereco) {
            os.set("endereco_liberado", endereco);
            $app.save(os);
          }
        }
      } catch (_) {}
    }
    if (!endereco) {
      throw new BadRequestError("Endereço indisponível para esta OS.");
    }

    let lat = Number(os.get("dest_lat") || 0);
    let lng = Number(os.get("dest_lng") || 0);
    if (!lat || !lng) {
      const coord = maps.geocode(endereco);
      if (coord && coord.lat && coord.lng) {
        lat = coord.lat;
        lng = coord.lng;
        try {
          os.set("dest_lat", lat);
          os.set("dest_lng", lng);
          $app.save(os);
        } catch (errSave) {
          console.error("[rota] save coords: " + errSave);
        }
      }
    }

    return e.json(200, {
      ok: true,
      osId: String(os.id),
      nome: String(os.get("nome_curto") || "—"),
      endereco: endereco,
      status: String(os.get("status") || ""),
      tipoServico: String(os.get("tipo_servico_nome") || ""),
      bairro: String(os.get("bairro") || ""),
      lat: lat || null,
      lng: lng || null,
    });
  },
  $apis.requireAuth(),
);
