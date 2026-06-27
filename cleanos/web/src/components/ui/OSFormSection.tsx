import { todayLocalDate, pbDateToLocalInput, type Servico, type User, userDisplayName } from '../../lib/collections'

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

interface OSFormSectionProps {
  servicos: Servico[]
  profissionais: User[]
  fields: OSFields
  errs: Record<string, string>
  onChange: (k: keyof OSFields, v: string) => void
  onServicoChange: (id: string) => void
  loadingLookups?: boolean
}

export function OSFormSection({
  servicos,
  profissionais,
  fields,
  errs,
  onChange,
  onServicoChange,
  loadingLookups = false,
}: OSFormSectionProps) {
  const today = todayLocalDate()

  return (
    <>
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

      <div className="form-field">
        <label>Nome do serviço (snapshot)</label>
        <input
          type="text"
          value={fields.tipo_servico_nome}
          onChange={(e) => onChange('tipo_servico_nome', e.target.value)}
          placeholder="Ex: Sofá 3 lugares"
        />
      </div>

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

      <div className="form-field">
        <label>Hora <span className="req">*</span></label>
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
      </div>

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
