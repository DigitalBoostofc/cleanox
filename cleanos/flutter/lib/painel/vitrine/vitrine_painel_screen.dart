/// Editor da vitrine pública dentro do painel autenticado CleanOS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../vitrine/admin/vitrine_admin_auth.dart';
import '../../vitrine/admin/vitrine_admin_screens.dart';
import '../../vitrine/vitrine_api.dart';

/// Reaproveita o PocketBase já autenticado no painel para todas as telas do CMS.
/// Assim o administrador não precisa fazer um segundo login na vitrine.
class VitrinePainelScope extends ConsumerWidget {
  const VitrinePainelScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pb = ref.watch(pocketBaseProvider);
    return ProviderScope(
      overrides: [
        vitrineAdminPbProvider.overrideWithValue(pb),
        vitrineAdminApiProvider.overrideWithValue(VitrineApi(pb: pb)),
      ],
      child: child,
    );
  }
}

class VitrinePainelScreen extends StatelessWidget {
  const VitrinePainelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VitrinePainelScope(child: _VitrineEditor());
  }
}

class _VitrineEditor extends StatelessWidget {
  const _VitrineEditor();

  static final Uri _publicUrl = Uri.parse('https://agendar.cleanox.com.br');

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x5,
              ClxSpace.x4,
              ClxSpace.x5,
              ClxSpace.x3,
            ),
            child: Wrap(
              spacing: ClxSpace.x3,
              runSpacing: ClxSpace.x3,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editar vitrine',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x1),
                    Text(
                      'Altere o conteúdo publicado em agendar.cleanox.com.br',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    _publicUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir vitrine'),
                ),
              ],
            ),
          ),
          Material(
            color: clx.bg,
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.edit_outlined), text: 'Conteúdo'),
                Tab(
                  icon: Icon(Icons.cleaning_services_outlined),
                  text: 'Serviços',
                ),
                Tab(icon: Icon(Icons.local_offer_outlined), text: 'Ofertas'),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                VitrineAdminPersonalizarScreen(),
                VitrineAdminServicosScreen(),
                VitrineAdminBumpsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
