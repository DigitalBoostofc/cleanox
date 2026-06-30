/**
 * ChecklistEditor — edita o checklist padrão do serviço.
 * Suporta adicionar, remover, editar título e reordenar (drag-and-drop nativo
 * pelo handle, com fallback de setas ↑/↓ para acessibilidade/teclado).
 * Mantém `ordem` sempre normalizada (1-based) na saída.
 */

import { useRef, useState } from 'react'
import type { ChecklistTemplateItem } from '../../../../lib/servicos/types'
import { IconCheck, IconChevronDown, IconPlus, IconX } from '../../../../components/ui/Icon'
import { IconGrip } from './icons'

interface ChecklistEditorProps {
  items: ChecklistTemplateItem[]
  onChange: (items: ChecklistTemplateItem[]) => void
}

/** ID temporário para itens recém-criados (substituído/normalizado no salvar). */
function tmpId(): string {
  return `chktmp_${Math.random().toString(36).slice(2, 9)}`
}

/** Reaplica `ordem` 1-based seguindo a ordem do array. */
function renumber(items: ChecklistTemplateItem[]): ChecklistTemplateItem[] {
  return items.map((it, i) => ({ ...it, ordem: i + 1 }))
}

export function ChecklistEditor({ items, onChange }: ChecklistEditorProps) {
  const [dragIndex, setDragIndex] = useState<number | null>(null)
  const [overIndex, setOverIndex] = useState<number | null>(null)
  const pendingFocus = useRef<string | null>(null)

  function move(from: number, to: number) {
    if (from === to || from < 0 || to < 0 || from >= items.length || to >= items.length) return
    const next = items.slice()
    const [moved] = next.splice(from, 1)
    next.splice(to, 0, moved)
    onChange(renumber(next))
  }

  function updateTitulo(index: number, titulo: string) {
    onChange(items.map((it, i) => (i === index ? { ...it, titulo } : it)))
  }

  function remove(index: number) {
    onChange(renumber(items.filter((_, i) => i !== index)))
  }

  function add() {
    const id = tmpId()
    pendingFocus.current = id
    onChange(renumber([...items, { id, titulo: '', ordem: items.length + 1 }]))
  }

  function focusRef(el: HTMLInputElement | null, id: string) {
    if (el && pendingFocus.current === id) {
      el.focus()
      pendingFocus.current = null
    }
  }

  return (
    <div className="checklist-editor">
      {items.length === 0 ? (
        <p className="checklist-empty">
          Nenhum item no checklist. Adicione itens que a equipe deverá marcar durante a execução.
        </p>
      ) : (
        <ul className="checklist-list" aria-label="Itens do checklist padrão">
          {items.map((item, i) => (
            <li
              key={item.id}
              className={[
                'checklist-item',
                dragIndex === i ? 'dragging' : '',
                overIndex === i && dragIndex !== null && dragIndex !== i ? 'drag-over' : '',
              ].filter(Boolean).join(' ')}
              onDragOver={(e) => {
                if (dragIndex === null) return
                e.preventDefault()
                e.dataTransfer.dropEffect = 'move'
                setOverIndex(i)
              }}
              onDrop={(e) => {
                e.preventDefault()
                if (dragIndex !== null) move(dragIndex, i)
                setDragIndex(null)
                setOverIndex(null)
              }}
            >
              <span
                className="checklist-handle"
                role="button"
                tabIndex={-1}
                aria-label="Arraste para reordenar"
                title="Arraste para reordenar"
                draggable
                onDragStart={(e) => {
                  setDragIndex(i)
                  e.dataTransfer.effectAllowed = 'move'
                  e.dataTransfer.setData('text/plain', String(i))
                }}
                onDragEnd={() => {
                  setDragIndex(null)
                  setOverIndex(null)
                }}
              >
                <IconGrip size={16} />
              </span>

              <span className="checklist-check" aria-hidden="true">
                <IconCheck size={13} />
              </span>

              <input
                ref={(el) => focusRef(el, item.id)}
                className="checklist-title-input"
                type="text"
                value={item.titulo}
                placeholder="Descreva o item…"
                onChange={(e) => updateTitulo(i, e.target.value)}
                aria-label={`Item ${i + 1} do checklist`}
              />

              <div className="checklist-row-actions">
                <button
                  type="button"
                  className="icon-btn checklist-move"
                  onClick={() => move(i, i - 1)}
                  disabled={i === 0}
                  aria-label="Mover para cima"
                  title="Mover para cima"
                >
                  <span style={{ display: 'flex', transform: 'rotate(180deg)' }}>
                    <IconChevronDown size={15} />
                  </span>
                </button>
                <button
                  type="button"
                  className="icon-btn checklist-move"
                  onClick={() => move(i, i + 1)}
                  disabled={i === items.length - 1}
                  aria-label="Mover para baixo"
                  title="Mover para baixo"
                >
                  <IconChevronDown size={15} />
                </button>
                <button
                  type="button"
                  className="icon-btn danger"
                  onClick={() => remove(i)}
                  aria-label={`Remover item ${i + 1}`}
                  title="Remover item"
                >
                  <IconX size={15} />
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <button type="button" className="checklist-add" onClick={add}>
        <IconPlus size={15} /> Adicionar item
      </button>
    </div>
  )
}
