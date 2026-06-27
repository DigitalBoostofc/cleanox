import { useEffect, useState } from 'react'
import {
  todayLocalDate,
  pbDateToLocalInput,
  type Servico,
  type User,
  type OrdemServico,
  type Disponibilidade,
  type DisponibilidadeDia,
  userDisplayName,
  gerarSlotsDisponiveis,
  COLLECTIONS,
} from '../../lib/collections'
import { pb } from '../../lib/pb'
import { Spinner } from './Spinner'

export interface OSFields {
  servicoId: string
  tipo_servico_nome: string
  data_date: string
  data_time_h: string
  data_time_m: string
  valor_servico: string
  profissionalId: string
  observacoes: string
}

export function emptyOSFields(): OSFields {
  return {
    servicoId: '',
    tipo_servico_nome: '',
    data_date: '',
    data_time_h: '08',
    data_time_m: '00',
    valor_servico: '',
    profissionalId: '',
    observacoes: '',
  }
}

export function snapMinutes(m: number): string {
  const snapped = Math.round(m / 15) * 15
  return String(snapped === 60 ? 0 : snapped).padStart(2, '0')
}

export function pbDateToOSFields(
  iso: string
): Pick<OSFields, 'data_date' | 'data_time_h' | 'data_time_m'> {
  if (!iso) return { data_date: '', data_time_h: '08', data_time_m: '00' }
  const local = pbDateToLocalInput(iso)
  if (!local) return { data_date: '', data_time_h: '08', data_time_m: '00' }
  const [date, time] = local.split('T')
  const [h, mRaw] = time.split(':')
  return {
    data_date: date,
    data_time_h: h.padStart(2, '0'),
    data_time_m: snapMinutes(parseInt(mRaw ?? '0', 10)),
  }
}

export function validateOSFields(
  fields: Pick<OSFields, 'data_date' | 'valor_servico'>
): Record<string, string> {
  const errs: Record<string, string> = {}
  const today = todayLocalDate()
  if (!fields.data_date) {
    errs.data_date = 'Data é obrigatória'
  } else if (fields.data_date < today) {
    errs.data_date = 'A data não pode ser no passado'
  }
  if (!fields.valor_servico || Number(fields.valor_servico) <= 0) {
    errs.valor_servico = 'Informe o valor'
  }
  return errs
}

const HOURS = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0'))
const MINUTES = ['00', '15', '30', '45']

/* ---- helpers (pure, used inside the component) ---- */

function localDateToUTCRange(dateStr: string): { start: string; end: string } {
  const [y, mo, d] = dateStr.split('-').map(Number)
  const start = new Date(y, mo - 1, d)
  const end = new Date(y, mo - 1, d + 1)
  const fmt = (dt: Date) => {
    const p = (n: number) => String(n).padStart(2, '0')
    return `${dt.getUTCFullYear()}-${p(dt.getUTCMonth() + 1)}-${p(dt.getUTCDate())} ${p(dt.getUTCHours())}:${p(dt.getUTCMinutes())}:00`
  }
  return { start: fmt(start), end: fmt(end) }
}

function pbToLocalHHMM(pbDate: string): string {
  const iso = pbDate.replace(' ', 'T')
  const d = new Date(iso.endsWith('Z') ? iso : iso + 'Z')
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}`
}

/* ---- Component ---- */

interface OSFormSectionProps {
  servicos: Servico[]
  profissionais: User[]
  fields: OSFields
  errs: Record<string, string>
  onChange: (k: keyof OSFields, v: string) => void
  onServicoChange: (id: string) => void
  loadingLookups?: boolean
  /** ID da OS sendo editada — seu slot permanece disponível */
  editingOSId?: string
}

type DispState = 'idle' | 'loading' | 'loaded' | 'error'

export function OSFormSection({
  servicos,
  profissionais,
  fields,
  errs,
  onChange,
  onServicoChange,
  loadingLookups = false,
  editingOSId,
}: OSFormSectionProps) {
  const today = todayLocalDate()

  /* ---- disponibilidade state ---- */
  const [disp, setDisp] = useState<Disponibilidade | null>(null)
  const [dispState, setDispState] = useState<DispState>('idle')
  const [ocupados, setOcupados] = useState<string[]>([])
  const [ocupadosLoading, setOcupadosLoading] = useState(false)

  /* fetch disponibilidade when profissional changes */
  useEffect(() => {
    if (!fields.profissionalId) {
      setDisp(null)
      setDispState('idle')
      return
    }
    setDispState('loading')
    let cancelled = false
    pb.collection(COLLECTIONS.DISPONIBILIDADE)
      .getFullList<Disponibilidade>({
        filter: `profissional='${fields.profissionalId}'`,
        requestKey: `disp-${fields.profissionalId}`,
      })
      .then((list) => {
        if (cancelled) return
        setDisp(list[0] ?? null)
        setDispState('loaded')
      })
      .catch(() => {
        if (!cancelled) {
          setDisp(null)
          setDispState('error')
        }
      })
    return () => { cancelled = true }
  }, [fields.profissionalId])

  /* fetch occupied slots when profissional + date change */
  useEffect(() => {
    if (!fields.profissionalId || !fields.data_date) {
      setOcupados([])
      return
    }
    let cancelled = false
    setOcupadosLoading(true)
    const { start, end } = localDateToUTCRange(fields.data_date)
    pb.collection(COLLECTIONS.ORDENS_SERVICO)
      .getFullList<OrdemServico>({
        filter: `profissional='${fields.profissionalId}' && data_hora>='${start}' && data_hora<'${end}' && status!='cancelada'`,
        requestKey: `slots-${fields.profissionalId}-${fields.data_date}`,
      })
      .then((list) => {
        if (cancelled) return
        const times = list
          .filter((o) => o.id !== editingOSId)
          .map((o) => pbToLocalHHMM(o.data_hora))
          .filter(Boolean)
        setOcupados(times)
      })
      .catch(() => { if (!cancelled) setOcupados([]) })
      .finally(() => { if (!cancelled) setOcupadosLoading(false) })
    return () => { cancelled = true }
  }, [fields.profissionalId, fields.data_date, editingOSId])

  /* ---- slot computation ---- */
  const slotAttempt = !!fields.profissionalId
  const slotLoading =
    slotAttempt && (dispState === 'loading' || (dispState === 'loaded' && disp !== null && ocupadosLoading))
  const isSlotMode = slotAttempt && dispState === 'loaded' && disp !== null

  let slotsDisponiveis: string[] = []
  let diaNaoAtende = false
  let diaConf: DisponibilidadeDia | undefined

  if (isSlotMode && fields.data_date) {
    const [y, mo, d] = fields.data_date.split('-').map(Number)
    const weekday = new Date(y, mo - 1, d).getDay()
    diaConf = disp!.dias[weekday]
    if (diaConf.ativo) {
      slotsDisponiveis = gerarSlotsDisponiveis(diaConf, disp!.duracao_min, ocupados)
    } else {
      diaNaoAtende = true
    }
  }

  /* auto-select first available slot when current time is invalid */
  const currentSlot = `${fields.data_time_h}:${fields.data_time_m}`
  useEffect(() => {
    if (!isSlotMode || slotLoading) return
    if (slotsDisponiveis.length === 0) return
    if (slotsDisponiveis.includes(currentSlot)) return
    const [h, m] = slotsDisponiveis[0].split(':')
    onChange('data_time_h', h)
    onChange('data_time_m', m)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSlotMode, slotLoading, slotsDisponiveis.join(','), currentSlot])

  /* ---- Render ---- */
  return (
    <>
      {/* 1. Serviço */}
      <div className="form-field">
        <label>Serviço</label>
        <select
          value={fields.servicoId}
          onChange={(e) => onServicoChange(e.target.value)}
          disabled={loadingLookups}
          className={errs.servicoId ? 'err' : ''}
        >
          <option value="">— Selecionar —</option>
          {servicos.map((s) => (
            <option key={s.id} value={s.id}>{s.nome}</option>
          ))}
        </select>
        {errs.servicoId && <span className="field-err">{errs.servicoId}</span>}
      </div>

      {/* 2. Nome do serviço (snapshot) */}
      <div className="form-field">
        <label>Nome do serviço (snapshot)</label>
        <input
          type="text"
          value={fields.tipo_servico_nome}
          onChange={(e) => onChange('tipo_servico_nome', e.target.value)}
          placeholder="Ex: Sofá 3 lugares"
        />
      </div>

      {/* 3. Profissional */}
      <div className="form-field">
        <label>Profissional</label>
        <select
          value={fields.profissionalId}
          onChange={(e) => onChange('profissionalId', e.target.value)}
          disabled={loadingLookups}
        >
          <option value="">— Não atribuído (status: Agendada) —</option>
          {profissionais.map((p) => (
            <option key={p.id} value={p.id}>{userDisplayName(p)}</option>
          ))}
        </select>
        <span style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)' }}>
          Ao atribuir um profissional, o status passa para "Atribuída".
        </span>
      </div>

      {/* 4. Data */}
      <div className="form-field">
        <label>Data <span className="req">*</span></label>
        <input
          type="date"
          value={fields.data_date}
          min={today}
          onChange={(e) => onChange('data_date', e.target.value)}
          className={errs.data_date ? 'err' : ''}
        />
        {errs.data_date && <span className="field-err">{errs.data_date}</span>}
      </div>

      {/* 5. Horário */}
      <div className="form-field">
        <label>Hora <span className="req">*</span></label>
        {slotLoading ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0' }}>
            <Spinner size={14} />
            <span style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem' }}>Carregando horários…</span>
          </div>
        ) : diaNaoAtende ? (
          <div style={{ color: 'var(--clx-error)', fontSize: '0.85rem', padding: '8px 0' }}>
            Profissional não atende neste dia
          </div>
        ) : isSlotMode ? (
          slotsDisponiveis.length === 0 ? (
            <div style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem', padding: '8px 0' }}>
              Sem horários disponíveis nesta data
            </div>
          ) : (
            <select
              value={currentSlot}
              onChange={(e) => {
                const [h, m] = e.target.value.split(':')
                onChange('data_time_h', h)
                onChange('data_time_m', m)
              }}
            >
              {slotsDisponiveis.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          )
        ) : (
          <div style={{ display: 'flex', gap: 8 }}>
            <select
              value={fields.data_time_h}
              onChange={(e) => onChange('data_time_h', e.target.value)}
              style={{ flex: 1 }}
            >
              {HOURS.map((h) => (
                <option key={h} value={h}>{h}h</option>
              ))}
            </select>
            <select
              value={fields.data_time_m}
              onChange={(e) => onChange('data_time_m', e.target.value)}
              style={{ width: 72 }}
            >
              {MINUTES.map((m) => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          </div>
        )}
      </div>

      {/* 6. Valor */}
      <div className="form-field">
        <label>Valor do serviço (R$) <span className="req">*</span></label>
        <input
          type="number"
          min="0"
          step="0.01"
          value={fields.valor_servico}
          onChange={(e) => onChange('valor_servico', e.target.value)}
          placeholder="0,00"
          className={errs.valor_servico ? 'err' : ''}
        />
        {errs.valor_servico && <span className="field-err">{errs.valor_servico}</span>}
      </div>

      {/* 7. Observações */}
      <div className="form-field form-col-span-2">
        <label>Observações</label>
        <textarea
          value={fields.observacoes}
          onChange={(e) => onChange('observacoes', e.target.value)}
          placeholder="Detalhes adicionais para o serviço…"
          rows={3}
        />
      </div>
    </>
  )
}
