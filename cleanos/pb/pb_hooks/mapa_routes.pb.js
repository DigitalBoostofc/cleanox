/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — mapa do dia do profissional + partida/deslocamento planejado.
 *
 *   GET  /api/cleanos/prof/mapa-hoje
 *   POST /api/cleanos/prof/deslocamento-dia/partida  { lat, lng }
 *   GET  /api/cleanos/os/{id}/rota
 *
 * R9: helpers via require() DENTRO de cada handler (VM isolada).
 * Sem PII de telefone. Degrada sem geocode/OSRM (nunca derruba a tela).
 */

routerAdd(
  "GET",
  "/api/cleanos/prof/mapa-hoje",
  (e) => {
    try {
      const lib = require(`${__hooks}/os_logic.js`);
      const maps = require(`${__hooks}/maps.js`);

      if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
      if (String(e.auth.get("role")) !== "profissional") {
        throw new ForbiddenError("Rota exclusiva para o papel profissional.");
      }
      const profId = String(e.auth.id);
      const bounds = maps.diaBrtHoje();
      const dia = bounds.dia;
      const esc = maps.escFilter;

      const filter =
        'profissional = "' +
        esc(profId) +
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
      for (let i = 0; i < rows.length; i++) {
        const os = rows[i];
        try {
          if (lib.relId(os.get("profissional")) !== profId) continue;

          let endereco = String(os.get("endereco_liberado") || "").trim();
          if (!endereco) {
            try {
              const cid = lib.relId(os.get("cliente"));
              if (cid) {
                const c = $app.findRecordById("clientes", cid);
                endereco = lib.buildEndereco(c);
              }
            } catch (_) {
              /* cofre/endereço indisponível */
            }
          }
          if (!endereco) continue;

          let lat = Number(os.get("dest_lat") || 0);
          let lng = Number(os.get("dest_lng") || 0);
          // Geocode best-effort. Só persiste coords em OS abertas (evita
          // side-effects de hooks em GET do mapa na concluída).
          if (!lat || !lng) {
            try {
              const coord = maps.geocode(endereco);
              if (coord && coord.lat && coord.lng) {
                lat = coord.lat;
                lng = coord.lng;
                const st = String(os.get("status") || "");
                if (st === "atribuida" || st === "em_andamento") {
                  try {
                    os.set("dest_lat", lat);
                    os.set("dest_lng", lng);
                    $app.save(os);
                  } catch (errSave) {
                    console.error("[mapa-hoje] save coords: " + errSave);
                  }
                }
              }
            } catch (errGeo) {
              console.error("[mapa-hoje] geocode: " + errGeo);
              lat = 0;
              lng = 0;
            }
          }

          const dataHora = String(os.get("data_hora") || "");
          let hora = "—";
          try {
            const brt = new Date(
              new Date(dataHora).getTime() - 3 * 3600 * 1000,
            );
            const p = (n) => String(n).padStart(2, "0");
            hora = p(brt.getUTCHours()) + ":" + p(brt.getUTCMinutes());
          } catch (_) {}

          pins.push({
            seq: pins.length + 1,
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
        } catch (errPin) {
          console.error("[mapa-hoje] pin: " + errPin);
        }
      }

      // Partida do dia — findRecords limit 1 (não throw se vazio).
      let partida = null;
      try {
        const recs = $app.findRecordsByFilter(
          "prof_deslocamento_dia",
          'profissional = "' +
            esc(profId) +
            '" && dia = "' +
            esc(dia) +
            '"',
          "",
          1,
          0,
        );
        if (recs && recs.length) {
          const rec = recs[0];
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
      } catch (errP) {
        console.error("[mapa-hoje] partida: " + errP);
      }

      // Circuito: partida → pins com coords → partida.
      let deslocamento = null;
      if (partida) {
        try {
          const points = [{ lat: partida.lat, lng: partida.lng }];
          for (let i = 0; i < pins.length; i++) {
            if (pins[i].lat && pins[i].lng) {
              points.push({ lat: pins[i].lat, lng: pins[i].lng });
            }
          }
          points.push({ lat: partida.lat, lng: partida.lng });
          if (points.length >= 3 && maps.routeCircuitKm) {
            const circuit = maps.routeCircuitKm(points);
            if (circuit) {
              deslocamento = {
                km: circuit.km,
                metros: circuit.metros,
                fonte: circuit.fonte,
                incluiRetorno: true,
              };
              try {
                const recs = $app.findRecordsByFilter(
                  "prof_deslocamento_dia",
                  'profissional = "' +
                    esc(profId) +
                    '" && dia = "' +
                    esc(dia) +
                    '"',
                  "",
                  1,
                  0,
                );
                if (recs && recs.length) {
                  recs[0].set("km_planejado", circuit.km);
                  $app.save(recs[0]);
                }
              } catch (_) {}
            }
          }
        } catch (errD) {
          console.error("[mapa-hoje] deslocamento: " + errD);
        }
      }

      return e.json(200, {
        ok: true,
        dia: dia,
        pins: pins,
        partida: partida,
        deslocamento: deslocamento,
      });
    } catch (err) {
      console.error("[mapa-hoje] FATAL: " + err);
      return e.json(200, {
        ok: true,
        dia: "",
        pins: [],
        partida: null,
        deslocamento: null,
        warning: String(err),
      });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "POST",
  "/api/cleanos/prof/deslocamento-dia/partida",
  (e) => {
    try {
      const maps = require(`${__hooks}/maps.js`);
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

      const bounds = maps.diaBrtHoje();
      const dia = bounds.dia;
      const esc = maps.escFilter;

      try {
        const recs = $app.findRecordsByFilter(
          "prof_deslocamento_dia",
          'profissional = "' +
            esc(profId) +
            '" && dia = "' +
            esc(dia) +
            '"',
          "",
          1,
          0,
        );
        if (recs && recs.length) {
          const existing = recs[0];
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
    } catch (err) {
      console.error("[partida] FATAL: " + err);
      if (err && err.status) throw err;
      throw new BadRequestError("Não foi possível registrar a partida.");
    }
  },
  $apis.requireAuth(),
);

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
            try {
              os.set("endereco_liberado", endereco);
              $app.save(os);
            } catch (_) {}
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
      try {
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
      } catch (errGeo) {
        console.error("[rota] geocode: " + errGeo);
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
