/// fintech_painel_shell.dart — Casco fintech do Painel (APK, doc 12 §3).
///
/// Bottom nav de 5 itens: Clientes · Ordens de Serviço · Agenda · Financeiro
/// têm destino direto; "Mais" abre uma tela local (não é uma rota/branch
/// nova) listando as demais seções — Dashboard (primeiro item, feedback do
/// dono testando o APK), Serviços, Avaliações, Usuários, WhatsApp
/// (admin-only) e Conta — reaproveitando os MESMOS
/// `PainelNavItem`/`painelPath()` de `painel_nav.dart`. Nenhuma tela ou rota
/// nova: é uma segunda casca em cima do MESMO `StatefulShellRoute.indexedStack`
/// que a sidebar/rail da Web já usa.
///
/// A rota inicial continua sendo Dashboard (inalterada), mas como ele não tem
/// mais destino direto, abrir o app deixa a barra SEM nenhum item marcado —
/// ver `noneSelected` em `_FintechPainelScaffoldState.build`.
///
/// Navegação pelos itens diretos usa `context.go(painelPath(section))` — o
/// mesmo padrão que `_Sidebar`/`_NavRail` (painel_shell.dart) já usam, em vez
/// de `navigationShell.goBranch`; o go_router resolve a troca de branch do
/// `indexedStack` de qualquer forma.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/models/collections.dart';
import '../painel_nav.dart';

/// Seções com destino direto na bottom nav (ordem revisada, feedback do dono
/// testando o APK: Dashboard sai da barra e vira o topo do "Mais" — ver
/// [kFintechMaisSections]).
const List<PainelSection> kFintechDirectSections = [
  PainelSection.clientes,
  PainelSection.ordens,
  PainelSection.agenda,
  PainelSection.financeiro,
];

/// Agrupamento de "Mais" (ordem revisada, feedback do dono: Dashboard entra
/// como primeiro item, acima de Serviços). WhatsApp é filtrado por papel na
/// hora de montar a lista (mesmo guard do menu da Web).
const List<PainelSection> kFintechMaisSections = [
  PainelSection.dashboard,
  PainelSection.servicos,
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

/// Label curto da bottom nav (feedback do dono: "Ordens de Serviço" quebra em
/// 2 linhas e polui a barra). Só afeta o texto visível do item da barra — o
/// tooltip do destino e as demais menções à seção (tela "Mais", topbar) usam
/// `painelTitle` cheio normalmente.
String _fintechNavLabel(PainelSection s) =>
    s == PainelSection.ordens ? 'OS' : painelTitle(s);

/// Semântica de substituição da bottom nav quando NENHUM item está
/// selecionado (QA-F6, Dashboard). Reconstrói os mesmos botões/labels dos
/// destinos diretos + "Mais", todos com `selected: false` explícito — a
/// barra real fica com a semântica excluída (ver `noneSelected` acima) e este
/// widget é sobreposto no lugar dela, do mesmo tamanho.
class _FintechNavBarNoSelectionSemantics extends StatelessWidget {
  const _FintechNavBarNoSelectionSemantics({required this.sections, required this.onSelect});

  final List<PainelSection> sections;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < sections.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: false,
              label: painelTitle(sections[i]),
              onTap: () => onSelect(i),
              child: const SizedBox.expand(),
            ),
          ),
        Expanded(
          child: Semantics(
            button: true,
            selected: false,
            label: 'Mais',
            onTap: () => onSelect(sections.length),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
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
    // Dashboard não tem destino direto (feedback do dono): abrir o app (ou
    // navegar Mais > Dashboard) precisa mostrar a tela SEM nenhum item da
    // barra selecionado — nem Dashboard (não está mais na barra) nem "Mais"
    // (a lista já fechou). As demais seções fora da barra (Serviços,
    // Avaliações, Usuários, WhatsApp, Conta) continuam realçando "Mais".
    final noneSelected = !_showMais && widget.section == PainelSection.dashboard;
    final int selectedIndex;
    if (_showMais) {
      selectedIndex = kFintechDirectSections.length;
    } else if (noneSelected) {
      // Índice fixo (0, Clientes) só pra satisfazer o assert do
      // `NavigationBar` M3 (exige 0 <= selectedIndex < length — não aceita
      // -1/fora do range). O visual "selecionado" desse índice é
      // neutralizado logo abaixo via `NavigationBarTheme` local, que faz o
      // ícone de QUALQUER destino renderizar sempre na cor "não selecionado"
      // (indicatorColor já é transparente no tema fintech) — ou seja,
      // nenhum item aparenta estar ativo.
      selectedIndex = 0;
    } else if (directIndex >= 0) {
      selectedIndex = directIndex;
    } else {
      // Outras seções fora da barra (Serviços, Avaliações, Usuários,
      // WhatsApp, Conta) continuam realçando "Mais".
      selectedIndex = kFintechDirectSections.length;
    }

    Widget navBar = NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      destinations: [
        for (final s in kFintechDirectSections)
          NavigationDestination(
            icon: Icon(fintechIconFor(s)),
            label: _fintechNavLabel(s),
            tooltip: painelTitle(s),
          ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Mais',
        ),
      ],
    );
    if (noneSelected) {
      // `selectedIndex` acima é um índice fixo (0) só pra satisfazer o assert
      // do `NavigationBar` — internamente ele sempre marca ESSE destino como
      // `Semantics(selected: true)` (a flag nunca pode ser "desfeita" por um
      // `Semantics(selected: false)` descendente: flags booleanas fazem OR no
      // merge, então `true` sempre vence). Por isso o visual é neutralizado
      // acima (ícones sempre na cor "não selecionado") e AQUI escondemos a
      // árvore de semântica inteira da barra (`ExcludeSemantics`) e a
      // reconstruímos do zero por cima, com os mesmos botões/labels mas SEM
      // nenhum marcado como selecionado — do contrário um leitor de tela
      // (TalkBack) anunciaria "Clientes, aba, selecionada" ao abrir o app no
      // Dashboard, o que é falso.
      navBar = Stack(
        children: [
          ExcludeSemantics(
            child: NavigationBarTheme(
              data: NavigationBarTheme.of(
                context,
              ).copyWith(iconTheme: WidgetStatePropertyAll(IconThemeData(color: clx.ink3))),
              child: navBar,
            ),
          ),
          Positioned.fill(
            child: _FintechNavBarNoSelectionSemantics(
              sections: kFintechDirectSections,
              onSelect: _onDestinationSelected,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(
        bottom: false,
        child: _showMais
            ? _MaisScreen(role: widget.role, onSelect: _openFromMais)
            : widget.navigationShell,
      ),
      bottomNavigationBar: navBar,
    );
  }
}

/// Lista da aba "Mais": as seções que não couberam na bottom nav direta + o
/// toggle de tema claro/escuro (único lugar do casco fintech pra alternar —
/// o `_TopBar` com o botão de tema não é montado neste surface, QA-F2).
class _MaisScreen extends ConsumerWidget {
  const _MaisScreen({required this.role, required this.onSelect});

  final Role? role;
  final ValueChanged<PainelSection> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final isAdmin = role == Role.admin;
    final items = kFintechMaisSections
        .where((s) => s != PainelSection.whatsapp || isAdmin)
        .toList();
    final mode = ref.watch(themeModeControllerProvider);
    final isDark = mode == ThemeMode.dark;

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
            itemCount: items.length + 1,
            separatorBuilder: (context, i) => Divider(height: 1, color: clx.line),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return ListTile(
                  leading: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: clx.ink2,
                  ),
                  title: Text(
                    isDark ? 'Tema claro' : 'Tema escuro',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: clx.ink),
                  ),
                  onTap: () =>
                      ref.read(themeModeControllerProvider.notifier).toggle(),
                );
              }
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
