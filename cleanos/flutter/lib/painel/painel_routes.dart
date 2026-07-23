/// painel_routes.dart — Rotas da superfície PAINEL (admin/gerente · Flutter Web).
///
/// Expõe [painelShellRoute]: o `StatefulShellRoute.indexedStack` do `/painel`,
/// com UM branch (seção) por [PainelSection]. O `core/router` importa esta função
/// e a pendura — as features registram suas rotas AQUI, sem o router precisar
/// conhecer cada tela e sem dependência circular (este arquivo NÃO importa o
/// `app_router`; só o go_router + as telas).
///
/// ── DEEP-LINK + ESTADO ───────────────────────────────────────────────────────
/// Cada seção ganha URL própria ([painelPath]) e o `indexedStack` preserva o
/// estado entre trocas (o que o `IndexedStack` interno fazia). Sub-rotas
/// deep-linkáveis: `/painel/ordens/:osId/execucao`, `/painel/servicos/:id`
/// (editor) e `/painel/financeiro/:tab` (7 abas).
///
/// ── CARREGAMENTO ─────────────────────────────────────────────────────────────
/// Import eager de todas as seções (estável em prod). Deferred + LazySection
/// quebrava Agenda/Financeiro/Serviços no browser ("Não foi possível carregar
/// este módulo") após deploys com chunks desalinhados / service worker.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../profissional/os_execucao/os_execucao_screen.dart';
import 'agenda/agenda_screen.dart';
import 'avaliacoes/avaliacoes_screen.dart';
import 'clientes/clientes_screen.dart';
import 'conta/conta_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'financeiro/fin_shell.dart';
import 'ordens/ordens_screen.dart';
import 'servicos/servico_editor.dart';
import 'servicos/servicos_list_screen.dart';
import 'shell/painel_nav.dart';
import 'shell/painel_shell.dart';
import 'usuarios/usuarios_screen.dart';
import 'whatsapp/whatsapp_admin_screen.dart';
// ⚠️ Eager (não deferred): em prod o loadLibrary dos chunks quebrou Agenda /
// Financeiro / Serviços ("Não foi possível carregar este módulo"). Bundle
// inicial maior, mas módulos estáveis.

/// Constrói o `StatefulShellRoute.indexedStack` do `/painel`.
///
/// [rootNavigatorKey] é o navigator RAIZ (acima do casco): as rotas de tela
/// cheia (execução da OS, editor de serviço) sobem nele para cobrir a sidebar,
/// como o `Navigator.push` fazia antes — mantendo a UX e ficando deep-linkáveis.
StatefulShellRoute painelShellRoute(
  GlobalKey<NavigatorState> rootNavigatorKey,
) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        PainelShell(navigationShell: navigationShell),
    branches: [
      // ── Dashboard (leve, eager) — home do Painel. ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.dashboard),
            name: 'painel-dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      ),
      // ── Clientes (cofre, lazy). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.clientes),
            name: 'painel-clientes',
            builder: (context, state) => const ClientesScreen(),
          ),
        ],
      ),
      // ── Ordens de Serviço (lazy) + execução (tela cheia, root navigator). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.ordens),
            name: 'painel-ordens',
            builder: (context, state) => const OrdensScreen(),
            routes: [
              GoRoute(
                path: ':osId/execucao',
                name: 'painel-os-execucao',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final osId = state.pathParameters['osId']!;
                  return OSExecucaoScreen(osId: osId);
                },
              ),
            ],
          ),
        ],
      ),
      // ── Agenda (grade densa, lazy). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.agenda),
            name: 'painel-agenda',
            builder: (context, state) => const AgendaScreen(),
          ),
        ],
      ),
      // ── Financeiro (fl_chart/PDF, lazy) — 7 abas via `/painel/financeiro/:tab`. ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.financeiro),
            name: 'painel-financeiro',
            // Sem builder: só redireciona a URL "pura" para a aba default.
            // Compara a URI COMPLETA (não `matchedLocation`, que num redirect de
            // rota-pai vale só o trecho do pai — dispararia também nas sub-rotas).
            redirect: (context, state) =>
                state.uri.path == painelPath(PainelSection.financeiro)
                ? '${painelPath(PainelSection.financeiro)}/principal'
                : null,
            routes: [
              GoRoute(
                path: ':tab',
                name: 'painel-financeiro-tab',
                // Todas as abas casam ESTE mesmo padrão de rota → o `pageKey` do
                // go_router é estável entre elas: trocar de aba mantém o MESMO
                // page/element (o chunk deferred NÃO recarrega, sem re-spinner);
                // só o corpo interno do FinanceiroShell troca pela aba do slug.
                // Canonicalização de slug legado (visao-geral→principal, etc.)
                // no FinanceiroShell.
                builder: (context, state) {
                  final tabSlug = state.pathParameters['tab'] ?? 'principal';
                  return FinanceiroShell(tabSlug: tabSlug);
                },
              ),
            ],
          ),
        ],
      ),
      // ── Serviços (catálogo, lazy) + editor (tela cheia, root navigator). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.servicos),
            name: 'painel-servicos',
            builder: (context, state) => const ServicosListScreen(),
            routes: [
              GoRoute(
                path: 'novo',
                name: 'painel-servico-novo',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const ServicoEditorScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'painel-servico-editar',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  return ServicoEditorScreen(servicoId: id);
                },
              ),
            ],
          ),
        ],
      ),
      // ── Usuários (equipe pequena, eager). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.usuarios),
            name: 'painel-usuarios',
            builder: (context, state) => const UsuariosScreen(),
          ),
        ],
      ),
      // ── Avaliações (lazy). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.avaliacoes),
            name: 'painel-avaliacoes',
            builder: (context, state) => const AvaliacoesScreen(),
          ),
        ],
      ),
      // ── WhatsApp (admin-only, lazy) — o guard admin×gerente é global (redirect). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.whatsapp),
            name: 'painel-whatsapp',
            builder: (context, state) => const WhatsAppAdminScreen(),
          ),
        ],
      ),
      // ── Minha Conta (eager) — acessada pelo rodapé do usuário. ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: painelPath(PainelSection.conta),
            name: 'painel-conta',
            builder: (context, state) => const ContaScreen(),
          ),
        ],
      ),
    ],
  );
}
