# Spec — Agenda estilo Google Calendar (CleanOS)

**Data:** 2026-07-13
**Superfícies:** Painel web (desktop + estreita) e APK unificado. Flutter + PocketBase.
**Origem:** pedido do dono (permitir sobrepor/encaixar OS e ajustar duração como no Google Agenda) + revisão crítica (pane-404) incorporada.

---

## 1. Problema

A agenda do painel (`lib/painel/agenda/`) trata sobreposição de OS como conflito:

- A OS **não tem duração** — só `data_hora` (início). Duração é global por profissional (`disponibilidade.duracao_min`).
- O bloqueio de conflito é **client-side**: `gerarSlotsDisponiveis` (`formatters.dart`) remove slots que colidem → não dá pra encaixar 09:30 se já há OS às 08:00.
- O servidor **não** barra sobreposição (nenhum hook valida conflito); a trava é só a UI escondendo o slot.
- A grade **empilha por hora de início** (`eventsForHour` bucketiza em 1h, clamp 6–22h). Sem span por duração, sem colunas lado a lado.

**Objetivo:** OS com duração própria; sobrepor é permitido (com aviso, não bloqueio); ajuste de duração/horário direto no calendário (desktop) e por sheet no APK; renderização estilo Google (blocos proporcionais + colunas para sobrepostos).

## 2. Decisões (com o dono) e resolução das perguntas em aberto

| # | Decisão |
|---|---|
| D1 | **Duração própria por OS** — novo campo `duracao_min`. |
| D2 | **Sobreposição permitida + aviso discreto** no form (amarelo, não bloqueia salvar). |
| D3 | **Ajuste no calendário**: redimensionar (borda) + mover (corpo) no **desktop web**. No **APK**, ajuste por **bottom-sheet com steppers ±15min** no long-press (não grade mobile — ver R-A1). |
| D4 | **Abordagem custom** (sem pacote de calendário); algoritmo de layout puro e testável. |
| D5 | **Faseado em 3 entregas mergeáveis** (ver §7). |
| D6 | **Status arrastáveis**: só `agendada` e `atribuida`. `em_andamento`/`concluida`/`cancelada` **não** arrastam (renderizam sem handles). Defesa no servidor. |
| D7 | **Arrastar no tempo**: permitido "mais cedo hoje"; **bloquear** mover para dia anterior (UI) + o form já valida passado. |
| D8 | **Cross-day na semana desktop**: suportado na Fase 2 (coluna destino = `x ~/ larguraColuna`); disponibilidade não bloqueia, no máximo aviso pós-drop. |
| D9 | **Duração no render**: função única `duracaoEfetivaMin(os[, dispProf])` → OS > profissional > **60**. Sem herança invisível server-side; o form **prefila visível** o campo Duração com a duração do profissional (usuário vê e pode mudar). |
| D10 | **Chips de "horário livre" removidos** (S2): com sobreposição permitida, "livre" é decorativo; o aviso "colide com OS de Fulano" é a fonte de verdade. Entrada de horário passa a ser livre (HH:MM + snap 15). |
| D11 | **Aviso de sobreposição** considera OS `agendada`/`atribuida`/`em_andamento` (exclui `cancelada` e `concluida` — evita ruído de reagendamento no mesmo dia). |
| D12 | **App do profissional ("Meus Serviços")**: exibir faixa "08:00–10:00" fica **fora** desta reforma (toca outra release de APK; nota de follow-up). |
| D13 | **Realtime / multi-admin**: fora da Fase 1. Entra **refresh-on-focus** da Agenda + recalcular "hoje". Realtime (`subscribe` na janela) fica como pendência consciente. |
| D14 | **Escala px/min fixa** (~56px/h) num **token único**; zoom é futuro. |

## 3. Modelo de dados

- **Migration** `1700000027_os_duracao.js`: `duracao_min` (NumberField, `min: 15`, opcional) em `ordens_servico` (id `ordserv00000001`). Idempotente (checar campo antes de criar), `down()` real. R8 no deploy (rsync exclui o seed). Conferir que não há branch paralela criando a 27 (há colisão histórica na `1700000018`).
- **Semântica:** fim = `data_hora` + `duracao_min`.
- **R2 numérica (R-M1):** NumberField opcional volta **`0`** quando vazio, não `null`. OS antiga chega com `duracao_min: 0`. Normalizar no `fromRecord`/converter: `<= 0 → null`. O `duracaoEfetivaMin` trata `null` **e** `<= 0`.
- **`OrdemServico`:** `int? duracaoMin` (`@JsonKey('duracao_min')`) + regen freezed/g. Teste com JSON de record **antigo** (`"duracao_min": 0`), não fixture `null`.
- **Sem migração de dados** das OS antigas: o fallback resolve no render.

## 4. Servidor (PocketBase)

- **Nenhuma** trava de conflito de horário (intencional — sobrepor é permitido).
- `os_logic.js` / `guardOrdemUpdateRequest`:
  - Adicionar `duracao_min` à **denylist do profissional** (defesa: prof não muda duração via PATCH). Confirmar que `duracao_min` **não** entra no `OSExecPatch` (espelho Dart) e anotar o contrato dos dois lados. Rodar `verify_rules.sh` + `anti-desvio.test.mjs`.
  - **Cerca de status (R-A4, padrão R3 — validar ANTES do `e.next()`):** rejeitar mudança de `data_hora` **ou** `duracao_min` quando `original().status` for `concluida` ou `cancelada`. Protege o histórico financeiro mesmo contra um painel com bug.
- Admin/gerente já podem gravar `data_hora`/`duracao_min` (confirmado no guard) — só o repasse é exclusivo de admin.

## 5. Núcleo puro e testável — `agenda_layout.dart` (novo, no core)

Funções puras, sem Flutter, cobertas por teste:

- `duracaoEfetivaMin(os, [dispProf]) -> int` — OS(`> 0`) > profissional(`> 0`) > 60.
- `intervaloBrtMin(os) -> (int startMin, int endMin)` — relógio de parede BRT em minutos (via `parsePbUtc(...).subtract(kBrtOffset)`), fim = start + duração efetiva. Toda aritmética em **minutos-BRT inteiros** (gate G-8); nunca `DateTime.now()` local no meio.
- `sobreposicoes(List<Intervalo> ocupados, int start, int dur) -> List<Intervalo>` — usada pelo aviso do form **e** (indiretamente) pela grade, pra aviso e desenho nunca se contradizerem (R-A2).
- `layoutDayEvents(events, dayStart, dayEnd) -> List<Posicionado{startMin,endMin,column,columnCount,truncTop,truncBottom}>`:
  - **Clusters** conectados por sobreposição; dentro do cluster, 1ª coluna livre; largura = `1/maxColumns do cluster` — **maxColumns final do cluster**, não running-max (R-M4.1).
  - **Cap de colunas** (3 mobile / 5 desktop); excedente vira chip **"+N"** que abre lista (coerente com R4) (R-M4.2).
  - **Duração mínima de layout** 15 min aplicada **antes** do algoritmo (intervalos `[x,x)` não sobrepõem) (R-M4.3).
  - **Ordenação estável** (start, depois end desc, depois id) → determinístico pros testes (R-M4.4).
  - **Janela dinâmica (R-M2/M3):** `dayStart = min(6h, floor(menorInício))`, `dayEnd = max(22h, ceil(maiorFim))` — elimina a classe de bugs de "evento fora de 6–22h some" e "estoura o Stack". Marca `truncTop/truncBottom` só se ainda houver corte.
  - **Cruzar meia-noite:** clampar a fração ao dia da coluna; marcar truncamento (a fração do outro dia aparece na coluna daquele dia).

Testes obrigatórios: sem overlap; overlap parcial; total; cadeia A(9–12)/B(9–10)/C(10–11) (largura 1/2); N idênticos → cap+"+N"; duração 0; fora da janela; cruzando meia-noite.

## 6. Grade time-grid (render) — desktop

- **Um único** `DayColumn(day, events, editable)` (R-S5) usado 1× na visão dia e 7× na semana. Gesture layer é **camada separada**, montada só quando `editable`.
- `Stack` posicionado por minuto: `top = (start − dayStart) × escala`, `height = dur × escala`. Linhas de hora ao fundo. Escala num **token único** (~56px/h).
- Altura visual mínima (~24px) só no render (não mexe no dado) pra blocos curtos.
- Mês: **intocado** (chips).
- Mobile/estreito/APK: continua **lista de cards** (`_MobileDayView/_MobileWeekView`), agora exibindo "08:00–10:00" (R-A1). Ajuste via sheet (Fase 3).

## 7. Interação

**Desktop (Fase 2):**
- Mouse: `MouseRegion` com cursor `resizeUpDown` na borda e `move`/`grab` no corpo. Hover revela handle na borda inferior.
- Arrastar borda = resize (`duracao_min`); arrastar corpo = mover (`data_hora`, inclusive cross-day na semana — D8).
- Snap 15 min, duração mín 15 min. Preview **em estado local do widget** (overlay/`ValueNotifier`), sem re-layoutar a grade por frame (R-B3). Persiste só no drop.
- Só `agendada`/`atribuida` têm handles (D6); mover pra dia anterior bloqueado (D7).

**APK (Fase 3):**
- Long-press num card → **bottom-sheet** com steppers ±15min de **início** e **duração**, aviso de sobreposição, salvar/cancelar. Feedback háptico no long-press. Sem grade mobile.

**Persistência do drop (R-A3):**
- Token de sequência em `AgendaController.load()` (padrão do `os_form`: `if (seq != _loadSeq) return`).
- No drop: aplicar o **record confirmado pelo servidor** por cima da lista (`osList.map((o) => o.id == r.id ? r : o)`) — **não** `load()` a janela de 500.
- Set de IDs "em voo" (`_pendingDrag`) bloqueia novo drag da mesma OS e faz `load()` concorrente preservar pendentes. Rollback restaura **só** a entrada da OS.

## 8. Formulário (`os_form`) — Fase 1

- Campo **Duração** (stepper/dropdown 15/30/45/60/90/120…), **prefilado visível** com a duração do profissional (D9).
- Horário passa a **entrada livre** HH:MM (`TextInputFormatter` + snap 15 no blur). **Remover** `_autoSelectSlot` e o modo dropdown-slot; **remover** os chips de "livre" (D10/R-M6). Atualizar/aposentar os testes de `os_form` correspondentes **na mesma entrega**.
- **Aviso** amarelo discreto quando `sobreposicoes(...)` não é vazio: "⚠ sobrepõe OS de Fulano (08:00–10:00)". Não bloqueia salvar (D11 define quais OS contam).

## 9. Ciclo de vida / estado (R-M7)

- Refresh-on-focus: recarregar a Agenda quando o branch ganha foco (listener no índice do shell) + recalcular `hoje` nesse momento.
- Realtime (`subscribe` limitado à janela) = follow-up, não Fase 1.

## 10. Fases (entregas mergeáveis)

- **Fase 1 — Fundação (sem interação):** migration + `duracao_min` no modelo/servidor (denylist + cerca de status), `agenda_layout.dart` puro + testes, render proporcional no desktop (blocos + colunas), cards do APK mostrando faixa, form com Duração + entrada livre + aviso. **Já entrega valor** (vê duração e encaixa pelo form).
- **Fase 2 — Drag desktop:** resize + move (incl. cross-day), preview local, persistência com sequência, refresh-on-focus.
- **Fase 3 — APK:** bottom-sheet de ajuste no long-press.

## 11. Testes & gate

- Unit: `agenda_layout` (casos do §5), `duracaoEfetivaMin` (0/null/prof/60), snap/clamp.
- Widget: bloco proporcional; aviso de sobreposição no form; entrada livre substitui o dropdown.
- Fase 2+: gestos (`WidgetTester.timedDrag`/long-press, "pan rola vs long-press arrasta"); ida-e-volta BRT (pixel→min→`localInputToPBDate`→PATCH→`parsePbUtc`→pixel, caso noturno 23h BRT = 02h UTC dia seguinte); corrida do controller (resposta velha não sobrescreve; rollback só a OS afetada).
- Backend: `verify_rules.sh` + `anti-desvio.test.mjs`.
- Gate por fase: `flutter analyze --fatal-infos` (0) + `flutter test` (verde). Deploy só com ordem do dono (R5); migration não sobe sem `migrate up` no dev antes.

## 12. Riscos residuais / follow-ups

- App do profissional exibir faixa de horário (D12).
- Realtime multi-admin (D13).
- Zoom/densidade da grade (D14).
- Confirmar ausência de outra migration `27` em branch paralela (R-B1).
