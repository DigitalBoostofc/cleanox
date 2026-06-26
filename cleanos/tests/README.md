# CleanOS — Suíte de Testes

Dois conjuntos de testes independentes: integração (backend) e unitário (frontend).

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

## 2. Testes unitários — helpers do frontend

**Arquivo:** `web/src/lib/collections.test.ts`  
**Runner:** Vitest  
**O que cobre (29 testes):**

- Labels: `osStatusLabel`, `formaPagamentoLabel`, `repasseStatusLabel`
- Formatadores: `formatCurrency`, `formatDate`, `formatDateTime`, `formatTime`
- Conversores de data: `toDateInputValue`, `localInputToPBDate`, `pbDateToLocalInput`
- Constantes: `COLLECTIONS`

### Como rodar

```bash
cd cleanos/web
npm test
```

---

## Rodar tudo de uma vez

```bash
# Da raiz cleanos/
(cd tests && npm test) && (cd web && npm test)
```

---

## Bugs de produção encontrados pelos testes

Nenhum bug de produção foi detectado. Todos os 30 testes de integração e 29
testes unitários passaram contra a implementação atual sem modificações.
