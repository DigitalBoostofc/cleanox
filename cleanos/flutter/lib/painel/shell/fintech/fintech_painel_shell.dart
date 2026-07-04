/// fintech_painel_shell.dart — Casco fintech do Painel (APK, doc 12 §3).
///
/// Bottom nav de 5 itens (decisão do dono P-3): Dashboard · Ordens de Serviço ·
/// Agenda · Financeiro têm destino direto; "Mais" abre uma tela local (não é
/// uma rota/branch nova) listando as demais seções — Serviços, Clientes,
/// Avaliações, Usuários, WhatsApp (admin-only) e Conta — reaproveitando os
/// MESMOS `PainelNavItem`/`painelPath()` de `painel_nav.dart`. Nenhuma tela ou
/// rota nova: é uma segunda casca em cima do MESMO
/// `StatefulShellRoute.indexedStack` que a sidebar/rail da Web já usa.
///
/// Navegação pelos itens diretos usa `context.go(painelPath(section))` — o
/// mesmo padrão que `_Sidebar`/`_NavRail` (painel_shell.dart) já usam, em vez
/// de `navigationShell.goBranch`; o go_router resolve a troca de branch do
/// `indexedStack` de qualquer forma.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/models/collections.dart';
import '../painel_nav.dart';

/// Seções com destino direto na bottom nav (ordem fixada pelo dono, P-3).
const List<PainelSection> kFintechDirectSections = [
  PainelSection.dashboard,
  PainelSection.ordens,
  PainelSection.agenda,
  PainelSection.financeiro,
];

/// Agrupamento de "Mais" (ordem fixada pelo dono, P-3). WhatsApp é filtrado
/// por papel na hora de montar a lista (mesmo guard do menu da Web).
const List<PainelSection> kFintechMaisSections = [
  PainelSection.servicos,
  PainelSection.clientes,
  PainelSection.avaliacoes,
  PainelSection.usuarios,
  PainelSection.whatsapp,
  PainelSection.conta,
];

/// Ícone de uma seção (reaproveita `kPainelNavItems`; "Conta" não está lá —
/// espelha o ícone que a sidebar já usa no rodapé de usuário).
IconData fintechIconFor(PainelSection s) {
  if (s == PainelSection.conta) return Icons.person_outline_rounded;
  return kPainelNavItems.firstWhere((i) => i.section == s).icon;
}

/// Casco fintech: `NavigationBar` de 5 itens sobre o mesmo
/// `StatefulNavigationShell` que a Web usa (sidebar/rail/drawer).
class FintechPainelScaffold extends StatefulWidget {
  const FintechPainelScaffold({
    super.key,
    required this.navigationShell,
    required this.section,
    required this.role,
  });

  final StatefulNavigationShell navigationShell;

  /// Seção ativa, derivada da rota atual ([painelSectionForLocation]).
  final PainelSection section;
  final Role? role;

  @override
  State<FintechPainelScaffold> createState() => _FintechPainelScaffoldState();
}

class _FintechPainelScaffoldState extends State<FintechPainelScaffold> {
  /// true = mostra a lista "Mais" no lugar do conteúdo da seção.
  bool _showMais = false;

  @override
  void didUpdateWidget(covariant FintechPainelScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Deep-link/voltar do navegador pra uma seção direta fecha a lista "Mais"
    // se estiver aberta (evita ficar preso na lista depois de um deep-link).
    if (widget.section != oldWidget.section &&
        kFintechDirectSections.contains(widget.section)) {
      _showMais = false;
    }
  }

  void _onDestinationSelected(int index) {
    if (index == kFintechDirectSections.length) {
      setState(() => _showMais = true);
      return;
    }
    setState(() => _showMais = false);
    context.go(painelPath(kFintechDirectSections[index]));
  }

  void _openFromMais(PainelSection section) {
    setState(() => _showMais = false);
    context.go(painelPath(section));
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final directIndex = kFintechDirectSections.indexOf(widget.section);
    // Seção "Mais"-agrupada ativa (ex.: Clientes) também realça o item "Mais",
    // mesmo com a lista fechada (mostrando o conteúdo real da seção).
    final selectedIndex = _showMais || directIndex < 0
        ? kFintechDirectSections.length
        : directIndex;

    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(
        bottom: false,
        child: _showMais
            ? _MaisScreen(role: widget.role, onSelect: _openFromMais)
            : widget.navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final s in kFintechDirectSections)
            NavigationDestination(
              icon: Icon(fintechIconFor(s)),
              label: painelTitle(s),
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}

/// Lista da aba "Mais": as seções que não couberam na bottom nav direta.
class _MaisScreen extends StatelessWidget {
  const _MaisScreen({required this.role, required this.onSelect});

  final Role? role;
  final ValueChanged<PainelSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final isAdmin = role == Role.admin;
    final items = kFintechMaisSections
        .where((s) => s != PainelSection.whatsapp || isAdmin)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x4,
            ClxSpace.x4,
            ClxSpace.x4,
            ClxSpace.x2,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mais',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: clx.ink),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x2),
            itemCount: items.length,
            separatorBuilder: (context, i) => Divider(height: 1, color: clx.line),
            itemBuilder: (context, i) {
              final s = items[i];
              return ListTile(
                leading: Icon(fintechIconFor(s), color: clx.ink2),
                title: Text(
                  painelTitle(s),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: clx.ink),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: clx.ink3),
                onTap: () => onSelect(s),
              );
            },
          ),
        ),
      ],
    );
  }
}
