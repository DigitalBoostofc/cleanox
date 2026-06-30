/**
 * ChecklistExecucao — checklist EXECUTÁVEL da OS, derivado do snapshot do serviço.
 *
 * Cada item alterna entre 'pendente' e 'concluido'. Ao concluir, grava `concluidoEm`
 * (ISO) e `concluidoPor`. A ordem dos itens é preservada (já vem ordenada do snapshot).
 * Cada item aceita uma observação opcional, editável inline.
 */

import { useState } from 'react'
import type { ChecklistExecItem } from '../../lib/servicos/types'
import { formatDateTime } from '../../lib/collections'
import { IconCheck, IconEdit } from '../ui/Icon'

interface ChecklistExecucaoProps {
  items: ChecklistExecItem[]
  onChange: (items: ChecklistExecItem[]) => void
  /** Nome gravado em `concluidoPor` ao marcar um item. */
  concluidoPor?: string
}

export default function ChecklistExecucao({
  items,
  onChange,
  concluidoPor = 'Profissional',
}: ChecklistExecucaoProps) {
  const [openObs, setOpenObs] = useState<Record<string, boolean>>({})

  const total = items.length
  const done = items.filter((i) => i.status === 'concluido').length
  const pct = total === 0 ? 0 : Math.round((done / total) * 100)

  function toggle(id: string) {
    onChange(
      items.map((it) => {
        if (it.id !== id) return it
        if (it.status === 'concluido') {
          return { ...it, status: 'pendente', concluidoEm: undefined, concluidoPor: undefined }
        }
        return {
          ...it,
          status: 'concluido',
          concluidoEm: new Date().toISOString(),
          concluidoPor,
        }
      }),
    )
  }

  function setObs(id: string, texto: string) {
    onChange(
      items.map((it) =>
        it.id === id ? { ...it, observacao: texto.trim() ? texto : undefined } : it,
      ),
    )
  }

  function toggleObs(id: string) {
    setOpenObs((prev) => ({ ...prev, [id]: !prev[id] }))
  }

  return (
    <section className="clx-card" style={{ padding: '16px 18px' }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
          marginBottom: 14,
        }}
      >
        <h3
          style={{
            margin: 0,
            fontFamily: 'var(--clx-font-display)',
            fontSize: '1rem',
            fontWeight: 700,
            color: 'var(--clx-ink)',
          }}
        >
          Checklist de execução
        </h3>
        <span
          className={`clx-chip ${done === total && total > 0 ? 'clx-chip-success' : 'clx-chip-primary'}`}
          style={{ whiteSpace: 'nowrap' }}
        >
          {done} de {total} concluídos
        </span>
      </div>

      {total === 0 ? (
        <div className="empty-state" style={{ padding: '24px 12px' }}>
          <h4>Checklist vazio</h4>
          <p>Selecione o serviço principal para gerar o checklist de execução.</p>
        </div>
      ) : (
        <>
          {/* Barra de progresso */}
          <div
            role="progressbar"
            aria-valuenow={pct}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={`${done} de ${total} itens concluídos`}
            style={{
              height: 6,
              borderRadius: 'var(--clx-r-pill)',
              background: 'var(--clx-line)',
              overflow: 'hidden',
              marginBottom: 14,
            }}
          >
            <div
              style={{
                height: '100%',
                width: `${pct}%`,
                background: 'var(--clx-success)',
                transition: 'width 0.25s var(--clx-ease-out)',
              }}
            />
          </div>

          <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {items.map((it) => {
              const concluido = it.status === 'concluido'
              const obsOpen = openObs[it.id] ?? false
              const obsCheckboxId = `chk-${it.id}`
              return (
                <li
                  key={it.id}
                  style={{
                    border: '1px solid var(--clx-line)',
                    borderRadius: 'var(--clx-r-md)',
                    background: concluido ? 'var(--clx-success-bg)' : 'var(--clx-bg-2)',
                    padding: '10px 12px',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
                    <input
                      id={obsCheckboxId}
                      type="checkbox"
                      checked={concluido}
                      onChange={() => toggle(it.id)}
                      style={{ marginTop: 2, width: 18, height: 18, flexShrink: 0, cursor: 'pointer', accentColor: 'var(--clx-success)' }}
                    />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <label
                        htmlFor={obsCheckboxId}
                        style={{
                          display: 'block',
                          fontSize: '0.9rem',
                          fontWeight: 600,
                          color: 'var(--clx-ink)',
                          textDecoration: concluido ? 'line-through' : 'none',
                          cursor: 'pointer',
                        }}
                      >
                        {it.titulo}
                      </label>
                      {concluido && it.concluidoEm && (
                        <div
                          style={{
                            marginTop: 3,
                            fontSize: '0.74rem',
                            color: 'var(--clx-success)',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 4,
                          }}
                        >
                          <IconCheck size={12} />
                          {it.concluidoPor ? `${it.concluidoPor} · ` : ''}
                          {formatDateTime(it.concluidoEm)}
                        </div>
                      )}
                      {it.observacao && !obsOpen && (
                        <div
                          style={{
                            marginTop: 6,
                            fontSize: '0.82rem',
                            color: 'var(--clx-ink-2)',
                            fontStyle: 'italic',
                          }}
                        >
                          “{it.observacao}”
                        </div>
                      )}
                    </div>
                    <button
                      type="button"
                      className="icon-btn"
                      onClick={() => toggleObs(it.id)}
                      title={it.observacao ? 'Editar observação' : 'Adicionar observação'}
                      aria-label={it.observacao ? 'Editar observação' : 'Adicionar observação'}
                      aria-expanded={obsOpen}
                      style={{ flexShrink: 0, color: it.observacao ? 'var(--clx-accent)' : undefined }}
                    >
                      <IconEdit size={15} />
                    </button>
                  </div>

                  {obsOpen && (
                    <div style={{ marginTop: 10 }}>
                      <textarea
                        value={it.observacao ?? ''}
                        onChange={(e) => setObs(it.id, e.target.value)}
                        placeholder="Observação sobre este item (opcional)…"
                        rows={2}
                        autoFocus
                        style={{
                          width: '100%',
                          resize: 'vertical',
                          padding: '8px 10px',
                          fontSize: '0.85rem',
                          fontFamily: 'inherit',
                          color: 'var(--clx-ink)',
                          background: 'var(--clx-bg)',
                          border: '1.5px solid var(--clx-line)',
                          borderRadius: 'var(--clx-r-md)',
                          outline: 'none',
                          boxSizing: 'border-box',
                        }}
                      />
                      <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 6 }}>
                        <button
                          type="button"
                          className="clx-btn clx-btn-ghost clx-btn-sm"
                          onClick={() => toggleObs(it.id)}
                        >
                          Concluir
                        </button>
                      </div>
                    </div>
                  )}
                </li>
              )
            })}
          </ul>
        </>
      )}
    </section>
  )
}
