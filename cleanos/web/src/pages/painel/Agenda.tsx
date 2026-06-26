import { Fragment, useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type OrdemServico,
  osStatusLabel,
  formatDateTime,
  formatCurrency,
  formaPagamentoLabel,
} from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconAlertCircle,
  IconChevronLeft,
  IconChevronRight,
} from '../../components/ui/Icon'

/* ---- Types ---- */
type AgendaView = 'dia' | 'semana' | 'mes'

const HOURS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
const DOW_SHORT = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const DOW_ABBR = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

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

export default function Agenda() {
  const navigate = useNavigate()
  const today = new Date()

  const [view, setView] = useState<AgendaView>('semana')
  const [anchor, setAnchor] = useState<Date>(new Date(today.getFullYear(), today.getMonth(), today.getDate()))

  const [osData, setOsData] = useState<OrdemServico[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [detailOS, setDetailOS] = useState<OrdemServico | null>(null)

  const loadGenRef = useRef(0)

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

  /* Navigation */
  function goToday() {
    setAnchor(new Date(today.getFullYear(), today.getMonth(), today.getDate()))
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
    return osData.filter((o) => {
      const d = new Date(o.data_hora)
      return sameDay(d, day) && hourSlot(o) === hour
    })
  }

  /* All events for a given day */
  function eventsForDay(day: Date): OrdemServico[] {
    return osData.filter((o) => sameDay(new Date(o.data_hora), day))
  }

  /* Week days */
  const weekStart = startOfWeek(anchor)
  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i))

  return (
    <div>
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

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando agenda…</div>
      ) : (
        <>
          {view === 'semana' && (
            <WeekView
              weekDays={weekDays}
              today={today}
              eventsFor={eventsFor}
              onEventClick={setDetailOS}
            />
          )}
          {view === 'mes' && (
            <MonthView
              anchor={anchor}
              today={today}
              eventsForDay={eventsForDay}
              onEventClick={setDetailOS}
              onDayClick={(d) => { setView('dia'); setAnchor(d) }}
            />
          )}
          {view === 'dia' && (
            <DayView
              day={anchor}
              today={today}
              eventsFor={eventsFor}
              onEventClick={setDetailOS}
            />
          )}
        </>
      )}

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
    </div>
  )
}

/* ---- Week View ---- */
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

/* ---- Month View ---- */
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

/* ---- Day View ---- */
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
