#!/usr/bin/env bash
# assert-agenda-features.sh — Gate pré-deploy do painel web.
#
# Causa raiz (jul/2026): features da Agenda (cards com serviço/valor/bairro,
# detalhe com Editar OS, colunas por profissional) ficaram só em branches de
# feature e NUNCA na main. Cada deploy de outra branch sobrescrevia pb_public
# e "sumia" o que o dono já tinha visto em prod.
#
# Rode SEMPRE antes de `flutter build web` + rsync do painel:
#   bash cleanos/scripts/assert-agenda-features.sh
#
# Exit 0 = OK. Exit 1 = NÃO faça deploy (código sem as features).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FLUTTER="$ROOT/cleanos/flutter/lib"
fail=0

check() {
  local file="$1"
  local pattern="$2"
  local why="$3"
  if ! grep -qE "$pattern" "$FLUTTER/$file"; then
    echo "FAIL: $file — falta: $why"
    echo "      padrão: $pattern"
    fail=1
  else
    echo "OK   $file — $why"
  fi
}

echo "=== assert-agenda-features (pré-deploy painel) ==="

# Cards da grade: serviço / valor / bairro no bloco
check "painel/agenda/day_column.dart" \
  "_detalhesAgendaOs" \
  "blocos com serviço/valor/bairro (_detalhesAgendaOs)"

check "painel/agenda/day_column.dart" \
  "tipoServicoNome|detalhes\.servico" \
  "texto de serviço no miolo do bloco"

# Mobile: subtítulo rico
check "painel/agenda/agenda_screen.dart" \
  "_agendaCardSubtitle" \
  "subtítulo mobile com serviço/valor/bairro"

# Clique → detalhe completo + Editar
check "painel/agenda/agenda_screen.dart" \
  "showOSDetail" \
  "toque no evento abre showOSDetail (não o dialog pobre)"

check "painel/ordens/os_detail.dart" \
  "_editavel" \
  "Editar OS também em concluída (_editavel)"

# Congela data/hora em concluída no form
check "painel/ordens/os_form.dart" \
  "_horarioCongelado" \
  "form congela data/hora/duração de OS finalizada"

# Colunas por profissional (lado estável no DIA — não só no aglomerado)
check "core/agenda/agenda_layout.dart" \
  "groupKey" \
  "layout agrupa colunas por profissional (groupKey)"

check "core/agenda/agenda_layout.dart" \
  "ordemGlobal|_denseColsDoCluster" \
  "lados estáveis no dia (ordemGlobal / dense por cluster)"

# Teste de regressão que trava o card alto
if ! grep -q "bloco alto mostra serviço, valor e bairro" \
  "$ROOT/cleanos/flutter/test/painel/agenda_day_column_test.dart"; then
  echo "FAIL: falta teste 'bloco alto mostra serviço, valor e bairro'"
  fail=1
else
  echo "OK   test/painel/agenda_day_column_test.dart — regressão do card"
fi

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "ABORT: Agenda incompleta. Não faça rsync do painel até restaurar as features."
  echo "Dica: elas devem estar na main — não só em branch de feature."
  exit 1
fi

echo ""
echo "PASS: features da Agenda presentes. Pode buildar e rsyncar o painel."
exit 0
