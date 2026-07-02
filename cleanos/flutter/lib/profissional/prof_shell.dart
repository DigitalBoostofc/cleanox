/// prof_shell.dart — Casco do APP DO PROFISSIONAL (Slice B1): bottom nav real.
///
/// Espelha `AppLayout.tsx`: três abas (Serviços / Mapa / Perfil) sobre o
/// `StatefulShellRoute.indexedStack` (estado preservado entre trocas), com
/// NavigationBar na thumb zone. A execução da OS (Slice B2) sobe em tela cheia
/// pela rota `/app/os/:osId` (navigator raiz), deep-linkável.
///
/// ── ROTAS ANINHADAS ──────────────────────────────────────────────────────────
/// Cada aba é um branch do StatefulShellRoute (ver `prof_routes.dart`): cada uma
/// tem URL (`/app`, `/app/mapa`, `/app/perfil`) e a troca usa
/// `navigationShell.goBranch(i)` (preserva o estado da aba). O casco só desenha a
/// moldura (bottom nav) — o corpo é o [StatefulNavigationShell].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/design.dart';
import '../core/env/env.dart';
import 'location/tracking_providers.dart';

class ProfShell extends ConsumerStatefulWidget {
  const ProfShell({super.key, required this.navigationShell});

  /// IndexedStack das abas, entregue pelo `StatefulShellRoute.indexedStack`.
  /// Preserva o estado de cada aba entre trocas.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ProfShell> createState() => _ProfShellState();
}

class _ProfShellState extends ConsumerState<ProfShell> {
  @override
  void initState() {
    super.initState();
    final push = ref.read(pushRegistrationServiceProvider);
    // Gancho de deep-link do push (finding G-8/#8 do doc09): o toque na
    // notificação "Nova OS" abre `/app/os/:id`. Ligado sempre (barato); o
    // registro FCM em si fica atrás de `Env.pushEnabled`.
    push.bindDeepLink((osId) {
      if (mounted) context.go('/app/os/$osId');
    });
    // B4/G-2: registra push (no-op enquanto Env.pushEnabled == false).
    if (Env.pushEnabled) {
      // ignore: discarded_futures
      push.register();
    }
  }

  void _onTap(int index) => widget.navigationShell.goBranch(
    index,
    // Retocar a aba ativa volta à raiz daquela aba (padrão de bottom nav).
    initialLocation: index == widget.navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(bottom: false, child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            label: 'Serviços',
          ),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
