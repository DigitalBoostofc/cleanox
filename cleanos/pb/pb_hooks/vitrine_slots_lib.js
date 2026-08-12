/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — motor de slots da vitrine (puro, testável fora do PB).
 *
 * Gera horários livres a partir de:
 *   - disponibilidade semanal por profissional (dias[0..6], 0=Dom)
 *   - duração do serviço (min)
 *   - OS já ocupando a agenda (start+dur)
 *
 * Horários são strings "HH:MM" em fuso de parede BRT (sem TZ no token de grade).
 */

var BRT_OFFSET_MS = 3 * 60 * 60 * 1000;

function pad2(n) {
  return String(n).padStart(2, "0");
}

/** "HH:MM" → minutos desde meia-noite; inválido → -1 */
function hmToMin(hm) {
  const s = String(hm || "");
  const m = /^(\d{1,2}):(\d{2})$/.exec(s.trim());
  if (!m) return -1;
  const h = Number(m[1]);
  const mi = Number(m[2]);
  if (h < 0 || h > 23 || mi < 0 || mi > 59) return -1;
  return h * 60 + mi;
}

function minToHm(min) {
  const m = Math.max(0, Math.floor(min));
  return pad2(Math.floor(m / 60)) + ":" + pad2(m % 60);
}

/**
 * Weekday JS (0=Dom…6=Sáb) a partir de YYYY-MM-DD interpretado como dia civil.
 * Usa UTC noon para evitar edge de DST.
 */
function weekdayFromYmd(ymd) {
  const p = String(ymd || "")
    .slice(0, 10)
    .split("-");
  if (p.length !== 3) return -1;
  const d = new Date(Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2]), 12));
  if (isNaN(d.getTime())) return -1;
  return d.getUTCDay(); // 0=Dom
}

/** Intervalos [start, end) em minutos colidem? */
function overlaps(a0, a1, b0, b1) {
  return a0 < b1 && b0 < a1;
}

/**
 * Parse data_hora PB (UTC) → minutos desde meia-noite BRT no dia ymd.
 * Se o instante não cair no dia BRT ymd, retorna null.
 */
function osStartMinOnYmdBrt(dataHoraUtc, ymd) {
  const raw = String(dataHoraUtc || "");
  if (!raw) return null;
  try {
    var iso = raw.indexOf("T") >= 0 ? raw : raw.replace(" ", "T");
    if (!/[zZ]$|[+-]\d{2}:?\d{2}$/.test(iso)) iso += "Z";
    var d = new Date(iso);
    if (isNaN(d.getTime())) return null;
    var brt = new Date(d.getTime() - BRT_OFFSET_MS);
    var day =
      brt.getUTCFullYear() +
      "-" +
      pad2(brt.getUTCMonth() + 1) +
      "-" +
      pad2(brt.getUTCDate());
    if (day !== String(ymd).slice(0, 10)) return null;
    return brt.getUTCHours() * 60 + brt.getUTCMinutes();
  } catch (_) {
    return null;
  }
}

/**
 * Converte ymd BRT + "HH:MM" → string data_hora UTC no formato PB.
 */
function brtSlotToUtcPb(ymd, hm) {
  const min = hmToMin(hm);
  if (min < 0) return "";
  const p = String(ymd).slice(0, 10).split("-");
  if (p.length !== 3) return "";
  const h = Math.floor(min / 60);
  const mi = min % 60;
  // BRT = UTC-3 → UTC = BRT + 3h
  const utcMs =
    Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2]), h, mi, 0) +
    BRT_OFFSET_MS;
  const d = new Date(utcMs);
  return (
    d.getUTCFullYear() +
    "-" +
    pad2(d.getUTCMonth() + 1) +
    "-" +
    pad2(d.getUTCDate()) +
    " " +
    pad2(d.getUTCHours()) +
    ":" +
    pad2(d.getUTCMinutes()) +
    ":00.000Z"
  );
}

/**
 * Gera candidatos de início [inicio, fim) com passo = stepMin (default = servDur).
 */
function gerarCandidatos(inicioHm, fimHm, servDurMin, stepMin) {
  const a = hmToMin(inicioHm);
  const b = hmToMin(fimHm);
  const dur = Math.max(15, Number(servDurMin) || 60);
  const step = Math.max(15, Number(stepMin) || dur);
  if (a < 0 || b < 0 || b <= a) return [];
  const out = [];
  for (var t = a; t + dur <= b; t += step) {
    out.push(t);
  }
  return out;
}

/**
 * Conta quantas OS (intervalos [start,end)) sobrepõem [a0,a1).
 * Inclui OS sem profissional — capacidade operacional, não só agenda por pro.
 */
function contarSobreposicoes(intervalos, a0, a1) {
  var n = 0;
  const list = intervalos || [];
  for (var i = 0; i < list.length; i++) {
    const iv = list[i];
    if (overlaps(a0, a1, iv[0], iv[1])) n += 1;
  }
  return n;
}

/**
 * @param {object} opts
 * @param {string} opts.ymd - YYYY-MM-DD BRT
 * @param {number} opts.servicoDurMin
 * @param {number} [opts.stepMin]
 * @param {Array<{profissional:string, dias:Array, duracao_min?:number}>} opts.disponibilidades
 * @param {Array<{profissional:string, data_hora:string, duracao_min?:number}>} opts.osOcupadas
 * @param {number} [opts.capacidadeSimultanea] - máx. OS sobrepostas (default = n° de pros ativos no dia)
 * @param {string} [opts.janelaInicio] - fallback CMS "HH:MM" se sem disponibilidade
 * @param {string} [opts.janelaFim]
 * @param {number} [opts.nowMs] - epoch ms (testes); default Date.now()
 * @param {number} [opts.horizonteMinutosAgora] - não oferece slot que já passou no dia de hoje
 * @returns {Array<{hora:string, profissionais:string[]}>}
 */
function calcularSlotsLivres(opts) {
  const ymd = String(opts.ymd || "").slice(0, 10);
  const servDur = Math.max(15, Number(opts.servicoDurMin) || 60);
  const step = Math.max(15, Number(opts.stepMin) || servDur);
  const wd = weekdayFromYmd(ymd);
  if (wd < 0) return [];

  const nowMs = opts.nowMs != null ? Number(opts.nowMs) : Date.now();
  const brtNow = new Date(nowMs - BRT_OFFSET_MS);
  const todayYmd =
    brtNow.getUTCFullYear() +
    "-" +
    pad2(brtNow.getUTCMonth() + 1) +
    "-" +
    pad2(brtNow.getUTCDate());
  var nowMinBrt = brtNow.getUTCHours() * 60 + brtNow.getUTCMinutes();
  const antec = Math.max(0, Number(opts.antecedenciaMinutos) || 0);
  if (ymd === todayYmd && antec > 0) {
    nowMinBrt += antec;
  }

  // ocupação por profissional + ocupação global (inclui profissional vazio)
  const ocup = {};
  const globalOcup = [];
  const osList = opts.osOcupadas || [];
  for (var i = 0; i < osList.length; i++) {
    const o = osList[i];
    const start = osStartMinOnYmdBrt(o.data_hora, ymd);
    if (start == null) continue;
    const odur = Math.max(15, Number(o.duracao_min) || servDur);
    const interval = [start, start + odur];
    globalOcup.push(interval);
    const pid = String(o.profissional || "");
    if (!pid) continue;
    if (!ocup[pid]) ocup[pid] = [];
    ocup[pid].push(interval);
  }

  // janelas ativas do dia (por profissional) + fallback CMS
  const disps = opts.disponibilidades || [];
  const janelas = []; // { pid, inicio, fim }
  const activePids = [];
  for (var d = 0; d < disps.length; d++) {
    const disp = disps[d];
    const pid = String(disp.profissional || "");
    const dias = disp.dias || [];
    const dia = dias[wd];
    if (!dia || !dia.ativo) continue;
    if (pid && activePids.indexOf(pid) === -1) activePids.push(pid);
    janelas.push({
      pid: pid,
      inicio: dia.inicio,
      fim: dia.fim,
    });
  }
  if (!janelas.length) {
    const ji = String(opts.janelaInicio || "08:00");
    const jf = String(opts.janelaFim || "18:00");
    if (hmToMin(ji) >= 0 && hmToMin(jf) > hmToMin(ji)) {
      janelas.push({ pid: "", inicio: ji, fim: jf });
    }
  }

  const capCfg = Number(opts.capacidadeSimultanea);
  const capacidade = Math.max(
    1,
    capCfg > 0 ? Math.floor(capCfg) : activePids.length || 1,
  );

  // mapa hora → set de pros livres (pode ser [] se só janela CMS)
  const byHora = {};
  const horasOk = {};

  for (var j = 0; j < janelas.length; j++) {
    const win = janelas[j];
    const candidatos = gerarCandidatos(win.inicio, win.fim, servDur, step);
    const busy = win.pid ? ocup[win.pid] || [] : [];
    for (var c = 0; c < candidatos.length; c++) {
      const start = candidatos[c];
      const end = start + servDur;
      if (ymd === todayYmd && start <= nowMinBrt) continue;

      // Capacidade operacional: OS sem profissional também ocupa.
      if (contarSobreposicoes(globalOcup, start, end) >= capacidade) continue;

      if (win.pid) {
        var colide = false;
        for (var b = 0; b < busy.length; b++) {
          if (overlaps(start, end, busy[b][0], busy[b][1])) {
            colide = true;
            break;
          }
        }
        if (colide) continue;
      }

      const hm = minToHm(start);
      horasOk[hm] = true;
      if (!byHora[hm]) byHora[hm] = [];
      if (win.pid && byHora[hm].indexOf(win.pid) === -1) {
        byHora[hm].push(win.pid);
      }
    }
  }

  const horas = Object.keys(horasOk).sort();
  const out = [];
  for (var h = 0; h < horas.length; h++) {
    out.push({
      hora: horas[h],
      profissionais: byHora[horas[h]] || [],
    });
  }
  return out;
}

/**
 * Escolhe o profissional com menos OS no dia (desempate: ordem estável do array).
 */
function escolherProfissional(profIds, contagemOsNoDia) {
  const ids = profIds || [];
  if (!ids.length) return "";
  var best = ids[0];
  var bestN = Number((contagemOsNoDia && contagemOsNoDia[best]) || 0);
  for (var i = 1; i < ids.length; i++) {
    const id = ids[i];
    const n = Number((contagemOsNoDia && contagemOsNoDia[id]) || 0);
    if (n < bestN) {
      best = id;
      bestN = n;
    }
  }
  return best;
}

module.exports = {
  hmToMin,
  minToHm,
  weekdayFromYmd,
  overlaps,
  contarSobreposicoes,
  osStartMinOnYmdBrt,
  brtSlotToUtcPb,
  gerarCandidatos,
  calcularSlotsLivres,
  escolherProfissional,
  BRT_OFFSET_MS,
};
