# Vitrine pública + agendamento Cleanox

**Status:** Fase 1 em implementação (MVP agendável, sem Pix).  
**Plano:** sessão de design 2026-07-21.

## Objetivo

Subdomínio **`https://agendar.cleanox.com.br`** onde o cliente vê o catálogo e **agenda horário real** na grade da equipe. Cliente e OS ficam no cofre CleanOS (anti-desvio).

## Superfície

| Item | Valor |
|------|--------|
| Entrypoint | `cleanos/flutter/lib/main_vitrine.dart` |
| Pasta UI | `cleanos/flutter/lib/vitrine/` |
| Auth | Nenhuma (anônimo) |
| API | `/api/cleanos/vitrine/*` (hooks PB, não abre listRule) |

### Dev

```bash
cd cleanos/flutter
flutter run -d chrome --dart-define=PB_URL=http://127.0.0.1:8090 -t lib/main_vitrine.dart
```

### Build

```bash
flutter build web --release -t lib/main_vitrine.dart
rsync -az --delete build/web/ hostinger:/opt/cleanos/vitrine/web/
# público em https://agendar.cleanox.com.br (ver docs/VITRINE-DNS.md)
```

## Backend

| Arquivo | Papel |
|---------|--------|
| `pb_migrations/1700000044_vitrine.js` | `origem=vitrine`, `ordens.canal_origem` |
| `pb_hooks/vitrine_slots_lib.js` | Motor de slots (testável) |
| `pb_hooks/vitrine_lib.js` | Catálogo, slots, agendar, rate-limit |
| `pb_hooks/vitrine_routes.pb.js` | `routerAdd` das rotas |

### Rotas

- `GET /api/cleanos/vitrine/servicos`
- `GET /api/cleanos/vitrine/servicos/{id}`
- `GET /api/cleanos/vitrine/atuacao`
- `GET /api/cleanos/vitrine/slots?servico=&data=`
- `POST /api/cleanos/vitrine/agendar`

Opcional em prod: `VITRINE_SLOT_SECRET` (senão cai no `CLEANOS_SERVICE_SECRET`).

## Fluxo (UX cotador)

1. **Serviços** — multi-select + total ao vivo  
2. **Seus dados** — nome, WhatsApp, endereço  
3. **Orçamento final** — resumo + CTA agendar  
4. **Agendar** — dia + horários reais (slots)  
5. OS `atribuida` + cliente `origem=vitrine` + `canal_origem=vitrine`  
   → badge **Vitrine** no painel (lista/detalhe/agenda)

Público: **https://agendar.cleanox.com.br**

## Fora da Fase 1

- Pix adiantado + desconto (Fase 2)
- Fotos SEO / cupons

## Testes

```bash
cd cleanos/tests && npm run test:unit
# inclui integration/vitrine_slots.unit.test.mjs
```
