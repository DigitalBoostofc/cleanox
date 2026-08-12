# Vitrine pública + agendamento Cleanox

**Status:** MVP agendável + CMS integrado + catálogo personalizável.
**Plano inicial:** sessão de design 2026-07-21. Catálogo v2: 2026-08-11.

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
| `pb_migrations/1700000064_vitrine_catalogo_personalizavel.js` | Layout/copy/preço por serviço e mídia associada |
| `pb_hooks/vitrine_slots_lib.js` | Motor de slots (testável) |
| `pb_hooks/vitrine_lib.js` | Catálogo, slots, agendar, rate-limit |
| `pb_hooks/vitrine_routes.pb.js` | `routerAdd` das rotas |

### Rotas

- `GET /api/cleanos/vitrine/servicos`
- `GET /api/cleanos/vitrine/servicos/{id}`
- `GET /api/cleanos/vitrine/atuacao`
- `GET /api/cleanos/vitrine/slots?servico=&data=`
- `POST /api/cleanos/vitrine/agendar`

## Catálogo personalizável

O CMS fica no painel principal em `/painel/vitrine` e usa a mesma sessão do
CleanOS. `admin` e `gerente` podem editar; `profissional` não possui acesso.

Cada serviço pode escolher um formato controlado:

- `destaque`: card amplo com fotografia e argumento comercial;
- `fotografico`: card de imagem dominante para o grid;
- `antes_depois`: comparação de um par de imagens;
- `compacto`: linha curta para serviços complementares.

Campos comerciais (`vitrine_titulo`, `vitrine_descricao`, `vitrine_badge`,
`vitrine_cta`, `vitrine_preco_modo` e `vitrine_ordem`) não alteram nome,
descrição ou preço operacional da OS. Serviços antigos, com campos vazios,
usam automaticamente o formato `fotografico`, textos operacionais e preço
"a partir de".

As imagens continuam em `vitrine_midia`, agora com relação opcional
`servico`, papel (`capa`, `galeria`, `antes`, `depois`), `par_id`, legenda e
ponto focal X/Y. Mídias globais antigas (`hero`, `categoria_*`) permanecem
compatíveis.

O frontend é mobile-first, oferece busca e filtros por grupo e preserva o
mesmo carrinho e o fluxo de agendamento. Imagem ausente degrada para um
placeholder da identidade Cleanox; nunca impede o orçamento.

`POST /vitrine/agendar` recalcula nome e preço no servidor; valores enviados
pelo navegador são ignorados. Promoção de order bump só é aceita quando o
`order_bump_id` está ativo e elegível para o carrinho. A duração gravada e
revalidada nunca pode ser menor que a soma canônica dos serviços selecionados.

Opcional em prod: `VITRINE_SLOT_SECRET` (senão cai no `CLEANOS_SERVICE_SECRET`).

## Fluxo (UX cotador)

1. **Serviços** — multi-select + total ao vivo  
2. **Seus dados** — nome, WhatsApp, endereço  
3. **Orçamento final** — resumo + CTA agendar  
4. **Agendar** — dia + horários reais (slots)  
5. OS `atribuida` + cliente `origem=vitrine` + `canal_origem=vitrine`  
   → badge **Vitrine** no painel (lista/detalhe/agenda)

Público: **https://agendar.cleanox.com.br**

## Fora do escopo atual

- Pix adiantado + desconto (Fase 2)
- Cupons

## Testes

```bash
cd cleanos/tests && npm run test:unit
# inclui integration/vitrine_slots.unit.test.mjs
```
