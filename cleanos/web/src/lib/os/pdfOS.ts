/**
 * os/pdfOS.ts — Geração do RELATÓRIO DA OS em formato imprimível / "salvar como PDF".
 *
 * Estratégia SEM dependência nova: monta um documento HTML A4 estilizado (print CSS),
 * abre numa janela própria (ou, se o popup for bloqueado, num iframe oculto) e dispara
 * `window.print()`. O usuário escolhe "Salvar como PDF" no diálogo do navegador.
 *
 * O documento já vem PREENCHIDO com os dados da OS (nº, cliente, endereço, serviço,
 * valores, checklist, orientações etc.) e deixa EM BRANCO apenas os campos de
 * preenchimento manual no local: checkboxes de conferência, observação do cliente,
 * avaliação por estrelas, assinaturas e data/horário da assinatura.
 *
 * IMPORTANTE: nunca dispara alert/confirm/prompt nativos (quebrariam automações);
 * `window.print()` é o único diálogo usado.
 */

import type { FaseFoto, RelatorioOS } from '../servicos/types'
import { aprovacaoLabel, formatTempoMedio } from '../servicos/labels'
import { formatCurrency, formatDateTime } from '../collections'

/* ---- Utilidades ---- */

/** Escapa texto para inserção segura em HTML. */
function esc(value: string | undefined | null): string {
  if (value === undefined || value === null) return ''
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/** Linha de informação "rótulo: valor" (valor já escapado pelo chamador). */
function infoRow(label: string, valueHtml: string): string {
  return `<div class="info-item"><span class="info-label">${esc(label)}</span><span class="info-value">${valueHtml}</span></div>`
}

/** Caixa de checkbox em branco para marcação manual no local. */
function manualCheckbox(label: string): string {
  return `<label class="check-row"><span class="check-box" aria-hidden="true"></span><span>${esc(label)}</span></label>`
}

/* ---- Seções do documento ---- */

function sectionDados(rel: RelatorioOS): string {
  const rows: string[] = []
  rows.push(infoRow('Nº da OS', esc(rel.numeroOS ?? rel.osId)))
  rows.push(infoRow('Data e hora', esc(formatDateTime(rel.dataHora))))
  rows.push(infoRow('Cliente', esc(rel.clienteNome)))
  if (rel.clienteTelefone) rows.push(infoRow('Telefone', esc(rel.clienteTelefone)))
  if (rel.enderecoCompleto) rows.push(infoRow('Endereço', esc(rel.enderecoCompleto)))
  if (rel.bairro) rows.push(infoRow('Bairro', esc(rel.bairro)))
  if (rel.profissionalNome) rows.push(infoRow('Profissional', esc(rel.profissionalNome)))
  return `<section class="block">
    <h2>Dados do atendimento</h2>
    <div class="info-grid">${rows.join('')}</div>
  </section>`
}

function sectionServico(rel: RelatorioOS): string {
  const s = rel.snapshot
  const tempo = formatTempoMedio(s.tempoMedioMin, s.tempoMedioLabel)
  const rows: string[] = []
  rows.push(infoRow('Serviço', esc(s.nome)))
  rows.push(infoRow('Valor do serviço', esc(formatCurrency(rel.valorPrincipal))))
  if (tempo) rows.push(infoRow('Tempo médio', esc(tempo)))
  if (s.observacaoTecnica) {
    rows.push(infoRow('Observação técnica', esc(s.observacaoTecnica)))
  }
  return `<section class="block">
    <h2>Serviço contratado</h2>
    <div class="info-grid">${rows.join('')}</div>
  </section>`
}

function sectionAdicionais(rel: RelatorioOS): string {
  if (rel.adicionais.length === 0) return ''
  const linhas = rel.adicionais
    .map((a) => {
      const subtotal = formatCurrency(a.valor * a.quantidade)
      return `<tr>
        <td>${esc(a.nome)}${a.motivo ? `<br><span class="muted">${esc(a.motivo)}</span>` : ''}</td>
        <td class="num">${a.quantidade}</td>
        <td class="num">${esc(formatCurrency(a.valor))}</td>
        <td class="num">${esc(subtotal)}</td>
        <td>${esc(aprovacaoLabel(a.aprovacao))}</td>
      </tr>`
    })
    .join('')
  return `<section class="block">
    <h2>Serviços adicionais</h2>
    <table class="tbl">
      <thead><tr><th>Item</th><th class="num">Qtd</th><th class="num">Valor</th><th class="num">Subtotal</th><th>Status</th></tr></thead>
      <tbody>${linhas}</tbody>
    </table>
  </section>`
}

function sectionFinanceiro(rel: RelatorioOS): string {
  const rows: string[] = []
  rows.push(`<tr><td>Serviço principal</td><td class="num">${esc(formatCurrency(rel.valorPrincipal))}</td></tr>`)
  if (rel.valorAdicionais > 0) {
    rows.push(`<tr><td>Serviços adicionais</td><td class="num">${esc(formatCurrency(rel.valorAdicionais))}</td></tr>`)
  }
  if (rel.descontos && rel.descontos > 0) {
    rows.push(`<tr><td>Descontos</td><td class="num">- ${esc(formatCurrency(rel.descontos))}</td></tr>`)
  }
  rows.push(`<tr class="total"><td>Total</td><td class="num">${esc(formatCurrency(rel.valorTotal))}</td></tr>`)
  return `<section class="block">
    <h2>Resumo financeiro</h2>
    <table class="tbl tbl-fin"><tbody>${rows.join('')}</tbody></table>
  </section>`
}

function sectionChecklist(rel: RelatorioOS): string {
  if (rel.checklist.length === 0) return ''
  const itens = rel.checklist
    .map((c) => {
      const ok = c.status === 'concluido'
      const mark = ok ? '☑' : '☐'
      const cls = ok ? 'done' : 'pending'
      const obs = c.observacao ? ` <span class="muted">— ${esc(c.observacao)}</span>` : ''
      return `<li class="${cls}"><span class="mark" aria-hidden="true">${mark}</span><span>${esc(c.titulo)}${obs}</span></li>`
    })
    .join('')
  return `<section class="block">
    <h2>Checklist executado</h2>
    <ul class="checklist">${itens}</ul>
  </section>`
}

const FASE_LABEL: Record<FaseFoto, string> = {
  antes: 'Antes',
  durante: 'Durante',
  depois: 'Depois',
}
const FASE_ORDER: FaseFoto[] = ['antes', 'durante', 'depois']

function sectionEvidencias(rel: RelatorioOS): string {
  if (!rel.evidencias || rel.evidencias.length === 0) return ''

  const porFase = new Map<FaseFoto, typeof rel.evidencias>()
  for (const ev of rel.evidencias) {
    const arr = porFase.get(ev.fase) ?? []
    arr.push(ev)
    porFase.set(ev.fase, arr)
  }

  const partes: string[] = []
  for (const fase of FASE_ORDER) {
    const fotos = porFase.get(fase)
    if (!fotos || fotos.length === 0) continue
    const figuras = fotos
      .map((ev) => {
        const caption = ev.legenda
          ? `<figcaption>${esc(ev.legenda)}</figcaption>`
          : ''
        return `<figure class="foto-item"><img src="${esc(ev.url)}" alt="${esc(ev.legenda ?? FASE_LABEL[fase])}" loading="eager">${caption}</figure>`
      })
      .join('')
    partes.push(
      `<div class="foto-fase"><h3>${FASE_LABEL[fase]}</h3><div class="foto-grid">${figuras}</div></div>`,
    )
  }

  if (partes.length === 0) return ''

  return `<section class="block foto-section">
    <h2>Registro fotográfico</h2>
    ${partes.join('')}
  </section>`
}

function sectionOrientacoes(rel: RelatorioOS): string {
  const pre = rel.snapshot.orientacoesPreServico?.trim()
  const pos = rel.orientacoesPos?.trim()
  if (!pre && !pos) return ''
  const partes: string[] = []
  if (pre) partes.push(`<div class="orient"><h3>Orientações pré-serviço</h3><p>${esc(pre)}</p></div>`)
  if (pos) partes.push(`<div class="orient"><h3>Orientações pós-serviço</h3><p>${esc(pos)}</p></div>`)
  return `<section class="block">${partes.join('')}</section>`
}

function sectionObservacoes(rel: RelatorioOS): string {
  if (rel.observacoesVisiveis.length === 0) return ''
  const itens = rel.observacoesVisiveis
    .map((o) => `<li>${esc(o.texto)}</li>`)
    .join('')
  return `<section class="block">
    <h2>Observações</h2>
    <ul class="bullet">${itens}</ul>
  </section>`
}

function sectionRodapeManual(rel: RelatorioOS): string {
  return `<section class="block manual">
    <h2>Conferência no local <span class="muted">(preencher com o cliente)</span></h2>

    <div class="manual-checks">
      ${manualCheckbox('Serviço conferido e aprovado pelo cliente')}
      ${manualCheckbox('Ambiente/veículo entregue limpo e organizado')}
      ${manualCheckbox('Orientações pós-serviço explicadas ao cliente')}
    </div>

    <div class="manual-field">
      <label>Observação adicional do cliente</label>
      <div class="write-lines"><span></span><span></span><span></span></div>
    </div>

    <div class="manual-field">
      <label>Avaliação do cliente</label>
      <div class="stars" aria-hidden="true">&#9734; &#9734; &#9734; &#9734; &#9734;</div>
      <span class="muted small">(marque de 1 a 5 estrelas)</span>
    </div>

    <div class="sign-grid">
      <div class="sign">
        <div class="sign-line"></div>
        <span>Assinatura do cliente</span>
      </div>
      <div class="sign">
        <div class="sign-line"></div>
        <span>Assinatura do profissional${rel.profissionalNome ? ` — ${esc(rel.profissionalNome)}` : ''}</span>
      </div>
    </div>

    <div class="manual-field sign-date">
      <label>Data / horário da assinatura</label>
      <div class="write-lines"><span></span></div>
    </div>
  </section>`
}

/* ---- Documento completo ---- */

function buildPrintableHtml(rel: RelatorioOS): string {
  const titulo = `Relatório de Serviço${rel.numeroOS ? ` — Nº ${esc(rel.numeroOS)}` : ''}`

  const styles = `
    :root { color-scheme: light; }
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', system-ui, -apple-system, Arial, sans-serif;
      color: #0B1F2A; font-size: 12px; line-height: 1.5;
      background: #fff; padding: 28px 32px;
    }
    .doc-header {
      display: flex; align-items: center; justify-content: space-between;
      border-bottom: 3px solid #00C2B8; padding-bottom: 14px; margin-bottom: 18px;
    }
    .brand { display: flex; flex-direction: column; }
    .brand .name { font-size: 22px; font-weight: 800; letter-spacing: -0.02em; color: #0F4C5C; }
    .brand .name b { color: #00C2B8; }
    .brand .sub { font-size: 11px; color: #7A8893; }
    .doc-header .os-no { text-align: right; }
    .doc-header .os-no .lbl { font-size: 10px; color: #7A8893; text-transform: uppercase; letter-spacing: 0.06em; }
    .doc-header .os-no .val { font-size: 18px; font-weight: 800; color: #0F4C5C; }
    h2 {
      font-size: 13px; font-weight: 700; color: #0F4C5C; margin: 0 0 8px;
      padding-bottom: 5px; border-bottom: 1px solid #E2EAEF; text-transform: uppercase; letter-spacing: 0.04em;
    }
    h3 { font-size: 12px; font-weight: 700; color: #0F4C5C; margin: 0 0 4px; }
    .block { margin-bottom: 16px; page-break-inside: avoid; }
    .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 24px; }
    .info-item { display: flex; gap: 8px; padding: 3px 0; border-bottom: 1px dotted #E2EAEF; }
    .info-label { color: #7A8893; min-width: 110px; font-weight: 600; }
    .info-value { color: #0B1F2A; flex: 1; }
    table.tbl { width: 100%; border-collapse: collapse; }
    table.tbl th, table.tbl td { text-align: left; padding: 6px 8px; border-bottom: 1px solid #E2EAEF; vertical-align: top; }
    table.tbl th { background: #F2F7F9; color: #0F4C5C; font-size: 11px; text-transform: uppercase; letter-spacing: 0.03em; }
    table.tbl td.num, table.tbl th.num { text-align: right; white-space: nowrap; }
    table.tbl-fin td { padding: 7px 8px; }
    table.tbl-fin tr.total td { font-weight: 800; font-size: 14px; color: #0F4C5C; border-top: 2px solid #0F4C5C; border-bottom: none; }
    .muted { color: #7A8893; }
    .small { font-size: 10px; }
    ul.checklist { list-style: none; margin: 0; padding: 0; }
    ul.checklist li { display: flex; gap: 8px; padding: 4px 0; align-items: flex-start; }
    ul.checklist li .mark { font-size: 14px; line-height: 1.2; }
    ul.checklist li.done .mark { color: #00A39B; }
    ul.checklist li.pending { color: #7A8893; }
    ul.bullet { margin: 0; padding-left: 18px; }
    ul.bullet li { padding: 2px 0; }
    .orient { margin-bottom: 10px; }
    .orient p { margin: 0; }
    .manual { page-break-inside: avoid; }
    .manual-checks { display: flex; flex-direction: column; gap: 6px; margin-bottom: 12px; }
    .check-row { display: flex; align-items: center; gap: 8px; }
    .check-box { width: 14px; height: 14px; border: 1.5px solid #0F4C5C; border-radius: 3px; display: inline-block; flex-shrink: 0; }
    .manual-field { margin-bottom: 12px; }
    .manual-field > label { display: block; font-weight: 700; color: #0F4C5C; margin-bottom: 6px; font-size: 11px; }
    .write-lines { display: flex; flex-direction: column; gap: 14px; padding-top: 4px; }
    .write-lines span { display: block; border-bottom: 1px solid #B9C6CE; height: 0; }
    .stars { font-size: 22px; letter-spacing: 6px; color: #0F4C5C; }
    .sign-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 28px; margin: 22px 0 8px; }
    .sign { text-align: center; }
    .sign-line { border-bottom: 1px solid #0B1F2A; height: 34px; margin-bottom: 6px; }
    .sign span { font-size: 11px; color: #7A8893; }
    .sign-date .write-lines { max-width: 240px; }
    .footer-note {
      margin-top: 18px; padding: 12px 14px; background: #F2F7F9; border-left: 3px solid #00C2B8;
      border-radius: 6px; font-size: 11px; color: #3A4A55; page-break-inside: avoid;
    }
    .footer-note strong { color: #0F4C5C; }
    .gerado { margin-top: 14px; text-align: right; font-size: 10px; color: #7A8893; }
    .foto-fase { margin-bottom: 12px; page-break-inside: avoid; }
    .foto-grid { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 6px; }
    .foto-item { margin: 0; text-align: center; page-break-inside: avoid; }
    .foto-item img { max-height: 140px; width: auto; max-width: 180px; display: block; border: 1px solid #E2EAEF; border-radius: 4px; }
    .foto-item figcaption { font-size: 10px; color: #7A8893; margin-top: 4px; max-width: 180px; word-break: break-word; }
    @page { size: A4; margin: 14mm; }
    @media print {
      body { padding: 0; }
      .block, .manual, .footer-note { page-break-inside: avoid; }
      .foto-fase, .foto-item { page-break-inside: avoid; }
    }
  `

  const autoPrint = `
    window.addEventListener('load', function () {
      try { window.focus(); } catch (e) {}
      setTimeout(function () { try { window.print(); } catch (e) {} }, 250);
    });
    window.addEventListener('afterprint', function () {
      setTimeout(function () { try { window.close(); } catch (e) {} }, 100);
    });
  `

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${titulo}</title>
<style>${styles}</style>
</head>
<body>
  <header class="doc-header">
    <div class="brand">
      <span class="name">Clean<b>ox</b></span>
      <span class="sub">Relatório de Ordem de Serviço</span>
    </div>
    <div class="os-no">
      <div class="lbl">Ordem de Serviço</div>
      <div class="val">${esc(rel.numeroOS ?? rel.osId)}</div>
    </div>
  </header>

  ${sectionDados(rel)}
  ${sectionServico(rel)}
  ${sectionAdicionais(rel)}
  ${sectionFinanceiro(rel)}
  ${sectionChecklist(rel)}
  ${sectionEvidencias(rel)}
  ${sectionOrientacoes(rel)}
  ${sectionObservacoes(rel)}

  <div class="footer-note">
    <strong>${esc(rel.textoPadrao)}</strong>
    <br><br>
    Prazo de até <strong>${rel.prazoIntercorrenciaDias} dias</strong> para relatar qualquer falha ou intercorrência.
  </div>

  ${sectionRodapeManual(rel)}

  <div class="gerado">Documento gerado em ${esc(formatDateTime(rel.geradoEm))}</div>

  <script>${autoPrint}<\/script>
</body>
</html>`
}

/* ---- API pública ---- */

/**
 * Abre o relatório imprimível da OS e dispara o diálogo de impressão
 * (o usuário pode "Salvar como PDF"). Tenta uma janela nova; se o popup for
 * bloqueado, cai para um iframe oculto. Não dispara diálogos nativos.
 */
export function gerarPDFOS(relatorio: RelatorioOS): void {
  if (typeof window === 'undefined' || typeof document === 'undefined') return

  const html = buildPrintableHtml(relatorio)

  /* 1) Janela dedicada (sem noopener — precisamos escrever no documento). */
  const win = window.open('', '_blank', 'width=900,height=1200')
  if (win && win.document) {
    win.document.open()
    win.document.write(html)
    win.document.close()
    return
  }

  /* 2) Fallback: iframe oculto (popup bloqueado). */
  printViaIframe(html)
}

/** Renderiza o documento num iframe fora da tela e imprime. */
function printViaIframe(html: string): void {
  const iframe = document.createElement('iframe')
  iframe.setAttribute('aria-hidden', 'true')
  iframe.style.position = 'fixed'
  iframe.style.right = '0'
  iframe.style.bottom = '0'
  iframe.style.width = '0'
  iframe.style.height = '0'
  iframe.style.border = '0'
  iframe.style.visibility = 'hidden'
  document.body.appendChild(iframe)

  const doc = iframe.contentWindow?.document
  if (!doc) {
    iframe.remove()
    return
  }

  doc.open()
  doc.write(html) // o próprio HTML chama window.print() no load (escopo do iframe)
  doc.close()

  /* Remove o iframe após a impressão (o diálogo é síncrono na maioria dos browsers). */
  iframe.contentWindow?.addEventListener('afterprint', () => {
    setTimeout(() => iframe.remove(), 200)
  })
  /* Rede de segurança caso 'afterprint' não dispare. */
  setTimeout(() => {
    if (iframe.parentNode) iframe.remove()
  }, 60_000)
}
