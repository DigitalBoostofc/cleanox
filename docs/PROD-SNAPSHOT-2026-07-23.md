# Snapshot de produção — 2026-07-23

## Por que este documento existe

Em 2026-07-23 um deploy web feito a partir de `origin/main` **sem** o working tree
de features já em produção **apagou** temporariamente o painel que o dono usava
(`1.2.0+73`, note `cynthia-split-dashboard-realizado`). O `pb_public` foi
restaurado do backup pré-deploy.

Causa: **código em produção ≠ código na `main`**. Features foram buildadas e
rsyncadas a partir de branch/WIP local sem PR mergeado.

## Estado medido em produção (após restore)

| Item | Valor |
|------|--------|
| URL | https://app.cleanox.com.br |
| `version.json` | `1.2.0+73` · note `cynthia-split-dashboard-realizado` |
| `agenda-features.json` | `git: 18e54eb` · features `agenda-cards`, `extrato`, `equipe-op-desktop-center` |
| Base git da main na época | `18e54eb` (merge PR #151 agenda-cards) |
| Fonte real do JS | `18e54eb` **+** working tree (extrato/equipe/fin + hooks) |

### Backend (hooks) — divergia de `origin/main`

Hooks em prod batem byte-a-byte com este snapshot (medido 2026-07-23):

- `os_financeiro_lib.js`
- `prof_comissao_lib.js`
- `prof_comissao_pago.pb.js` / `prof_comissao_pago_lib.js`
- hooks **vitrine_*** (presentes em prod; **ausentes** da main na medição)

Migrations vitrine em prod (ausentes da main na medição):

- `1700000044_vitrine.js`
- `1700000045_vitrine_cms.js`
- `1700000046_vitrine_midia_public.js`

### Frontend (Flutter) — o que some se deployar só a main

- Financeiro: Extrato, Realizado/Previsto, Equipe/comissões (extrato por profissional)
- Shell/rotas/ordens/status e demais ajustes do working tree
- Identidade de marca (logos) e polish de UI já em uso
- Agenda cards (já na main via #151) + lados estáveis (commit neste snapshot)

## O que esta PR grava no git

Tudo o que estava **em produção e/ou no working tree que gerou o +73**, para a
`main` voltar a ser fonte da verdade e futuros deploys não regredirem.

## Regras a partir daqui (operacional)

1. **Nunca** `rsync` de `flutter build web` a partir de uma checkout que não
   contenha as features listadas em `agenda-features.json` / este snapshot.
2. Antes de todo deploy web do painel:
   ```bash
   bash cleanos/scripts/assert-agenda-features.sh
   bash cleanos/scripts/assert-prod-snapshot.sh
   ```
3. Depois do build, gravar markers no `build/web/`:
   ```bash
   GIT=$(git rev-parse --short HEAD)
   echo "{\"git\":\"$GIT\",\"features\":[\"agenda-cards\",\"extrato\",\"equipe-op-desktop-center\",\"prod-snapshot-2026-07-23\"]}" \
     > cleanos/flutter/build/web/agenda-features.json
   # version.json já vem do Flutter; preferir build_number >= 73
   ```
4. Merge desta PR **antes** de qualquer outro deploy web de feature paralela.

## Backup de emergência

Pré-deploy que salvou o +73:

`/opt/cleanos/predeploy-2026-07-23/pb_public-agenda-lados-173136.tar.gz`

(Usado no restore em 2026-07-23.)
