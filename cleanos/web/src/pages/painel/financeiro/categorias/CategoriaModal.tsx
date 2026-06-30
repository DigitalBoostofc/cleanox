/**
 * CategoriaModal — criar/editar categoria ou subcategoria (PANE FIN-B4).
 *
 * Campos: nome, tipo (despesa/receita), cor, ícone (nome lógico, opcional) e
 * categoria-mãe opcional (define uma subcategoria). No modo edição expõe a
 * exclusão, BLOQUEADA quando a categoria tem lançamentos ou subcategorias —
 * nesse caso orienta a arquivar.
 */

import { useEffect, useState } from 'react'
import type { Categoria, CategoriaInput, TipoLancamento } from '../../../../lib/financeiro/types'
import { Modal } from '../../../../components/ui/Modal'
import { Spinner } from '../../../../components/ui/Spinner'
import { IconAlertCircle, IconTrash } from '../../../../components/ui/Icon'
import { CategoriaIcon } from '../components'

const PRESET_CORES = [
  '#0E9F9C', '#14B8A6', '#10B981', '#22C55E', '#3B82F6', '#6366F1',
  '#8B5CF6', '#EC4899', '#F59E0B', '#F97316', '#EF4444', '#64748B',
]

export interface CategoriaModalProps {
  open: boolean
  mode: 'new' | 'edit'
  /** Categoria sendo editada (mode 'edit'). */
  categoria?: Categoria
  /** Tipo pré-selecionado (aba ativa) para novas categorias. */
  presetTipo: TipoLancamento
  /** Categoria-mãe pré-selecionada (ao criar subcategoria). */
  presetParentId?: string
  /** Possíveis mães (categorias-mãe não-arquivadas), para o seletor. */
  parents: Categoria[]
  /** Lançamentos vinculados (bloqueia exclusão quando > 0). */
  lancCount: number
  /** Possui subcategorias (bloqueia exclusão). */
  hasChildren: boolean
  saving: boolean
  error: string | null
  onSubmit: (input: CategoriaInput) => void
  onDelete: () => void
  onClose: () => void
}

export function CategoriaModal({
  open,
  mode,
  categoria,
  presetTipo,
  presetParentId,
  parents,
  lancCount,
  hasChildren,
  saving,
  error,
  onSubmit,
  onDelete,
  onClose,
}: CategoriaModalProps) {
  const [nome, setNome] = useState('')
  const [tipo, setTipo] = useState<TipoLancamento>(presetTipo)
  const [cor, setCor] = useState(PRESET_CORES[0])
  const [icone, setIcone] = useState('')
  const [parentId, setParentId] = useState<string>('')
  const [confirmDel, setConfirmDel] = useState(false)
  const [formErr, setFormErr] = useState<string | null>(null)

  // Sincroniza o estado do formulário sempre que o modal (re)abre.
  useEffect(() => {
    if (!open) return
    setConfirmDel(false)
    setFormErr(null)
    if (mode === 'edit' && categoria) {
      setNome(categoria.nome)
      setTipo(categoria.tipo)
      setCor(categoria.cor || PRESET_CORES[0])
      setIcone(categoria.icone ?? '')
      setParentId(categoria.parentId ?? '')
    } else {
      setNome('')
      setIcone('')
      setCor(PRESET_CORES[0])
      setParentId(presetParentId ?? '')
      // Subcategoria herda o tipo da mãe; senão usa a aba ativa.
      const mae = presetParentId ? parents.find((p) => p.id === presetParentId) : undefined
      setTipo(mae?.tipo ?? presetTipo)
    }
  }, [open, mode, categoria, presetTipo, presetParentId, parents])

  // Mães elegíveis: do mesmo tipo, não a própria categoria, sem auto-referência.
  const maesElegiveis = parents.filter((p) => p.tipo === tipo && p.id !== categoria?.id)

  function handleParent(id: string) {
    setParentId(id)
    if (id) {
      const mae = parents.find((p) => p.id === id)
      if (mae) setTipo(mae.tipo)
    }
  }

  function handleSubmit() {
    const nomeLimpo = nome.trim()
    if (!nomeLimpo) {
      setFormErr('Informe o nome da categoria.')
      return
    }
    setFormErr(null)
    onSubmit({
      nome: nomeLimpo,
      tipo,
      icone: icone.trim() || 'tag',
      cor,
      parentId: parentId || undefined,
      arquivada: categoria?.arquivada ?? false,
    })
  }

  const ehSub = !!parentId
  const podeExcluir = lancCount === 0 && !hasChildren
  const titulo =
    mode === 'edit'
      ? `Editar ${categoria?.parentId ? 'subcategoria' : 'categoria'}`
      : ehSub
        ? 'Nova subcategoria'
        : 'Nova categoria'

  const previewCat: Categoria = {
    id: 'preview',
    nome: nome || 'Prévia',
    tipo,
    icone: icone || 'tag',
    cor,
    arquivada: false,
    created: '',
    updated: '',
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={titulo}
      size="sm"
      footer={
        <>
          <button className="clx-btn clx-btn-ghost" onClick={onClose} disabled={saving}>
            Cancelar
          </button>
          <button className="clx-btn clx-btn-primary" onClick={handleSubmit} disabled={saving}>
            {saving ? (
              <>
                <Spinner size={14} /> Salvando…
              </>
            ) : mode === 'edit' ? (
              'Salvar alterações'
            ) : (
              'Criar'
            )}
          </button>
        </>
      }
    >
      {(error || formErr) && (
        <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
          <IconAlertCircle size={15} /> {formErr ?? error}
        </div>
      )}

      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <CategoriaIcon categoria={previewCat} size={40} />
        <div style={{ fontSize: '0.8rem', color: 'var(--clx-ink-3)' }}>
          Prévia do ícone (cor + inicial do nome).
        </div>
      </div>

      <div className="form-grid">
        <div className="form-field">
          <label>
            Nome <span className="req">*</span>
          </label>
          <input
            type="text"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="Ex.: Produtos de limpeza"
            autoFocus
          />
        </div>

        <div className="form-field">
          <label>Categoria-mãe (opcional)</label>
          <select value={parentId} onChange={(e) => handleParent(e.target.value)}>
            <option value="">Nenhuma (categoria principal)</option>
            {maesElegiveis.map((p) => (
              <option key={p.id} value={p.id}>
                {p.nome}
              </option>
            ))}
          </select>
          <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
            Escolha uma mãe para criar uma subcategoria.
          </span>
        </div>

        <div className="form-field">
          <label>Tipo</label>
          <select
            value={tipo}
            onChange={(e) => setTipo(e.target.value as TipoLancamento)}
            disabled={ehSub}
          >
            <option value="despesa">Despesa</option>
            <option value="receita">Receita</option>
          </select>
          {ehSub && (
            <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
              A subcategoria herda o tipo da categoria-mãe.
            </span>
          )}
        </div>

        <div className="form-field">
          <label>Ícone (opcional)</label>
          <input
            type="text"
            value={icone}
            onChange={(e) => setIcone(e.target.value)}
            placeholder="Ex.: spray-can, truck, home"
          />
        </div>

        <div className="form-field">
          <label>Cor</label>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <input
              type="color"
              value={cor}
              onChange={(e) => setCor(e.target.value)}
              style={{ width: 40, height: 32, padding: 0, border: '1px solid var(--clx-line)', borderRadius: 6, cursor: 'pointer' }}
              aria-label="Cor personalizada"
            />
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {PRESET_CORES.map((c) => (
                <button
                  key={c}
                  type="button"
                  aria-label={`Cor ${c}`}
                  onClick={() => setCor(c)}
                  style={{
                    width: 22,
                    height: 22,
                    borderRadius: '50%',
                    background: c,
                    border: cor.toLowerCase() === c.toLowerCase() ? '2px solid var(--clx-ink)' : '2px solid transparent',
                    cursor: 'pointer',
                  }}
                />
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Exclusão (somente edição) */}
      {mode === 'edit' && (
        <div style={{ marginTop: 18, paddingTop: 14, borderTop: '1px solid var(--clx-line)' }}>
          {!podeExcluir ? (
            <div style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)', lineHeight: 1.5 }}>
              <IconAlertCircle size={14} />{' '}
              Não é possível excluir: esta categoria possui{' '}
              {lancCount > 0 && (
                <strong>
                  {lancCount} {lancCount === 1 ? 'lançamento' : 'lançamentos'}
                </strong>
              )}
              {lancCount > 0 && hasChildren ? ' e ' : ''}
              {hasChildren && <strong>subcategorias</strong>}. Você pode <strong>arquivá-la</strong> para ocultá-la sem
              perder o histórico.
            </div>
          ) : confirmDel ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <span style={{ fontSize: '0.82rem', color: 'var(--clx-error)' }}>Excluir definitivamente?</span>
              <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={() => setConfirmDel(false)} disabled={saving}>
                Cancelar
              </button>
              <button
                className="clx-btn clx-btn-danger clx-btn-sm"
                onClick={onDelete}
                disabled={saving}
                style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
              >
                {saving ? <Spinner size={13} /> : <IconTrash size={13} />} Excluir
              </button>
            </div>
          ) : (
            <button
              className="clx-btn clx-btn-ghost clx-btn-sm"
              onClick={() => setConfirmDel(true)}
              disabled={saving}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'var(--clx-error)' }}
            >
              <IconTrash size={14} /> Excluir categoria
            </button>
          )}
        </div>
      )}
    </Modal>
  )
}
