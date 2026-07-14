/// prof_shell.dart — Casco Easypay do APP DO PROFISSIONAL.
///
/// Cabeçalho fixo (título + avatar → Perfil) + bottom nav:
/// Serviços / [Carteira se comissão] / Mapa / Perfil.
/// Branches fixos do go_router (0 Serviços, 1 Financeiro, 2 Mapa, 3 Perfil);
/// a UI esconde Carteira quando não há comissão ativa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/design/design.dart';
import '../core/env/env.dart';
import '../core/formatters/formatters.dart';
import '../core/models/user.dart';
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
  int _branchForNav(int navIndex, {required bool hasFin}) {
    if (hasFin) return navIndex;
    if (navIndex == 0) return 0;
    return navIndex + 1; // 1→2 mapa, 2→3 perfil
  }

  int _navForBranch(int branch, {required bool hasFin}) {
    if (hasFin) return branch.clamp(0, 3);
    if (branch <= 0) return 0;
    if (branch == 1) return 0;
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

  void _openPerfil() {
    widget.navigationShell.goBranch(
      3,
      initialLocation: widget.navigationShell.currentIndex == 3,
    );
  }

  String _headerTitle(User? user) {
    final branch = widget.navigationShell.currentIndex;
    if (branch == 0) {
      final raw = (user?.nome ?? user?.name ?? '').trim();
      final first = raw.isEmpty ? '' : raw.split(RegExp(r'\s+')).first;
      return first.isEmpty ? 'Olá 👋' : 'Olá, $first 👋';
    }
    return switch (branch) {
      1 => 'Carteira',
      2 => 'Mapa',
      3 => 'Perfil',
      _ => kAppDisplayName,
    };
  }

  String _headerSubtitle() {
    final branch = widget.navigationShell.currentIndex;
    if (branch == 0) return _longDatePtBr();
    return switch (branch) {
      1 => 'Comissões e ganhos',
      2 => 'Serviço em andamento',
      3 => 'Seus dados e ajustes',
      _ => '',
    };
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

    final items = <_NavSpec>[
      const _NavSpec(
        icon: Icons.checklist_rounded,
        label: 'Serviços',
        keyName: 'prof-nav-servicos',
      ),
      if (hasFin)
        const _NavSpec(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Carteira',
          keyName: 'prof-nav-carteira',
        ),
      const _NavSpec(
        icon: Icons.map_rounded,
        label: 'Mapa',
        keyName: 'prof-nav-mapa',
      ),
      const _NavSpec(
        icon: Icons.person_rounded,
        label: 'Perfil',
        keyName: 'prof-nav-perfil',
      ),
    ];

    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ProfTopBar(
              title: _headerTitle(me),
              subtitle: _headerSubtitle(),
              user: me,
              onAvatarTap: _openPerfil,
            ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 12,
        shadowColor: clx.ink.withValues(alpha: 0.12),
        color: clx.bg.withValues(alpha: 0.96),
        child: SizedBox(
          height: 68 + bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _ProfNavItem(
                      key: ValueKey(items[i].keyName),
                      icon: items[i].icon,
                      label: items[i].label,
                      selected: selected == i,
                      onTap: () => _onTap(i, hasFin: hasFin),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho fixo igual ao do painel: título + subtítulo + avatar à direita.
class _ProfTopBar extends StatelessWidget {
  const _ProfTopBar({
    required this.title,
    required this.subtitle,
    required this.user,
    required this.onAvatarTap,
  });

  final String title;
  final String subtitle;
  final User? user;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: clx.bg2,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: ClxMotion.shortDuration,
                    child: Text(
                      title,
                      key: ValueKey(title),
                      style: tt.titleLarge?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: ClxMotion.shortDuration,
                    child: Text(
                      subtitle,
                      key: ValueKey(subtitle),
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Perfil',
              child: UserAvatar(
                user: user,
                radius: 22,
                onTap: onAvatarTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _longDatePtBr() {
  final brt = DateTime.now().toUtc().subtract(kBrtOffset);
  const semana = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  const meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final dia = brt.day.toString().padLeft(2, '0');
  return '${semana[brt.weekday - 1]}, $dia de ${meses[brt.month - 1]}';
}

class _NavSpec {
  const _NavSpec({
    required this.icon,
    required this.label,
    required this.keyName,
  });
  final IconData icon;
  final String label;
  final String keyName;
}

class _ProfNavItem extends StatelessWidget {
  const _ProfNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = selected ? clx.primary : clx.ink3;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: ClxMotion.shortDuration,
              curve: ClxMotion.standard,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected
                    ? clx.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            AnimatedContainer(
              duration: ClxMotion.shortDuration,
              margin: const EdgeInsets.only(top: 3),
              width: selected ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: clx.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
