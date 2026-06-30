/**
 * ContasFiltros — barra de filtros das contas a pagar/receber (PANE FIN-B4).
 * Filtros combinados (AND): Tipo, Origem, Categoria, Conta, Vencimento + "Limpar".
 */

import type { Categoria, Conta, OrigemLancamento } from '../../../../lib/financeiro/types'

export type VencimentoPreset = 'todos' | 'vencidas' | 'hoje' | 'd7' | 'd30'

export interface ContaFilters {
  tipo: 'todos' | 'receita' | 'despesa'
  origem: 'todas' | OrigemLancamento
  categoriaId: 'todas' | string
  contaId: 'todas' | string
  vencimento: VencimentoPreset
}

export const FILTROS_PADRAO: ContaFilters = {
  tipo: 'todos',
  origem: 'todas',
  categoriaId: 'todas',
  contaId: 'todas',
  vencimento: 'todos',
}

export function filtrosAtivos(f: ContaFilters): boolean {
  return (
    f.tipo !== 'todos' ||
    f.origem !== 'todas' ||
    f.categoriaId !== 'todas' ||
    f.contaId !== 'todas' ||
    f.vencimento !== 'todos'
  )
}

interface Props {
  filters: ContaFilters
  categorias: Categoria[]
  contas: Conta[]
  onChange: (f: ContaFilters) => void
  onClear: () => void
}

const selectStyle: React.CSSProperties = {
  padding: '8px 12px',
  background: 'var(--clx-bg-2)',
  border: '1.5px solid var(--clx-line)',
  borderRadius: 'var(--clx-r-md, 8px)',
  fontSize: '0.85rem',
  color: 'var(--clx-ink)',
  cursor: 'pointer',
  minWidth: 150,
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
      <label style={{ fontSize: '0.72rem', fontWeight: 600, color: 'var(--clx-ink-3)' }}>{label}</label>
      {children}
    </div>
  )
}

export function ContasFiltros({ filters, categorias, contas, onChange, onClear }: Props) {
  const set = <K extends keyof ContaFilters>(key: K, value: ContaFilters[K]) =>
    onChange({ ...filters, [key]: value })

  // Categorias-mãe (não-arquivadas) para o seletor.
  const catsOrdenadas = categorias
    .filter((c) => !c.parentId && !c.arquivada)
    .sort((a, b) => a.nome.localeCompare(b.nome))

  return (
    <div
      className="fin-filters-bar clx-card"
      style={{
        display: 'flex',
        gap: 14,
        flexWrap: 'wrap',
        alignItems: 'flex-end',
        padding: '14px 16px',
        marginBottom: 20,
      }}
    >
      <Field label="Tipo">
        <select style={selectStyle} value={filters.tipo} onChange={(e) => set('tipo', e.target.value as ContaFilters['tipo'])}>
          <option value="todos">Todos os tipos</option>
          <option value="despesa">Despesas (a pagar)</option>
          <option value="receita">Receitas (a receber)</option>
        </select>
      </Field>

      <Field label="Origem">
        <select style={selectStyle} value={filters.origem} onChange={(e) => set('origem', e.target.value as ContaFilters['origem'])}>
          <option value="todas">Todas as origens</option>
          <option value="manual">Manual</option>
          <option value="via_os">Via OS</option>
        </select>
      </Field>

      <Field label="Categoria">
        <select style={selectStyle} value={filters.categoriaId} onChange={(e) => set('categoriaId', e.target.value)}>
          <option value="todas">Todas as categorias</option>
          {catsOrdenadas.map((c) => (
            <option key={c.id} value={c.id}>
              {c.nome}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Conta">
        <select style={selectStyle} value={filters.contaId} onChange={(e) => set('contaId', e.target.value)}>
          <option value="todas">Todas as contas</option>
          {contas.map((c) => (
            <option key={c.id} value={c.id}>
              {c.nome}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Vencimento">
        <select
          style={selectStyle}
          value={filters.vencimento}
          onChange={(e) => set('vencimento', e.target.value as VencimentoPreset)}
        >
          <option value="todos">Todos os vencimentos</option>
          <option value="vencidas">Vencidas</option>
          <option value="hoje">Vence hoje</option>
          <option value="d7">Próximos 7 dias</option>
          <option value="d30">Próximos 30 dias</option>
        </select>
      </Field>

      <button
        type="button"
        className="clx-btn clx-btn-ghost clx-btn-sm"
        onClick={onClear}
        disabled={!filtrosAtivos(filters)}
        style={{ marginLeft: 'auto' }}
      >
        Limpar filtros
      </button>
    </div>
  )
}
