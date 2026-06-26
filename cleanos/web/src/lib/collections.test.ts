import { describe, it, expect } from 'vitest'
import {
  osStatusLabel,
  formaPagamentoLabel,
  repasseStatusLabel,
  userDisplayName,
  formatCurrency,
  formatDate,
  formatDateTime,
  formatTime,
  toDateInputValue,
  localInputToPBDate,
  pbDateToLocalInput,
  getUtcDayBounds,
  getBrtDayBounds,
  getBrtMonthBounds,
  formatHour,
  OS_STATUS_LIST,
  COLLECTIONS,
} from './collections'

describe('osStatusLabel', () => {
  it('mapeia cada status para o label correto', () => {
    expect(osStatusLabel('agendada')).toBe('Agendada')
    expect(osStatusLabel('atribuida')).toBe('Atribuída')
    expect(osStatusLabel('em_andamento')).toBe('Em andamento')
    expect(osStatusLabel('concluida')).toBe('Concluída')
    expect(osStatusLabel('cancelada')).toBe('Cancelada')
  })

  it('cobre todos os valores de OS_STATUS_LIST', () => {
    OS_STATUS_LIST.forEach(s => {
      expect(osStatusLabel(s)).toBeTruthy()
    })
  })
})

describe('formaPagamentoLabel', () => {
  it('mapeia cada forma de pagamento corretamente', () => {
    expect(formaPagamentoLabel('debito')).toBe('Débito')
    expect(formaPagamentoLabel('credito')).toBe('Crédito')
    expect(formaPagamentoLabel('pix_maquininha')).toBe('Pix (maquininha)')
  })
})

describe('repasseStatusLabel', () => {
  it('pago → Repassado', () => expect(repasseStatusLabel('pago')).toBe('Repassado'))
  it('pendente → Pendente', () => expect(repasseStatusLabel('pendente')).toBe('Pendente'))
})

describe('userDisplayName', () => {
  it('retorna nome quando só name está preenchido', () => {
    expect(userDisplayName({ name: 'Dennis' })).toBe('Dennis')
  })

  it('retorna nome quando só nome está preenchido', () => {
    expect(userDisplayName({ nome: 'Dennis', name: '' })).toBe('Dennis')
  })

  it('prefere nome sobre name quando ambos estão presentes', () => {
    expect(userDisplayName({ nome: 'Dennis Silva', name: 'dennis' })).toBe('Dennis Silva')
  })

  it('cai para name quando nome é string vazia (bug original com ??)', () => {
    expect(userDisplayName({ nome: '', name: 'Dennis' })).toBe('Dennis')
  })

  it('cai para name quando nome é só espaços', () => {
    expect(userDisplayName({ nome: '   ', name: 'Dennis' })).toBe('Dennis')
  })

  it('retorna "—" quando ambos estão ausentes', () => {
    expect(userDisplayName({})).toBe('—')
  })

  it('retorna "—" para null', () => {
    expect(userDisplayName(null)).toBe('—')
  })

  it('retorna "—" para undefined', () => {
    expect(userDisplayName(undefined)).toBe('—')
  })
})

describe('formatCurrency', () => {
  it('retorna string contendo R$', () => {
    expect(formatCurrency(100)).toMatch(/R\$/)
  })

  it('formata 240 em BRL (R$ 240,00)', () => {
    const result = formatCurrency(240)
    expect(result).toMatch(/R\$/)
    expect(result).toMatch(/240/)
    // pt-BR usa vírgula como separador decimal
    expect(result).toContain(',')
  })

  it('formata zero sem quebrar', () => {
    const result = formatCurrency(0)
    expect(result).toMatch(/R\$/)
    expect(result).toMatch(/0/)
  })

  it('formata valor decimal com dois casas', () => {
    const result = formatCurrency(99.5)
    expect(result).toMatch(/99/)
    expect(result).toContain(',')
  })
})

describe('formatDate', () => {
  it('retorna "—" para string vazia', () => {
    expect(formatDate('')).toBe('—')
  })

  it('formata data ISO PocketBase e bate com toLocaleDateString("pt-BR")', () => {
    const iso = '2024-07-04 12:00:00.000Z'
    expect(formatDate(iso)).toBe(new Date(iso).toLocaleDateString('pt-BR'))
  })

  it('resultado contém separadores de data', () => {
    const result = formatDate('2024-07-04 12:00:00.000Z')
    expect(result).toMatch(/\d{2}\/\d{2}\/\d{4}/)
  })
})

describe('formatDateTime', () => {
  it('retorna "—" para string vazia', () => {
    expect(formatDateTime('')).toBe('—')
  })

  it('retorna string não vazia para ISO válido', () => {
    const result = formatDateTime('2024-07-04 12:00:00.000Z')
    expect(result).toBeTruthy()
    expect(result).not.toBe('—')
  })

  it('resultado contém ":" para separar horas e minutos', () => {
    const result = formatDateTime('2024-07-04 12:00:00.000Z')
    expect(result).toMatch(/:/)
  })
})

describe('formatTime', () => {
  it('retorna "—" para string vazia', () => {
    expect(formatTime('')).toBe('—')
  })

  it('formata horário no padrão HH:MM', () => {
    const result = formatTime('2024-07-04 12:00:00.000Z')
    expect(result).toMatch(/\d{2}:\d{2}/)
  })
})

describe('toDateInputValue', () => {
  it('retorna "" para string vazia', () => {
    expect(toDateInputValue('')).toBe('')
  })

  it('extrai YYYY-MM-DD de datetime PocketBase (com espaço)', () => {
    expect(toDateInputValue('2024-07-04 12:00:00.000Z')).toBe('2024-07-04')
  })

  it('extrai YYYY-MM-DD de ISO com T', () => {
    expect(toDateInputValue('2024-07-04T12:00:00.000Z')).toBe('2024-07-04')
  })

  it('preserva exatamente 10 caracteres', () => {
    expect(toDateInputValue('2025-12-31 23:59:00.000Z')).toHaveLength(10)
  })
})

describe('localInputToPBDate', () => {
  it('retorna "" para string vazia', () => {
    expect(localInputToPBDate('')).toBe('')
  })

  it('produz string no formato PB "YYYY-MM-DD HH:MM:SS" sem T', () => {
    const result = localInputToPBDate('2024-07-04T14:30')
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/)
    expect(result).not.toContain('T')
  })

  it('converte horário local para UTC — roundtrip sem perda de instante', () => {
    // Invariante: o resultado interpretado como UTC deve corresponder ao
    // mesmo instante que o input interpretado como horário local.
    const input = '2024-07-04T14:30'
    const pbDate = localInputToPBDate(input)
    const utcMs = new Date(pbDate.replace(' ', 'T') + 'Z').getTime()
    const localMs = new Date(input).getTime()
    expect(utcMs).toBe(localMs)
  })

  it('roundtrip com pbDateToLocalInput recupera o valor original', () => {
    const input = '2025-03-15T09:45'
    expect(pbDateToLocalInput(localInputToPBDate(input))).toBe(input)
  })
})

describe('pbDateToLocalInput', () => {
  it('retorna "" para string vazia', () => {
    expect(pbDateToLocalInput('')).toBe('')
  })

  it('resultado tem exatamente 16 chars (YYYY-MM-DDTHH:mm)', () => {
    const result = pbDateToLocalInput('2025-01-15 09:05:00.000Z')
    expect(result).toHaveLength(16)
  })

  it('contém T como separador entre data e hora', () => {
    expect(pbDateToLocalInput('2024-03-20 08:00:00.000Z')).toContain('T')
  })

  it('converte UTC do PB para horário local — instante preservado no roundtrip', () => {
    // Invariante: o output local parseado pelo browser devolve o mesmo instante UTC.
    const pbDate = '2024-07-04 17:30:00.000Z'
    const localInput = pbDateToLocalInput(pbDate)
    const localMs = new Date(localInput).getTime()
    const utcMs = new Date(pbDate).getTime()
    expect(localMs).toBe(utcMs)
  })
})

describe('getUtcDayBounds', () => {
  it('retorna todayStart e tomorrowStart no formato PB', () => {
    const { todayStart, tomorrowStart } = getUtcDayBounds()
    expect(todayStart).toMatch(/^\d{4}-\d{2}-\d{2} 00:00:00$/)
    expect(tomorrowStart).toMatch(/^\d{4}-\d{2}-\d{2} 00:00:00$/)
  })

  it('tomorrowStart é exatamente 1 dia UTC após todayStart', () => {
    const { todayStart, tomorrowStart } = getUtcDayBounds()
    const todayMs = new Date(todayStart.replace(' ', 'T') + 'Z').getTime()
    const tomorrowMs = new Date(tomorrowStart.replace(' ', 'T') + 'Z').getTime()
    expect(tomorrowMs - todayMs).toBe(24 * 60 * 60 * 1000)
  })
})

describe('formatHour', () => {
  it('retorna "--:--" para string vazia', () => {
    expect(formatHour('')).toBe('--:--')
  })

  it('retorna string no padrão HH:MM', () => {
    expect(formatHour('2024-07-04 12:00:00.000Z')).toMatch(/\d{2}:\d{2}/)
  })
})

describe('COLLECTIONS constantes', () => {
  it('tem os 4 nomes de coleção corretos', () => {
    expect(COLLECTIONS.USERS).toBe('users')
    expect(COLLECTIONS.CLIENTES).toBe('clientes')
    expect(COLLECTIONS.SERVICOS).toBe('servicos')
    expect(COLLECTIONS.ORDENS_SERVICO).toBe('ordens_servico')
  })
})

describe('getBrtDayBounds', () => {
  it('retorna todayStart e tomorrowStart no formato PB', () => {
    const { todayStart, tomorrowStart } = getBrtDayBounds()
    expect(todayStart).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$/)
    expect(tomorrowStart).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$/)
  })

  it('tomorrowStart é exatamente 24h após todayStart', () => {
    const { todayStart, tomorrowStart } = getBrtDayBounds()
    const todayMs = new Date(todayStart.replace(' ', 'T') + 'Z').getTime()
    const tomorrowMs = new Date(tomorrowStart.replace(' ', 'T') + 'Z').getTime()
    expect(tomorrowMs - todayMs).toBe(24 * 60 * 60 * 1000)
  })

  it('todayStart corresponde à meia-noite do dia LOCAL', () => {
    const { todayStart } = getBrtDayBounds()
    const now = new Date()
    const localMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const startMs = new Date(todayStart.replace(' ', 'T') + 'Z').getTime()
    expect(startMs).toBe(localMidnight.getTime())
  })

  it('tomorrowStart corresponde à meia-noite do dia seguinte LOCAL', () => {
    const { tomorrowStart } = getBrtDayBounds()
    const now = new Date()
    const nextMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
    const endMs = new Date(tomorrowStart.replace(' ', 'T') + 'Z').getTime()
    expect(endMs).toBe(nextMidnight.getTime())
  })
})

describe('getBrtMonthBounds', () => {
  it('retorna start e end no formato PB', () => {
    const { start, end } = getBrtMonthBounds(2025, 0)
    expect(start).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$/)
    expect(end).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$/)
  })

  it('start corresponde à meia-noite local do 1º do mês', () => {
    const { start } = getBrtMonthBounds(2025, 0)
    const expected = new Date(2025, 0, 1)
    const startMs = new Date(start.replace(' ', 'T') + 'Z').getTime()
    expect(startMs).toBe(expected.getTime())
  })

  it('end é 1º do mês seguinte (meia-noite local)', () => {
    const { end } = getBrtMonthBounds(2025, 5)
    const expected = new Date(2025, 6, 1)
    const endMs = new Date(end.replace(' ', 'T') + 'Z').getTime()
    expect(endMs).toBe(expected.getTime())
  })

  it('dezembro → end é 1º de janeiro do ano seguinte', () => {
    const { end } = getBrtMonthBounds(2025, 11)
    const expected = new Date(2026, 0, 1)
    const endMs = new Date(end.replace(' ', 'T') + 'Z').getTime()
    expect(endMs).toBe(expected.getTime())
  })

  it('range de junho de 2025 abrange exatamente 30 dias', () => {
    const { start, end } = getBrtMonthBounds(2025, 5)
    const startMs = new Date(start.replace(' ', 'T') + 'Z').getTime()
    const endMs = new Date(end.replace(' ', 'T') + 'Z').getTime()
    expect((endMs - startMs) / (24 * 60 * 60 * 1000)).toBe(30)
  })
})
