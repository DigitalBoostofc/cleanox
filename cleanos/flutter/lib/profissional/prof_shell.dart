/// prof_shell.dart — Casco do APP DO PROFISSIONAL: bottom nav.
///
/// Abas: Serviços / [Financeiro se comissão] / Mapa / Perfil.
/// Branches do go_router são fixos (0 Serviços, 1 Financeiro, 2 Mapa, 3 Perfil);
/// a UI esconde Financeiro quando o profissional não tem comissão ativa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/design/design.dart';
import '../core/env/env.dart';
import 'location/tracking_providers.dart';

class ProfShell extends ConsumerStatefulWidget {
  const ProfShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ProfShell> createState() => _ProfShellState();
}

class _ProfShellState extends ConsumerState<ProfShell> {
  @override
  void initState() {
    super.initState();
    final push = ref.read(pushRegistrationServiceProvider);
    push.bindDeepLink((osId) {
      if (mounted) context.go('/app/os/$osId');
    });
    if (Env.pushEnabled) {
      // ignore: discarded_futures
      push.register();
    }
  }

  /// Mapeia índice da bottom nav → branch do shell.
  /// Com comissão: 0→0, 1→1, 2→2, 3→3.
  /// Sem: 0→0, 1→2 (mapa), 2→3 (perfil) — pula financeiro.
  int _branchForNav(int navIndex, {required bool hasFin}) {
    if (hasFin) return navIndex;
    if (navIndex == 0) return 0;
    return navIndex + 1; // 1→2 mapa, 2→3 perfil
  }

  int _navForBranch(int branch, {required bool hasFin}) {
    if (hasFin) return branch.clamp(0, 3);
    if (branch <= 0) return 0;
    if (branch == 1) return 0; // financeiro escondido → trata como serviços
    if (branch == 2) return 1;
    return 2;
  }

  void _onTap(int navIndex, {required bool hasFin}) {
    final branch = _branchForNav(navIndex, hasFin: hasFin);
    widget.navigationShell.goBranch(
      branch,
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final me = ref.watch(currentUserProvider);
    final hasFin = me?.hasComissaoAtiva ?? false;
    final selected = _navForBranch(
      widget.navigationShell.currentIndex,
      hasFin: hasFin,
    );

    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(bottom: false, child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _onTap(i, hasFin: hasFin),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            label: 'Serviços',
          ),
          if (hasFin)
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Financeiro',
            ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Mapa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
