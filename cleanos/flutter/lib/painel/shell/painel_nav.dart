/// painel_nav.dart — Modelo de navegação do Painel (menu por papel + seção ativa).
///
/// Espelha o menu de `PainelLayout.tsx` (BASE_NAV_ITEMS + ADMIN_NAV_ITEMS) e o
/// mapa `PAGE_TITLES`. Cada seção é uma `GoRoute` (branch do
/// `StatefulShellRoute.indexedStack` do `/painel`) com URL deep-linkável
/// ([painelPath]); a seção ativa é DERIVADA da rota atual
/// ([painelSectionForLocation]) — não mais de um StateProvider interno.
///
/// 🔒 Papel: `admin` vê tudo (inclusive WhatsApp); `gerente` vê tudo MENOS
/// WhatsApp (admin-only). Paridade 1:1 com o React.
library;

import 'package:flutter/material.dart';

import '../../core/models/collections.dart';

/// Seções do Painel. Nesta onda só `dashboard` e `conta` estão implementadas; as
/// demais aparecem no menu (paridade fiel) e abrem um placeholder "próxima onda".
enum PainelSection {
  dashboard,
  clientes,
  ordens,
  agenda,
  financeiro,
  servicos,
  usuarios,
  avaliacoes,
  whatsapp,
  conta,
}

/// Item do menu lateral. `adminOnly` espelha `ADMIN_NAV_ITEMS`; `implemented`
/// marca o que já existe (Onda 1) vs. o que abre placeholder até a onda chegar.
@immutable
class PainelNavItem {
  const PainelNavItem({
    required this.section,
    required this.label,
    required this.icon,
    this.adminOnly = false,
    this.implemented = false,
  });

  final PainelSection section;
  final String label;
  final IconData icon;
  final bool adminOnly;
  final bool implemented;
}

/// Menu principal — ordem e rótulos idênticos ao `PainelLayout.tsx`.
/// `conta` NÃO entra aqui (acessada pelo rodapé do usuário, como no React).
const List<PainelNavItem> kPainelNavItems = [
  PainelNavItem(
    section: PainelSection.dashboard,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    implemented: true,
  ),
  PainelNavItem(
    section: PainelSection.clientes,
    label: 'Clientes',
    icon: Icons.people_alt_outlined,
  ),
  PainelNavItem(
    section: PainelSection.ordens,
    label: 'Ordens de Serviço',
    icon: Icons.receipt_long_outlined,
  ),
  PainelNavItem(
    section: PainelSection.agenda,
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
  ),
  PainelNavItem(
    section: PainelSection.financeiro,
    label: 'Financeiro',
    icon: Icons.account_balance_wallet_outlined,
  ),
  PainelNavItem(
    section: PainelSection.servicos,
    label: 'Serviços',
    icon: Icons.cleaning_services_outlined,
  ),
  PainelNavItem(
    section: PainelSection.usuarios,
    label: 'Usuários',
    icon: Icons.badge_outlined,
  ),
  PainelNavItem(
    section: PainelSection.avaliacoes,
    label: 'Avaliações',
    icon: Icons.star_outline_rounded,
  ),
  PainelNavItem(
    section: PainelSection.whatsapp,
    label: 'WhatsApp',
    icon: Icons.chat_outlined,
    adminOnly: true,
  ),
];

/// Menu visível para o [role]: admin vê tudo; qualquer outro papel (gerente) não
/// vê os itens `adminOnly` (WhatsApp). Espelha o cálculo de `navItems` do React.
List<PainelNavItem> navItemsForRole(Role? role) {
  final isAdmin = role == Role.admin;
  return kPainelNavItems.where((i) => isAdmin || !i.adminOnly).toList();
}

/// Título da topbar por seção (espelha `PAGE_TITLES` / `resolveTitle`).
String painelTitle(PainelSection s) => switch (s) {
  PainelSection.dashboard => 'Dashboard',
  PainelSection.clientes => 'Clientes',
  PainelSection.ordens => 'Ordens de Serviço',
  PainelSection.agenda => 'Agenda',
  PainelSection.financeiro => 'Financeiro',
  PainelSection.servicos => 'Serviços',
  PainelSection.usuarios => 'Usuários',
  PainelSection.avaliacoes => 'Avaliações',
  PainelSection.whatsapp => 'WhatsApp',
  PainelSection.conta => 'Minha Conta',
};

/// URL canônica (branch do `StatefulShellRoute`) de cada seção. Fonte única dos
/// paths do Painel — o router (`painel_routes.dart`) e a sidebar consomem daqui.
String painelPath(PainelSection s) => switch (s) {
  PainelSection.dashboard => '/painel/dashboard',
  PainelSection.clientes => '/painel/clientes',
  PainelSection.ordens => '/painel/ordens',
  PainelSection.agenda => '/painel/agenda',
  PainelSection.financeiro => '/painel/financeiro',
  PainelSection.servicos => '/painel/servicos',
  PainelSection.usuarios => '/painel/usuarios',
  PainelSection.avaliacoes => '/painel/avaliacoes',
  PainelSection.whatsapp => '/painel/whatsapp',
  PainelSection.conta => '/painel/conta',
};

/// Seção ativa derivada da [loc] atual (match por prefixo do path da seção).
/// Cobre sub-rotas (`/painel/ordens/:id/execucao`, `/painel/financeiro/:tab`).
/// Fallback: Dashboard (home do `/painel`).
PainelSection painelSectionForLocation(String loc) {
  for (final s in PainelSection.values) {
    final p = painelPath(s);
    if (loc == p || loc.startsWith('$p/')) return s;
  }
  return PainelSection.dashboard;
}
