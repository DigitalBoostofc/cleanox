/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — rotas da vitrine (públicas + admin CMS).
 *
 * Público (sem auth):
 *   GET  /api/cleanos/vitrine/servicos
 *   GET  /api/cleanos/vitrine/servicos/{id}
 *   GET  /api/cleanos/vitrine/atuacao
 *   GET  /api/cleanos/vitrine/config
 *   GET  /api/cleanos/vitrine/midia
 *   GET  /api/cleanos/vitrine/order-bumps?servicos=id1,id2
 *   GET  /api/cleanos/vitrine/slots?servico=&data=
 *   POST /api/cleanos/vitrine/agendar
 *
 * Admin (auth admin|gerente — profissional bloqueado):
 *   GET/PUT /api/cleanos/vitrine/admin/config
 *   GET     /api/cleanos/vitrine/admin/servicos
 *   PATCH   /api/cleanos/vitrine/admin/servicos/{id}
 *   GET     /api/cleanos/vitrine/admin/order-bumps
 *   POST    /api/cleanos/vitrine/admin/order-bumps
 *   PUT     /api/cleanos/vitrine/admin/order-bumps/{id}
 *   DELETE  /api/cleanos/vitrine/admin/order-bumps/{id}
 *   GET     /api/cleanos/vitrine/admin/agendamentos
 *   GET     /api/cleanos/vitrine/admin/midia
 *
 * R9: require() DENTRO de cada handler (VM isolada).
 */

routerAdd("GET", "/api/cleanos/vitrine/servicos", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const ip = lib.clientIp(e);
    const rl = lib.rateLimit(ip, 60);
    if (rl) return e.json(429, { error: rl });
    return e.json(200, { items: lib.listarServicosPublicos(e.app) });
  } catch (err) {
    console.error("[vitrine] servicos: " + err);
    return e.json(500, { error: "Falha ao listar serviços" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/servicos/{id}", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const id = e.request.pathValue("id");
    const s = lib.getServicoPublico(e.app, id);
    if (!s) return e.json(404, { error: "Serviço não encontrado" });
    return e.json(200, s);
  } catch (err) {
    console.error("[vitrine] servico: " + err);
    return e.json(500, { error: "Falha ao carregar serviço" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/atuacao", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    return e.json(200, lib.getAtuacao(e.app));
  } catch (err) {
    console.error("[vitrine] atuacao: " + err);
    return e.json(500, { error: "Falha ao carregar área de atuação" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/slots", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const ip = lib.clientIp(e);
    const rl = lib.rateLimit(ip, 40);
    if (rl) return e.json(429, { error: rl });

    const q = e.requestInfo().query || {};
    const servico = String(q.servico || q.servico_id || "");
    const data = String(q.data || q.date || "").slice(0, 10);
    const duracao = Number(q.duracao || q.duracao_min || 0);
    // Aceita só data + duração (pacote multi-item) ou servico+data
    if (!/^\d{4}-\d{2}-\d{2}$/.test(data)) {
      return e.json(400, { error: "Parâmetro data (YYYY-MM-DD) obrigatório" });
    }
    if (!servico && !(duracao > 0)) {
      return e.json(400, {
        error: "Informe servico e/ou duracao (minutos do pacote)",
      });
    }
    const res = lib.slotsDoDia(e.app, servico, data, duracao > 0 ? duracao : 0);
    if (res.error) return e.json(res.status || 400, { error: res.error });
    return e.json(200, {
      data: res.data,
      servico: res.servico,
      slots: res.slots,
    });
  } catch (err) {
    console.error("[vitrine] slots: " + err);
    return e.json(500, { error: "Falha ao calcular horários" });
  }
});

routerAdd("POST", "/api/cleanos/vitrine/agendar", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const ip = lib.clientIp(e);
    const rl = lib.rateLimit(ip, 10);
    if (rl) return e.json(429, { error: rl });

    const body = e.requestInfo().body || {};
    const result = lib.agendar(e.app, body);
    return e.json(200, result);
  } catch (err) {
    const msg = String(err && err.message ? err.message : err);
    console.error("[vitrine] agendar: " + msg);
    const code =
      /inválid|obrigat|expir|preenchid|cidade|Horário|Rejeitado|Telefone|Nome/i.test(
        msg,
      )
        ? 400
        : 500;
    return e.json(code, { error: msg || "Falha ao agendar" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/config", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    return e.json(200, lib.getConfig(e.app));
  } catch (err) {
    console.error("[vitrine] config: " + err);
    return e.json(500, { error: "Falha ao carregar config" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/bootstrap", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const base = lib.requestBaseUrl(e);
    return e.json(200, lib.bootstrapPublico(e.app, base));
  } catch (err) {
    console.error("[vitrine] bootstrap: " + err);
    return e.json(500, { error: "Falha ao carregar vitrine" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/midia", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const base = lib.requestBaseUrl(e);
    return e.json(200, {
      items: lib.listarMidiaPublica(e.app, base, true),
    });
  } catch (err) {
    console.error("[vitrine] midia: " + err);
    return e.json(500, { error: "Falha ao carregar mídia" });
  }
});

routerAdd("GET", "/api/cleanos/vitrine/order-bumps", (e) => {
  try {
    const lib = require(`${__hooks}/vitrine_lib.js`);
    const ip = lib.clientIp(e);
    const rl = lib.rateLimit(ip, 60);
    if (rl) return e.json(429, { error: rl });
    const base = lib.requestBaseUrl(e);
    const q = e.requestInfo().query || {};
    const raw = String(q.servicos || q.ids || "");
    const ids = raw
      ? raw.split(",").map((s) => s.trim()).filter(Boolean)
      : [];
    if (!ids.length) {
      return e.json(200, { items: lib.listarBumpsRaw(e.app, true, base) });
    }
    return e.json(200, {
      items: lib.orderBumpsParaCarrinho(e.app, ids, base),
    });
  } catch (err) {
    const msg = String(err && err.message ? err.message : err);
    console.error("[vitrine] order-bumps: " + msg);
    return e.json(500, { error: msg || "Falha ao carregar ofertas" });
  }
});

// ─── Admin CMS ──────────────────────────────────────────────────────────────

routerAdd(
  "GET",
  "/api/cleanos/vitrine/admin/config",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      return e.json(200, lib.getConfig(e.app));
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin config get] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "PUT",
  "/api/cleanos/vitrine/admin/config",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      const body = e.requestInfo().body || {};
      return e.json(200, lib.saveConfig(e.app, body));
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin config put] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "GET",
  "/api/cleanos/vitrine/admin/servicos",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      return e.json(200, { items: lib.listarServicosAdmin(e.app) });
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin servicos] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "PATCH",
  "/api/cleanos/vitrine/admin/servicos/{id}",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      const id = e.request.pathValue("id");
      const body = e.requestInfo().body || {};
      return e.json(200, lib.setServicoVitrineFlags(e.app, id, body));
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin servico patch] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "GET",
  "/api/cleanos/vitrine/admin/order-bumps",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      return e.json(200, { items: lib.listarBumpsRaw(e.app, false) });
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin bumps list] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "POST",
  "/api/cleanos/vitrine/admin/order-bumps",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      const body = e.requestInfo().body || {};
      return e.json(200, lib.upsertBump(e.app, body, null));
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin bumps create] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "PUT",
  "/api/cleanos/vitrine/admin/order-bumps/{id}",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      const id = e.request.pathValue("id");
      const body = e.requestInfo().body || {};
      return e.json(200, lib.upsertBump(e.app, body, id));
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin bumps update] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "DELETE",
  "/api/cleanos/vitrine/admin/order-bumps/{id}",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      const id = e.request.pathValue("id");
      return e.json(200, lib.deleteBump(e.app, id));
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin bumps delete] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "GET",
  "/api/cleanos/vitrine/admin/agendamentos",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      const q = e.requestInfo().query || {};
      const limit = Number(q.limit || 30);
      return e.json(200, {
        items: lib.listarAgendamentosVitrine(e.app, limit),
      });
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin agendamentos] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

routerAdd(
  "GET",
  "/api/cleanos/vitrine/admin/midia",
  (e) => {
    try {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      lib.assertVitrineAdmin(e);
      // Admin vê todos (ativos e não) — reusa listagem pública + inactive
      let list = [];
      try {
        list = e.app.findRecordsByFilter("vitrine_midia", "", "ordem", 200, 0);
      } catch (_) {
        list = [];
      }
      const items = [];
      for (let i = 0; i < (list || []).length; i++) {
        const r = list[i];
        items.push({
          id: r.id,
          chave: String(r.get("chave") || ""),
          titulo: String(r.get("titulo") || ""),
          url_externa: String(r.get("url_externa") || ""),
          arquivo: String(r.get("arquivo") || ""),
          ordem: Number(r.get("ordem") || 0),
          ativo: r.get("ativo") !== false,
        });
      }
      return e.json(200, { items: items });
    } catch (err) {
      const lib = require(`${__hooks}/vitrine_lib.js`);
      const x = lib.adminHttpError(err);
      console.error("[vitrine admin midia admin] " + x.error);
      return e.json(x.status, { error: x.error });
    }
  },
  $apis.requireAuth(),
);

