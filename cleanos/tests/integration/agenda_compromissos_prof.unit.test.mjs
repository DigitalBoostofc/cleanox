import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const {
  ehCofre,
  ehProfissional,
  camposTravadosProf,
  validarUpdateProf,
} = require('../../pb/pb_hooks/agenda_compromissos_lib.js')

describe('agenda_compromissos_lib', () => {
  it('cofre = admin ou gerente', () => {
    assert.equal(ehCofre('admin'), true)
    assert.equal(ehCofre('gerente'), true)
    assert.equal(ehCofre('profissional'), false)
  })

  it('profissional pelo role ativo ou pela lista roles', () => {
    assert.equal(ehProfissional('profissional', []), true)
    assert.equal(ehProfissional('admin', ['profissional']), true)
    assert.equal(ehProfissional('admin', []), false)
  })

  it('prof só atualiza a própria tarefa e só status válido', () => {
    assert.equal(
      validarUpdateProf({
        authId: 'p1',
        recordProfId: 'p1',
        status: 'concluida',
      }),
      null,
    )
    assert.match(
      validarUpdateProf({
        authId: 'p1',
        recordProfId: 'p2',
        status: 'concluida',
      }),
      /suas tarefas/,
    )
    assert.match(
      validarUpdateProf({
        authId: 'p1',
        recordProfId: 'p1',
        status: 'apagada',
      }),
      /inválido/,
    )
  })

  it('campos de cadastro ficam travados para o prof', () => {
    assert.ok(camposTravadosProf().includes('titulo'))
    assert.ok(camposTravadosProf().includes('data_hora'))
    assert.ok(!camposTravadosProf().includes('status'))
  })
})
