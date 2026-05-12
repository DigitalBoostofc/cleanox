/* ============ Cleanox — vanilla JS interactivity ============ */
(function () {
  "use strict";

  /* ---------- SVG icons used by JS-rendered markup ---------- */
  const svg = {
    check: (size = 16) => `<svg width="${size}" height="${size}" viewBox="0 0 16 16" fill="none"><path d="M3 8.5L6.5 12L13 5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
    arrowRight: (size = 16) => `<svg width="${size}" height="${size}" viewBox="0 0 16 16" fill="none"><path d="M3 8h10m-4-4l4 4l-4 4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
    x: (size = 12) => `<svg width="${size}" height="${size}" viewBox="0 0 14 14" fill="none"><path d="M3 3l8 8m0-8l-8 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
    shield: () => `<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 1.5L3 3.5v4c0 3 2 5.5 5 6c3-.5 5-3 5-6v-4z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/><path d="M6 8l1.5 1.5L10.5 6.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
    download: () => `<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 2v8m-3-3l3 3l3-3M3 13h10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
    whatsapp: () => `<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M17.5 14.4c-.3-.1-1.7-.8-2-.9c-.3-.1-.5-.1-.7.1c-.2.3-.8.9-1 1.1c-.2.2-.4.2-.7.1c-.3-.1-1.3-.5-2.4-1.5c-.9-.8-1.5-1.8-1.7-2.1c-.2-.3 0-.5.1-.6c.1-.1.3-.3.4-.5c.1-.1.2-.3.3-.4c.1-.2.1-.4 0-.5c-.1-.1-.7-1.6-.9-2.2c-.3-.6-.5-.5-.7-.5h-.6c-.2 0-.5.1-.8.4c-.3.3-1.1 1-1.1 2.5c0 1.5 1.1 2.9 1.2 3.1c.1.2 2.1 3.2 5.1 4.5c.7.3 1.3.5 1.7.6c.7.2 1.4.2 1.9.1c.6-.1 1.7-.7 2-1.4c.2-.7.2-1.3.2-1.4c-.1-.1-.3-.2-.6-.4zM12 2C6.5 2 2 6.5 2 12c0 1.8.5 3.6 1.4 5.1L2 22l5-1.3c1.5.8 3.2 1.3 5 1.3c5.5 0 10-4.5 10-10S17.5 2 12 2z"/></svg>`,
    calendar: () => `<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><rect x="2.5" y="3.5" width="11" height="10" rx="1.5" stroke="currentColor" stroke-width="1.4"/><path d="M5 2v3M11 2v3M2.5 6.5h11" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>`,
    Seat: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M5 9c0-1.5 1-2.5 2.5-2.5h7c1.5 0 2.5 1 2.5 2.5v3H5z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M5 12v5h12v-5M7 17v2M15 17v2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
    Dashboard: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M3 13a8 8 0 0 1 16 0v3H3z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M11 13l3-3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><circle cx="11" cy="13" r="1.2" fill="currentColor"/></svg>`,
    Door: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><rect x="5" y="3" width="12" height="16" rx="1.5" stroke="currentColor" stroke-width="1.5"/><circle cx="14" cy="11" r="0.8" fill="currentColor"/></svg>`,
    Roof: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M3 13l8-7l8 7" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/><path d="M5 13v5h12v-5" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>`,
    Belt: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M5 4l12 14M5 8l8 10M5 12l4 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
    Sun: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><circle cx="11" cy="11" r="3.5" stroke="currentColor" stroke-width="1.5"/><path d="M11 3v2M11 17v2M3 11h2M17 11h2M5.5 5.5l1.4 1.4M15.1 15.1l1.4 1.4M5.5 16.5l1.4-1.4M15.1 6.9l1.4-1.4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
    Lining: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><rect x="4" y="4" width="14" height="14" rx="2" stroke="currentColor" stroke-width="1.5"/><path d="M4 9h14M4 14h14M9 4v14M14 4v14" stroke="currentColor" stroke-width="1" opacity="0.5"/></svg>`,
    Vacuum: () => `<svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M7 18a4 4 0 1 0 8 0a4 4 0 1 0-8 0z" stroke="currentColor" stroke-width="1.5"/><path d="M11 14V7l4-3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  };

  /* ---------- Helpers ---------- */
  const fmtBRL = (n) => "R$ " + n.toFixed(2).replace(".", ",");
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  /* ---------- Theme toggle ---------- */
  function initTheme() {
    const KEY = "cleanox-theme";
    const html = document.documentElement;
    const meta = document.getElementById("meta-theme-color");
    const btn = document.getElementById("theme-toggle");
    const apply = (theme) => {
      if (theme === "light") {
        html.setAttribute("data-theme", "light");
        meta?.setAttribute("content", "#FFFFFF");
      } else {
        html.removeAttribute("data-theme");
        meta?.setAttribute("content", "#0C0C0C");
      }
    };
    btn?.addEventListener("click", () => {
      const next = html.getAttribute("data-theme") === "light" ? "dark" : "light";
      apply(next);
      try { localStorage.setItem(KEY, next); } catch (e) {}
    });
  }

  /* ---------- Hero marquee ---------- */
  function initMarquee() {
    const track = $("#marquee-track");
    if (!track) return;
    const words = ["BANCOS", "TETO", "PAINEL", "PORTAS", "ASPIRAÇÃO", "CINTOS", "SOFÁ", "COLCHÃO", "QUEBRA-SÓIS", "FORROS"];
    const repeated = [...words, ...words, ...words];
    track.innerHTML = repeated
      .map((w, i) => `<span class="marquee-word ${i % 4 === 1 ? "solid" : "stroke"}">${w}</span>`)
      .join("");
  }

  /* ---------- Header scroll ---------- */
  function initHeader() {
    const header = $("#site-header");
    if (!header) return;
    const onScroll = () => header.classList.toggle("scrolled", window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ---------- Mobile menu ---------- */
  function initMobileMenu() {
    const toggle = $("#menu-toggle");
    const menu = $("#mobile-menu");
    if (!toggle || !menu) return;
    const close = () => {
      menu.classList.remove("open");
      toggle.setAttribute("aria-expanded", "false");
    };
    toggle.addEventListener("click", () => {
      const open = menu.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    $$("a", menu).forEach((a) => a.addEventListener("click", close));
  }

  /* ---------- Reveal-on-scroll ---------- */
  function initReveal() {
    const els = $$(".reveal, .reveal-stagger");
    if (!("IntersectionObserver" in window)) {
      els.forEach((el) => el.classList.add("in"));
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -60px 0px" }
    );
    els.forEach((el) => io.observe(el));
  }

  /* ---------- FAQ accordion ---------- */
  function initFAQ() {
    const items = $$(".faq-item");
    items.forEach((item) => {
      const trigger = $(".faq-trigger", item);
      if (!trigger) return;
      trigger.addEventListener("click", () => {
        const wasOpen = item.classList.contains("open");
        items.forEach((other) => {
          other.classList.remove("open");
          $(".faq-trigger", other)?.setAttribute("aria-expanded", "false");
        });
        if (!wasOpen) {
          item.classList.add("open");
          trigger.setAttribute("aria-expanded", "true");
        }
      });
    });
  }

  /* ---------- Before/After drag ---------- */
  function initBeforeAfter() {
    const wrap = $("#ba-wrap");
    if (!wrap) return;
    let dragging = false;
    const setFromX = (clientX) => {
      const rect = wrap.getBoundingClientRect();
      const p = Math.min(100, Math.max(0, ((clientX - rect.left) / rect.width) * 100));
      wrap.style.setProperty("--ba", p + "%");
    };
    const start = (e) => {
      dragging = true;
      const x = e.touches ? e.touches[0].clientX : e.clientX;
      setFromX(x);
    };
    const move = (e) => {
      if (!dragging) return;
      const x = e.touches ? e.touches[0].clientX : e.clientX;
      setFromX(x);
    };
    const stop = () => { dragging = false; };
    wrap.addEventListener("mousedown", start);
    wrap.addEventListener("touchstart", start, { passive: true });
    window.addEventListener("mousemove", move);
    window.addEventListener("touchmove", move, { passive: true });
    window.addEventListener("mouseup", stop);
    window.addEventListener("touchend", stop);
  }

  /* ---------- Quoter ---------- */
  const SERVICES = [
    { id: "bancos",    name: "Bancos",                    price: 100, icon: "Seat",      desc: "Limpeza profunda dos bancos para remover sujeiras, manchas superficiais, odores e resíduos acumulados." },
    { id: "painel",    name: "Revitalização de painel",   price: 50,  icon: "Dashboard", desc: "Limpeza e revitalização do painel para devolver aparência de cuidado ao interior do veículo." },
    { id: "portas",    name: "Revitalização das portas",  price: 40,  icon: "Door",      desc: "Higienização e acabamento das áreas internas das portas." },
    { id: "teto",      name: "Teto",                      price: 50,  icon: "Roof",      desc: "Limpeza do teto interno, ideal para marcas, poeira e sujeiras acumuladas." },
    { id: "cintos",    name: "Cintos",                    price: 20,  icon: "Belt",      desc: "Higienização dos cintos de segurança, uma área muito usada e pouco lembrada na limpeza comum." },
    { id: "quebrasol", name: "Quebra-sóis",               price: 20,  icon: "Sun",       desc: "Limpeza dos quebra-sóis, removendo poeira e marcas de uso." },
    { id: "forros",    name: "Forros da porta",           price: 20,  icon: "Lining",    desc: "Higienização dos forros internos das portas." },
    { id: "aspiracao", name: "Aspiração completa",        price: 20,  icon: "Vacuum",    desc: "Aspiração interna para remover poeira, resíduos, areia, pelos e sujeiras soltas." },
  ];

  const WHATSAPP_NUMBER = "5500000000000";

  const state = {
    step: 1,
    selected: [],
    data: { nome: "", whatsapp: "", endereco: "", veiculo: "", dia: "", horario: "", observacoes: "" },
    prevTotal: 0,
  };

  const totalOf = (ids) => ids.reduce((s, id) => s + (SERVICES.find((x) => x.id === id)?.price || 0), 0);

  function renderQuoter() {
    const root = $("#quoter-root");
    if (!root) return;
    root.innerHTML = `
      <div class="steps" aria-label="Etapas do orçamento">
        ${stepperHTML()}
      </div>
      <div id="quoter-body"></div>
    `;
    renderStep();
  }

  function stepperHTML() {
    const s = state.step;
    const item = (n, label) => {
      const cls = s > n ? "done" : s === n ? "active" : "";
      const num = s > n ? svg.check(14) : String(n);
      return `<div class="step-item ${cls}"><div class="step-num">${num}</div><div class="step-label">${label}</div></div>`;
    };
    return `
      ${item(1, "Serviços")}
      <div class="step-bar"></div>
      ${item(2, "Seus dados")}
      <div class="step-bar"></div>
      ${item(3, "Orçamento final")}
    `;
  }

  function renderStep() {
    const body = $("#quoter-body");
    if (!body) return;
    if (state.step === 1) body.innerHTML = renderStep1();
    if (state.step === 2) body.innerHTML = renderStep2();
    if (state.step === 3) body.innerHTML = renderStep3();
    wireStep();
  }

  function renderStep1() {
    const cardsHTML = SERVICES.map((s) => {
      const selected = state.selected.includes(s.id);
      return `
        <button type="button" class="service-card ${selected ? "selected" : ""}" data-id="${s.id}" aria-pressed="${selected}">
          <div class="service-icon">${(svg[s.icon] || (() => ""))()}</div>
          <div class="service-body">
            <div class="service-head">
              <div class="service-name">${s.name}</div>
              <div class="service-price">${fmtBRL(s.price)}</div>
            </div>
            <div class="service-desc">${s.desc}</div>
          </div>
          <span class="check-box" aria-hidden="true">${svg.check(14)}</span>
        </button>
      `;
    }).join("");

    return `
      <div class="quoter-layout">
        <div>
          <h3 class="sub">O que seu veículo mais precisa hoje?</h3>
          <div class="service-grid">${cardsHTML}</div>
        </div>
        ${renderSummary()}
      </div>
    `;
  }

  function renderSummary() {
    const items = state.selected.map((id) => SERVICES.find((s) => s.id === id)).filter(Boolean);
    const total = totalOf(state.selected);
    const rowsHTML = items
      .map(
        (s) => `
        <li class="summary-row">
          <span>${s.name}</span>
          <span style="display:inline-flex; align-items:center; gap:6px;">
            <strong>${fmtBRL(s.price)}</strong>
            <button type="button" class="x" data-remove="${s.id}" aria-label="Remover ${s.name}">${svg.x()}</button>
          </span>
        </li>`
      )
      .join("");
    return `
      <aside class="summary-card">
        <h4>Seu orçamento até agora</h4>
        <p class="muted">Atualizado em tempo real conforme você seleciona.</p>
        <ul class="summary-list">${rowsHTML}</ul>
        <div class="summary-total">
          <div><div class="lbl">Total parcial</div></div>
          <div class="val" id="summary-total-val">${fmtBRL(total)}</div>
        </div>
        <p class="fine">Valor estimado com base nos itens selecionados. A equipe Cleanox poderá confirmar os detalhes pelo WhatsApp antes do atendimento.</p>
        <button type="button" class="btn btn-primary btn-block btn-lg" id="continue-btn" ${state.selected.length === 0 ? "disabled" : ""}>
          Continuar orçamento ${svg.arrowRight()}
        </button>
      </aside>
    `;
  }

  function renderStep2() {
    const d = state.data;
    return `
      <div style="max-width:760px; margin:0 auto;">
        <h3 class="sub" style="text-align:center;">Agora só falta saber onde vamos atender você</h3>
        <form id="quoter-form" class="form-grid" novalidate>
          <div class="field" data-field="nome">
            <label>Nome completo</label>
            <input type="text" name="nome" placeholder="Como podemos te chamar" value="${escapeAttr(d.nome)}" />
          </div>
          <div class="field" data-field="whatsapp">
            <label>WhatsApp</label>
            <input type="tel" name="whatsapp" placeholder="(11) 99999-0000" value="${escapeAttr(d.whatsapp)}" />
          </div>
          <div class="field full" data-field="endereco">
            <label>Endereço ou bairro</label>
            <input type="text" name="endereco" placeholder="Rua, número, bairro / cidade" value="${escapeAttr(d.endereco)}" />
          </div>
          <div class="field" data-field="veiculo">
            <label>Tipo de veículo</label>
            <input type="text" name="veiculo" placeholder="Ex.: Honda Civic 2022" value="${escapeAttr(d.veiculo)}" />
          </div>
          <div class="field">
            <label>Melhor dia para atendimento</label>
            <input type="date" name="dia" value="${escapeAttr(d.dia)}" />
          </div>
          <div class="field">
            <label>Melhor horário</label>
            <select name="horario">
              <option value="">Selecione um período</option>
              <option ${d.horario === "Manhã (8h às 12h)" ? "selected" : ""}>Manhã (8h às 12h)</option>
              <option ${d.horario === "Almoço (12h às 14h)" ? "selected" : ""}>Almoço (12h às 14h)</option>
              <option ${d.horario === "Tarde (14h às 18h)" ? "selected" : ""}>Tarde (14h às 18h)</option>
              <option ${d.horario === "Final de tarde (após 18h)" ? "selected" : ""}>Final de tarde (após 18h)</option>
            </select>
          </div>
          <div class="field full">
            <label>Observações adicionais <span class="field-help">(opcional)</span></label>
            <textarea name="observacoes" placeholder="Manchas específicas, odores, pelos de pet, etc.">${escapeHTML(d.observacoes)}</textarea>
          </div>
          <div class="privacy-row full">
            ${svg.shield()}
            <span>Usamos seus dados apenas para enviar o orçamento, confirmar o atendimento e facilitar o agendamento. Sem spam, sem repasse a terceiros.</span>
          </div>
          <div class="full" style="display:flex; gap:12px; justify-content:space-between; flex-wrap:wrap; margin-top:6px;">
            <button type="button" class="btn btn-outline" id="back-btn">Voltar</button>
            <button type="submit" class="btn btn-primary btn-lg">
              Ver meu orçamento final ${svg.arrowRight()}
            </button>
          </div>
        </form>
      </div>
    `;
  }

  function renderStep3() {
    const items = state.selected.map((id) => SERVICES.find((s) => s.id === id)).filter(Boolean);
    const total = items.reduce((s, x) => s + x.price, 0);
    const d = state.data;
    const chips = items.map((i) => `<span style="padding:6px 12px; background:rgba(255,255,255,0.06); border:1px solid var(--line); border-radius:999px; font-size:13px; font-weight:500;">${i.name} · ${fmtBRL(i.price)}</span>`).join("");

    return `
      <div style="max-width:920px; margin:0 auto;">
        <div class="final-card reveal in">
          <div class="final-head">
            <div class="badge">${svg.check(26)}</div>
            <div>
              <span class="eyebrow"><span class="dot"></span> Orçamento pronto</span>
              <h2 style="margin-top:12px;">Seu orçamento Cleanox ficou pronto</h2>
            </div>
          </div>
          <p class="lead">Com base nos serviços selecionados, o valor estimado para sua higienização é:</p>
          <div class="total-block">
            <div class="lbl">Valor total estimado</div>
            <div class="val">${fmtBRL(total)}</div>
            <div class="note">Após o envio, um especialista Cleanox poderá confirmar os detalhes, tirar dúvidas e validar o melhor horário para o atendimento.</div>
          </div>
          <div class="summary-table">
            <div class="item"><div class="label">Cliente</div><div class="value">${escapeHTML(d.nome)}</div></div>
            <div class="item"><div class="label">WhatsApp</div><div class="value">${escapeHTML(d.whatsapp)}</div></div>
            <div class="item"><div class="label">Endereço / bairro</div><div class="value">${escapeHTML(d.endereco)}</div></div>
            <div class="item"><div class="label">Veículo</div><div class="value">${escapeHTML(d.veiculo)}</div></div>
            <div class="item"><div class="label">Melhor dia</div><div class="value">${escapeHTML(d.dia || "A combinar")}</div></div>
            <div class="item"><div class="label">Melhor horário</div><div class="value">${escapeHTML(d.horario || "A combinar")}</div></div>
            <div class="item" style="grid-column:1 / -1;">
              <div class="label">Serviços selecionados</div>
              <div class="value" style="display:flex; flex-wrap:wrap; gap:8px; margin-top:6px;">${chips}</div>
            </div>
            ${d.observacoes ? `<div class="item" style="grid-column:1 / -1;"><div class="label">Observações</div><div class="value" style="font-weight:400; color:var(--ink-2);">${escapeHTML(d.observacoes)}</div></div>` : ""}
          </div>
          <div class="final-actions">
            <button type="button" class="btn btn-outline" id="download-pdf">${svg.download()} Baixar PDF</button>
            <button type="button" class="btn btn-whatsapp" id="send-wa">${svg.whatsapp()} Enviar pelo WhatsApp</button>
            <button type="button" class="btn btn-primary" id="schedule-cal">${svg.calendar()} Agendar atendimento</button>
          </div>
          <div style="margin-top:24px; text-align:center;">
            <button type="button" class="btn btn-ghost btn-sm" id="restart-btn">Recomeçar orçamento</button>
          </div>
        </div>
      </div>
    `;
  }

  function wireStep() {
    if (state.step === 1) {
      $$(".service-card", $("#quoter-body")).forEach((btn) => {
        btn.addEventListener("click", () => toggleService(btn.dataset.id));
      });
      $$("[data-remove]", $("#quoter-body")).forEach((b) => {
        b.addEventListener("click", (e) => {
          e.stopPropagation();
          toggleService(b.dataset.remove);
        });
      });
      $("#continue-btn")?.addEventListener("click", () => {
        if (state.selected.length === 0) return;
        state.step = 2;
        renderQuoter();
        scrollToQuoter();
      });
    } else if (state.step === 2) {
      $("#back-btn")?.addEventListener("click", () => {
        state.step = 1;
        renderQuoter();
        scrollToQuoter();
      });
      const form = $("#quoter-form");
      form?.addEventListener("submit", (e) => {
        e.preventDefault();
        const fd = new FormData(form);
        const d = {
          nome: (fd.get("nome") || "").toString().trim(),
          whatsapp: (fd.get("whatsapp") || "").toString().trim(),
          endereco: (fd.get("endereco") || "").toString().trim(),
          veiculo: (fd.get("veiculo") || "").toString().trim(),
          dia: (fd.get("dia") || "").toString(),
          horario: (fd.get("horario") || "").toString(),
          observacoes: (fd.get("observacoes") || "").toString().trim(),
        };
        const errs = validate(d);
        $$(".field", form).forEach((f) => {
          f.classList.remove("error");
          $(".errtext", f)?.remove();
        });
        if (Object.keys(errs).length > 0) {
          for (const [k, msg] of Object.entries(errs)) {
            const f = $(`[data-field="${k}"]`, form);
            if (!f) continue;
            f.classList.add("error");
            const span = document.createElement("span");
            span.className = "errtext";
            span.textContent = msg;
            f.appendChild(span);
          }
          return;
        }
        state.data = d;
        state.step = 3;
        renderQuoter();
        setTimeout(scrollToQuoter, 80);
      });
    } else if (state.step === 3) {
      $("#download-pdf")?.addEventListener("click", downloadPDF);
      $("#send-wa")?.addEventListener("click", sendWhatsApp);
      $("#schedule-cal")?.addEventListener("click", openCalendar);
      $("#restart-btn")?.addEventListener("click", () => {
        state.step = 1;
        state.selected = [];
        renderQuoter();
        scrollToQuoter();
      });
    }
  }

  function toggleService(id) {
    if (!id) return;
    const idx = state.selected.indexOf(id);
    if (idx >= 0) state.selected.splice(idx, 1);
    else state.selected.push(id);

    // Update card pressed state in-place
    const card = $(`.service-card[data-id="${id}"]`);
    card?.classList.toggle("selected", state.selected.includes(id));
    card?.setAttribute("aria-pressed", String(state.selected.includes(id)));

    // Re-render summary aside only (preserves scroll position)
    const layout = $(".quoter-layout");
    const oldAside = $(".summary-card", layout);
    if (oldAside) {
      const wrapper = document.createElement("div");
      wrapper.innerHTML = renderSummary();
      const newAside = wrapper.firstElementChild;
      oldAside.replaceWith(newAside);
      // wire summary
      $$("[data-remove]", newAside).forEach((b) => {
        b.addEventListener("click", (e) => { e.stopPropagation(); toggleService(b.dataset.remove); });
      });
      $("#continue-btn")?.addEventListener("click", () => {
        if (state.selected.length === 0) return;
        state.step = 2;
        renderQuoter();
        scrollToQuoter();
      });
      // bump animation
      const valEl = $("#summary-total-val", newAside);
      const total = totalOf(state.selected);
      if (valEl && state.prevTotal !== total) {
        valEl.classList.remove("bump");
        void valEl.offsetWidth;
        valEl.classList.add("bump");
      }
      state.prevTotal = total;
    }
  }

  function validate(d) {
    const errs = {};
    if (!d.nome || d.nome.length < 2) errs.nome = "Informe seu nome completo";
    if (!d.whatsapp || d.whatsapp.replace(/\D/g, "").length < 10) errs.whatsapp = "WhatsApp inválido";
    if (!d.endereco || d.endereco.length < 2) errs.endereco = "Informe um endereço ou bairro";
    if (!d.veiculo || d.veiculo.length < 2) errs.veiculo = "Informe o tipo de veículo";
    return errs;
  }

  function scrollToQuoter() {
    document.getElementById("orcamento")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  function sendWhatsApp() {
    const items = state.selected.map((id) => SERVICES.find((s) => s.id === id)).filter(Boolean);
    const total = items.reduce((s, x) => s + x.price, 0);
    const d = state.data;
    const lines = [
      "Olá, Cleanox! Gostaria de solicitar meu orçamento.",
      "",
      `Nome: ${d.nome}`,
      `WhatsApp: ${d.whatsapp}`,
      `Endereço/Bairro: ${d.endereco}`,
      `Tipo de veículo: ${d.veiculo}`,
      "",
      "Serviços selecionados:",
      ...items.map((i) => `• ${i.name} — ${fmtBRL(i.price)}`),
      "",
      `Valor estimado: ${fmtBRL(total)}`,
      `Melhor dia: ${d.dia || "—"}`,
      `Melhor horário: ${d.horario || "—"}`,
      `Observações: ${d.observacoes || "—"}`,
      "",
      "Aguardando confirmação.",
    ];
    const text = encodeURIComponent(lines.join("\n"));
    window.open(`https://wa.me/${WHATSAPP_NUMBER}?text=${text}`, "_blank");
  }

  function downloadPDF() {
    const items = state.selected.map((id) => SERVICES.find((s) => s.id === id)).filter(Boolean);
    const total = items.reduce((s, x) => s + x.price, 0);
    const d = state.data;
    const w = window.open("", "_blank", "width=720,height=900");
    if (!w) {
      alert("Habilite pop-ups para baixar o PDF.");
      return;
    }
    const itemsHTML = items
      .map(
        (i) =>
          `<tr><td style="padding:8px 0;border-bottom:1px solid #eee">${escapeHTML(i.name)}</td><td style="text-align:right;padding:8px 0;border-bottom:1px solid #eee">${fmtBRL(i.price)}</td></tr>`
      )
      .join("");
    w.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>Orçamento Cleanox</title><style>
      body{font-family:system-ui,sans-serif;max-width:640px;margin:40px auto;padding:32px;color:#0E1B22}
      h1{color:#FD6037;margin:0 0 4px}
      .muted{color:#5A6970;font-size:14px}
      table{width:100%;border-collapse:collapse;margin-top:24px;font-size:14px}
      .total{margin-top:16px;padding-top:16px;border-top:2px solid #0C0C0C;display:flex;justify-content:space-between;font-size:22px;font-weight:700;color:#FD6037}
      .box{margin-top:24px;padding:18px;background:#F7F4EE;border-radius:12px;font-size:14px;line-height:1.6}
    </style></head><body>
      <h1>Orçamento Cleanox</h1>
      <div class="muted">Higienização profissional de estofados a seco</div>
      <div class="box">
        <div><strong>Cliente:</strong> ${escapeHTML(d.nome)}</div>
        <div><strong>WhatsApp:</strong> ${escapeHTML(d.whatsapp)}</div>
        <div><strong>Endereço:</strong> ${escapeHTML(d.endereco)}</div>
        <div><strong>Veículo:</strong> ${escapeHTML(d.veiculo)}</div>
        <div><strong>Melhor dia:</strong> ${escapeHTML(d.dia || "—")}</div>
        <div><strong>Horário:</strong> ${escapeHTML(d.horario || "—")}</div>
      </div>
      <table>
        <thead><tr><th style="text-align:left;padding:8px 0;border-bottom:2px solid #0E1B22">Serviço</th><th style="text-align:right;padding:8px 0;border-bottom:2px solid #0E1B22">Valor</th></tr></thead>
        <tbody>${itemsHTML}</tbody>
      </table>
      <div class="total"><span>Total</span><span>${fmtBRL(total)}</span></div>
      <p style="margin-top:24px;font-size:12px;color:#5A6970">Valor estimado com base nos itens selecionados. A equipe Cleanox poderá confirmar os detalhes pelo WhatsApp antes do atendimento.</p>
      <script>window.print()<\/script>
    </body></html>`);
    w.document.close();
  }

  function openCalendar() {
    const items = state.selected.map((id) => SERVICES.find((s) => s.id === id)).filter(Boolean);
    const total = items.reduce((s, x) => s + x.price, 0);
    const d = state.data;
    const start = d.dia ? d.dia.replace(/-/g, "") + "T100000Z" : "";
    const end = d.dia ? d.dia.replace(/-/g, "") + "T120000Z" : "";
    const details = `Cliente: ${d.nome}\nWhatsApp: ${d.whatsapp}\nEndereço: ${d.endereco}\nVeículo: ${d.veiculo}\nServiços: ${items.map((i) => i.name).join(", ")}\nTotal: ${fmtBRL(total)}\nObs: ${d.observacoes || "—"}`;
    const url =
      `https://calendar.google.com/calendar/render?action=TEMPLATE` +
      `&text=${encodeURIComponent("Atendimento Cleanox — " + d.nome)}` +
      `&details=${encodeURIComponent(details)}` +
      `&location=${encodeURIComponent(d.endereco)}` +
      (start ? `&dates=${start}/${end}` : "");
    window.open(url, "_blank");
  }

  function escapeHTML(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }
  function escapeAttr(s) {
    return escapeHTML(s);
  }

  /* ---------- Init ---------- */
  function init() {
    initTheme();
    initMarquee();
    initHeader();
    initMobileMenu();
    initReveal();
    initFAQ();
    initBeforeAfter();
    renderQuoter();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
