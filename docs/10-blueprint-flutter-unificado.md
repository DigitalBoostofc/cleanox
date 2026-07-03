# 10 — Blueprint de Arquitetura: CleanOS Flutter Unificado (Painel Web + App Profissional)

> **Status: BLUEPRINT PARA APROVAÇÃO DO DONO — nenhum código Dart escrito ainda.**
> Autor: Arquiteto. Data: 2026-07-01.
> Decisão do dono (imutável neste doc): reescrever TODO o frontend React em **um único projeto Flutter** com **core compartilhado** e duas superfícies — **Painel** (Flutter Web, admin/gerente) e **Profissional** (Android nativo agora, iOS depois) — falando com o **MESMO backend PocketBase, que fica INTOCADO**.
> Este documento é o contrato de arquitetura que os dois times paralelos (Painel e Profissional) vão consumir. Ele sucede e se apoia no [doc 09](09-app-profissional-flutter-gps.md) (GPS/tracking/push).

---

## 0. Princípios inegociáveis (herdados do backend)

Qualquer decisão de arquitetura Flutter obedece a estes invariantes que **já vivem no servidor** (`pb_migrations/1700000001_init_collections.js`, `pb_hooks/os_logic.js`, `pb_hooks/whatsapp_routes.pb.js`):

1. **Anti-desvio é server-side e o cliente Flutter NÃO o enfraquece.** O profissional:
   - **nunca** consulta a coleção `clientes` (negada por regra: `listRule/viewRule = admin||gerente`);
   - **nunca** vê telefone/e-mail/sobrenome/endereço completo — só a "visão-de-job" (`nome_curto`, `bairro`, `tipo_servico_nome`, `data_hora`, `valor_servico`, `status`);
   - só vê `endereco_liberado` quando a OS está `em_andamento` (preenchido/limpo por hook).
2. **O contrato de dados é o das coleções PocketBase** (nomes snake_case). O Flutter consome via SDK Dart `pocketbase`. O core deve espelhar `collections.ts` como fonte única de verdade em Dart.
3. **Regras de campo são impostas no servidor** (`guardOrdemUpdateRequest`): o app só pode PATCH em `status`, `valor_pago`, `forma_pagamento`, `checklist_exec`, `adicionais`, `observacoes_prof`, `descontos`. Tentar tocar campos travados → 403. O cliente deve tratar 403 graciosamente, nunca "esconder o botão e assumir que passou".
4. **Transições de status válidas** (profissional): `atribuida → em_andamento → concluida`. Iniciar exige ser o dia do serviço (BRT); concluir exige pagamento registrado + itens obrigatórios do checklist concluídos.

---

## 1. Inventário de paridade (React → Flutter)

Complexidade estimada: **P** (pequena, <250 LOC), **M** (média, 250–550), **G** (grande, 550–900), **XG** (900+). LOC do React entre parênteses.

### 1.1 Superfície compartilhada

| Rota React | Tela Flutter | Papel | Complex. | Notas de porte |
|---|---|---|---|---|
| `/login` (`Login.tsx`, 132) | `LoginScreen` | público | P | `authWithPassword('users')`; roteia por `role` após sucesso. Único ponto de entrada das duas superfícies. |
| `RootRedirect` (`App.tsx`) | redirect no `go_router` | — | P | `profissional → /app`, senão `→ /painel`. |

### 1.2 Painel (admin / gerente) — target Flutter Web

| Rota React | Tela Flutter | Papel | Complex. | Notas de porte |
|---|---|---|---|---|
| `/painel` → `Dashboard` (222) | `DashboardScreen` | admin/gerente | M | KPIs + listas resumo. Consome `ordens_servico` agregado. |
| `/painel/clientes` → `Clientes` (1075) | `ClientesScreen` + `ClienteFormSheet` | admin/gerente | XG | CRUD do **cofre** `clientes`: máscaras telefone/CEP, endereço, busca, paginação. Tela mais pesada do painel. |
| `/painel/ordens` → `OrdensServico` (782) | `OrdensServicoScreen` + `NovaOSModal` | admin/gerente | G | Lista/filtros de OS, criar OS (seleciona cliente+serviço+profissional+slot), atribuir. |
| `/painel/ordens/:osId/execucao` → `OSExecucaoPage` (877) | `OSExecucaoAdminScreen` | admin/gerente | G | Visão admin da execução: checklist, evidências, adicionais, observações, descontos, gerar/enviar relatório. Compartilha widgets de execução com o app. |
| `/painel/agenda` → `Agenda` (1012) | `AgendaScreen` | admin/gerente | XG | Grade de slots por profissional/dia via `disponibilidade` + `gerarSlotsDisponiveis`. Layout denso — desafio de Flutter Web. |
| `/painel/financeiro` → `FinanceiroLayout` (46) | `FinanceiroShell` (ShellRoute aninhada) | admin/gerente | P | Navegação por abas do módulo financeiro. |
| ├ index → `VisaoGeral` (477) | `FinVisaoGeralScreen` | admin/gerente | M | KPIs + donut/barras. |
| ├ `lancamentos` → `Lancamentos` (855) | `FinLancamentosScreen` + `LancamentoFormModal` | admin/gerente | XG | Lista agrupada por data, CRUD `fin_lancamentos`, filtros, anexos. |
| ├ `contas` → `ContasPagarReceber` (536) | `FinContasPagarReceberScreen` | admin/gerente | G | Derivações de vencimento/atraso. |
| ├ `categorias` → `Categorias` (535) | `FinCategoriasScreen` | admin/gerente | G | Árvore categoria/subcategoria (`parent_id`), ícones, cores. |
| ├ `relatorios` → `Relatorios` (777) | `FinRelatoriosScreen` | admin/gerente | XG | **Charts** (barras/donut). Avaliar `fl_chart`. Denso. |
| ├ `limites` → `LimiteGastos` (370) | `FinLimitesScreen` | admin/gerente | M | Progresso vs teto por categoria (`fin_limites`). |
| └ `carteiras` → `ContasCarteiras` (476) | `FinCarteirasScreen` | admin/gerente | M | CRUD `fin_contas`, saldos. |
| `/painel/servicos` → `ServicosListPage` (414) | `ServicosListScreen` | admin/gerente | M | Catálogo rico `servicos`, chips de grupo/categoria. |
| `/painel/servicos/novo` \| `:id` → `ServicoEditorPage` (645) | `ServicoEditorScreen` + `ChecklistEditor` | admin/gerente | G | Editor de serviço + checklist padrão + orientações. |
| `/painel/usuarios` → `Usuarios` (436) | `UsuariosScreen` + `DisponibilidadeEditor` | admin/gerente | M | CRUD `users` (papéis) + `disponibilidade` semanal. |
| `/painel/avaliacoes` → `Avaliacoes` (249) | `AvaliacoesScreen` | admin/gerente | M | Notas/motivos das OS avaliadas (StarRating). |
| `/painel/conta` → `Conta` (184) | `ContaScreen` | admin/gerente | P | Perfil próprio + trocar senha. |
| `/painel/whatsapp` → `WhatsApp` (508) | `WhatsAppAdminScreen` | **admin only** | G | Status/conexão UAZAPI (QR/paircode), edição de templates. Guard por papel `admin`. |

### 1.3 App do profissional — target Android (iOS depois)

| Rota React | Tela Flutter | Papel | Complex. | Notas de porte |
|---|---|---|---|---|
| `/app` → `MeusServicos` (935) | `MeusServicosScreen` | profissional | XG | Núcleo do app: OS de hoje/próximas/atrasadas, cards com ações (Iniciar, avisar a-caminho, registrar pagamento, concluir), realtime, toasts, modal de pagamento. |
| `/app/os/:osId` → `OSExecucaoApp` (534) | `OSExecucaoScreen` | profissional | G | Checklist marcável (auto-save debounced), evidências (câmera/upload), snapshot do serviço, gerar laudo PDF. |
| `/app/mapa` → `Mapa` (178) | `MapaScreen` | profissional | P→M | Hoje: só serviço ativo + botão "abrir no Google Maps". **Evolui** com GPS ao vivo do doc 09. |
| `/app/perfil` → `Perfil` (371) | `PerfilScreen` | profissional | M | Média de avaliação, resumo do dia, trocar senha, liberar localização (novo), logout. |

### 1.4 Telas/serviços NOVOS (não existem no React — vêm do doc 09)

| Componente Flutter | Papel | Complex. | Origem |
|---|---|---|---|
| `LocationTrackingService` (foreground/background) | profissional | G | doc 09 §4 — GPS em background, POST `/os/{id}/posicao`. |
| Botão "Cheguei ao local" + estado "a caminho" no card | profissional | M | doc 09 §1/§4 — POST `/os/{id}/cheguei`. |
| `PushRegistrationService` (FCM) | profissional | M | doc 09 §4 — POST `/push/register`, "Nova OS". |
| Fluxo de permissões de localização/notificação | profissional | M | doc 09 §2 — Android background location + notificação persistente. |

**Total estimado de superfície:** ~22 telas de painel + ~4 de profissional + ~4 serviços novos. O grosso do esforço concentra-se em Clientes, Agenda, Lançamentos, Relatórios (painel) e MeusServicos (profissional).

---

## 2. Stack & decisões técnicas

| Camada | Escolha | Justificativa |
|---|---|---|
| **State management** | **Riverpod 2.x** (com `riverpod_generator`/`riverpod_annotation`) | Compile-time safe, testável sem `BuildContext`, providers como fonte única. Escala para o painel (muitos módulos independentes) e casa bem com streams do PocketBase realtime (`StreamProvider`). Evita o acoplamento de InheritedWidget manual que o React faz com Context. |
| **Roteamento** | **go_router** com `redirect` global por papel + `ShellRoute` por superfície | Espelha 1:1 o `App.tsx`: uma `ShellRoute` `/painel` (sidebar) e uma `/app` (bottom nav), com `redirect` que reproduz `RoleGuard` e `RootRedirect`. Deep-linking nativo (necessário p/ push "Nova OS" → abrir a OS). |
| **Camada de dados** | SDK **`pocketbase`** (pub.dev) + **padrão Repository** por domínio | Um `PocketBaseClient` singleton (espelha `lib/pb.ts`), repositórios que expõem métodos de domínio e escondem nomes de coleção/filtros. O core define as **interfaces** dos repositórios (contrato); as superfícies só consomem interfaces. |
| **Modelos** | classes imutáveis Dart 3 (sealed/records onde couber) + `json_serializable`, OU `freezed` | Porte fiel de `collections.ts`, `servicos/types.ts`, `financeiro/types.ts`. Recomendo `freezed` para `copyWith`/igualdade/serialização dos ~15 modelos JSON ricos (snapshot, checklist, adicionais). |
| **Auth/token** | `flutter_secure_storage` como `AuthStore` customizado do PocketBase + auto-refresh | **NÃO usar SharedPreferences para token** (anti-pattern de segurança mobile). Implementar `AsyncAuthStore` persistindo em Keychain/EncryptedSharedPreferences. Refresh proativo no boot (espelha `authRefresh().catch(clear)` do `AuthContext`). No web, `pb.authStore` em cookie/localStorage é aceitável (paridade com hoje). |
| **i18n** | `flutter_localizations` + `intl`, locale fixo **pt_BR** | Toda a UI é PT-BR. `intl` para moeda (`R$`), datas BRT (UTC-3) e o cuidado de fuso que hoje vive em `localInputToPBDate`/`getBrtDayBounds`. |
| **Tema** | `ThemeData` claro/escuro derivado dos **design tokens** (`tokens.css`) | Petrol `#0F4C5C` + cyan/teal `#00C2B8`. Um `AppTheme` com `ColorScheme` + `ThemeExtension` custom (`CleanoxColors`) para os tokens que não cabem no ColorScheme (status de OS, cores de grupo, paleta financeira). `ThemeMode` persistido (espelha `ThemeContext`, chave `cleanos-theme`). |
| **HTTP custom routes** | via `pb.send()` do SDK (já usado no React) | Rotas `/api/cleanos/os/{id}/a-caminho`, `/relatorio`, e as futuras do doc 09 (`/posicao`, `/cheguei`, `/push/register`). |
| **PDF (laudo)** | pacote `pdf` + `printing` | Substitui `pdfOS.ts`/`relatorioOS.ts` do web. Gera o laudo da OS a partir do snapshot+checklist+evidências. |
| **Fotos/evidências** | `image_picker` (câmera/galeria) + upload multipart via SDK | Porte de `os_evidencias` (`createEvidencia` com FormData). Arquivos são **protegidos** → precisa de file token (`pb.files.getToken()`), igual ao web. |

**Renderer Flutter Web:** ver §4.

---

## 3. Estrutura de pastas — projeto unificado

Projeto único (`cleanos/flutter/` — sugestão), com **core compartilhado** e duas features isoladas. Flavors/entrypoints separam as superfícies mas o binário compartilha o core.

```
cleanos/flutter/
├── pubspec.yaml
├── lib/
│   ├── main_painel.dart          # entrypoint Flutter Web (painel) — dev
│   ├── main_profissional.dart    # entrypoint Android profissional — dev
│   ├── main_android.dart         # ⭐ entrypoint unificado do APK (BUILD/CI); roteamento por papel
│   │
│   ├── core/                     # ⭐ CONTRATO COMPARTILHADO (congelar antes do fan-out)
│   │   ├── env/
│   │   │   └── env.dart          # PB_URL, GOOGLE_MAPS_API_KEY (STUB), FCM (STUB) via --dart-define
│   │   ├── pb/
│   │   │   └── pb_client.dart    # singleton PocketBase + AsyncAuthStore (secure storage)
│   │   ├── auth/
│   │   │   ├── auth_service.dart      # login/logout/refresh/role  (espelha AuthContext)
│   │   │   └── auth_providers.dart    # Riverpod: currentUser, currentRole, authState
│   │   ├── models/               # porte 1:1 de collections.ts + servicos/types + financeiro/types
│   │   │   ├── user.dart              # User + Role enum
│   │   │   ├── cliente.dart           # 🔒 só o painel usa
│   │   │   ├── ordem_servico.dart     # OrdemServico + OSStatus + campos JSON ricos
│   │   │   ├── servico.dart           # ServicoPB + ServiceSnapshot + ChecklistTemplateItem
│   │   │   ├── os_execucao.dart       # ChecklistExecItem, ServicoAdicionalOS, ObservacaoProfissional, EvidenciaFoto
│   │   │   ├── financeiro.dart        # FinConta, FinCategoria, FinLancamento, FinLimite + unions
│   │   │   └── collections.dart       # const nomes de coleção (COLLECTIONS/FIN_COLLECTIONS)
│   │   ├── repositories/         # ⭐ INTERFACES = o contrato que os times consomem
│   │   │   ├── ordens_repository.dart      # abstract + impl PB (list/get/create/update/subscribe)
│   │   │   ├── clientes_repository.dart     # abstract + impl PB (só painel injeta)
│   │   │   ├── servicos_repository.dart
│   │   │   ├── financeiro_repository.dart
│   │   │   ├── usuarios_repository.dart
│   │   │   ├── evidencias_repository.dart
│   │   │   └── whatsapp_repository.dart     # rotas custom /a-caminho, /relatorio, status/connect
│   │   ├── formatters/           # porte de maskPhoneBR, formatCurrency, BRT bounds, localInputToPBDate...
│   │   ├── errors/
│   │   │   └── os_error.dart      # describeOSError → {isPermission, isOffline, isNotFound}
│   │   └── design/               # ⭐ DESIGN SYSTEM compartilhado
│   │       ├── theme.dart             # ThemeData claro/escuro + ThemeMode controller
│   │       ├── cleanox_colors.dart    # ThemeExtension: status OS, grupos, paleta financeira
│   │       ├── tokens.dart            # espaçamentos, raios (r-sm..r-pill), sombras, tipografia (Sora)
│   │       └── widgets/               # ClxButton, ClxCard, ClxChip, StatusBadge, StarRating, Spinner, ClxModal, ErrorBanner, EmptyState, Toast
│   │
│   ├── painel/                   # 🅰 FEATURE PAINEL — time A (Flutter Web)
│   │   ├── painel_router.dart         # ShellRoute /painel (sidebar) — consome go_router
│   │   ├── shell/painel_shell.dart    # sidebar + topbar (espelha PainelLayout)
│   │   ├── dashboard/ clientes/ ordens/ agenda/ servicos/ usuarios/ avaliacoes/ conta/ whatsapp/
│   │   └── financeiro/                # sub-shell + 7 telas
│   │
│   └── profissional/             # 🅱 FEATURE PROFISSIONAL — time B (Android)
│       ├── prof_router.dart           # ShellRoute /app (bottom nav) — espelha AppLayout
│       ├── meus_servicos/ os_execucao/ mapa/ perfil/
│       └── services/                  # LocationTrackingService, PushRegistrationService (doc 09)
│
├── shared_widgets_os/            # widgets de execução compartilhados painel+prof
│   └── checklist_execucao.dart, evidencias_section.dart, snapshot_resumo.dart, relatorio_os_modal.dart
├── android/                      # config Android (profissional)
└── web/                          # config Web (painel)
```

### 3.1 O CONTRATO DO CORE (o que os dois times consomem SEM se colidir)

Estes artefatos do `core/` são a **fronteira estável**. Uma vez congelados (fase 1), Time A (painel) e Time B (profissional) trabalham em paralelo sem tocar arquivos um do outro:

1. **Modelos** (`core/models/*`) — imutáveis, com `fromRecord(RecordModel)`/`toJson()`. São a tradução Dart do `collections.ts`. Nenhuma feature redefine modelo.
2. **Interfaces de repositório** (`core/repositories/*` — classes `abstract`) — assinam os métodos de domínio. Ex.:
   ```
   abstract class OrdensRepository {
     Future<List<OrdemServico>> listDoProfissional(String profId, {DateRange? janela});
     Future<OrdemServico> getExec(String osId);           // expand profissional,servico
     Future<OrdemServico> patchExec(String osId, OSExecPatch patch);
     Future<OrdemServico> updateStatus(String osId, OSStatus novo);
     Stream<OrdemServiceEvent> subscribe();               // realtime
   }
   ```
   As features dependem da **abstração** (injetada por Riverpod), nunca da impl. Isso permite mockar em teste e trocar a impl sem quebrar consumidores.
3. **AuthService + providers** (`currentUserProvider`, `currentRoleProvider`) — ambas superfícies leem daqui; ninguém reimplementa auth.
4. **Design system** (`core/design/*`) — tema, tokens e widgets base. Ambos os times usam `ClxButton`, `ClxCard`, etc. Mudança de token é PR no core, revisado, nunca fork por feature.
5. **Formatters/errors** — utilitários puros portados de `collections.ts`/`osStore.ts`.

**Regra anti-colisão:** o core só muda por PR revisado e com changelog; features NÃO editam `core/`. Se uma feature precisa de algo novo no core, abre issue → core entrega → feature consome. Enquanto o core está sendo estabilizado (fase 1), nenhuma feature começa.

---

## 4. Flutter Web para o painel admin

**Renderer recomendado:** **CanvasKit** (não o HTML/`skwasm` auto). O painel é ddashboard denso com muitos widgets, charts e tabelas — CanvasKit dá renderização consistente e melhor performance de repaint que o renderer HTML. Trade-off já aceito pelo dono: **bundle inicial maior** (~1.5–2MB do CanvasKit wasm) e SEO irrelevante (é app autenticado interno).

**Mitigações concretas para densidade de dados/tabelas:**

1. **Virtualização de listas SEMPRE.** Nada de renderizar N linhas de uma vez. As telas críticas (Clientes 1075 LOC, Lançamentos 855, OrdensServico 782) usam `ListView.builder`/`SliverList` com paginação servidor via `getList(page, perPage)` — o PocketBase já pagina (`getList`), e as telas React já usam isso. Nunca `getFullList` para listas grandes na UI.
2. **Tabelas densas → `TwoDimensionalScrollView`/`TableView` (package `two_dimensional_scrollables`)** ou `DataTable2` com virtualização, NÃO o `DataTable` padrão (renderiza tudo). Header fixo + scroll horizontal para Agenda e Relatórios.
3. **Lazy routes / code-splitting por módulo.** `go_router` com `deferred as` imports nas rotas pesadas (financeiro, agenda) → Flutter Web faz split de bundle por `loadLibrary()`. O usuário baixa o módulo financeiro só ao abri-lo.
4. **`--web-renderer canvaskit` + `--dart2js-optimization O4` + tree-shake de ícones.** Buildar com `flutter build web --release`. Servir com gzip/brotli no Nginx da VPS (o `pb_public` já é servido; o painel web vira mais um artefato estático).
5. **Charts:** `fl_chart` (donut/barras de VisaoGeral/Relatorios) — leve e canvas-based; evitar libs que injetam HTML.
6. **Imagens/evidências:** `cached_network_image` com o file token na query; liberar cache ao trocar de OS.
7. **Responsivo desktop-first:** `LayoutBuilder` + breakpoints. Sidebar fixa ≥1024px, drawer <1024px (espelha `PainelLayout` que já tem overlay mobile). Largura de conteúdo máx. 1200px (token `--clx-content-max-w`).

**Aviso ao dono (gate):** o primeiro load do painel será mais lento que o React/Vite atual (CanvasKit + wasm). Depois de cacheado é fluido. Se o load inicial for crítico, alternativa é manter o painel React e migrar só o profissional — mas o dono já decidiu unificar; registramos o trade-off.

---

## 5. Offline-first & sync/realtime

**Diagnóstico honesto por superfície:**

### Painel (admin/gerente) — **NÃO precisa de offline-first.**
É trabalho de escritório com internet. Estratégia: **online-first com estados de erro graciosos** (banner + retry, como o React já faz). Realtime via `pb.collection(...).subscribe()` exposto como `StreamProvider` para Dashboard/Ordens/Agenda refletirem mudanças ao vivo. Sem cache local persistente (evita complexidade e risco LGPD de dados de cliente no disco).

### Profissional (mobile) — **offline-resiliente, não offline-first pleno.**
O profissional está em campo (garagem, prédio, sinal ruim), mas **as ações-chave dependem do servidor por design de segurança** (o hook decide se pode iniciar/concluir, libera endereço, valida pagamento). Um offline-first "de verdade" (fila de writes + merge) **colidiria com o anti-desvio** — não dá para "liberar endereço" offline. Recomendação equilibrada:

| Capacidade | Estratégia offline |
|---|---|
| **Ler "Meus serviços" do dia** | Cache local (Hive/`shared_preferences` cifrado) da lista de OS **sem dados sensíveis** — só a visão-de-job que o servidor já expõe. Mostra last-known ao abrir sem sinal, com banner "offline — dados de HH:MM". |
| **Marcar checklist** | Buffer local + auto-save debounced (já é o padrão do `OSExecucaoApp`: salva 800ms após parar). Se offline, mantém no buffer e re-tenta ao voltar sinal (retry com backoff). `checklist_exec` é um campo do profissional (não travado), então o replay é seguro. |
| **Fotos/evidências** | Fila de upload persistente (`workmanager`/`flutter_uploader`): tira a foto offline, enfileira, sobe quando reconectar. |
| **Iniciar / Concluir / Pagamento / a-caminho** | **Requerem online** — são gates de servidor. Offline → desabilita com aviso claro "precisa de internet". NÃO enfileirar transição de status (o servidor precisa validar dia/pagamento/checklist no momento). |
| **GPS em background (doc 09)** | O `LocationTrackingService` **bufferiza posições** offline e faz flush de `POST /posicao` ao reconectar (o cron de avisos tolera posição "recente"; posições antigas são descartadas server-side). |

**Sync/realtime:** PocketBase realtime (SSE) via SDK. No app, `subscribe('*')` na `ordens_servico` filtrando por profissional (o React já faz isso em `MeusServicos`), reconciliando com o cache. Cuidado portado: **dedupe de race entre fetch e realtime** (o React usa `fetchGenRef`; em Dart, versionar o fetch ou usar o `StreamProvider` como fonte única).

---

## 6. Arquitetura de GPS / tracking / push (app profissional)

Implementa o [doc 09](09-app-profissional-flutter-gps.md). Backend (rotas, migração, cron) é construído **depois** e por outro executor; aqui defino como o app se conecta.

### 6.1 Pacotes
- **Localização background:** `flutter_background_geolocation` (robusto, foreground service Android + iOS Always) **ou** `flutter_foreground_task` + `geolocator` (mais leve/gratuito). **Recomendo `flutter_foreground_task` + `geolocator`** para Android-agora (sem custo de licença, controle do foreground service + notificação persistente). Reavaliar para iOS depois.
- **Push:** `firebase_core` + `firebase_messaging`. Chaves `google-services.json` ficam **STUB por env/flavor** até o dono liberar Firebase.
- **Rotas/URL externa:** `url_launcher` (abrir Google Maps — já é o comportamento do `Mapa.tsx`).
- **Permissões:** `permission_handler`.

### 6.2 `LocationTrackingService`
- Inicia quando a OS entra em "a caminho" (após "Avisar que estou a caminho" → hoje `POST /a-caminho`, doc 09 estende para geocodificar destino).
- Foreground service Android com notificação persistente ("CleanOS rastreando trajeto").
- Throttle de envio ~20–30s ou por deslocamento mínimo (bateria/dados) — `POST /api/cleanos/os/{id}/posicao {lat,lng}`.
- Para ao tocar **"Cheguei ao local"** (`POST /os/{id}/cheguei`) ou ao **Concluir**.
- Degradação: permissão negada → esconde tracking automático, mantém "Cheguei" manual (doc 09 §4).
- **Anti-desvio no cliente:** o app manda só `{lat,lng}`; quem geocodifica o endereço e mede ETA é o servidor (`maps.js`). O app **nunca** recebe o endereço destino em coordenadas do cliente fora de `em_andamento`.

### 6.3 `PushRegistrationService`
- No login/boot do profissional: obtém FCM token, `POST /api/cleanos/push/register {token, plataforma}`.
- Handler de mensagem "Nova OS atribuída" → `go_router` deep-link para `/app` (ou direto `/app/os/:id`). Reaproveita o roteador — por isso deep-linking precisa estar no core desde a fase 1.
- Renovação de token (`onTokenRefresh`) → re-registra.

### 6.4 Contrato com o backend (a ser criado — doc 09 §3)
O `WhatsAppRepository`/`TrackingRepository` do core expõe métodos que batem nas rotas custom. Enquanto o backend não existe, essas impls ficam atrás de **feature flags** (`env.trackingEnabled = false`) — o app compila e roda sem elas. Quando o backend do doc 09 subir, liga a flag.

---

## 7. Plano de fases para execução PARALELA

### Fase 0 — Scaffold & decisões travadas (1 dev, curto)
- `flutter create` do projeto unificado, `pubspec.yaml` com deps (Riverpod, go_router, pocketbase, freezed, secure_storage, intl, fl_chart, pdf, image_picker).
- Três entrypoints (`main_painel.dart`, `main_profissional.dart`, `main_android.dart`) — o entrypoint de BUILD/CI é `main_android.dart` (APK unificado por papel); os demais continuam existindo p/ dev.
- CI: build Android (Linux OK) + build Web. iOS fica pendente do gate do dono.

### Fase 1 — CORE ESTÁVEL (⭐ bloqueia o paralelismo — nenhuma feature começa antes)
Entregáveis, todos com testes:
1. `pb_client.dart` + `AsyncAuthStore` em secure storage + auto-refresh.
2. **Todos os modelos** (`core/models/*`) portados de `collections.ts`/`servicos/types.ts`/`financeiro/types.ts`, com `fromRecord`/`toJson` e testes de (de)serialização contra fixtures reais do PB.
3. **Interfaces de repositório** (assinaturas congeladas) + impl PB básica de `OrdensRepository` e `AuthService`.
4. **Design system**: `theme.dart`, `cleanox_colors.dart` (tokens do `tokens.css`), widgets base (`ClxButton/Card/Chip/StatusBadge/Spinner/Modal/ErrorBanner/EmptyState/Toast/StarRating`).
5. `go_router` base com `redirect` por papel + as duas `ShellRoute` vazias + deep-linking configurado.
6. Formatters/errors portados + testados (BRT, moeda, máscaras, `describeOSError`).

**Gate de saída da Fase 1:** login funciona nas duas superfícies, tema claro/escuro, um repositório real lendo `ordens_servico`, contrato de repos revisado e aprovado. **A partir daqui o core é congelado** (só muda por PR revisado com changelog).

### Fase 2 — PARALELO (2 executores independentes)

**Time A — Painel (Flutter Web):**
- Slice A1: `PainelShell` (sidebar/topbar) + Dashboard + Conta.
- Slice A2: Clientes (cofre) + Ordens de Serviço + Nova OS.
- Slice A3: Execução da OS (admin) + Serviços/Editor + Usuários/Disponibilidade + Agenda.
- Slice A4: Módulo Financeiro completo (shell + 7 telas + charts).
- Slice A5: Avaliações + WhatsApp (admin-only).

**Time B — Profissional (Android):**
- Slice B1: `AppShell` (bottom nav) + MeusServicos (lista + realtime + ações + pagamento).
- Slice B2: OSExecucaoApp (checklist auto-save + evidências/câmera + laudo PDF).
- Slice B3: Mapa + Perfil.
- Slice B4 (após backend doc 09): Tracking GPS + Push + "Cheguei" + permissões.

**Ponto de dependência/sincronização entre os times:**
- **Widgets de execução compartilhados** (`shared_widgets_os/`: ChecklistExecucao, EvidenciasSection, SnapshotResumo, RelatorioOSModal) são usados por A3 (admin) **e** B2 (profissional). **Risco de colisão.** Mitigação: são entregues como parte do **core/shared na Fase 1.5** (mini-fase entre 1 e 2), por UM dono, antes de A3/B2 começarem. Se não der, um dos times é "dono" desses widgets e o outro só consome.
- Ambos dependem só de `core/repositories` (interfaces) → não se tocam. Se um time precisa de um método novo no repo, é PR no core (revisado), não edição paralela.
- `env`/flags de tracking: Time B mocka até o backend do doc 09 existir.

### Fase 3 — Integração, hardening, deploy
- Testes de widget/golden dos fluxos críticos; teste de integração (`patrol`) do fluxo profissional (login → iniciar → checklist → pagamento → concluir).
- Verificação anti-desvio no cliente (o profissional nunca busca `clientes`; endereço só em `em_andamento`) — porte dos casos de `anti-desvio.test.mjs` como testes de contrato do repo.
- Build Web do painel → servir na VPS (novo artefato estático ao lado do `pb_public`). Build Android (AAB/APK). iOS **bloqueado** pelo gate do dono (Mac/CI + conta Apple).

---

## 8. Riscos & gates do dono

| # | Risco / Gate | Impacto | Ação / Owner |
|---|---|---|---|
| G-1 | **Conta Apple Developer ($99/ano) + Mac/CI para iOS** | iOS não builda em Linux. Toda a superfície iOS fica parada. | **Gate do dono.** Android segue 100% local. iOS só entra quando o dono prover conta + Mac/CI (Codemagic/GitHub macOS). |
| G-2 | **Chaves Google Maps (`GOOGLE_MAPS_API_KEY`) + Firebase (`google-services.json`, APNs, `FCM_SERVER_KEY`)** | Sem elas, GPS/ETA e push não funcionam de verdade. | **Gate do dono.** Ficam **STUB por env/flavor** (decisão já tomada). App compila e roda sem; liga por feature flag quando as chaves chegarem. |
| G-3 | **Flutter Web em painel denso (Clientes/Agenda/Relatórios)** | Load inicial mais lento (CanvasKit wasm), risco de jank em tabelas grandes. | Mitigações da §4 (virtualização, lazy routes, paginação servidor, `fl_chart`). Medir em device/rede real antes de aposentar o React. |
| G-4 | **2ª stack (Dart/Flutter) além de React+PocketBase** | Custo de manutenção dobra durante a transição. | Coexistência: manter o React no ar até o Flutter atingir paridade + validação. Aposentar por superfície, não tudo de uma vez. |
| G-5 | **Backend do doc 09 ainda não existe** | Tracking/push do app dependem de rotas/migração/cron não construídos. | Time B usa flags/mocks; backend do doc 09 é um trabalho separado. Não bloqueia B1–B3. |
| G-6 | **Colisão nos widgets de execução compartilhados** (painel admin + app usam os mesmos) | Dois times editando os mesmos widgets → conflito. | Entregar `shared_widgets_os/` na Fase 1.5 por um único dono, antes de A3/B2. |
| G-7 | **Anti-desvio no cliente nativo** | Um bug de UI pode tentar ler `clientes` ou exibir endereço fora de hora. | O servidor já barra (403), mas adicionar testes de contrato no repo + code review focado. O cliente **nunca** é a linha de defesa — só não deve provocar 403 desnecessário. |
| G-8 | **Fuso BRT (UTC-3) e (de)serialização de datas** | Bugs sutis de "dia do serviço" (o React já teve F-04, F-401). | Centralizar TODA lógica de data BRT no core (`formatters`), com testes espelhando `getBrtDayBounds`/`assertServiceIsToday`. Nenhuma feature faz conta de fuso sozinha. |
| G-9 | **Realtime race (fetch vs subscribe)** | Lista de OS pisca/dessincroniza (o React resolve com `fetchGenRef`). | Usar `StreamProvider` do Riverpod como fonte única ou versionar o fetch. Definir o padrão no core na Fase 1. |

---

## Apêndice A — Mapa de coleções PocketBase (contrato de dados)

Fonte: `pb_migrations/*` + `collections.ts`. O core Dart espelha exatamente isto.

| Coleção | Acesso profissional | Campos-chave |
|---|---|---|
| `users` (auth) | vê só o próprio | `role` (admin/gerente/profissional), `nome`, `email` |
| `clientes` 🔒 | **NEGADO** | `nome/sobrenome/telefone/email` (sensíveis), `endereco_*`, `ativo` |
| `servicos` (catálogo rico) | leitura (autenticado) | `slug, categoria, grupo, valor_base, tipo_valor, checklist_padrao, orientacoes_*, status` |
| `ordens_servico` | só as suas (regra de registro) | visão-job: `nome_curto, bairro, tipo_servico_nome, data_hora, valor_servico, status`; efêmero: `endereco_liberado`; execução JSON: `service_snapshot, checklist_exec, adicionais, observacoes_prof, descontos`; pagamento: `valor_pago, forma_pagamento`; repasse (admin): `repasse_*`; avaliação: `avaliacao_*`; tracking (doc 09, futuro): `prof_lat/lng, dest_lat/lng, aviso_*_em, cheguei_em` |
| `os_evidencias` 🔒 | só evidências de OS suas; arquivo **protegido** (file token) | `os, foto, fase (antes/durante/depois), legenda, vínculos, enviado_por` |
| `disponibilidade` | admin/gerente | `profissional, duracao_min, dias[7]` |
| `config_atuacao` | admin/gerente | `estado, cidades[]` (singleton) |
| `fin_contas / fin_categorias / fin_lancamentos / fin_limites` | admin/gerente | módulo financeiro (ver `financeiro/types.ts`) |
| `app_config` (via hooks) | server-side | templates WhatsApp, instância UAZAPI; doc 09 add `aviso_*_texto`; nova `push_tokens` |

## Apêndice B — Rotas custom (via `pb.send`)

| Rota | Papel | No Flutter |
|---|---|---|
| `POST /api/cleanos/os/{id}/a-caminho` | profissional dono, `em_andamento` | `WhatsAppRepository.avisarACaminho(osId)` → `{ok, sentAt}` / 409 se WhatsApp desconectado |
| `POST /api/cleanos/os/{id}/relatorio` | admin/gerente ou prof dono | `enviarRelatorio(osId)` |
| `GET/POST /api/cleanos/whatsapp/{status,connect,disconnect}` | admin/gerente | tela WhatsApp (painel) |
| `POST /api/cleanos/os/{id}/posicao` · `/cheguei` · `POST /push/register` | profissional (doc 09, **futuro**) | `TrackingRepository` atrás de feature flag |
```
