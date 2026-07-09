# MVP Build Spec — Cleanox / CleanOS

**Data:** 2026-06-25 | **Versão:** 1.1 | **Para:** dono do negócio + time de desenvolvimento

> ⚠ **Implementação atual (2026-07):** frontend **100% Flutter** (`cleanos/flutter/`) — painel em Flutter Web + APK Android unificado. Backend PocketBase (`cleanos/pb/`). DNA e orientações de dev: [`../CLAUDE.md`](../CLAUDE.md). Qualquer menção a React/PWA/Vite neste arquivo é **histórico de especificação**; não recriar stack legada.

---

## 1. O que é

Uma ferramenta interna para a empresa de higienização de estofados a domicílio (sofá, poltrona, colchão, cadeira, tapete). É composta de dois ambientes: um **painel web** (Flutter Web) para o dono/atendente gerenciar tudo, e um **app no celular** (Flutter Android) para o profissional consultar os serviços do dia. A prioridade é simplicidade — o volume é pequeno (menos de 50 ordens de serviço por mês) e o objetivo é organizar a operação e proteger o negócio.

---

## 2. Os 2 princípios que resolvem a dor central

> **O problema:** prestador aprende a operar, sai e vira concorrente levando os clientes.

---

### Princípio 1 — O dinheiro fica na empresa

O cliente paga na **maquininha da empresa** (Stone, PagBank, Cielo — no CNPJ da empresa). O profissional apenas opera a maquininha no local; o dinheiro cai **direto na conta da empresa**, nunca na conta do profissional. Sem link de pagamento, sem gateway online, sem split automático. Simples.

### Princípio 2 — O profissional trabalha sem saber quem é o cliente

O profissional **nunca vê o telefone do cliente**. Antes do dia do serviço, vê só o bairro. Quando toca "Iniciar" no dia, recebe o endereço para chegar. O aviso "estou a caminho" sai pelo sistema da empresa (WhatsApp ou SMS do número da empresa), não do celular do profissional. A base de clientes pertence à empresa, não ao prestador.

---

## 3. As telas

### Painel web (dono / atendente)

| Área | O que faz |
|---|---|
| **Dashboard** | Resumo do dia: serviços agendados, em andamento, concluídos, faturamento do dia. Lista dos próximos atendimentos. |
| **Clientes** | Lista com nome, telefone, bairro, último serviço, status ativo/inativo. Busca rápida. Botão "Novo cliente". **Esta lista é o ativo mais valioso da empresa.** |
| **Ordens de Serviço** | Lista por status (Agendadas / Em andamento / Concluídas) com OS, cliente, serviço, data, profissional. Botão "Nova OS". |
| **Agenda** | Calendário (dia / semana / mês) com os serviços agendados. |
| **Financeiro** | Recebido no mês, pendente, ticket médio. Lançamentos com cliente, data, valor, forma de pagamento, status. Coluna "a repassar ao profissional" — admin marca como pago manualmente. |
| **Usuários** | Cadastro de proprietário, gerente e colaborador (profissional/prestador). |

### App do profissional (celular — Flutter Android, APK unificado)

Tela principal **"Meus serviços"**: lista do dia com hora, cliente (nome parcial), serviço, endereço (só no dia), status e botões de ação. Navegação inferior: Meus serviços / Mapa / Perfil.

---

## 4. Ajustes anti-desvio (a parte mais importante)

### No app do profissional

| Situação | Hoje (sem sistema) | No MVP |
|---|---|---|
| Ver o cliente antes do dia | Sabe nome, telefone, endereço | Vê só: primeiro nome + inicial ("Carlos S."), tipo de serviço, **bairro**, horário |
| Chegar no cliente no dia | Liga do próprio celular | Toca "Iniciar" → sistema libera endereço completo + botão "Ver rota" (abre Google Maps) |
| Avisar que está a caminho | Liga do próprio celular | Botão **"Avisar que estou a caminho"** → dispara WhatsApp/SMS **pelo número da empresa** |
| Histórico após concluir | Fica com o contato | Endereço **some** do histórico — ele volta a ver só o bairro |
| Telefone do cliente | Sempre visível | **Nunca aparece** em nenhuma tela do profissional |
| Registrar pagamento | Anota no papel ou não anota | Passo obrigatório antes de "Concluir": informa valor + forma (débito / crédito / Pix da maquininha) |

### No painel (admin)

| Item | Comportamento no MVP |
|---|---|
| Login de colaborador | Cai direto no **app do profissional** (com todas as restrições acima), nunca no painel |
| Telefone do cliente | Visível apenas para admin e gerente |
| Repasse ao profissional | Coluna "a repassar" no Financeiro — admin marca como pago manualmente após conferir extrato da maquininha. Repasse semanal, feito por Pix pelo dono |
| Dados do cliente (endereço, histórico) | Visível normalmente para admin/gerente no painel |

---

## 5. Fluxo de uma OS (ponta a ponta)

```
Cliente entra em contato (WhatsApp, telefone, indicação)
    ↓
Atendente cadastra o cliente + cria a OS no painel
    ↓
Atribui um profissional + define data e horário
    ↓
Profissional recebe notificação: vê bairro + horário
    ↓
No dia do serviço — profissional toca "Iniciar"
    → sistema libera endereço completo + avisa o cliente pelo WhatsApp/SMS da empresa
    ↓
Profissional executa o serviço
    ↓
Profissional registra pagamento na maquininha (valor + forma)
    ↓
Profissional toca "Concluir" → endereço some do histórico dele
    ↓
Admin confere no extrato da maquininha (Stone/PagBank/Cielo)
    ↓
Admin faz repasse semanal ao profissional via Pix e marca como pago no sistema
    ↓
Cliente recebe confirmação da empresa (WhatsApp/SMS)
```

---

## 6. Estados de uma OS

```
agendada → atribuída → em_andamento → concluída
                   ↘
                 cancelada
```

| Estado | Quando muda |
|---|---|
| **agendada** | OS criada no painel |
| **atribuída** | Admin define o profissional |
| **em_andamento** | Profissional toca "Iniciar" no app |
| **concluída** | Profissional toca "Concluir" (após registrar pagamento) |
| **cancelada** | Admin cancela em qualquer etapa antes de concluir |

Sem estados financeiros complexos no MVP.

---

## 7. Dinheiro — como funciona a maquininha

- A maquininha (Stone / PagBank / Cielo) está no **CNPJ da empresa**.
- O profissional opera a maquininha no local do serviço.
- O dinheiro cai na **conta da empresa**, não na do profissional.
- O profissional registra o pagamento no app (valor + forma) antes de concluir a OS.
- O admin confere o extrato da maquininha e faz o repasse ao profissional **manualmente, toda semana**, via Pix.
- O sistema controla quanto cada profissional tem a receber e registra quando o repasse foi feito.

**Não há nenhum gateway de pagamento online no MVP.** Nenhum split automático. Nenhum link de pagamento.

---

## 8. Fora do MVP (depois, se fizer sentido)

Estes itens **não serão construídos agora** para manter o sistema simples:

- Gateway de pagamento online / split automático / link de pagamento
- GPS em tempo real no mapa (a aba "Mapa" abre o Google Maps com o endereço)
- App iOS (Android já entregue em Flutter; iOS bloqueado por gate do dono)
- Pagamento online pelo cliente antes do serviço
- Nota fiscal automática (NFS-e)
- Detecção por IA de qualquer tipo
- Portal do cliente (autoagendamento, histórico)

---

## 9. Ressalva honesta

A tecnologia reduz o risco de desvio de clientes — ela não elimina. Como o profissional está fisicamente na casa do cliente, o contato pode ser trocado verbalmente no local, fora do sistema. O que o MVP faz é (a) não facilitar isso — o profissional nunca tem o telefone em mãos e nunca leva o endereço anotado — e (b) tornar tudo rastreável: o admin vê quais clientes um profissional atendeu e quando. Mitigações concretas: a OS não fecha sem o pagamento registrado (rastreia se o dinheiro passou pela maquininha), e o cliente recebe confirmação oficial da empresa após cada serviço, reforçando a marca como responsável pelo serviço.

---

## 10. Apêndice técnico (para o desenvolvedor)

### Stack

**Backend: PocketBase numa VPS.**
- PocketBase = um backend pronto, em binário único (Go + SQLite). Já traz: autenticação com papéis, API REST/realtime, painel administrativo, armazenamento de arquivos (fotos do serviço) e REGRAS DE ACESSO POR COLEÇÃO. Barato e simples de rodar numa VPS — ideal pra <50 OS/mês.
- Rodar na VPS como serviço (systemd), atrás de um proxy com HTTPS (Caddy ou Nginx), com backup periódico da pasta pb_data.

**Frontend: Flutter unificado (único frontend do projeto).**
- **Flutter Web** (`main_painel.dart`) — painel admin/gerente em https://app.cleanox.com.br
- **Flutter Android** (`main_android.dart`) — APK único; roteamento por papel (admin → painel, profissional → app)
- Estado: Riverpod · rotas: go_router · SDK: `pocketbase` Dart
- Web estreita (&lt;600dp) usa o mesmo visual **Fintech Clean** do APK; desktop/tablet web mantém layout clássico (sidebar)

**Papéis (auth do PocketBase):** admin, gerente, profissional(colaborador). O catálogo de serviços (sofá X lugares, poltrona, colchão, tapete, etc.) e os preços são editáveis pelo admin.

---

> ### ⚠ Proteção anti-desvio = na API, não na tela
>
> - Esconder telefone/endereço só no frontend NÃO protege nada — o profissional abre o navegador e vê o JSON da API. A proteção TEM que ser imposta pelas regras/hooks do PocketBase.
> - Modelagem recomendada:
>   1. O contato sensível do cliente (telefone, endereço completo, sobrenome) fica numa coleção que o papel "profissional" NÃO tem permissão de leitura (regra de API da coleção).
>   2. O profissional lê uma "visão de job" que expõe só: primeiro nome + inicial, tipo de serviço, BAIRRO e horário.
>   3. O endereço completo só é liberado pro profissional via HOOK do PocketBase (pb_hooks, JS) quando a OS muda para "em_andamento" (ao tocar "Iniciar") no dia do serviço; após "concluida", o acesso ao endereço é novamente restringido (some do histórico do profissional).
>   4. O telefone do cliente nunca é exposto ao profissional em nenhum estado. O aviso "estou a caminho" é disparado pelo sistema (envio pela empresa), não pelo profissional.
> - Recomendação: a Auditoria de Segurança deve testar essas regras na API (não na UI) antes do go-live.

---

*MVP Build Spec — Cleanox / CleanOS | 2026-06-25*
