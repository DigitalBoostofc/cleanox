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
  maskPhoneBR,
  onlyDigitsPhone,
  splitNome,
  maskCEP,
  gerarSlotsDisponiveis,
} from './collections'
import type { DisponibilidadeDia } from './collections'

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
  it('tem os 5 nomes de coleção corretos', () => {
    expect(COLLECTIONS.USERS).toBe('users')
    expect(COLLECTIONS.CLIENTES).toBe('clientes')
    expect(COLLECTIONS.SERVICOS).toBe('servicos')
    expect(COLLECTIONS.ORDENS_SERVICO).toBe('ordens_servico')
    expect(COLLECTIONS.DISPONIBILIDADE).toBe('disponibilidade')
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

describe('maskPhoneBR', () => {
  it('celular 11 dígitos: 85997385758 → (85) 99738-5758', () => {
    expect(maskPhoneBR('85997385758')).toBe('(85) 99738-5758')
  })

  it('fixo 10 dígitos: 8534567890 → (85) 3456-7890', () => {
    expect(maskPhoneBR('8534567890')).toBe('(85) 3456-7890')
  })

  it('entrada com lixo é formatada corretamente', () => {
    expect(maskPhoneBR('(85) 99738-5758')).toBe('(85) 99738-5758')
    expect(maskPhoneBR('85 99738 5758')).toBe('(85) 99738-5758')
    expect(maskPhoneBR('abc85xyz997385758zzz')).toBe('(85) 99738-5758')
  })

  it('parcial 4 dígitos: 8599 → (85) 99', () => {
    expect(maskPhoneBR('8599')).toBe('(85) 99')
  })

  it('parcial 2 dígitos: 85 → (85', () => {
    expect(maskPhoneBR('85')).toBe('(85')
  })

  it('parcial 1 dígito: 8 → (8', () => {
    expect(maskPhoneBR('8')).toBe('(8')
  })

  it('string vazia → string vazia', () => {
    expect(maskPhoneBR('')).toBe('')
  })

  it('limita a 11 dígitos (ignora excedente)', () => {
    expect(maskPhoneBR('859973857589999')).toBe('(85) 99738-5758')
  })

  it('parcial 7 dígitos (fixo parcial): 8534567 → (85) 3456-7', () => {
    expect(maskPhoneBR('8534567')).toBe('(85) 3456-7')
  })
})

describe('onlyDigitsPhone', () => {
  it('remove não-dígitos', () => {
    expect(onlyDigitsPhone('(85) 99738-5758')).toBe('85997385758')
  })

  it('string só com dígitos permanece igual', () => {
    expect(onlyDigitsPhone('85997385758')).toBe('85997385758')
  })

  it('string vazia → vazia', () => {
    expect(onlyDigitsPhone('')).toBe('')
  })
})

describe('splitNome', () => {
  it('nome com sobrenome → divide no primeiro espaço', () => {
    const r = splitNome('Carlos Silva')
    expect(r.nome).toBe('Carlos')
    expect(r.sobrenome).toBe('Silva')
  })

  it('nome composto no sobrenome → restante vai todo pro sobrenome', () => {
    const r = splitNome('João da Silva Sauro')
    expect(r.nome).toBe('João')
    expect(r.sobrenome).toBe('da Silva Sauro')
  })

  it('só uma palavra → sobrenome vazio', () => {
    const r = splitNome('Carlos')
    expect(r.nome).toBe('Carlos')
    expect(r.sobrenome).toBe('')
  })

  it('string vazia → ambos vazios', () => {
    const r = splitNome('')
    expect(r.nome).toBe('')
    expect(r.sobrenome).toBe('')
  })

  it('string só com espaços → ambos vazios', () => {
    const r = splitNome('   ')
    expect(r.nome).toBe('')
    expect(r.sobrenome).toBe('')
  })

  it('espaços extras entre palavras → sobrenome sem espaço líder', () => {
    const r = splitNome('  Ana   Lima  ')
    expect(r.nome).toBe('Ana')
    expect(r.sobrenome).toBe('Lima')
  })
})

describe('maskCEP', () => {
  it('8 dígitos → NNNNN-NNN', () => {
    expect(maskCEP('01310100')).toBe('01310-100')
  })

  it('já mascarado → mantém corretamente', () => {
    expect(maskCEP('01310-100')).toBe('01310-100')
  })

  it('parcial 4 dígitos → sem traço', () => {
    expect(maskCEP('0131')).toBe('0131')
  })

  it('parcial 6 dígitos → NNNNN-N', () => {
    expect(maskCEP('013101')).toBe('01310-1')
  })

  it('string vazia → vazia', () => {
    expect(maskCEP('')).toBe('')
  })

  it('ignora excedente além de 8 dígitos', () => {
    expect(maskCEP('013101009999')).toBe('01310-100')
  })

  it('remove não-dígitos antes de mascarar', () => {
    expect(maskCEP('abc01310xyz100')).toBe('01310-100')
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

describe('gerarSlotsDisponiveis', () => {
  const ativo: DisponibilidadeDia = { ativo: true, inicio: '08:00', fim: '18:00' }
  const inativo: DisponibilidadeDia = { ativo: false, inicio: '08:00', fim: '18:00' }

  it('dia inativo → []', () => {
    expect(gerarSlotsDisponiveis(inativo, 60, [])).toEqual([])
  })

  it('dia ativo sem ocupação gera todos os slots', () => {
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '10:00' }, 60, [])
    expect(r).toEqual(['08:00', '09:00'])
  })

  it('slot ocupado é excluído', () => {
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '10:00' }, 60, ['08:00'])
    expect(r).toEqual(['09:00'])
  })

  it('todos os slots ocupados → []', () => {
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '10:00' }, 60, ['08:00', '09:00'])
    expect(r).toEqual([])
  })

  it('duração 120 min gera slots corretos', () => {
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '12:00' }, 120, [])
    expect(r).toEqual(['08:00', '10:00'])
  })

  it('borda do fim — slot que termina exatamente no fim é incluído', () => {
    // 08:00 + 120 = 10:00 === fim(10:00) → incluído
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '10:00' }, 120, [])
    expect(r).toEqual(['08:00'])
  })

  it('borda do fim — slot que ultrapassaria o fim é excluído', () => {
    // 08:00 + 120 = 10:00 > fim(09:30) → nenhum slot
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '09:30' }, 120, [])
    expect(r).toEqual([])
  })

  it('OS às 08:00 com duração 120 bloqueia só o slot das 08:00', () => {
    // Slot 10:00: 600 < 480+120=600 → false (não colide)
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '12:00' }, 120, ['08:00'])
    expect(r).toEqual(['10:00'])
  })

  it('OS fora do grid bloqueia slots sobrepostos', () => {
    // OS às 09:00 ocupa 09:00-11:00; slot 08:00 ocupa 08:00-10:00 → sobreposição; slot 10:00 ocupa 10:00-12:00 → sobreposição
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '12:00' }, 120, ['09:00'])
    expect(r).toEqual([])
  })

  it('duração 15 min gera 4 slots por hora', () => {
    const r = gerarSlotsDisponiveis({ ativo: true, inicio: '08:00', fim: '09:00' }, 15, [])
    expect(r).toEqual(['08:00', '08:15', '08:30', '08:45'])
  })

  it('inicio >= fim → []', () => {
    expect(gerarSlotsDisponiveis({ ativo: true, inicio: '10:00', fim: '08:00' }, 60, [])).toEqual([])
  })

  it('gera slots do ativo com larga janela e colisões parciais', () => {
    // 8h-18h, dur=60, ocupados: 08:00, 10:00, 14:00
    const r = gerarSlotsDisponiveis(ativo, 60, ['08:00', '10:00', '14:00'])
    expect(r).toEqual(['09:00', '11:00', '12:00', '13:00', '15:00', '16:00', '17:00'])
  })
})
