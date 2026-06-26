#!/usr/bin/env bash
# CleanOS — verificação das regras anti-desvio pela API REST (não pela UI).
# Requisitos: pocketbase rodando em $BASE, migrations 1 e 2 aplicadas (seed), jq.
# Uso: ./verify_rules.sh
set -uo pipefail

BASE="${BASE:-http://127.0.0.1:8090}"
PASS=0; FAIL=0
ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
hr()   { echo "------------------------------------------------------------"; }

login() { # $1=identity $2=password -> echo token
  curl -s "$BASE/api/collections/users/auth-with-password" \
    -H 'Content-Type: application/json' \
    -d "{\"identity\":\"$1\",\"password\":\"$2\"}" | jq -r '.token // empty'
}

echo "### CleanOS — Verificação anti-desvio via API REST ($BASE)"
hr

# ---- autenticação ----
PROF_TOKEN=$(login "pedro@cleanox.local" "cleanox123")
ADMIN_TOKEN=$(login "admin@cleanox.local" "cleanox123")
[ -n "$PROF_TOKEN" ] && ok "profissional autenticou (pedro)" || bad "profissional NÃO autenticou"
[ -n "$ADMIN_TOKEN" ] && ok "admin autenticou (ana)" || bad "admin NÃO autenticou"
hr

# ============================================================
echo "(a) GET /api/collections/clientes/records como PROFISSIONAL deve ser NEGADO"
# ------------------------------------------------------------
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/collections/clientes/records" \
  -H "Authorization: $PROF_TOKEN")
CODE=$(echo "$RESP" | tail -1); BODY=$(echo "$RESP" | sed '$d')
echo "  HTTP $CODE -> $BODY"
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ] || [ "$CODE" = "400" ]; then
  ok "clientes (LIST) negado ao profissional (HTTP $CODE)"
else
  TOTAL=$(echo "$BODY" | jq -r '.totalItems // "?"')
  [ "$TOTAL" = "0" ] && ok "clientes (LIST) retornou 0 itens ao profissional" \
                     || bad "profissional conseguiu LISTAR clientes (totalItems=$TOTAL)"
fi
# tentativa de VIEW direto por id (pega um id real via admin)
CID=$(curl -s "$BASE/api/collections/clientes/records?perPage=1" -H "Authorization: $ADMIN_TOKEN" | jq -r '.items[0].id')
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/collections/clientes/records/$CID" -H "Authorization: $PROF_TOKEN")
CODE=$(echo "$RESP" | tail -1)
echo "  VIEW /clientes/$CID -> HTTP $CODE"
{ [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; } && ok "clientes (VIEW por id) negado ao profissional (HTTP $CODE)" \
                                                || bad "profissional conseguiu VER cliente por id (HTTP $CODE)"
hr

# ============================================================
echo "(b) OS do profissional em agendada/atribuida NÃO traz telefone/nome completo/endereço"
# ------------------------------------------------------------
OS_JSON=$(curl -s "$BASE/api/collections/ordens_servico/records?perPage=200&expand=cliente" -H "Authorization: $PROF_TOKEN")
echo "  OS visíveis ao profissional:"
echo "$OS_JSON" | jq -r '.items[] | "    - \(.status) | nome_curto=\(.nome_curto) | bairro=\(.bairro) | endereco_liberado=\"\(.endereco_liberado)\""'
# nenhum campo sensível pode existir no JSON cru
LEAK=$(echo "$OS_JSON" | jq -r '[.items[] | (.telefone // empty), (.email // empty), (.sobrenome // empty)] | length')
[ "$LEAK" = "0" ] && ok "OS não possui campos telefone/email/sobrenome" || bad "OS expôs campo sensível!"
# expand do cliente deve vir VAZIO (profissional não lê clientes)
EXP=$(echo "$OS_JSON" | jq -r '[.items[] | select(.expand.cliente != null)] | length')
[ "$EXP" = "0" ] && ok "expand=cliente veio vazio para o profissional (cofre protegido)" \
                 || bad "expand=cliente VAZOU dados do cofre!"
# agendada/atribuida não podem ter endereco_liberado preenchido
BADADDR=$(echo "$OS_JSON" | jq -r '[.items[] | select((.status=="agendada" or .status=="atribuida") and .endereco_liberado != "")] | length')
[ "$BADADDR" = "0" ] && ok "endereco_liberado vazio em agendada/atribuida" \
                     || bad "endereço exposto em agendada/atribuida!"
hr

# ============================================================
echo "(c) Endereço aparece SÓ em em_andamento e SOME em concluida"
# ------------------------------------------------------------
# já existe uma OS em_andamento no seed:
ANDAMENTO_ADDR=$(echo "$OS_JSON" | jq -r '[.items[] | select(.status=="em_andamento")][0].endereco_liberado')
echo "  OS em_andamento (seed) endereco_liberado = \"$ANDAMENTO_ADDR\""
[ -n "$ANDAMENTO_ADDR" ] && [ "$ANDAMENTO_ADDR" != "null" ] && ok "em_andamento expõe endereço ao profissional" \
                     || bad "em_andamento sem endereço"
# garantir que NÃO há telefone embutido na string do endereço
echo "$ANDAMENTO_ADDR" | grep -Eq '1199999|@email' && bad "endereço contém telefone/email!" \
                                                   || ok "endereço liberado NÃO contém telefone/email"

# fluxo dinâmico: pegar a OS 'atribuida' de HOJE e Iniciar -> Concluir como profissional
ATRIB_ID=$(echo "$OS_JSON" | jq -r '[.items[] | select(.status=="atribuida")][0].id')
echo "  OS atribuida alvo: $ATRIB_ID"
# Iniciar (atribuida -> em_andamento): deve liberar endereço
R=$(curl -s "$BASE/api/collections/ordens_servico/records/$ATRIB_ID" \
  -X PATCH -H "Authorization: $PROF_TOKEN" -H 'Content-Type: application/json' \
  -d '{"status":"em_andamento"}')
ADDR=$(echo "$R" | jq -r '.endereco_liberado // ""')
echo "  após Iniciar -> status=$(echo "$R" | jq -r '.status'), endereco=\"$ADDR\""
[ -n "$ADDR" ] && [ "$ADDR" != "null" ] && ok "ao Iniciar, hook liberou o endereço" \
                                        || bad "endereço não foi liberado ao Iniciar"
# Concluir sem pagamento -> deve FALHAR
R=$(curl -s -w "\n%{http_code}" "$BASE/api/collections/ordens_servico/records/$ATRIB_ID" \
  -X PATCH -H "Authorization: $PROF_TOKEN" -H 'Content-Type: application/json' \
  -d '{"status":"concluida"}')
CODE=$(echo "$R" | tail -1)
echo "  Concluir SEM pagamento -> HTTP $CODE"
[ "$CODE" != "200" ] && ok "concluir sem pagamento foi BLOQUEADO (HTTP $CODE)" \
                     || bad "concluiu sem registrar pagamento!"
# Registrar pagamento + Concluir -> deve limpar endereço
R=$(curl -s "$BASE/api/collections/ordens_servico/records/$ATRIB_ID" \
  -X PATCH -H "Authorization: $PROF_TOKEN" -H 'Content-Type: application/json' \
  -d '{"valor_pago":90,"forma_pagamento":"pix_maquininha","status":"concluida"}')
ST=$(echo "$R" | jq -r '.status'); ADDR=$(echo "$R" | jq -r '.endereco_liberado')
echo "  após Concluir -> status=$ST, endereco=\"$ADDR\""
{ [ "$ST" = "concluida" ] && [ -z "$ADDR" -o "$ADDR" = "" ]; } && ok "ao Concluir, endereço foi RE-RESTRINGIDO (limpo)" \
                                                              || bad "endereço não foi limpo na conclusão"
hr

# ============================================================
echo "(d) Profissional NÃO consegue alterar campos proibidos"
# ------------------------------------------------------------
# usa a OS em_andamento original do seed
EMAND_ID=$(echo "$OS_JSON" | jq -r '[.items[] | select(.status=="em_andamento")][0].id')
echo "  OS em_andamento alvo: $EMAND_ID"
try_block() { # $1=descr $2=json-body
  local R CODE
  R=$(curl -s -w "\n%{http_code}" "$BASE/api/collections/ordens_servico/records/$EMAND_ID" \
    -X PATCH -H "Authorization: $PROF_TOKEN" -H 'Content-Type: application/json' -d "$2")
  CODE=$(echo "$R" | tail -1)
  echo "    tentativa [$1] -> HTTP $CODE :: $(echo "$R" | sed '$d' | jq -c '{message,data}' 2>/dev/null)"
  [ "$CODE" != "200" ] && ok "bloqueado: $1 (HTTP $CODE)" || bad "NÃO bloqueado: $1"
}
try_block "alterar valor_servico"   '{"valor_servico":9999}'
# usa um cliente DIFERENTE do atual da OS para garantir que é uma mudança real
EMAND_CLI=$(echo "$OS_JSON" | jq -r '[.items[] | select(.status=="em_andamento")][0].cliente')
OTHER_CID=$(curl -s "$BASE/api/collections/clientes/records?perPage=200" -H "Authorization: $ADMIN_TOKEN" | jq -r --arg x "$EMAND_CLI" '[.items[] | select(.id != $x)][0].id')
try_block "trocar cliente"          "{\"cliente\":\"$OTHER_CID\"}"
try_block "trocar profissional"     "{\"profissional\":\"\"}"
try_block "alterar data_hora"       '{"data_hora":"2030-01-01 10:00:00.000Z"}'
try_block "marcar repasse pago"     '{"repasse_status":"pago"}'
try_block "transição inválida"      '{"status":"agendada"}'
hr

# ============================================================
echo "(e) Sanidade: admin enxerga tudo (telefone do cliente visível só p/ admin)"
# ------------------------------------------------------------
TEL=$(curl -s "$BASE/api/collections/clientes/records?perPage=1" -H "Authorization: $ADMIN_TOKEN" | jq -r '.items[0].telefone')
[ -n "$TEL" ] && [ "$TEL" != "null" ] && ok "admin lê telefone do cliente ($TEL)" || bad "admin não leu telefone"
hr

# ============================================================
echo "(f) Profissional NÃO pode CRIAR ordem de serviço (createRule)"
# ------------------------------------------------------------
SOME_SRV=$(curl -s "$BASE/api/collections/servicos/records?perPage=1" -H "Authorization: $ADMIN_TOKEN" | jq -r '.items[0].id')
SOME_CLI=$(curl -s "$BASE/api/collections/clientes/records?perPage=1" -H "Authorization: $ADMIN_TOKEN" | jq -r '.items[0].id')
PROF_ID=$(curl -s "$BASE/api/collections/users/auth-refresh" -X POST -H "Authorization: $PROF_TOKEN" | jq -r '.record.id')
R=$(curl -s -w "\n%{http_code}" "$BASE/api/collections/ordens_servico/records" \
  -X POST -H "Authorization: $PROF_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"cliente\":\"$SOME_CLI\",\"servico\":\"$SOME_SRV\",\"data_hora\":\"2030-01-01 10:00:00.000Z\",\"status\":\"agendada\"}")
CODE=$(echo "$R" | tail -1)
echo "  POST /ordens_servico como profissional -> HTTP $CODE"
[ "$CODE" != "200" ] && ok "criação de OS bloqueada para profissional (HTTP $CODE)" || bad "profissional CRIOU uma OS!"
hr

# ============================================================
echo "(g) Day-check: profissional NÃO inicia OS fora do dia do serviço"
# ------------------------------------------------------------
# admin cria uma OS atribuída ao profissional com data FUTURA
NEW_OS=$(curl -s "$BASE/api/collections/ordens_servico/records" \
  -X POST -H "Authorization: $ADMIN_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"cliente\":\"$SOME_CLI\",\"servico\":\"$SOME_SRV\",\"profissional\":\"$PROF_ID\",\"data_hora\":\"2099-12-31 10:00:00.000Z\",\"status\":\"atribuida\",\"valor_servico\":100}")
NEW_OS_ID=$(echo "$NEW_OS" | jq -r '.id')
echo "  OS futura criada: $NEW_OS_ID"
R=$(curl -s -w "\n%{http_code}" "$BASE/api/collections/ordens_servico/records/$NEW_OS_ID" \
  -X PATCH -H "Authorization: $PROF_TOKEN" -H 'Content-Type: application/json' -d '{"status":"em_andamento"}')
CODE=$(echo "$R" | tail -1)
echo "  profissional tenta Iniciar OS futura -> HTTP $CODE :: $(echo "$R" | sed '$d' | jq -r '.message' 2>/dev/null)"
[ "$CODE" != "200" ] && ok "Iniciar fora do dia foi BLOQUEADO (HTTP $CODE)" || bad "profissional iniciou OS fora do dia!"
# cleanup
curl -s -o /dev/null "$BASE/api/collections/ordens_servico/records/$NEW_OS_ID" -X DELETE -H "Authorization: $ADMIN_TOKEN"
hr

echo "### RESULTADO: $PASS passaram, $FAIL falharam"
[ "$FAIL" = "0" ] && echo "### ✅ TODAS AS GARANTIAS ANTI-DESVIO VERIFICADAS" || echo "### ❌ HÁ FALHAS"
exit 0
