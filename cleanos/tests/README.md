# CleanOS — Suíte de Testes (backend / integração)

Testes de integração e unitários do **PocketBase** e hooks. O frontend Flutter
tem a própria suíte em `../flutter/test/` (`flutter test`).

---

## 1. Testes de integração — garantias anti-desvio

**Arquivo:** `integration/anti-desvio.test.mjs`  
**Runner:** Node.js 18+ (nativo, zero dependências extras)  
**O que cobre (30 testes):**

| Grupo | Garantia |
|-------|----------|
| A | Autenticação de todos os papéis do seed |
| B | Profissional negado no cofre `clientes` (list, view por id, expand, fields) |
| C | Campos sensíveis ausentes nas OS; `endereco_liberado` vazio exceto em `em_andamento` |
| D | Profissional vê só as próprias OS |
| E | Ciclo de vida do endereço: day-check, Iniciar libera, concluir sem pgto bloqueado, concluir com pgto limpa |
| F | Travas de campo: 8 campos/transições rejeitados para o profissional |
| G | Profissional não cria OS |
| H | Admin e Gerente têm acesso pleno; gerente não toca repasse |

### Pré-requisito

PocketBase rodando com o seed aplicado:

```bash
cd cleanos/pb
./pocketbase serve --http=127.0.0.1:8090   # em outro terminal
```

### Como rodar

```bash
cd cleanos/tests
npm test
```

Ou passando uma URL diferente:

```bash
PB_URL=http://meu-servidor:8090 npm test
```

Os testes são **determinísticos**: cada grupo cria os registros que precisa (via admin)
e os remove no `after`, independentemente do estado atual do seed.

---

## 2. Testes unitários de hooks (financeiro / prof_delete)

Ver `integration/*.unit.test.mjs` no mesmo pacote `npm test`.

---

## 3. Frontend Flutter (não fica aqui)

```bash
cd cleanos/flutter
flutter analyze --fatal-infos
flutter test
```

---

## Bugs de produção encontrados pelos testes

Os testes de anti-desvio e de integridade financeira já pegaram regressões reais
(saldo, repasse, fuso BRT, acesso ao cofre). Preferir estender esta suíte a
reproduzir bug em script solto.
