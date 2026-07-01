/**
 * financeiro/ContasCarteiras.tsx — Tela CONTAS / CARTEIRAS do módulo Financeiro.
 *
 * Saldo geral no topo (saldoGeral) + lista de contas/carteiras (nome, tipo,
 * saldo inicial, saldo atual, status ativo/inativo). Ações: nova conta, editar,
 * excluir (bloqueada quando há lançamentos associados) e TRANSFERÊNCIA entre
 * contas (modal origem/destino/valor que ajusta o saldoAtual das duas — mock).
 * Saldos negativos aparecem em vermelho. Estado vazio com CTA.
 *
 * Regras da transferência (mock): valor > 0, origem ≠ destino; debita o
 * saldoAtual da origem e credita o do destino via updateConta. Saldo negativo
 * é PERMITIDO (não bloqueia), apenas sinalizado em vermelho.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  listContas,
  listLancamentos,
  createConta,
  updateConta,
  deleteConta,
  ajustarSaldoConta,
  transferirSaldo,
  definirContaPadrao,
  saldoGeral,
} from '../../../lib/financeiro/store'
import type { Conta, ContaTipo, Lancamento } from '../../../lib/financeiro/types'
import { contaTipoLabel } from '../../../lib/financeiro/labels'
import { formatCurrency } from '../../../lib/collections'
import { Spinner } from '../../../components/ui/Spinner'
import { Modal } from '../../../components/ui/Modal'
import { IconAlertCircle, IconPlus, IconEdit, IconTrash, IconArrowRight, IconCheckCircle } from '../../../components/ui/Icon'

const TIPO_OPTS: ContaTipo[] = ['carteira', 'banco', 'cartao', 'caixa']

interface FormState {
  nome: string
  tipo: ContaTipo
  saldoInicial: string
  ativo: boolean
}

const EMPTY_FORM: FormState = { nome: '', tipo: 'carteira', saldoInicial: '', ativo: true }

function saldoColor(v: number): string {
  return v < 0 ? 'var(--clx-error)' : 'var(--clx-ink)'
}

export default function ContasCarteiras() {
  const [contas, setContas] = useState<Conta[]>([])
  const [lancamentos, setLancamentos] = useState<Lancamento[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  /* Modal conta (criar/editar) */
  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<Conta | null>(null)
  const [form, setForm] = useState<FormState>(EMPTY_FORM)
  const [formErr, setFormErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  /* Modal exclusão */
  const [deleting, setDeleting] = useState<Conta | null>(null)
  const [deletingBusy, setDeletingBusy] = useState(false)

  /* Definir conta padrão (destino da receita de OS) */
  const [padraoBusyId, setPadraoBusyId] = useState<string | null>(null)

  /* Modal transferência */
  const [transferOpen, setTransferOpen] = useState(false)
  const [transferFrom, setTransferFrom] = useState('')
  const [transferTo, setTransferTo] = useState('')
  const [transferValor, setTransferValor] = useState('')
  const [transferErr, setTransferErr] = useState<string | null>(null)
  const [transferBusy, setTransferBusy] = useState(false)

  const genRef = useRef(0)

  const load = useCallback(async () => {
    const gen = ++genRef.current
    try {
      setLoading(true)
      setError(null)
      const [c, l] = await Promise.all([listContas(), listLancamentos()])
      if (gen !== genRef.current) return
      setContas(c)
      setLancamentos(l)
    } catch {
      if (gen === genRef.current) setError('Não foi possível carregar as contas.')
    } finally {
      if (gen === genRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  /** Quantidade de lançamentos por conta (para bloquear exclusão). */
  const lancCountByConta = useMemo(() => {
    const m = new Map<string, number>()
    lancamentos.forEach((l) => m.set(l.contaId, (m.get(l.contaId) ?? 0) + 1))
    return m
  }, [lancamentos])

  const saldoTotal = useMemo(() => saldoGeral(contas), [contas])

  function openNew() {
    setEditing(null)
    setForm(EMPTY_FORM)
    setFormErr(null)
    setFormOpen(true)
  }

  function openEdit(c: Conta) {
    setEditing(c)
    setForm({ nome: c.nome, tipo: c.tipo, saldoInicial: String(c.saldoInicial), ativo: c.ativo })
    setFormErr(null)
    setFormOpen(true)
  }

  async function handleSave() {
    const nome = form.nome.trim()
    const saldoInicial = Number(form.saldoInicial || 0)
    if (!nome) { setFormErr('Informe o nome da conta.'); return }
    if (isNaN(saldoInicial)) { setFormErr('Saldo inicial inválido.'); return }
    try {
      setSaving(true)
      setFormErr(null)
      if (editing) {
        // Editar saldo inicial reflete no saldo atual pela DIFERENÇA (incremental).
        // NÃO grava saldoAtual absoluto a partir do estado de UI (que pode estar
        // stale vs. o hook OS→Financeiro): atualiza os demais campos e aplica só o
        // delta via ajustarSaldoConta (relê o saldo fresco antes de somar). Evita
        // lost-update (F-220).
        const delta = saldoInicial - editing.saldoInicial
        await updateConta(editing.id, {
          nome,
          tipo: form.tipo,
          saldoInicial,
          ativo: form.ativo,
        })
        await ajustarSaldoConta(editing.id, delta)
      } else {
        await createConta({
          nome,
          tipo: form.tipo,
          saldoInicial,
          saldoAtual: saldoInicial,
          ativo: form.ativo,
        })
      }
      setFormOpen(false)
      await load()
    } catch {
      setFormErr('Não foi possível salvar a conta.')
    } finally {
      setSaving(false)
    }
  }

  const deletingCount = deleting ? lancCountByConta.get(deleting.id) ?? 0 : 0

  async function handleDelete() {
    if (!deleting || deletingCount > 0) return
    try {
      setDeletingBusy(true)
      await deleteConta(deleting.id)
      setDeleting(null)
      await load()
    } catch {
      setError('Não foi possível excluir a conta.')
      setDeleting(null)
    } finally {
      setDeletingBusy(false)
    }
  }

  async function handleSetPadrao(c: Conta) {
    if (c.padrao || padraoBusyId) return
    try {
      setPadraoBusyId(c.id)
      setError(null)
      // Atômico no servidor: marca esta e desmarca as demais na mesma transação (F-223).
      await definirContaPadrao(c.id)
      await load()
    } catch {
      setError('Não foi possível definir a conta padrão.')
    } finally {
      setPadraoBusyId(null)
    }
  }

  function openTransfer() {
    const ativas = contas.filter((c) => c.ativo)
    setTransferFrom(ativas[0]?.id ?? '')
    setTransferTo(ativas[1]?.id ?? '')
    setTransferValor('')
    setTransferErr(null)
    setTransferOpen(true)
  }

  async function handleTransfer() {
    const valor = Number(transferValor)
    if (!transferFrom || !transferTo) { setTransferErr('Selecione as contas de origem e destino.'); return }
    if (transferFrom === transferTo) { setTransferErr('Origem e destino devem ser diferentes.'); return }
    if (isNaN(valor) || valor <= 0) { setTransferErr('Informe um valor maior que zero.'); return }
    const origem = contas.find((c) => c.id === transferFrom)
    const destino = contas.find((c) => c.id === transferTo)
    if (!origem || !destino) { setTransferErr('Conta não encontrada.'); return }
    try {
      setTransferBusy(true)
      setTransferErr(null)
      // Aplica DELTAS incrementais (−valor origem / +valor destino) relendo o saldo
      // fresco em cada perna — não sobrescreve incrementos concorrentes do hook
      // OS→Financeiro (lost-update, F-220). Rollback do débito se o crédito falhar.
      await transferirSaldo(origem.id, destino.id, valor)
      setTransferOpen(false)
      await load()
    } catch {
      setTransferErr('Não foi possível concluir a transferência.')
    } finally {
      setTransferBusy(false)
    }
  }

  return (
    <div>
      {/* Header */}
      <div className="section-header" style={{ alignItems: 'flex-start' }}>
        <div>
          <h2>Contas e carteiras</h2>
          <p style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem', marginTop: 2 }}>
            Gerencie onde o dinheiro do seu negócio entra e sai.
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            className="clx-btn clx-btn-ghost clx-btn-sm"
            onClick={openTransfer}
            disabled={contas.filter((c) => c.ativo).length < 2}
            title={contas.filter((c) => c.ativo).length < 2 ? 'É preciso ao menos 2 contas ativas' : 'Transferir entre contas'}
          >
            <IconArrowRight size={14} /> Transferência
          </button>
          <button className="clx-btn clx-btn-primary clx-btn-sm" onClick={openNew}>
            <IconPlus size={14} /> Nova conta
          </button>
        </div>
      </div>

      {/* Saldo geral */}
      <div className="kpi-card" style={{ marginBottom: 18 }}>
        <div className="kpi-card-label">Saldo geral</div>
        <div className="kpi-card-value" style={{ fontSize: '1.6rem', color: saldoColor(saldoTotal) }}>
          {formatCurrency(saldoTotal)}
        </div>
        <div style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)', marginTop: 4 }}>
          Soma do saldo atual de {contas.length} conta{contas.length !== 1 ? 's' : ''}
        </div>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
            Tentar novamente
          </button>
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando…</div>
      ) : contas.length === 0 ? (
        <div className="empty-state">
          <h4>Nenhuma conta cadastrada</h4>
          <p>Crie uma conta ou carteira para começar a controlar seus saldos.</p>
          <button className="clx-btn clx-btn-primary clx-btn-sm" onClick={openNew} style={{ marginTop: 12 }}>
            <IconPlus size={14} /> Criar primeira conta
          </button>
        </div>
      ) : (
        <div className="clx-card" style={{ padding: 0 }}>
          {contas.map((c, i) => {
            const count = lancCountByConta.get(c.id) ?? 0
            return (
              <div
                key={c.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 14,
                  padding: '16px 18px',
                  borderTop: i === 0 ? 'none' : '1px solid var(--clx-line)',
                  opacity: c.ativo ? 1 : 0.6,
                }}
              >
                <span
                  className="fin-list-icon"
                  aria-hidden
                  style={{ background: c.cor ?? 'var(--clx-primary)', width: 40, height: 40, fontSize: '0.85rem', fontWeight: 700 }}
                >
                  {c.nome.slice(0, 1).toUpperCase()}
                </span>

                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontWeight: 600, color: 'var(--clx-ink)' }}>{c.nome}</span>
                    {!c.ativo && <span className="clx-chip">Inativa</span>}
                    {c.padrao && (
                      <span
                        className="clx-chip"
                        title="Destino padrão da receita de OS"
                        style={{ background: 'var(--clx-primary)', color: '#fff', display: 'inline-flex', alignItems: 'center', gap: 4 }}
                      >
                        <IconCheckCircle size={12} /> Padrão
                      </span>
                    )}
                  </div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)', marginTop: 2 }}>
                    {contaTipoLabel(c.tipo)} · Saldo inicial {formatCurrency(c.saldoInicial)}
                    {count > 0 && ` · ${count} lançamento${count !== 1 ? 's' : ''}`}
                  </div>
                </div>

                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <div style={{ fontSize: '0.68rem', color: 'var(--clx-ink-3)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                    Saldo atual
                  </div>
                  <div style={{ fontWeight: 700, fontSize: '1rem', color: saldoColor(c.saldoAtual) }}>
                    {formatCurrency(c.saldoAtual)}
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                  {c.ativo && (
                    <button
                      className="icon-btn"
                      onClick={() => handleSetPadrao(c)}
                      disabled={c.padrao || padraoBusyId === c.id}
                      aria-label={c.padrao ? `${c.nome} é a conta padrão` : `Definir ${c.nome} como conta padrão`}
                      title={c.padrao ? 'Conta padrão para receita de OS' : 'Definir como conta padrão (destino da receita de OS)'}
                      style={c.padrao ? { color: 'var(--clx-primary)' } : undefined}
                    >
                      {padraoBusyId === c.id ? <Spinner size={14} /> : <IconCheckCircle size={15} />}
                    </button>
                  )}
                  <button className="icon-btn" onClick={() => openEdit(c)} aria-label={`Editar ${c.nome}`} title="Editar">
                    <IconEdit size={15} />
                  </button>
                  <button className="icon-btn" onClick={() => setDeleting(c)} aria-label={`Excluir ${c.nome}`} title="Excluir">
                    <IconTrash size={15} />
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Modal criar/editar conta */}
      <Modal
        open={formOpen}
        onClose={() => setFormOpen(false)}
        title={editing ? 'Editar conta' : 'Nova conta'}
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setFormOpen(false)} disabled={saving}>Cancelar</button>
            <button className="clx-btn clx-btn-primary" onClick={handleSave} disabled={saving}>
              {saving ? <><Spinner size={14} /> Salvando…</> : 'Salvar'}
            </button>
          </>
        }
      >
        {formErr && (
          <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} /> {formErr}
          </div>
        )}
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="conta-nome">Nome <span className="req">*</span></label>
            <input
              id="conta-nome"
              type="text"
              value={form.nome}
              onChange={(e) => setForm((f) => ({ ...f, nome: e.target.value }))}
              placeholder="Ex.: Banco Inter"
            />
          </div>
          <div className="form-field">
            <label htmlFor="conta-tipo">Tipo</label>
            <select
              id="conta-tipo"
              value={form.tipo}
              onChange={(e) => setForm((f) => ({ ...f, tipo: e.target.value as ContaTipo }))}
            >
              {TIPO_OPTS.map((t) => (
                <option key={t} value={t}>{contaTipoLabel(t)}</option>
              ))}
            </select>
          </div>
          <div className="form-field">
            <label htmlFor="conta-saldo">Saldo inicial (R$)</label>
            <input
              id="conta-saldo"
              type="number"
              step="0.01"
              value={form.saldoInicial}
              onChange={(e) => setForm((f) => ({ ...f, saldoInicial: e.target.value }))}
              placeholder="0,00"
            />
            {editing && (
              <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
                Alterar o saldo inicial ajusta o saldo atual pela diferença.
              </span>
            )}
          </div>
          <div className="form-field">
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={form.ativo}
                onChange={(e) => setForm((f) => ({ ...f, ativo: e.target.checked }))}
              />
              Conta ativa
            </label>
          </div>
        </div>
      </Modal>

      {/* Modal excluir conta */}
      <Modal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        title="Excluir conta"
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setDeleting(null)} disabled={deletingBusy}>
              {deletingCount > 0 ? 'Fechar' : 'Cancelar'}
            </button>
            {deletingCount === 0 && (
              <button className="clx-btn clx-btn-danger" onClick={handleDelete} disabled={deletingBusy}>
                {deletingBusy ? <><Spinner size={14} /> Excluindo…</> : 'Excluir'}
              </button>
            )}
          </>
        }
      >
        {deletingCount > 0 ? (
          <div className="error-banner" role="alert">
            <IconAlertCircle size={15} />
            Não é possível excluir <strong>{deleting?.nome}</strong>: há {deletingCount} lançamento
            {deletingCount !== 1 ? 's' : ''} associado{deletingCount !== 1 ? 's' : ''}. Reatribua-os antes de excluir.
          </div>
        ) : (
          <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)' }}>
            Tem certeza que deseja excluir a conta <strong>{deleting?.nome}</strong>? Esta ação não pode ser desfeita.
          </p>
        )}
      </Modal>

      {/* Modal transferência */}
      <Modal
        open={transferOpen}
        onClose={() => setTransferOpen(false)}
        title="Transferência entre contas"
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setTransferOpen(false)} disabled={transferBusy}>Cancelar</button>
            <button className="clx-btn clx-btn-primary" onClick={handleTransfer} disabled={transferBusy}>
              {transferBusy ? <><Spinner size={14} /> Transferindo…</> : 'Transferir'}
            </button>
          </>
        }
      >
        {transferErr && (
          <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} /> {transferErr}
          </div>
        )}
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="tr-from">De <span className="req">*</span></label>
            <select id="tr-from" value={transferFrom} onChange={(e) => setTransferFrom(e.target.value)}>
              {contas.map((c) => (
                <option key={c.id} value={c.id}>{c.nome} — {formatCurrency(c.saldoAtual)}</option>
              ))}
            </select>
          </div>
          <div className="form-field">
            <label htmlFor="tr-to">Para <span className="req">*</span></label>
            <select id="tr-to" value={transferTo} onChange={(e) => setTransferTo(e.target.value)}>
              {contas.map((c) => (
                <option key={c.id} value={c.id}>{c.nome} — {formatCurrency(c.saldoAtual)}</option>
              ))}
            </select>
          </div>
          <div className="form-field">
            <label htmlFor="tr-valor">Valor (R$) <span className="req">*</span></label>
            <input
              id="tr-valor"
              type="number"
              min="0"
              step="0.01"
              value={transferValor}
              onChange={(e) => setTransferValor(e.target.value)}
              placeholder="0,00"
            />
          </div>
        </div>
      </Modal>
    </div>
  )
}
