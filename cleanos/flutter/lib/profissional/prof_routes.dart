/// prof_routes.dart — Rotas da superfície PROFISSIONAL (Android · bottom nav).
///
/// Expõe [profShellRoute]: o `StatefulShellRoute.indexedStack` do `/app`, com um
/// branch por aba (Serviços / Mapa / Perfil) — o `indexedStack` preserva o estado
/// entre trocas (o que o `IndexedStack` interno do `ProfShell` fazia). O
/// `core/router` importa esta função e a pendura; as telas se registram AQUI, sem
/// dependência circular (não importa o `app_router`).
///
/// ── DEEP-LINK DA EXECUÇÃO ────────────────────────────────────────────────────
/// `/app/os/:osId` abre a execução da OS em tela cheia (navigator RAIZ, cobrindo
/// a bottom nav — como o `Navigator.push` fazia). Deep-linkável: é o que o push
/// "Nova OS" chama (`context.go('/app/os/:id')`, ver `push_registration_service`).
/// O flag `?pendentes=1` reabre a execução destacando os itens obrigatórios.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'financeiro/prof_financeiro_screen.dart';
import 'mapa/mapa_screen.dart';
import 'meus_servicos/meus_servicos_screen.dart';
import 'os_execucao/os_execucao_screen.dart';
import 'perfil/perfil_screen.dart';
import 'prof_shell.dart';

/// Constrói o `StatefulShellRoute.indexedStack` do `/app`.
///
/// Branches fixos: Serviços(0) · Financeiro(1) · Mapa(2) · Perfil(3).
/// A aba Financeiro só aparece na bottom nav se o profissional tiver comissão
/// ativa ([ProfShell] mapeia os índices).
///
/// [rootNavigatorKey] é o navigator RAIZ: a execução da OS sobe nele (tela cheia
/// sobre a bottom nav).
StatefulShellRoute profShellRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        ProfShell(navigationShell: navigationShell),
    branches: [
      // ── Serviços (home) + execução deep-linkável (tela cheia, root navigator). ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/app',
            name: 'app-servicos',
            builder: (context, state) => const MeusServicosScreen(),
            routes: [
              GoRoute(
                path: 'os/:osId',
                name: 'app-os-execucao',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => OSExecucaoScreen(
                  osId: state.pathParameters['osId']!,
                  obrigatoriosPendentes:
                      state.uri.queryParameters['pendentes'] == '1',
                ),
              ),
            ],
          ),
        ],
      ),
      // ── Financeiro (comissões) — sempre no router; nav condicional no shell. ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/app/financeiro',
            name: 'app-financeiro',
            builder: (context, state) => const ProfFinanceiroScreen(),
          ),
        ],
      ),
      // ── Mapa. ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/app/mapa',
            name: 'app-mapa',
            builder: (context, state) => const MapaScreen(),
          ),
        ],
      ),
      // ── Perfil. ──
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/app/perfil',
            name: 'app-perfil',
            builder: (context, state) => const PerfilScreen(),
          ),
        ],
      ),
    ],
  );
}
