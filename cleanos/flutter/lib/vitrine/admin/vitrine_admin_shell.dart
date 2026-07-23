/// Shell do admin da vitrine (`/admin/*`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import 'vitrine_admin_auth.dart';

class VitrineAdminShell extends ConsumerWidget {
  const VitrineAdminShell({super.key, required this.child});

  final Widget child;

  static const _nav = [
    (path: '/admin', label: 'Resumo', icon: Icons.dashboard_outlined),
    (
      path: '/admin/personalizar',
      label: 'Personalizar',
      icon: Icons.edit_outlined,
    ),
    (path: '/admin/midia', label: 'Mídia', icon: Icons.photo_outlined),
    (path: '/admin/servicos', label: 'Serviços', icon: Icons.list_alt_outlined),
    (
      path: '/admin/order-bumps',
      label: 'Order bumps',
      icon: Icons.local_offer_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final user = ref.watch(vitrineAdminUserProvider).valueOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    Widget navList({bool dense = false}) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final item in _nav)
              ListTile(
                dense: dense,
                leading: Icon(item.icon, size: 20),
                title: Text(item.label),
                selected: loc == item.path ||
                    (item.path != '/admin' && loc.startsWith(item.path)),
                selectedTileColor: ClxBrand.cyan.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(borderRadius: ClxRadii.rMd),
                onTap: () => context.go(item.path),
              ),
          ],
        );

    final body = Scaffold(
      backgroundColor: ClxBrand.canvas,
      appBar: AppBar(
        title: Text(
          wide ? 'Admin da vitrine' : _titleFor(loc),
          style: const TextStyle(fontFamily: kFontFamily),
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${user.displayName} · ${user.role.wire}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              ref.read(vitrineAdminAuthProvider).logout();
              context.go('/admin/login');
            },
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DrawerHeader(
                      child: Text(
                        'CLEANOX · Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ClxBrand.navy,
                        ),
                      ),
                    ),
                    Expanded(child: navList()),
                  ],
                ),
              ),
            ),
      body: wide
          ? Row(
              children: [
                Container(
                  width: 220,
                  color: ClxBrand.navy,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      listTileTheme: const ListTileThemeData(
                        iconColor: Colors.white70,
                        textColor: Colors.white,
                        selectedColor: Colors.white,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                          child: Text(
                            'CLEANOX',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(child: navList(dense: true)),
                      ],
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            )
          : child,
    );

    return body;
  }

  String _titleFor(String loc) {
    for (final item in _nav.reversed) {
      if (loc == item.path || loc.startsWith(item.path)) return item.label;
    }
    return 'Admin';
  }
}
