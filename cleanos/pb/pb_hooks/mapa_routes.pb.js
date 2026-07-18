/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — mapa do dia do profissional + partida/deslocamento planejado.
 *
 *   GET  /api/cleanos/prof/mapa-hoje
 *   POST /api/cleanos/prof/deslocamento-dia/partida  { lat, lng }
 *   GET  /api/cleanos/os/{id}/rota
 *
 * mapa-hoje: OS do dia BRT (atribuída | em_andamento | concluída) com pins,
 * partida do 1º Em deslocamento e km planejado (partida → OS… → partida).
 * Sem PII de telefone.
 */

function diaBrtHoje() {
  const nowBRT = new Date(Date.now() - 3 * 3600 * 1000);
  const y = nowBRT.getUTCFullYear();
  const m = nowBRT.getUTCMonth();
  const d = nowBRT.getUTCDate();
  const dia =
    y +
    "-" +
    String(m + 1).padStart(2, "0") +
    "-" +
    String(d).padStart(2, "0");
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
  return { dia: dia, start: fmtPb(startUtc), end: fmtPb(endUtc) };
}

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
    const bounds = diaBrtHoje();
    const dia = bounds.dia;

    const filter =
      'profissional = "' +
      profId.replace(/"/g, '\\"') +
      '" && data_hora >= "' +
      bounds.start +
      '" && data_hora < "' +
      bounds.end +
      '" && (status = "atribuida" || status = "em_andamento" || status = "concluida")';

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
      if (lib.relId(os.get("profissional")) !== profId) continue;

      let endereco = String(os.get("endereco_liberado") || "").trim();
      if (!endereco) {
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
      if (!endereco) continue;

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

    // Partida do dia (1º Em deslocamento).
    let partida = null;
    try {
      const rec = $app.findFirstRecordByFilter(
        "prof_deslocamento_dia",
        'profissional = "' +
          profId.replace(/"/g, '\\"') +
          '" && dia = "' +
          dia +
          '"',
      );
      if (rec) {
        const plat = Number(rec.get("partida_lat") || 0);
        const plng = Number(rec.get("partida_lng") || 0);
        if (plat && plng) {
          partida = {
            lat: plat,
            lng: plng,
            em: String(rec.get("partida_em") || ""),
          };
        }
      }
    } catch (_) {
      /* sem partida ainda */
    }

    // Circuito: partida → pins com coords → partida.
    let deslocamento = null;
    if (partida) {
      const points = [{ lat: partida.lat, lng: partida.lng }];
      for (let i = 0; i < pins.length; i++) {
        if (pins[i].lat && pins[i].lng) {
          points.push({ lat: pins[i].lat, lng: pins[i].lng });
        }
      }
      points.push({ lat: partida.lat, lng: partida.lng });
      if (points.length >= 3) {
        const circuit = maps.routeCircuitKm(points);
        if (circuit) {
          deslocamento = {
            km: circuit.km,
            metros: circuit.metros,
            fonte: circuit.fonte,
            incluiRetorno: true,
          };
          // Cache best-effort.
          try {
            const rec = $app.findFirstRecordByFilter(
              "prof_deslocamento_dia",
              'profissional = "' +
                profId.replace(/"/g, '\\"') +
                '" && dia = "' +
                dia +
                '"',
            );
            if (rec) {
              rec.set("km_planejado", circuit.km);
              $app.save(rec);
            }
          } catch (_) {}
        }
      }
    }

    return e.json(200, {
      ok: true,
      dia: dia,
      pins: pins,
      partida: partida,
      deslocamento: deslocamento,
    });
  },
  $apis.requireAuth(),
);

/**
 * POST /api/cleanos/prof/deslocamento-dia/partida
 * Body: { lat, lng }
 * Idempotente: grava só no 1º Em deslocamento do dia BRT.
 */
routerAdd(
  "POST",
  "/api/cleanos/prof/deslocamento-dia/partida",
  (e) => {
    if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
    if (String(e.auth.get("role")) !== "profissional") {
      throw new ForbiddenError("Rota exclusiva para o papel profissional.");
    }
    const profId = String(e.auth.id);
    const body = e.requestInfo().body || {};
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    if (isNaN(lat) || isNaN(lng) || !lat || !lng) {
      throw new BadRequestError("Informe lat e lng válidos.");
    }
    if (Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      throw new BadRequestError("Coordenadas fora do intervalo.");
    }

    const bounds = diaBrtHoje();
    const dia = bounds.dia;

    try {
      const existing = $app.findFirstRecordByFilter(
        "prof_deslocamento_dia",
        'profissional = "' +
          profId.replace(/"/g, '\\"') +
          '" && dia = "' +
          dia +
          '"',
      );
      if (existing) {
        return e.json(200, {
          ok: true,
          already: true,
          dia: dia,
          partida: {
            lat: Number(existing.get("partida_lat")),
            lng: Number(existing.get("partida_lng")),
            em: String(existing.get("partida_em") || ""),
          },
        });
      }
    } catch (_) {
      /* create below */
    }

    const col = $app.findCollectionByNameOrId("prof_deslocamento_dia");
    const rec = new Record(col);
    const now =
      new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
    rec.set("profissional", profId);
    rec.set("dia", dia);
    rec.set("partida_lat", lat);
    rec.set("partida_lng", lng);
    rec.set("partida_em", now);
    $app.save(rec);

    return e.json(200, {
      ok: true,
      already: false,
      dia: dia,
      partida: { lat: lat, lng: lng, em: now },
    });
  },
  $apis.requireAuth(),
);

/**
 * GET /api/cleanos/os/{id}/rota
 *
 * Destino geocodificado da OS (para mapa in-app "Ver rota").
 * Profissional dono da OS ou admin/gerente.
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
          if (endereco && role === "profissional") {
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
