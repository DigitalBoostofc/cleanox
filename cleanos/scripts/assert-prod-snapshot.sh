#!/usr/bin/env bash
# assert-prod-snapshot.sh — Gate pré-deploy: features que JÁ estavam em prod
# (1.2.0+73, cynthia-split-dashboard-realizado) e não podem sumir da main.
#
# Uso (junto com assert-agenda-features.sh):
#   bash cleanos/scripts/assert-agenda-features.sh
#   bash cleanos/scripts/assert-prod-snapshot.sh
#
# Exit 0 = OK. Exit 1 = NÃO faça rsync do painel.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FLUTTER="$ROOT/cleanos/flutter/lib"
PB="$ROOT/cleanos/pb"
fail=0

check() {
  local file="$1"
  local pattern="$2"
  local why="$3"
  if ! grep -qE "$pattern" "$ROOT/$file"; then
    echo "FAIL: $file — falta: $why"
    echo "      padrão: $pattern"
    fail=1
  else
    echo "OK   $file — $why"
  fi
}

echo "=== assert-prod-snapshot (pré-deploy painel) ==="

# ── Financeiro / Extrato / Equipe (estavam em prod +73) ─────────────────────
check "cleanos/flutter/lib/painel/financeiro/fin_comissoes_screen.dart" \
  "Extrato por profissional" \
  "Equipe: extrato por profissional"

check "cleanos/flutter/lib/painel/financeiro/fin_derivations.dart" \
  "isLancamentoRealizado" \
  "derivação Realizado (split dashboard)"

check "cleanos/flutter/lib/painel/financeiro/fin_principal_screen.dart" \
  "Realizado|Extrato" \
  "Principal com Realizado/Extrato"

check "cleanos/flutter/lib/painel/financeiro/lancamentos/fin_transacoes_screen.dart" \
  "saldoPrevistoPorDia|Extrato" \
  "Transações/Extrato com previsto"

# ── Agenda: lados estáveis (groupKey + ordem do dia) ────────────────────────
check "cleanos/flutter/lib/core/agenda/agenda_layout.dart" \
  "ordemGlobal|_denseColsDoCluster" \
  "agenda: lados estáveis por profissional no dia"

# ── Hooks de comissão / OS financeiro (prod ≠ main antiga) ──────────────────
check "cleanos/pb/pb_hooks/prof_comissao_pago_lib.js" \
  "." \
  "hook prof_comissao_pago_lib presente"

check "cleanos/pb/pb_hooks/os_financeiro_lib.js" \
  "." \
  "hook os_financeiro_lib presente"

# ── Vitrine (hooks presentes em prod na medição 2026-07-23) ─────────────────
for f in vitrine_lib.js vitrine_routes.pb.js vitrine_slots_lib.js vitrine_bumps_lib.js; do
  if [[ ! -f "$PB/pb_hooks/$f" ]]; then
    echo "FAIL: cleanos/pb/pb_hooks/$f — hook vitrine em prod ausente no repo"
    fail=1
  else
    echo "OK   pb_hooks/$f — vitrine (prod)"
  fi
done

for f in 1700000044_vitrine.js 1700000045_vitrine_cms.js 1700000046_vitrine_midia_public.js; do
  if [[ ! -f "$PB/pb_migrations/$f" ]]; then
    echo "FAIL: cleanos/pb/pb_migrations/$f — migration vitrine em prod ausente no repo"
    fail=1
  else
    echo "OK   pb_migrations/$f — vitrine (prod)"
  fi
done

# ── Versão: não regredir abaixo do build em prod ────────────────────────────
ver_line=$(grep -E '^version:' "$ROOT/cleanos/flutter/pubspec.yaml" | head -1 || true)
build=$(echo "$ver_line" | sed -n 's/.*+\([0-9][0-9]*\).*/\1/p')
if [[ -z "${build:-}" ]]; then
  echo "FAIL: pubspec.yaml sem version build (+N)"
  fail=1
elif [[ "$build" -lt 73 ]]; then
  echo "FAIL: pubspec build +$build < +73 (prod medido). Suba o +N antes do deploy."
  fail=1
else
  echo "OK   pubspec version build +$build (>= 73)"
fi

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "ABORT: snapshot de produção incompleto. Não faça rsync do painel."
  echo "Ver: docs/PROD-SNAPSHOT-2026-07-23.md"
  exit 1
fi

echo ""
echo "PASS: snapshot de produção presente. Pode buildar e rsyncar o painel."
exit 0
