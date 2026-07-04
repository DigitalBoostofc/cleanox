/// fin_common.dart — Widgets compartilhados das telas do Financeiro.
///
/// Seletor de período (mês anterior/próximo), cabeçalho de seção, card de KPI,
/// e um wrapper padrão de estados (carregando/erro/vazio/sucesso) para os
/// `AsyncValue` dos providers. Tudo MD3 + tokens do design system (nada
/// hardcoded), acessível (toque ≥ 48dp nos controles).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/design/design.dart';
import 'fin_providers.dart';

/* ─────────────────────── erros das rotas/CRUD do Financeiro ─────────────────────── */

/// Traduz um erro do Financeiro em mensagem amigável POR CÓDIGO HTTP. As rotas
/// transacionais de saldo (`/api/cleanos/fin/...`) e o CRUD devolvem:
///   • 0        → offline (sem conexão);
///   • 401/403  → sem permissão (só admin/gerente — o cofre financeiro);
///   • 404      → conta inexistente (ajuste via `novoSaldo` / transferência);
///   • 400      → validação (from==to, valor<=0, conta inexistente via delta) —
///                usa a `message` do backend;
///   • outros   → [fallback].
/// O servidor é a linha de defesa; a UI só TRADUZ o erro (não esconde a ação).
String finErrorMessage(
  Object? err, {
  String fallback = 'Não foi possível concluir a operação.',
}) {
  if (err is ClientException) {
    switch (err.statusCode) {
      case 0:
        return 'Sem conexão com o servidor. Verifique sua internet.';
      case 401:
      case 403:
        return 'Você não tem permissão para esta ação (apenas admin/gerente).';
      case 404:
        return 'Conta não encontrada.';
      default:
        final msg = err.response['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        return fallback;
    }
  }
  return fallback;
}

/* ─────────────────────── breakpoint mobile ─────────────────────── */

/// Largura-limite (px) abaixo da qual as telas do Financeiro usam o layout
/// COMPACTO de celular: toolbar/período/KPIs rolam junto com o conteúdo e o
/// filtro fica colapsável (F-741). Acima disso, o layout de desktop/tablet é
/// preservado 100%.
const double kFinMobileBreakpoint = 600;

/// `true` quando a viewport é estreita (celular/APK). Usa a largura da tela
/// (não do widget), suficiente para o painel do Financeiro que ocupa a área útil.
bool finIsMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kFinMobileBreakpoint;

/* ─────────────────────── seletor de período ─────────────────────── */

/// Navega mês a mês (BRT). Lê/escreve [finPeriodProvider].
///
/// Com [expand] o seletor OCUPA toda a largura disponível e o rótulo vira
/// `Expanded` (encolhe com elipse quando necessário) — use apenas dentro de um
/// pai de largura LIMITADA (ex.: `SizedBox(width: double.infinity)` ou
/// `Expanded`), como no layout de celular. Sem [expand] mantém o comportamento
/// original de largura mínima (desktop).
class FinPeriodSelector extends ConsumerWidget {
  const FinPeriodSelector({super.key, this.expand = false});

  /// Preenche a largura do pai (limitado) e deixa o rótulo encolher.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final period = ref.watch(finPeriodProvider);
    void go(int delta) =>
        ref.read(finPeriodProvider.notifier).state = period.shift(delta);

    final label = Text(
      period.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: clx.ink),
    );

    return Container(
      decoration: BoxDecoration(
        color: clx.bg2,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => go(-1),
          ),
          // expand: rótulo flexível (pai bounded garante que não estoura).
          // Caso contrário, minWidth fixo do desktop.
          if (expand)
            Expanded(child: label)
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 132),
              child: label,
            ),
          IconButton(
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => go(1),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── botão "Filtros" (mobile) ─────────────────────── */

/// Botão que colapsa/expande a seção de filtros no layout de celular (F-741).
/// Sinaliza com um ponto quando há filtro ativo. Toque ≥ 48dp. Usado por
/// Lançamentos, Relatórios e Visão geral para um comportamento consistente.
class FinFiltrosToggle extends StatelessWidget {
  const FinFiltrosToggle({
    super.key,
    required this.active,
    required this.hasActiveFilters,
    required this.onTap,
  });

  /// Seção de filtros atualmente aberta.
  final bool active;

  /// Há ao menos um filtro aplicado (mostra o ponto indicador).
  final bool hasActiveFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final on = active || hasActiveFilters;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rMd,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x3),
        decoration: BoxDecoration(
          color: on ? clx.primary.withValues(alpha: 0.14) : clx.bg2,
          borderRadius: ClxRadii.rMd,
          border: Border.all(color: on ? clx.primary : clx.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: on ? clx.primary : clx.ink2,
            ),
            const SizedBox(width: ClxSpace.x2),
            Text(
              'Filtros',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: on ? clx.primary : clx.ink2,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: ClxSpace.x2),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: clx.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── cabeçalho de seção ─────────────────────── */

class FinSectionHeader extends StatelessWidget {
  const FinSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/* ─────────────────────── card de KPI ─────────────────────── */

class FinKpiCard extends StatelessWidget {
  const FinKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.trend,
    this.hint,
    this.wide = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  /// Variação vs. período anterior: seta ↑/↓ (verde/vermelho) + texto. Espelha o
  /// `trend` do `FinKpiCard.tsx`.
  final ({bool up, String text})? trend;

  /// Legenda neutra abaixo do valor (ex.: "Disponível em contas"). Mostrada só
  /// quando não há [trend], igual ao web.
  final String? hint;

  /// Variante horizontal (mock `.kpi-card--wide`): label+hint à esquerda,
  /// valor grande empurrado à direita — usada só p/ "Saldo do mês" no
  /// surface Fintech Clean, ocupando a linha inteira em vez da grade 2x2.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    if (wide) {
      return ClxCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: ClxSpace.x2),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(color: clx.ink3),
                        ),
                      ),
                    ],
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: ClxSpace.x1),
                    Text(
                      hint!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: ClxSpace.x3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
      );
    }
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: ClxSpace.x2),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelMedium?.copyWith(color: clx.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: ClxSpace.x1),
            Row(
              children: [
                Icon(
                  trend!.up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 13,
                  color: trend!.up ? clx.finIncome : clx.finExpense,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    trend!.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      color: trend!.up ? clx.finIncome : clx.finExpense,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (hint != null) ...[
            const SizedBox(height: ClxSpace.x1),
            Text(
              hint!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: clx.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grade responsiva de KPIs (2 → 4 colunas).
class FinKpiGrid extends StatelessWidget {
  const FinKpiGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 820
            ? 4
            : w >= 520
            ? 3
            : 2;
        const gap = ClxSpace.x3;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: itemW.clamp(120.0, w), child: card),
          ],
        );
      },
    );
  }
}

/* ─────────────────────── estados async ─────────────────────── */

/// Renderiza um [AsyncValue]: spinner central (loading), [ErrorBanner] com retry
/// (erro), ou [data]. O estado VAZIO é decidido pela própria tela dentro de [data].
class FinAsync<T> extends StatelessWidget {
  const FinAsync({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
    this.errorMessage = 'Não foi possível carregar os dados do financeiro.',
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: Spinner(size: 26)),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(message: errorMessage, onRetry: onRetry),
          ),
        ),
      ),
      data: data,
    );
  }
}
