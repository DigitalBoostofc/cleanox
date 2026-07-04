# 12 — Redesign do APK (Opção B "Fintech Clean"): plano técnico de arquitetura

> Status: **proposta para aprovação do dono** — nenhum código foi escrito. Este documento é o handoff da missão de arquitetura; a implementação só começa após o dono validar as decisões abaixo (em especial as 3 marcadas como "decisão do dono" nas Perguntas Abertas).
>
> Especificação de design aprovada: `design-opcao-b.html` (5 telas + design tokens — cores, tipografia, raios, espaçamento). Este plano mapeia essa especificação para o código real em `cleanos/flutter`.

## 0. Contexto e restrição central

O CleanOS é um binário único (`cleanos/flutter`) com **três** entrypoints hoje, não dois:

| Entrypoint | Superfície | Papel | Status |
|---|---|---|---|
| `lib/main_painel.dart` | Flutter Web | admin/gerente | produção, **não muda** |
| `lib/main_profissional.dart` | APK Android (legado, só profissional) | profissional | superado pelo unificado (ver Pergunta Aberta P-1) |
| `lib/main_android.dart` | APK Android unificado | admin/gerente/profissional (roteado por papel) | é o que vai receber a Opção B |

Os três chamam `CleanosApp(surface: AppSurface.<x>)` em `lib/app.dart`, que hoje monta o **mesmo** `ThemeData` (`buildLightTheme()`/`buildDarkTheme()` de `core/design/theme.dart`) para todo mundo — `surface` só troca o `title` da `MaterialApp`. Isso é o ponto exato onde a bifurcação precisa entrar.

**Restrição do dono, não negociável:** a Web em produção (`main_painel.dart`) fica byte-a-byte como está. Qualquer mecanismo proposto abaixo precisa tornar isso *estruturalmente impossível de violar por acidente* (não só "por convenção").

---

## 1. Mecanismo de bifurcação

### Opções avaliadas

| Opção | Descrição | Veredito |
|---|---|---|
| **A. Duplicar `ThemeData` + flag por `AppSurface`** | Novo `theme_fintech.dart` irmão de `theme.dart`; `app.dart` escolhe qual builder chamar com base em `surface == AppSurface.android`. Decisões estruturais (nav de 5 itens, hero de saldo) lidas via `AppSurface` já existente. | **Recomendada** |
| B. Um `ThemeData` só, com `if (isAndroid)` espalhado dentro do `_build()` compartilhado | Menos arquivos novos, mas mistura os dois design systems no MESMO arquivo que a Web depende — um `if` invertido por engano quebra a Web em produção. | Rejeitada — risco de vazamento é exatamente o que a restrição do dono proíbe |
| C. Segunda árvore de widgets / segundo `CleanosApp` inteiro para Android | Isolamento total, mas duplica router, providers, telas —Controle de estado (Riverpod) teria que ser espelhado. Esforço muito acima do que a Opção B pede (ela é visual + navegação, não um app novo). | Rejeitada — duplicação desproporcional |

### Decisão: Opção A, com dois níveis de bifurcação

**Nível 1 — Tema (cobre ~80% da Opção B).** Em `lib/app.dart`, a única mudança estrutural no arquivo compartilhado:

```dart
theme: surface == AppSurface.android ? buildFintechLightTheme() : buildLightTheme(),
darkTheme: surface == AppSurface.android ? buildFintechDarkTheme() : buildDarkTheme(),
```

Um diff de 2 linhas, num arquivo de 48 linhas que qualquer revisor lê inteiro. `buildFintechLightTheme()`/`buildFintechDarkTheme()` vivem em `lib/core/design/theme_fintech.dart` — arquivo **novo**, não uma ramificação dentro de `theme.dart`. Nada na Web referencia esse arquivo; ele só é alcançável quando `surface == AppSurface.android`, e `main_painel.dart` passa `AppSurface.painel` fixo.

**Nível 2 — Decisões estruturais que ThemeData não cobre** (nav de 5 itens vs. sidebar/drawer, hero de saldo, CTA fixo no rodapé, cards com número grande). Aqui a pergunta é *como* os shells/telas sabem que estão no build fintech.

Avaliei `InheritedWidget` novo vs. reaproveitar o padrão que o projeto já usa em todo lugar (Riverpod). **Não existe nenhum `InheritedWidget` hoje no código** (`grep` vazio) — introduzir um agora seria um segundo mecanismo de propagação de config concorrendo com Riverpod, que já é usado para exatamente esse tipo de dado somente-leitura (`currentRoleProvider`, `themeModeControllerProvider`). Por consistência, a decisão é:

```dart
// lib/core/design/app_surface_provider.dart (novo, ~10 linhas)
final appSurfaceProvider = Provider<AppSurface>((ref) {
  throw UnimplementedError('appSurfaceProvider: instale via CleanosApp');
});
```

`CleanosApp.build()` (em `app.dart`) instala esse provider **internamente**, a partir do `surface` que ele já recebe como parâmetro de construtor — um `ProviderScope` aninhado dentro do `ProviderScope` que os três `main_*.dart` já criam:

```dart
return ProviderScope(
  overrides: [appSurfaceProvider.overrideWithValue(surface)],
  child: /* MaterialApp.router de hoje, inalterado por fora */,
);
```

Consequência importante: **nenhum dos três `main_*.dart` muda** — eles já passam `surface` para `CleanosApp`; o resto é interno a `app.dart`. E nenhum teste existente que já monta `ProviderScope(child: CleanosApp(surface: X))` quebra, porque o override é auto-instalado a partir do mesmo `surface` que o teste já fornece.

Consumo nos shells/telas: `ref.watch(appSurfaceProvider) == AppSurface.android` (ou um sugar `context.isFintechClean`/`ref.isFintechClean`, espelhando o `context.clx` que já existe em `cleanox_colors.dart`).

### Duplicar vs. parametrizar — critério usado em cada camada

| Camada | Decisão | Por quê |
|---|---|---|
| Tokens/cores/tipografia (`theme.dart` → `theme_fintech.dart`) | **Duplicar** o arquivo inteiro (novo `_build()`, novo `_textTheme()`) | É o arquivo que a Web depende de não mudar. Duplicar 150 linhas é mais barato e mais seguro do que uma condicional dentro do arquivo compartilhado — zero chance de flag invertida vazar pra Web. |
| Widgets compartilhados de baixo nível (`ClxButton`, `ClxCard`, `ClxChip`, `StatusBadge`, `EmptyState`, `Spinner`, `Toast`) | **Parametrizar via Theme** — nenhuma mudança de código | Esses widgets já leem cor/raio de `Theme.of(context)`/`context.clx`, nunca hardcoded (exceto 1 ponto, ver §2). Trocar o `ThemeData` injetado já basta. |
| Estrutura de navegação (`PainelShell`, `ProfShell`) e telas com layout próprio (login, hero de saldo, CTA fixo) | **Ramificar no ponto de uso** (`if (isFintechClean) ... else ...` dentro do shell/tela), sem propagar a flag para dentro dos widgets de baixo nível | Mantém os widgets compartilhados "burros" (só leem tema); a decisão estrutural fica localizada em ~4-5 arquivos que já são o ponto de entrada visual de cada superfície. |

---

## 2. Tokens → código: mapa exato

### 2.1 Cores → `ColorScheme` / novo `CleanoxColors.fintechLight`/`.fintechDark`

`CleanoxColors` (`core/design/cleanox_colors.dart`) é um `ThemeExtension` — **a forma (campos) não muda**, só os valores. Isso porque os campos que já existem cobrem 100% do que a Opção B pede, inclusive o "violeta" de status atribuída (`statusAtribuida`/`statusAtribuidaBg`, hoje `#7C3AED`/`#A78BFA` — já é o violeta do mock, só ajusta o hex pra `#7C5CFC`/`#A78BFA`).

| Token Opção B | Campo `CleanoxColors` | Observação |
|---|---|---|
| `primary` (#00C896 / #2FE3B4) | `primary` | Troca de valor; **não** reaproveita o teal atual (#00C2B8) |
| `on-primary` (#04231C) | *(novo campo `onPrimary`, ver abaixo)* | Hoje é uma constante fixa `ClxBrand.onPrimary` (#04201E) usada direto em `ClxButton` — ver ponto de atenção abaixo |
| `background` (#F7F8FA / #0E0F10) | `bg2` (scaffold background) | `bg2` já é o que `theme.dart` usa em `scaffoldBackgroundColor` |
| `surface`/card (#FFFFFF / #17191B) | `bg` | `bg` já é o que `CardThemeData.color` usa — a hierarquia "card mais claro que o fundo" já existe hoje, só muda o hex |
| `ink`/`ink2`/`ink3` | `ink`/`ink2`/`ink3` | Mapeamento direto |
| `danger` (#E5484D / #FF6B6E) | `error` | Direto |
| `warning` (~~#E8A400~~ **#96650A** / #FFC24B) | `warning` | **Correção pós-Onda 4**: #E8A400 sobre `bg2` (#F7F8FA) dá ~2.0:1, abaixo do mínimo AA de 4.5:1 p/ texto normal — implementado como `#96650A` (~4.75:1), mesma intenção âmbar. O claro deste doc está desatualizado; o dark (#FFC24B) já passava (~11:1) e não mudou. |
| `info` (#3E7BFA / #6C9BFF) | `info` | Direto |
| `violeta` (#7C5CFC / #A78BFA) | `statusAtribuida` | Já existe, só ajusta hex |
| `success` (= primary) | `success` | Direto |

**Ponto de atenção concreto:** `ClxButton` (`core/design/widgets/clx_button.dart:40`) usa `ClxBrand.onPrimary` — uma constante **fixa**, não um campo de `CleanoxColors` — para o texto do botão primário. Isso funciona hoje porque o valor é quase idêntico em ambos os design systems (#04201E atual vs. #04231C da Opção B — diferença imperceptível), mas é o tipo de acoplamento que trava a Opção B de ter seu próprio `onPrimary` caso o dono queira ajustar essa cor depois sem tocar na Web. Onda 1 deve adicionar um campo `onPrimary` a `CleanoxColors` e trocar essa uma linha em `ClxButton` para `context.clx.onPrimary` — não quebra nada hoje (valor idêntico), e desacopla os dois sistemas de verdade.

`ColorScheme` (`_scheme()` em `theme.dart`) é derivado desses mesmos campos — `theme_fintech.dart` espelha essa função com os novos valores; `tertiary`/`tertiaryContainer` (hoje um roxo hardcoded separado do `CleanoxColors`) devem passar a vir de `statusAtribuida`/`statusAtribuidaBg` também, pra não ter uma terceira fonte de "violeta".

### 2.2 Tipografia → `TextTheme`

A Opção B tem uma escala de 7 degraus com pesos diferentes da escala MD3 atual (que já usa os papéis certos, mas com tamanhos/pesos de outra marca). Sora já está registrada no `pubspec.yaml` com os pesos 400/500/600/700/800 — **cobre os 7 degraus sem precisar de novo asset de fonte**.

| Token Opção B | Tamanho/altura/peso | Papel MD3 mais próximo | Uso |
|---|---|---|---|
| `display` | 34/40, 800 | `displayLarge` (hoje 36/700 → vira 34/800) | Saldo geral, valores hero |
| `title1` | 24/30, 800 | `headlineSmall` (hoje 24/700 → vira 24/800) | Título de tela |
| `title2` | 18/24, 700 | `titleLarge` (hoje 20/700 → vira 18/700) | Título de card |
| `bodyLg` | 16/22, 500 | `titleMedium` (hoje 16/600 → vira 16/500) | Nome do item, valor de linha |
| `body` | 15/21, 400 | `titleSmall`/`bodyLarge` (hoje 15/600 ou 14/400 → vira 15/400) | Texto corrido |
| `label` | 13/18, 600 | `bodyMedium` (hoje 13/400 → vira 13/600) | Chip, botão, rótulo |
| `caption` | 12/16, 500 | `bodySmall`/`labelMedium` (hoje 12/400 → vira 12/500) | Metadados, timestamps |

`theme_fintech.dart` ganha seu próprio `_textThemeFintech()` — não dá pra reaproveitar `_textTheme()` de `theme.dart` porque os pesos mudam nos MESMOS papéis MD3 (um `if` aqui teria que trocar praticamente toda função, o que já é reescrever — melhor ser um arquivo próprio desde o início).

### 2.3 Raios — reaproveita 100% dos tokens existentes, sem criar nada novo

Comparando `ClxRadii` (`core/design/tokens.dart`) com a escala da Opção B:

- Opção B: `sm=10, md=14, lg=20, pill` — **isso já existe** como `ClxRadii.md=10`, `ClxRadii.lg=14`, `ClxRadii.xl=20`, `ClxRadii.pill=100`.
- A única diferença é de *nome*: o degrau mais baixo da Opção B (`sm`, 10px) é o que o código chama de `md`. `ClxRadii.sm` (6px) simplesmente **não é usado** nas telas fintech.

Decisão: **não criar `ClxRadiiFintech`**. Documentar no style guide da Onda 1 que as telas Android-fintech usam `ClxRadii.{md,lg,xl,pill}` (nunca `.sm`) — zero token novo, zero risco de duplicar a escala errado.

### 2.4 Espaçamento — idêntico, zero mudança

`ClxSpace.{x1,x2,x3,x4,x5,x6,x8}` = 4/8/12/16/20/24/32 — bate exatamente com a grade de 4px da Opção B. `ClxLayout.minTouchTarget = 48` já é o mínimo pedido. Nada a fazer aqui.

### 2.5 O que exige mudança de widget, não só de tema

| Elemento da Opção B | Por que ThemeData não basta | Onde entra |
|---|---|---|
| Hero de saldo (card escuro `ink`-on-`bg`, número gigante) | Inversão de cor (fundo escuro mesmo no tema claro) não é um componente MD3 padrão | Novo widget `FintechBalanceHero` em `painel/financeiro/` (usado só quando `isFintechClean`) |
| Cards hairline com número grande (KPI) | Layout de grid 2 colunas + tipografia `display`/`title1` num card — composição, não cor | Novo widget `FintechKpiCard`, reaproveitando `ClxCard` como casco |
| CTA fixo no rodapé (sticky, com gradiente de fade) | `Scaffold` atual não tem esse slot; é posicionamento absoluto sobre o conteúdo | Novo widget `FintechStickyCta`, usado em `os_execucao_screen.dart` (Onda 2) |
| Bottom nav de 5 itens (admin) | Estrutural — troca Drawer/Sidebar por `NavigationBar`, ver §3 | `PainelShell` ganha um branch `isFintechClean` |
| Checklist com item "obrigatório" destacado, progresso | Já existe conceito parecido — precisa confirmar se `os_execucao_screen.dart` atual já modela isso ou se é novo | Onda 2, avaliar no código antes de estimar |

---

## 3. Mudança estrutural de navegação

### Estado atual

- **Painel (admin/gerente)**: `PainelShell` (`painel/shell/painel_shell.dart`) já é responsivo por breakpoint — desktop (≥1024px) usa sidebar fixa, "medium" (600–1023px) usa `NavigationRail`, compacto (<600px) usa `Drawer` + hambúrguer na AppBar. O menu tem **9 seções** + Conta: `PainelSection.{dashboard, clientes, ordens, agenda, financeiro, servicos, usuarios, avaliacoes, whatsapp(admin-only), conta}` (`painel/shell/painel_nav.dart`).
- **Profissional**: `ProfShell` (`profissional/prof_shell.dart`) já é uma `NavigationBar` de 3 itens (Serviços/Mapa/Perfil) sobre `StatefulShellRoute.indexedStack` — **já bate exatamente** com a tela 2 do mock. Não precisa mudar estrutura, só reskin (tema).

### Mudança proposta (só admin/gerente, só quando `isFintechClean`)

O mock mostra 5 itens: **Dashboard, Agenda, Financeiro, Serviços, Mais**. Isso cobre 4 das 9 seções diretamente; as outras 5 (**Clientes, Ordens de Serviço, Usuários, Avaliações, WhatsApp**) mais **Conta** precisam ir para um destino "Mais".

Implementação sem duplicar telas: `PainelShell.build()` já recebe o `StatefulNavigationShell` (o `IndexedStack` das seções) e já ramifica por `LayoutBuilder` — o novo branch entra como um quarto caso, **antes** do breakpoint compacto atual:

```dart
if (isFintechClean && constraints.maxWidth < _desktopBreakpoint) {
  return _FintechScaffold(navigationShell: navigationShell, section: section, role: role);
}
// ... os 3 branches de hoje, inalterados, servem a Web
```

`_FintechScaffold` é um widget novo (`painel/shell/fintech/fintech_painel_shell.dart` ou similar) que:
- Desenha `NavigationBar` com 5 destinos: os 4 diretos + "Mais".
- "Mais" abre um **bottom sheet ou tela simples** listando as 5 seções restantes + Conta — reaproveitando os MESMOS `PainelNavItem`/`painelPath()` de `painel_nav.dart` (nenhuma tela nova, nenhuma rota nova — é puramente uma segunda casca em cima do MESMO `StatefulShellRoute.indexedStack` de `painel_routes.dart`).
- Continua chamando `navigationShell.goBranch(i)` do mesmo jeito que a sidebar/rail fazem hoje — não adiciona rotas, só um jeito diferente de navegar entre os branches que já existem.

Como o breakpoint desktop (≥1024px) nunca é atingido num telefone Android real, o caminho "tablet Android grande" fica coberto pelo `_mediumBreakpoint` (NavigationRail) já existente — vale confirmar com o dono se um tablet Android também deve ver a bottom nav de 5 itens ou o rail atual (ver Pergunta Aberta P-2).

### Agrupamento proposto pro "Mais" — precisa validação do dono

O mock não mostra o conteúdo do "Mais", só o ícone. Proposta de agrupamento (ordem por frequência de uso estimada, não confirmada com o dono):

1. Ordens de Serviço
2. Clientes
3. Avaliações
4. Usuários
5. WhatsApp *(admin-only, mesmo guard de hoje)*
6. Minha Conta *(rodapé, como na Web)*

**Atenção:** "Ordens de Serviço" ficar fora da bottom nav direta e dentro de "Mais" é uma escolha de UX que merece confirmação explícita do dono — é uma seção operacional pesada, diferente de Avaliações/Usuários que são consultadas com menos frequência.

---

## 4. Faseamento em ondas paralelizáveis

Pensado para **2 executores simultâneos** (mobile-developer × 2, ou 1 mobile + 1 mobile/backend de apoio na Onda 4). Onda 1 é sequencial-bloqueante (fundação); Ondas 2 e 3 rodam em paralelo depois dela; Onda 4 é sequencial no fim.

### Onda 1 — Fundação (bloqueante, 1 executor, não paraleliza)

**Arquivos-alvo:**
- `lib/core/design/cleanox_colors.dart` — novos `CleanoxColors.fintechLight`/`.fintechDark` + campo `onPrimary`
- `lib/core/design/theme_fintech.dart` (novo) — `buildFintechLightTheme()`/`buildFintechDarkTheme()`, `_textThemeFintech()`
- `lib/core/design/app_surface_provider.dart` (novo) — `appSurfaceProvider`
- `lib/app.dart` — instala o `ProviderScope` aninhado + troca de `theme`/`darkTheme` condicional
- `lib/core/design/widgets/clx_button.dart` — troca `ClxBrand.onPrimary` fixo por `context.clx.onPrimary`
- `lib/painel/shell/fintech/fintech_painel_shell.dart` (novo, esqueleto) — `NavigationBar` de 5 itens + "Mais", sem estilizar ainda

**Critério de pronto:** `flutter run -t lib/main_android.dart` mostra o app com as cores/tipografia da Opção B e a bottom nav de 5 itens navegando entre as seções já existentes; `flutter run -t lib/main_painel.dart` continua pixel-idêntico ao que está em produção hoje.

**O que NÃO pode quebrar:** todos os testes de `test/` (atualmente 52 arquivos `*_test.dart`) continuam passando sem editar nenhum teste — o `ProviderScope` aninhado em `CleanosApp` é auto-suficiente a partir do `surface` que os testes já passam.

### Onda 2 — Telas do Profissional (paralelizável com Onda 3)

**Arquivos-alvo:** `lib/features/login/login_screen.dart`, `lib/profissional/meus_servicos/{meus_servicos_screen,os_card,pagamento_modal}.dart`, `lib/profissional/os_execucao/os_execucao_screen.dart`.

**Critério de pronto:** as 3 telas do mock que envolvem o profissional (Login, Home/Meus Serviços, Execução de OS) reproduzem o layout do `design-opcao-b.html` no APK, com `flutter test` cobrindo os widgets novos (`FintechStickyCta`, cards de job).

**O que NÃO pode quebrar:** a Web não tem tela de "meus serviços"/"execução de OS" (é feature só-profissional-mobile hoje?) — **confirmar** se `os_execucao_admin_screen.dart` (Painel) reaproveita algum widget dessas telas antes de mexer, pra não vazar estilo fintech pro admin via um widget compartilhado sem querer.

### Onda 3 — Telas do Financeiro/Admin (paralelizável com Onda 2)

**Arquivos-alvo:** `lib/painel/financeiro/fin_visao_geral_screen.dart` (hero de saldo + KPIs + ações rápidas — já tem grid de 4 ações, só reskin + `FintechBalanceHero`/`FintechKpiCard` novos), `lib/painel/financeiro/lancamentos/*` (tela de lançamentos do mock), `lib/painel/shell/fintech/fintech_painel_shell.dart` (completar a tela "Mais").

**Critério de pronto:** as telas 4 e 5 do mock (Visão geral, Lançamentos) reproduzidas no APK; grade 2x2 de ações rápidas (já existe desde `baacec5`) e filtros colapsáveis (já existem desde `5e70b38`) continuam funcionando dentro do novo visual — ver riscos no §5.

**Atenção de escopo:** esta onda só cobre as 2 telas do mock. O Painel tem 9 seções — Ondas futuras (fora deste plano) cobririam Clientes/Ordens/Usuários/Avaliações/WhatsApp no visual fintech; até lá, essas seções abrem no APK com o visual novo só na casca (bottom nav) mas conteúdo ainda no estilo MD3 atual, o que é uma inconsistência temporária a comunicar ao dono.

### Onda 4 — Polimento + QA (sequencial, depois de 2 e 3 convergirem)

- Rodar `flutter test` completo + os testes existentes do módulo Financeiro (`bda7b11`, `7744973`) especificamente no tamanho mobile, já que foram os fixes mais recentes.
- QA visual manual nas 5 telas do mock, claro e escuro, comparando lado a lado com o `design-opcao-b.html`.
- Prova de que a Web não mudou: **não existe infraestrutura de golden test hoje** (`find test -iname "*golden*"` vazio) — a prova prática nesta rodada é rodar a suíte de widget tests existente que já constrói `CleanosApp(surface: AppSurface.painel)` e olhar visualmente o `main_painel.dart` em produção antes/depois do merge. Recomendação (fora do escopo desta implementação, decisão do dono): iniciar golden tests da Web como rede de segurança permanente para o *próximo* redesign, não bloquear esta onda nisso.

---

## 5. Riscos e mitigação

| Risco | Onde conflita | Mitigação |
|---|---|---|
| **Fixes mobile recentes assumem o tema MD3 atual** (grade 2x2 das ações rápidas `baacec5`, filtros colapsáveis `5e70b38`, headers responsivos `8802602`/`1881086`/`3ed100a`) | Todos em `painel/financeiro/` — exatamente a área da Onda 3 | Esses fixes são de **layout/breakpoint**, não de cor — o grid 2x2 e o colapso de filtro são lógica de `LayoutBuilder`/`MediaQuery`, que não muda com o tema. Risco real é baixo, mas a Onda 3 deve rodar os testes de regressão `bda7b11`/`7744973` explicitamente após o reskin, não só o `flutter test` geral. |
| **`ClxBrand.onPrimary` hardcoded em `ClxButton`** (único hardcode de marca fora do `ThemeExtension`, achado em `core/design/widgets/clx_button.dart:40`) | Onda 1 | Resolvido na própria Onda 1 (vira campo de `CleanoxColors`) — listado aqui pra não ser esquecido/re-descoberto depois. |
| **`main_profissional.dart` legado ainda existe** — não fica claro se ainda é buildado/distribuído ou se foi substituído por `main_android.dart` | Escopo da Onda 2 — a Opção B vale pra ele também? | Pergunta Aberta P-1 abaixo — bloqueia decisão de escopo, não bloqueia início da Onda 1. |
| **Ausência de golden tests** — "a Web não pode mudar" hoje só pode ser verificado por inspeção manual, não por CI | Onda 4 | Mitigação de curto prazo: checklist manual de QA antes do merge (§4, Onda 4). Mitigação estrutural: proposta separada de golden tests para a Web, fora do escopo desta remodelagem (decisão do dono, ver P-3). |
| **Inconsistência visual temporária** nas 5 seções do Painel que a Opção B não cobre nesta rodada (Clientes/Ordens/Usuários/Avaliações/WhatsApp) | Onda 3 em diante | Comunicar explicitamente ao dono que, ao fim das Ondas 1–4, o APK terá casca (bottom nav) e 3 seções (Dashboard implícito, Financeiro, e as telas do profissional) no visual novo, com o resto ainda em MD3 clássico até uma rodada futura. |
| **Esforço grosseiro por onda** | — | Onda 1: ~2–3 dias (1 executor). Onda 2: ~4–5 dias (1 executor). Onda 3: ~5–6 dias (1 executor, mais telas e mais lógica de dados). Onda 4: ~2–3 dias. Com 2 executores rodando Onda 2 ∥ Onda 3, o caminho crítico é Onda 1 (seq) → max(Onda 2, Onda 3) → Onda 4 (seq) ≈ **2–3 + 6 + 3 ≈ 11–12 dias úteis**, não 18–20. |

---

## Perguntas abertas para o dono (bloqueiam decisões, não o início da Onda 1)

- **P-1 — `main_profissional.dart` legado:** ainda é buildado/distribuído, ou o APK unificado (`main_android.dart`) já o substituiu de vez? Se substituído, vale removê-lo neste redesign (fora do escopo original da missão, mas encontrado durante a exploração) ou isso fica pra depois?
- **P-2 — Tablet Android:** num tablet Android (janela ≥600px), a Opção B deve manter a bottom nav de 5 itens ou usar o `NavigationRail` que a Web já tem pra essa largura? O mock só mostra telefone.
- **P-3 — Agrupamento do "Mais":** confirmar a ordem proposta no §3 (Ordens de Serviço, Clientes, Avaliações, Usuários, WhatsApp, Conta) — em especial se "Ordens de Serviço" deveria ter posição direta na bottom nav em vez de "Serviços" (catálogo), dado que OS é operação do dia a dia e Serviços é cadastro.
- **P-4 (menor, não bloqueia) — Golden tests da Web:** proposta de iniciar uma rede de segurança automatizada pra "a Web não muda" fica registrada aqui como sugestão de próxima iniciativa, fora do escopo desta remodelagem.
