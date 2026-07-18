/// fintech_painel_shell.dart — Casco Easypay do Painel (APK + web estreita).
///
/// Bottom nav: **Início · Clientes · ⊕ · OS · Carteira**
/// - Header: título + hamburger (☰) abre o Menu
/// - Menu: foto do usuário + Agenda, Serviços, Usuários, etc.
/// - FAB: sheet com Nova OS / Cliente / Receita / Despesa — cada um abre a
///   tela correspondente **já com o formulário flutuante aberto**.
///
/// Mesmo `StatefulShellRoute.indexedStack` da Web — só a casca muda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/models/financeiro.dart';
import '../../../core/models/user.dart';
import '../../clientes/cliente_form.dart';
import '../../clientes/clientes_controller.dart';
import '../../financeiro/lancamentos/fin_lancamentos_controller.dart';
import '../../financeiro/lancamentos/lancamento_form.dart';
import '../../ordens/ordens_controller.dart';
import '../../ordens/os_form.dart';
import '../painel_nav.dart';

/// Destinos na barra inferior (ordem: Início · Clientes · [FAB] · OS · Carteira).
const List<PainelSection> kFintechDirectSections = [
  PainelSection.dashboard,
  PainelSection.clientes,
  PainelSection.ordens,
  PainelSection.financeiro,
];

/// Itens do Menu (hamburger) — o que não está na barra inferior.
/// Conta fica só no card da foto no topo (evita "Minha Conta" em duplicata).
const List<PainelSection> kFintechMaisSections = [
  PainelSection.agenda,
  PainelSection.servicos,
  PainelSection.avaliacoes,
  PainelSection.usuarios,
  PainelSection.whatsapp,
];

IconData fintechIconFor(PainelSection s) {
  if (s == PainelSection.conta) return Icons.person_outline_rounded;
  if (s == PainelSection.dashboard) return Icons.home_rounded;
  if (s == PainelSection.financeiro) return Icons.account_balance_wallet_rounded;
  if (s == PainelSection.clientes) return Icons.people_alt_rounded;
  if (s == PainelSection.ordens) return Icons.receipt_long_rounded;
  return kPainelNavItems.firstWhere((i) => i.section == s).icon;
}

class FintechPainelScaffold extends ConsumerStatefulWidget {
  const FintechPainelScaffold({
    super.key,
    required this.navigationShell,
    required this.section,
    required this.role,
  });

  final StatefulNavigationShell navigationShell;
  final PainelSection section;
  final Role? role;

  @override
  ConsumerState<FintechPainelScaffold> createState() =>
      _FintechPainelScaffoldState();
}

class _FintechPainelScaffoldState extends ConsumerState<FintechPainelScaffold> {
  bool _showMais = false;

  @override
  void didUpdateWidget(covariant FintechPainelScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != oldWidget.section &&
        kFintechDirectSections.contains(widget.section)) {
      _showMais = false;
    }
  }

  void _goDirect(PainelSection section) {
    setState(() => _showMais = false);
    context.go(painelPath(section));
  }

  void _openMenu() => setState(() => _showMais = true);

  void _openFromMais(PainelSection section) {
    setState(() => _showMais = false);
    context.go(painelPath(section));
  }

  /// Navega para a seção e abre o formulário flutuante em seguida.
  Future<void> _goAndOpenForm({
    required String path,
    required Future<bool?> Function() openForm,
    Future<void> Function()? onSaved,
  }) async {
    setState(() => _showMais = false);
    context.go(path);
    // Aguarda a rota montar o branch antes do dialog.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final saved = await openForm();
    if (saved == true && mounted) {
      await onSaved?.call();
    }
  }

  Future<void> _openCreateSheet() async {
    final clx = context.clx;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: clx.ink.withValues(alpha: 0.45),
      builder: (ctx) {
        return _CreateSheet(
          onNovaOs: () {
            Navigator.pop(ctx);
            _goAndOpenForm(
              path: painelPath(PainelSection.ordens),
              // `showOSForm` devolve a OS gravada (ou null); aqui só interessa
              // se salvou.
              openForm: () => showOSForm(context).then((os) => os != null),
              onSaved: () async {
                await ref.read(ordensControllerProvider.notifier).refresh();
                ref.invalidate(ordensCountsProvider);
                if (mounted) {
                  showClxToast(context, 'OS criada.', type: ToastType.success);
                }
              },
            );
          },
          onNovoCliente: () {
            Navigator.pop(ctx);
            _goAndOpenForm(
              path: painelPath(PainelSection.clientes),
              openForm: () => showClienteForm(context),
              onSaved: () async {
                await ref.read(clientesControllerProvider.notifier).refresh();
                if (mounted) {
                  showClxToast(
                    context,
                    'Cliente criado.',
                    type: ToastType.success,
                  );
                }
              },
            );
          },
          onReceita: () {
            Navigator.pop(ctx);
            _goAndOpenForm(
              path: '${painelPath(PainelSection.financeiro)}/lancamentos',
              openForm: () => showLancamentoForm(
                context,
                initialTipo: TipoLancamento.receita,
              ),
              onSaved: () async {
                await ref
                    .read(finLancControllerProvider.notifier)
                    .refresh();
                if (mounted) {
                  showClxToast(
                    context,
                    'Receita lançada.',
                    type: ToastType.success,
                  );
                }
              },
            );
          },
          onDespesa: () {
            Navigator.pop(ctx);
            _goAndOpenForm(
              path: '${painelPath(PainelSection.financeiro)}/lancamentos',
              openForm: () => showLancamentoForm(
                context,
                initialTipo: TipoLancamento.despesa,
              ),
              onSaved: () async {
                await ref
                    .read(finLancControllerProvider.notifier)
                    .refresh();
                if (mounted) {
                  showClxToast(
                    context,
                    'Despesa lançada.',
                    type: ToastType.success,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  String _headerTitle() {
    if (_showMais) return 'Menu';
    final user = ref.read(currentUserProvider);
    if (widget.section == PainelSection.dashboard) {
      // R2: `nome` no PB costuma ser "" (não null) — não usar `??` cego.
      final raw = user == null ? '' : user.displayName.trim();
      final first = (raw.isEmpty || raw == '—')
          ? ''
          : raw.split(RegExp(r'\s+')).first;
      return first.isEmpty ? 'Olá 👋' : 'Olá, $first 👋';
    }
    return switch (widget.section) {
      PainelSection.financeiro => 'Carteira',
      PainelSection.ordens => 'Ordens',
      PainelSection.agenda => 'Agenda',
      PainelSection.clientes => 'Clientes',
      PainelSection.servicos => 'Serviços',
      PainelSection.usuarios => 'Usuários',
      PainelSection.avaliacoes => 'Avaliações',
      PainelSection.whatsapp => 'WhatsApp',
      PainelSection.conta => 'Minha Conta',
      PainelSection.dashboard => 'Início',
    };
  }

  String _headerSubtitle() {
    if (_showMais) return 'Cadastros, equipe e ajustes';
    if (widget.section == PainelSection.dashboard) {
      return _longDatePtBrHeader();
    }
    return switch (widget.section) {
      PainelSection.agenda => 'Horários marcados',
      PainelSection.financeiro => 'Saldo e lançamentos',
      PainelSection.clientes => 'Sua base de clientes',
      PainelSection.ordens => 'Ordens de serviço',
      PainelSection.servicos => 'Catálogo de serviços',
      PainelSection.usuarios => 'Equipe e acessos',
      PainelSection.avaliacoes => 'Feedback dos clientes',
      PainelSection.whatsapp => 'Conexão e templates',
      PainelSection.conta => 'Seus dados e senha',
      PainelSection.dashboard => _longDatePtBrHeader(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final user = ref.watch(currentUserProvider);
    final onDirect = kFintechDirectSections.contains(widget.section);
    final selected = _showMais
        ? null
        : onDirect
            ? widget.section
            : null;

    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _EasypayTopBar(
              title: _headerTitle(),
              subtitle: _headerSubtitle(),
              menuOpen: _showMais,
              onMenuTap: () {
                if (_showMais) {
                  setState(() => _showMais = false);
                } else {
                  _openMenu();
                }
              },
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: ClxMotion.standardDuration,
                switchInCurve: ClxMotion.emphasized,
                switchOutCurve: Curves.easeIn,
                child: _showMais
                    ? _MaisScreen(
                        key: const ValueKey('mais'),
                        role: widget.role,
                        user: user,
                        onSelect: _openFromMais,
                        compactHeader: true,
                      )
                    : KeyedSubtree(
                        key: const ValueKey('shell'),
                        child: widget.navigationShell,
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _EasypayBottomBar(
        selected: selected,
        onInicio: () => _goDirect(PainelSection.dashboard),
        onClientes: () => _goDirect(PainelSection.clientes),
        onOs: () => _goDirect(PainelSection.ordens),
        onCarteira: () => _goDirect(PainelSection.financeiro),
        onFab: _openCreateSheet,
      ),
    );
  }
}

/// Cabeçalho fixo: título + hamburger (abre Menu). Foto fica dentro do Menu.
class _EasypayTopBar extends StatelessWidget {
  const _EasypayTopBar({
    required this.title,
    required this.subtitle,
    required this.menuOpen,
    required this.onMenuTap,
  });

  final String title;
  final String subtitle;
  final bool menuOpen;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: clx.bg2,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
              label: menuOpen ? 'Fechar menu' : 'Abrir menu',
              child: IconButton(
                key: const ValueKey('nav-menu-header'),
                tooltip: menuOpen ? 'Fechar menu' : 'Menu',
                onPressed: onMenuTap,
                icon: AnimatedSwitcher(
                  duration: ClxMotion.shortDuration,
                  child: Icon(
                    menuOpen ? Icons.close_rounded : Icons.menu_rounded,
                    key: ValueKey(menuOpen),
                    color: clx.ink,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _longDatePtBrHeader() {
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

/// Barra: Início · Clientes · ⊕ · OS · Carteira
class _EasypayBottomBar extends StatelessWidget {
  const _EasypayBottomBar({
    required this.selected,
    required this.onInicio,
    required this.onClientes,
    required this.onOs,
    required this.onCarteira,
    required this.onFab,
  });

  final PainelSection? selected;
  final VoidCallback onInicio;
  final VoidCallback onClientes;
  final VoidCallback onOs;
  final VoidCallback onCarteira;
  final VoidCallback onFab;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      elevation: 12,
      shadowColor: clx.ink.withValues(alpha: 0.12),
      color: clx.bg.withValues(alpha: 0.96),
      child: SizedBox(
        height: 72 + bottom,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  key: const ValueKey('nav-inicio'),
                  icon: Icons.home_rounded,
                  label: 'Início',
                  selected: selected == PainelSection.dashboard,
                  onTap: onInicio,
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('nav-clientes'),
                  icon: Icons.people_alt_rounded,
                  label: 'Clientes',
                  selected: selected == PainelSection.clientes,
                  onTap: onClientes,
                ),
              ),
              SizedBox(
                width: 72,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -12),
                    child: Semantics(
                      button: true,
                      label: 'Criar',
                      child: ClxPressScale(
                        key: const ValueKey('nav-fab'),
                        onTap: onFab,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [clx.primary, clx.primary2],
                            ),
                            border: Border.all(color: clx.bg, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: clx.primary.withValues(alpha: 0.42),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: clx.onPrimary,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('nav-os'),
                  icon: Icons.receipt_long_rounded,
                  label: 'OS',
                  selected: selected == PainelSection.ordens,
                  onTap: onOs,
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('nav-carteira'),
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Carteira',
                  selected: selected == PainelSection.financeiro,
                  onTap: onCarteira,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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

class _CreateSheet extends StatelessWidget {
  const _CreateSheet({
    required this.onNovaOs,
    required this.onNovoCliente,
    required this.onReceita,
    required this.onDespesa,
  });

  final VoidCallback onNovaOs;
  final VoidCallback onNovoCliente;
  final VoidCallback onReceita;
  final VoidCallback onDespesa;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClxFadeSlide(
      child: Container(
        decoration: BoxDecoration(
          color: clx.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: clx.line2,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'O que você quer fazer?',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: clx.ink,
              ),
            ),
            const SizedBox(height: 12),
            _SheetAction(
              icon: Icons.add_rounded,
              iconBg: clx.primary,
              iconColor: clx.onPrimary,
              title: 'Nova OS',
              subtitle: 'Agendar atendimento para um cliente',
              onTap: onNovaOs,
            ),
            _SheetAction(
              icon: Icons.person_add_alt_1_rounded,
              iconBg: clx.infoBg,
              iconColor: clx.info,
              title: 'Novo cliente',
              subtitle: 'Cadastro rápido com endereço',
              onTap: onNovoCliente,
            ),
            _SheetAction(
              icon: Icons.south_west_rounded,
              iconBg: clx.successBg,
              iconColor: clx.success,
              title: 'Nova receita',
              subtitle: 'Lançar entrada no financeiro',
              onTap: onReceita,
            ),
            _SheetAction(
              icon: Icons.north_east_rounded,
              iconBg: clx.errorBg,
              iconColor: clx.error,
              title: 'Nova despesa',
              subtitle: 'Registrar saída do caixa',
              onTap: onDespesa,
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return ClxPressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: clx.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: clx.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: clx.ink3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: clx.ink3),
          ],
        ),
      ),
    );
  }
}

class _MaisScreen extends ConsumerWidget {
  const _MaisScreen({
    required this.role,
    required this.onSelect,
    this.user,
    this.compactHeader = false,
    super.key,
  });

  final Role? role;
  final User? user;
  final ValueChanged<PainelSection> onSelect;

  /// Quando true, o título "Menu" já está no top bar global.
  final bool compactHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final isAdmin = role == Role.admin;
    final items = kFintechMaisSections
        .where((s) => s != PainelSection.whatsapp || isAdmin)
        .toList();
    final mode = ref.watch(themeModeControllerProvider);
    final isDark = mode == ThemeMode.dark;
    final u = user;
    final dn = u?.displayName ?? 'Usuário';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Foto do usuário (substituiu o avatar do header).
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x4,
            ClxSpace.x2,
            ClxSpace.x4,
            ClxSpace.x3,
          ),
          child: ClxFadeSlide(
            child: Material(
              color: clx.bg,
              borderRadius: ClxRadii.rLg,
              child: InkWell(
                borderRadius: ClxRadii.rLg,
                onTap: () => onSelect(PainelSection.conta),
                child: Container(
                  padding: const EdgeInsets.all(ClxSpace.x4),
                  decoration: BoxDecoration(
                    borderRadius: ClxRadii.rLg,
                    border: Border.all(color: clx.line),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(user: u, radius: 28),
                      const SizedBox(width: ClxSpace.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dn != '—' ? dn : 'Usuário',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: clx.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if ((u?.email ?? '').isNotEmpty)
                              Text(
                                u!.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: clx.ink3),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              'Minha conta',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: clx.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: clx.ink3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!compactHeader)
          Container(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x5,
              ClxSpace.x2,
              ClxSpace.x5,
              ClxSpace.x3,
            ),
            child: Text(
              'Menu',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x3,
              0,
              ClxSpace.x3,
              ClxSpace.x8,
            ),
            // itens + tema + sair
            itemCount: items.length + 2,
            itemBuilder: (context, i) {
              if (i == items.length) {
                return ClxFadeSlide(
                  delay: Duration(milliseconds: 40 * i),
                  child: _MenuTile(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    iconBg: clx.bg3,
                    title: isDark ? 'Tema claro' : 'Tema escuro',
                    onTap: () =>
                        ref.read(themeModeControllerProvider.notifier).toggle(),
                  ),
                );
              }
              if (i == items.length + 1) {
                return ClxFadeSlide(
                  delay: Duration(milliseconds: 40 * i),
                  child: Padding(
                    padding: const EdgeInsets.only(top: ClxSpace.x2),
                    child: _MenuTile(
                      icon: Icons.logout_rounded,
                      iconBg: clx.errorBg,
                      title: 'Sair da conta',
                      onTap: () => ref.read(authServiceProvider).logout(),
                    ),
                  ),
                );
              }
              final s = items[i];
              return ClxFadeSlide(
                delay: Duration(milliseconds: 40 * i),
                child: _MenuTile(
                  icon: fintechIconFor(s),
                  iconBg: clx.primary.withValues(alpha: 0.12),
                  title: painelTitle(s),
                  onTap: () => onSelect(s),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x2),
      child: Material(
        color: clx.bg,
        borderRadius: ClxRadii.rLg,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: ClxRadii.rLg,
            side: BorderSide(color: clx.line),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: clx.ink2, size: 20),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: clx.ink3),
          onTap: onTap,
        ),
      ),
    );
  }
}
