/**
 * CleanOS — testes UNITÁRIOS da validação de senha (users_senha_lib.js).
 *
 * Cobre a regra pura `validarNovaSenha` da rota que deixa o ADMIN redefinir a
 * senha de outra conta (POST /api/cleanos/users/{id}/senha). As travas de auth
 * (papel admin, reconfirmação da senha do admin, alvo em `users`) dependem de
 * PocketBase vivo e são cobertas no smoke E2E — aqui fica a validação isolada.
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { validarNovaSenha, SENHA_MIN } = require('../../pb/pb_hooks/users_senha_lib.js')

describe('validarNovaSenha', () => {
  it('senha válida e confirmação igual → null (ok)', () => {
    assert.equal(validarNovaSenha('umasenha123', 'umasenha123'), null)
  })

  it('mínimo é 8 caracteres', () => {
    assert.equal(SENHA_MIN, 8)
  })

  it('senha curta (<8) → erro de tamanho', () => {
    const err = validarNovaSenha('1234567', '1234567')
    assert.match(err, /pelo menos 8/)
  })

  it('exatamente 8 caracteres → ok', () => {
    assert.equal(validarNovaSenha('12345678', '12345678'), null)
  })

  it('senha e confirmação diferentes → não coincidem', () => {
    const err = validarNovaSenha('umasenha123', 'outrasenha9')
    assert.match(err, /não coincidem/)
  })

  it('não-string (undefined) → erro de tamanho, sem lançar', () => {
    assert.match(validarNovaSenha(undefined, undefined), /pelo menos 8/)
  })

  it('tamanho é checado ANTES da igualdade (curta ganha)', () => {
    // Ambas curtas e iguais: a mensagem é a de tamanho, não a de coincidência.
    assert.match(validarNovaSenha('123', '123'), /pelo menos 8/)
  })
})
