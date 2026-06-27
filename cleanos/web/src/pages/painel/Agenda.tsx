import { Fragment, useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type OrdemServico,
  type User,
  type Disponibilidade,
  type DisponibilidadeDia,
  osStatusLabel,
  formatDateTime,
  formatCurrency,
  formaPagamentoLabel,
  userDisplayName,
} from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconAlertCircle,
  IconChevronLeft,
  IconChevronRight,
  IconSettings,
  IconCheckCircle,
} from '../../components/ui/Icon'
import { useIsMobile } from '../../hooks/useIsMobile'
import { useAuth } from '../../contexts/AuthContext'

/* ---- Types ---- */
type AgendaView = 'dia' | 'semana' | 'mes'

const HOURS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
const DOW_SHORT = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const DOW_ABBR = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const DIAS_SEMANA = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']
const DEFAULT_DIA: DisponibilidadeDia = { ativo: false, inicio: '08:00', fim: '18:00' }

/* ---- Date helpers ---- */

function startOfWeek(d: Date): Date {
  const r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const day = r.getDay()
  r.setDate(r.getDate() - (day === 0 ? 6 : day - 1))
  return r
}

function addDays(d: Date, n: number): Date {
  const r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  r.setDate(r.getDate() + n)
  return r
}

function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  )
}

function toUtcStr(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:00`
}

function getMonthCalendar(year: number, month: number): Date[][] {
  const firstDay = new Date(year, month, 1)
  let d = startOfWeek(firstDay)
  const weeks: Date[][] = []
  for (let w = 0; w < 6; w++) {
    const week: Date[] = []
    for (let i = 0; i < 7; i++) {
      week.push(new Date(d))
      d = addDays(d, 1)
    }
    weeks.push(week)
    if (d.getMonth() > month || d.getFullYear() > year) break
  }
  return weeks
}

/* ---- Hour slot for an event ---- */
function hourSlot(os: OrdemServico): number {
  const h = new Date(os.data_hora).getHours()
  return Math.max(HOURS[0], Math.min(HOURS[HOURS.length - 1], h))
}

/* ---- Event color class ---- */
function eventClass(os: OrdemServico): string {
  return `os-event-${os.status}`
}

/* ---- Period label ---- */
function periodLabel(view: AgendaView, anchor: Date): string {
  if (view === 'dia') {
    return anchor.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' })
  }
  if (view === 'semana') {
    const ws = startOfWeek(anchor)
    const we = addDays(ws, 6)
    const wsStr = ws.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' })
    const weStr = we.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' })
    return `${wsStr} – ${weStr}`
  }
  return anchor.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
}

/* ---- Compute load range based on view ---- */
function getLoadRange(view: AgendaView, anchor: Date): { from: Date; to: Date } {
  if (view === 'dia') {
    const from = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate(), 0, 0, 0)
    const to = addDays(from, 1)
    return { from, to }
  }
  if (view === 'semana') {
    const from = startOfWeek(anchor)
    const to = addDays(from, 7)
    return { from, to }
  }
  // mes
  const firstDay = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
  const from = startOfWeek(firstDay)
  const to = addDays(from, 42)
  return { from, to }
}

/* ======================================================
   DISPONIBILIDADE MODAL
   ====================================================== */

function DisponibilidadeModal({
  profissional,
  open,
  onClose,
}: {
  profissional: User
  open: boolean
  onClose: () => void
}) {
  const [dias, setDias] = useState<DisponibilidadeDia[]>(
    () => Array.from({ length: 7 }, () => ({ ...DEFAULT_DIA }))
  )
  const [duracaoMin, setDuracaoMin] = useState(60)
  const [existingId, setExistingId] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [saveErr, setSaveErr] = useState<string | null>(null)
  const [saveOk, setSaveOk] = useState(false)

  useEffect(() => {
    if (!open) return
    setLoading(true)
    setSaveErr(null)
    setSaveOk(false)
    pb.collection(COLLECTIONS.DISPONIBILIDADE)
      .getFullList<Disponibilidade>({ filter: `profissional='${profissional.id}'` })
      .then((list) => {
        const d = list[0]
        if (d) {
          setExistingId(d.id)
          setDias(d.dias.map((x) => ({ ...x })))
          setDuracaoMin(d.duracao_min)
        } else {
          setExistingId(null)
          setDias(Array.from({ length: 7 }, () => ({ ...DEFAULT_DIA })))
          setDuracaoMin(60)
        }
      })
      .catch(() => {
        setExistingId(null)
        setDias(Array.from({ length: 7 }, () => ({ ...DEFAULT_DIA })))
        setDuracaoMin(60)
      })
      .finally(() => setLoading(false))
  }, [open, profissional.id])

  function updateDia(idx: number, patch: Partial<DisponibilidadeDia>) {
    setDias((prev) => prev.map((d, i) => (i === idx ? { ...d, ...patch } : d)))
  }

  async function handleSave() {
    setSaving(true)
    setSaveErr(null)
    setSaveOk(false)
    try {
      const payload = { profissional: profissional.id, duracao_min: duracaoMin, dias }
      if (existingId) {
        await pb.collection(COLLECTIONS.DISPONIBILIDADE).update(existingId, payload)
      } else {
        const record = await pb.collection(COLLECTIONS.DISPONIBILIDADE).create<Disponibilidade>(payload)
        setExistingId(record.id)
      }
      setSaveOk(true)
    } catch (e) {
      setSaveErr(e instanceof Error ? e.message : 'Erro ao salvar disponibilidade.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`Disponibilidade — ${userDisplayName(profissional)}`}
      size="md"
      footer={
        <>
          <button className="clx-btn clx-btn-ghost" onClick={onClose} disabled={saving}>
            Fechar
          </button>
          <button className="clx-btn clx-btn-accent" onClick={handleSave} disabled={saving || loading}>
            {saving ? <><Spinner size={14} /> Salvando…</> : 'Salvar'}
          </button>
        </>
      }
    >
      {loading ? (
        <div className="loading-overlay"><Spinner size={20} /> Carregando…</div>
      ) : (
        <>
          {saveErr && (
            <div className="error-banner" role="alert" style={{ marginBottom: 12 }}>
              <IconAlertCircle size={15} /> {saveErr}
            </div>
          )}
          {saveOk && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--clx-success, #16a34a)', marginBottom: 12, fontSize: '0.875rem' }}>
              <IconCheckCircle size={15} /> Salvo com sucesso
            </div>
          )}

          <div className="form-field" style={{ marginBottom: 16 }}>
            <label>Duração do serviço (min)</label>
            <input
              type="number"
              min="15"
              step="15"
              value={duracaoMin}
              onChange={(e) => setDuracaoMin(Math.max(15, Number(e.target.value)))}
              style={{ maxWidth: 120 }}
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {DIAS_SEMANA.map((nome, idx) => (
              <div
                key={idx}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  flexWrap: 'wrap',
                  padding: '8px 10px',
                  background: dias[idx].ativo ? 'var(--clx-bg-2)' : 'transparent',
                  borderRadius: 'var(--clx-r-md)',
                  border: '1px solid var(--clx-line)',
                }}
              >
                <label
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    minWidth: 90,
                    fontWeight: 500,
                    fontSize: '0.875rem',
                    cursor: 'pointer',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={dias[idx].ativo}
                    onChange={(e) => updateDia(idx, { ativo: e.target.checked })}
                  />
                  {nome}
                </label>
                {dias[idx].ativo && (
                  <>
                    <input
                      type="time"
                      value={dias[idx].inicio}
                      step="900"
                      onChange={(e) => updateDia(idx, { inicio: e.target.value })}
                      style={{
                        padding: '4px 8px',
                        background: 'var(--clx-bg)',
                        border: '1.5px solid var(--clx-line)',
                        borderRadius: 'var(--clx-r-md)',
                        fontSize: '0.875rem',
                        color: 'var(--clx-ink)',
                      }}
                    />
                    <span style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem' }}>até</span>
                    <input
                      type="time"
                      value={dias[idx].fim}
                      step="900"
                      onChange={(e) => updateDia(idx, { fim: e.target.value })}
                      style={{
                        padding: '4px 8px',
                        background: 'var(--clx-bg)',
                        border: '1.5px solid var(--clx-line)',
                        borderRadius: 'var(--clx-r-md)',
                        fontSize: '0.875rem',
                        color: 'var(--clx-ink)',
                      }}
                    />
                  </>
                )}
              </div>
            ))}
          </div>
        </>
      )}
    </Modal>
  )
}

/* ======================================================
   MAIN Agenda COMPONENT
   ====================================================== */

export default function Agenda() {
  const navigate = useNavigate()
  const today = new Date()
  const isMobile = useIsMobile()
  const { role } = useAuth()
  const canManageDisp = role === 'admin' || role === 'gerente'

  const [view, setView] = useState<AgendaView>(isMobile ? 'dia' : 'semana')
  const [anchor, setAnchor] = useState<Date>(new Date(today.getFullYear(), today.getMonth(), today.getDate()))
  const [selectedDay, setSelectedDay] = useState<Date>(new Date(today.getFullYear(), today.getMonth(), today.getDate()))

  const [osData, setOsData] = useState<OrdemServico[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [detailOS, setDetailOS] = useState<OrdemServico | null>(null)

  /* profissional filter */
  const [profs, setProfs] = useState<User[]>([])
  const [filterProfId, setFilterProfId] = useState('')
  const [dispModalOpen, setDispModalOpen] = useState(false)

  const loadGenRef = useRef(0)

  /* load profissionais on mount */
  useEffect(() => {
    pb.collection(COLLECTIONS.USERS)
      .getFullList<User>({ filter: "role='profissional'", sort: 'nome,name' })
      .then(setProfs)
      .catch(() => {})
  }, [])

  /* close disp modal when filter cleared */
  useEffect(() => {
    if (!filterProfId) setDispModalOpen(false)
  }, [filterProfId])

  // Sync selectedDay when navigating months in mobile month view
  useEffect(() => {
    if (view !== 'mes') return
    const inSameMonth =
      selectedDay.getMonth() === anchor.getMonth() &&
      selectedDay.getFullYear() === anchor.getFullYear()
    if (inSameMonth) return
    const todayInAnchor =
      today.getFullYear() === anchor.getFullYear() &&
      today.getMonth() === anchor.getMonth()
    setSelectedDay(
      todayInAnchor
        ? new Date(today.getFullYear(), today.getMonth(), today.getDate())
        : new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate())
    )
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [anchor, view])

  const load = useCallback(async () => {
    const gen = ++loadGenRef.current
    const { from, to } = getLoadRange(view, anchor)
    try {
      setLoading(true)
      setError(null)
      const list = await pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
        filter: `data_hora >= '${toUtcStr(from)}' && data_hora < '${toUtcStr(to)}'`,
        sort: 'data_hora',
        expand: 'profissional',
      })
      if (gen !== loadGenRef.current) return
      setOsData(list)
    } catch {
      if (gen === loadGenRef.current) setError('Não foi possível carregar a agenda.')
    } finally {
      if (gen === loadGenRef.current) setLoading(false)
    }
  }, [view, anchor])

  useEffect(() => { load() }, [load])

  /* profissional filter applied in-memory */
  const filteredOsData = filterProfId
    ? osData.filter((o) => o.profissional === filterProfId)
    : osData

  /* Navigation */
  function goToday() {
    const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
    setAnchor(todayDate)
    setSelectedDay(todayDate)
  }
  function goPrev() {
    if (view === 'dia') setAnchor((a) => addDays(a, -1))
    else if (view === 'semana') setAnchor((a) => addDays(a, -7))
    else setAnchor((a) => new Date(a.getFullYear(), a.getMonth() - 1, 1))
  }
  function goNext() {
    if (view === 'dia') setAnchor((a) => addDays(a, 1))
    else if (view === 'semana') setAnchor((a) => addDays(a, 7))
    else setAnchor((a) => new Date(a.getFullYear(), a.getMonth() + 1, 1))
  }

  /* Events for a given day + hour */
  function eventsFor(day: Date, hour: number): OrdemServico[] {
    return filteredOsData.filter((o) => {
      const d = new Date(o.data_hora)
      return sameDay(d, day) && hourSlot(o) === hour
    })
  }

  /* All events for a given day */
  function eventsForDay(day: Date): OrdemServico[] {
    return filteredOsData.filter((o) => sameDay(new Date(o.data_hora), day))
  }

  /* Week days */
  const weekStart = startOfWeek(anchor)
  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i))

  const selectedProf = filterProfId ? profs.find((p) => p.id === filterProfId) : undefined

  return (
    <div className="agenda-root">
      {/* Toolbar */}
      <div className="agenda-toolbar">
        <div className="agenda-nav">
          <button className="agenda-nav-btn" onClick={goPrev} aria-label="Anterior">
            <IconChevronLeft size={14} />
          </button>
          <span className="agenda-period-label">{periodLabel(view, anchor)}</span>
          <button className="agenda-nav-btn" onClick={goNext} aria-label="Próximo">
            <IconChevronRight size={14} />
          </button>
        </div>

        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={goToday}>
          Hoje
        </button>
        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 4 }}>
          Atualizar
        </button>

        {/* Profissional filter */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <select
            value={filterProfId}
            onChange={(e) => setFilterProfId(e.target.value)}
            style={{
              padding: '4px 10px',
              background: 'var(--clx-bg-2)',
              border: '1.5px solid var(--clx-line)',
              borderRadius: 'var(--clx-r-md)',
              fontSize: '0.8rem',
              color: 'var(--clx-ink)',
              outline: 'none',
              cursor: 'pointer',
            }}
          >
            <option value="">Todos os profissionais</option>
            {profs.map((p) => (
              <option key={p.id} value={p.id}>{userDisplayName(p)}</option>
            ))}
          </select>
          {filterProfId && canManageDisp && (
            <button
              className="icon-btn"
              title="Configurar disponibilidade"
              onClick={() => setDispModalOpen(true)}
            >
              <IconSettings size={15} />
            </button>
          )}
        </div>

        <div className="agenda-view-tabs">
          {(['dia', 'semana', 'mes'] as AgendaView[]).map((v) => (
            <button
              key={v}
              className={`agenda-view-btn${view === v ? ' active' : ''}`}
              onClick={() => setView(v)}
            >
              {v.charAt(0).toUpperCase() + v.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
        </div>
      )}

      <div className="agenda-body">
      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando agenda…</div>
      ) : (
        <>
          {view === 'semana' && (
            isMobile ? (
              <MobileWeekView
                weekDays={weekDays}
                today={today}
                eventsForDay={eventsForDay}
                onEventClick={setDetailOS}
              />
            ) : (
              <WeekView
                weekDays={weekDays}
                today={today}
                eventsFor={eventsFor}
                onEventClick={setDetailOS}
              />
            )
          )}
          {view === 'mes' && (
            isMobile ? (
              <MobileMonthView
                anchor={anchor}
                today={today}
                selectedDay={selectedDay}
                onSelectDay={setSelectedDay}
                eventsForDay={eventsForDay}
                onEventClick={setDetailOS}
              />
            ) : (
              <MonthView
                anchor={anchor}
                today={today}
                eventsForDay={eventsForDay}
                onEventClick={setDetailOS}
                onDayClick={(d) => { setView('dia'); setAnchor(d) }}
              />
            )
          )}
          {view === 'dia' && (
            isMobile ? (
              <MobileDayView
                day={anchor}
                today={today}
                events={eventsForDay(anchor)}
                onEventClick={setDetailOS}
              />
            ) : (
              <DayView
                day={anchor}
                today={today}
                eventsFor={eventsFor}
                onEventClick={setDetailOS}
              />
            )
          )}
        </>
      )}
      </div>{/* /agenda-body */}

      {/* Detail modal */}
      {detailOS && (
        <Modal
          open={!!detailOS}
          onClose={() => setDetailOS(null)}
          title={detailOS.nome_curto}
          size="sm"
          footer={
            <div style={{ display: 'flex', gap: 8, width: '100%', justifyContent: 'space-between' }}>
              <button
                className="clx-btn clx-btn-ghost clx-btn-sm"
                onClick={() => { setDetailOS(null); navigate('/painel/ordens') }}
              >
                Ver em Ordens
              </button>
              <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={() => setDetailOS(null)}>
                Fechar
              </button>
            </div>
          }
        >
          <OSMiniDetail os={detailOS} />
        </Modal>
      )}

      {/* Disponibilidade modal */}
      {selectedProf && (
        <DisponibilidadeModal
          profissional={selectedProf}
          open={dispModalOpen}
          onClose={() => setDispModalOpen(false)}
        />
      )}
    </div>
  )
}

/* ======================================================
   DESKTOP VIEWS — unchanged
   ====================================================== */

/* ---- Week View (desktop) ---- */
function WeekView({
  weekDays, today, eventsFor, onEventClick,
}: {
  weekDays: Date[]
  today: Date
  eventsFor: (day: Date, hour: number) => OrdemServico[]
  onEventClick: (os: OrdemServico) => void
}) {
  return (
    <div className="cal-week">
      {/* Header */}
      <div className="cal-week-header">
        <div style={{ gridColumn: 1, borderBottom: 'none' }} />
        {weekDays.map((day, i) => (
          <div
            key={i}
            className={`cal-week-day-header${sameDay(day, today) ? ' today' : ''}`}
          >
            <div className="dow">{DOW_SHORT[day.getDay()]}</div>
            <div className="date">{day.getDate()}</div>
          </div>
        ))}
      </div>

      {/* Body */}
      <div className="cal-week-body">
        {HOURS.map((h) => (
          <Fragment key={h}>
            <div className="cal-hour-label">{h}:00</div>
            {weekDays.map((day, di) => {
              const events = eventsFor(day, h)
              return (
                <div key={di} className="cal-week-cell">
                  {events.map((os) => (
                    <div
                      key={os.id}
                      className={`cal-week-event ${eventClass(os)}`}
                      onClick={() => onEventClick(os)}
                      title={`${os.nome_curto} — ${osStatusLabel(os.status)}`}
                    >
                      {new Date(os.data_hora).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}{' '}
                      {os.nome_curto}
                    </div>
                  ))}
                </div>
              )
            })}
          </Fragment>
        ))}
      </div>
    </div>
  )
}

/* ---- Month View (desktop) ---- */
function MonthView({
  anchor, today, eventsForDay, onEventClick, onDayClick,
}: {
  anchor: Date
  today: Date
  eventsForDay: (day: Date) => OrdemServico[]
  onEventClick: (os: OrdemServico) => void
  onDayClick: (day: Date) => void
}) {
  const weeks = getMonthCalendar(anchor.getFullYear(), anchor.getMonth())
  return (
    <div className="cal-month">
      <div className="cal-month-header">
        {DOW_ABBR.map((d) => (
          <div key={d} className="cal-month-dow">{d}</div>
        ))}
      </div>
      <div className="cal-month-grid">
        {weeks.flatMap((week) =>
          week.map((day, i) => {
            const events = eventsForDay(day)
            const isToday = sameDay(day, today)
            const isOtherMonth = day.getMonth() !== anchor.getMonth()
            return (
              <div
                key={`${day.toISOString()}-${i}`}
                className={`cal-day${isToday ? ' today' : ''}${isOtherMonth ? ' other-month' : ''}`}
                onClick={() => onDayClick(day)}
              >
                <div className="cal-day-num">{day.getDate()}</div>
                {events.slice(0, 3).map((os) => (
                  <div
                    key={os.id}
                    className={`cal-event ${eventClass(os)}`}
                    onClick={(e) => { e.stopPropagation(); onEventClick(os) }}
                    title={`${os.nome_curto} — ${osStatusLabel(os.status)}`}
                  >
                    {new Date(os.data_hora).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}{' '}
                    {os.nome_curto}
                  </div>
                ))}
                {events.length > 3 && (
                  <div style={{ fontSize: '0.68rem', color: 'var(--clx-ink-3)', paddingLeft: 4 }}>
                    +{events.length - 3} mais
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}

/* ---- Day View (desktop) ---- */
function DayView({
  day, today, eventsFor, onEventClick,
}: {
  day: Date
  today: Date
  eventsFor: (day: Date, hour: number) => OrdemServico[]
  onEventClick: (os: OrdemServico) => void
}) {
  const isToday = sameDay(day, today)
  const label = day.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' })
  return (
    <div className="cal-day-view">
      <div className={`cal-day-header${isToday ? '' : ''}`}>
        {label}{isToday ? ' — Hoje' : ''}
      </div>
      <div className="cal-day-slots">
        {HOURS.map((h) => {
          const events = eventsFor(day, h)
          return (
            <div key={h} className="cal-day-slot">
              <div className="cal-day-slot-label">{h}:00</div>
              <div className="cal-day-slot-events">
                {events.map((os) => (
                  <div
                    key={os.id}
                    className={`cal-day-event ${eventClass(os)}`}
                    onClick={() => onEventClick(os)}
                  >
                    <strong>
                      {new Date(os.data_hora).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}
                    </strong>{' '}
                    {os.nome_curto} — {os.tipo_servico_nome ?? '—'}
                    {os.expand?.profissional && (
                      <span style={{ marginLeft: 6, opacity: 0.75 }}>
                        · {os.expand.profissional.nome ?? os.expand.profissional.name}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

/* ======================================================
   MOBILE VIEWS
   ====================================================== */

/* ---- Agenda Mini-card (used in all mobile views) ---- */
function AgendaMiniCard({ os, onClick }: { os: OrdemServico; onClick: () => void }) {
  const prof = os.expand?.profissional
  const profName = prof ? (prof.nome ?? prof.name) : null
  const time = new Date(os.data_hora).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  return (
    <div className={`agenda-mini-card agenda-mc-${os.status}`} onClick={onClick}>
      <div className="agenda-mini-card-time">{time}</div>
      <div className="agenda-mini-card-body">
        <div className="agenda-mini-card-client">{os.nome_curto}</div>
        <div className="agenda-mini-card-sub">
          {os.tipo_servico_nome ?? '—'}
          {profName && <> · {profName}</>}
        </div>
      </div>
      <span className={`clx-status clx-status-${os.status}`}>{osStatusLabel(os.status)}</span>
    </div>
  )
}

/* ---- Mobile Day View ---- */
function MobileDayView({
  day, today, events, onEventClick,
}: {
  day: Date
  today: Date
  events: OrdemServico[]
  onEventClick: (os: OrdemServico) => void
}) {
  const isToday = sameDay(day, today)
  const label = day.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' })
  return (
    <div className="cal-agenda-mobile">
      <div className={`cal-agenda-mobile-header${isToday ? ' today' : ''}`}>
        {label}{isToday ? ' — Hoje' : ''}
      </div>
      {events.length === 0 ? (
        <div className="agenda-empty-day">Sem atendimentos neste dia</div>
      ) : (
        <div className="agenda-mini-list">
          {events.map((os) => (
            <AgendaMiniCard key={os.id} os={os} onClick={() => onEventClick(os)} />
          ))}
        </div>
      )}
    </div>
  )
}

/* ---- Mobile Week View — agenda list grouped by day ---- */
function MobileWeekView({
  weekDays, today, eventsForDay, onEventClick,
}: {
  weekDays: Date[]
  today: Date
  eventsForDay: (day: Date) => OrdemServico[]
  onEventClick: (os: OrdemServico) => void
}) {
  const hasAnyEvents = weekDays.some((day) => eventsForDay(day).length > 0)

  if (!hasAnyEvents) {
    return (
      <div className="agenda-empty-week">
        <p>Nenhum atendimento nesta semana.</p>
      </div>
    )
  }

  return (
    <div className="cal-agenda-week">
      {weekDays.map((day) => {
        const events = eventsForDay(day)
        if (events.length === 0) return null
        const isToday = sameDay(day, today)
        const dayLabel = day
          .toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: 'short' })
          .toUpperCase()
        return (
          <div key={day.toISOString()} className="cal-agenda-day-group">
            <div className={`cal-agenda-day-header${isToday ? ' today' : ''}`}>
              {dayLabel}
              {isToday && <span className="cal-agenda-today-chip">Hoje</span>}
            </div>
            <div className="agenda-mini-list">
              {events.map((os) => (
                <AgendaMiniCard key={os.id} os={os} onClick={() => onEventClick(os)} />
              ))}
            </div>
          </div>
        )
      })}
    </div>
  )
}

/* ---- Mobile Month View — compact grid + day list ---- */
function MobileMonthView({
  anchor, today, selectedDay, onSelectDay, eventsForDay, onEventClick,
}: {
  anchor: Date
  today: Date
  selectedDay: Date
  onSelectDay: (d: Date) => void
  eventsForDay: (day: Date) => OrdemServico[]
  onEventClick: (os: OrdemServico) => void
}) {
  const weeks = getMonthCalendar(anchor.getFullYear(), anchor.getMonth())
  const selectedEvents = eventsForDay(selectedDay)

  return (
    <div className="cal-month-mobile">
      {/* DOW header */}
      <div className="cal-month-mobile-header">
        {DOW_SHORT.map((d) => (
          <div key={d} className="cal-month-mobile-dow">{d}</div>
        ))}
      </div>

      {/* Compact day grid */}
      <div className="cal-month-mobile-grid">
        {weeks.flatMap((week) =>
          week.map((day, i) => {
            const events = eventsForDay(day)
            const isToday = sameDay(day, today)
            const isSelected = sameDay(day, selectedDay)
            const isOtherMonth = day.getMonth() !== anchor.getMonth()
            const cls = [
              'cal-day-mobile',
              isToday ? 'today' : '',
              isSelected ? 'selected' : '',
              isOtherMonth ? 'other-month' : '',
            ].filter(Boolean).join(' ')
            return (
              <div
                key={`${day.toISOString()}-${i}`}
                className={cls}
                onClick={() => onSelectDay(day)}
              >
                <div className="cal-day-num">{day.getDate()}</div>
                {events.length > 0 && (
                  <div className="cal-month-dot-row">
                    {events.length <= 3
                      ? events.map((os, idx) => (
                          <span key={idx} className={`cal-month-dot cal-dot-${os.status}`} />
                        ))
                      : (
                        <>
                          {events.slice(0, 2).map((os, idx) => (
                            <span key={idx} className={`cal-month-dot cal-dot-${os.status}`} />
                          ))}
                          <span className="cal-month-more">+{events.length - 2}</span>
                        </>
                      )
                    }
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>

      {/* Selected day event list */}
      <div className="cal-day-events-list">
        <div className="cal-day-events-header">
          {selectedDay.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' })}
        </div>
        {selectedEvents.length === 0 ? (
          <div className="agenda-empty-day">Sem atendimentos neste dia</div>
        ) : (
          <div className="agenda-mini-list">
            {selectedEvents.map((os) => (
              <AgendaMiniCard key={os.id} os={os} onClick={() => onEventClick(os)} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

/* ---- OS mini-detail for modal ---- */
function OSMiniDetail({ os }: { os: OrdemServico }) {
  const prof = os.expand?.profissional
  return (
    <div>
      <div className="detail-section">
        <h4>Identificação</h4>
        <dl>
          <div className="detail-row">
            <dt>Bairro</dt><dd>{os.bairro}</dd>
          </div>
          <div className="detail-row">
            <dt>Serviço</dt><dd>{os.tipo_servico_nome ?? '—'}</dd>
          </div>
          <div className="detail-row">
            <dt>Data / Hora</dt><dd>{formatDateTime(os.data_hora)}</dd>
          </div>
          <div className="detail-row">
            <dt>Status</dt>
            <dd>
              <span className={`clx-status clx-status-${os.status}`}>
                {osStatusLabel(os.status)}
              </span>
            </dd>
          </div>
          <div className="detail-row">
            <dt>Profissional</dt>
            <dd>{prof ? (prof.nome ?? prof.name) : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}</dd>
          </div>
        </dl>
      </div>
      {os.status === 'concluida' && (
        <div className="detail-section">
          <h4>Financeiro</h4>
          <dl>
            <div className="detail-row">
              <dt>Valor pago</dt>
              <dd>{os.valor_pago != null ? formatCurrency(os.valor_pago) : '—'}</dd>
            </div>
            {os.forma_pagamento && (
              <div className="detail-row">
                <dt>Forma</dt>
                <dd>{formaPagamentoLabel(os.forma_pagamento)}</dd>
              </div>
            )}
          </dl>
        </div>
      )}
    </div>
  )
}
