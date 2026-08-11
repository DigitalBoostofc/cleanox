/// Garante que o CMS da vitrine usa a sessão autenticada do painel.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/painel/vitrine/vitrine_painel_screen.dart';
import 'package:cleanos/vitrine/admin/vitrine_admin_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  testWidgets(
    'VitrinePainelScope reutiliza o PocketBase autenticado do painel',
    (tester) async {
      final painelPb = PocketBase('https://app.cleanox.com.br');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [pocketBaseProvider.overrideWithValue(painelPb)],
          child: const MaterialApp(
            home: VitrinePainelScope(child: _SessionProbe()),
          ),
        ),
      );

      expect(find.text('mesma-sessao'), findsOneWidget);
    },
  );
}

class _SessionProbe extends ConsumerWidget {
  const _SessionProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painelPb = ref.watch(pocketBaseProvider);
    final vitrinePb = ref.watch(vitrineAdminPbProvider);
    return Text(
      identical(painelPb, vitrinePb) ? 'mesma-sessao' : 'outra-sessao',
    );
  }
}
