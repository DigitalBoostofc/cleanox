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

/* ─────────────────────── seletor de período ─────────────────────── */

/// Navega mês a mês (BRT). Lê/escreve [finPeriodProvider].
class FinPeriodSelector extends ConsumerWidget {
  const FinPeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final period = ref.watch(finPeriodProvider);
    void go(int delta) =>
        ref.read(finPeriodProvider.notifier).state = period.shift(delta);

    return Container(
      decoration: BoxDecoration(
        color: clx.bg2,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => go(-1),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 132),
            child: Text(
              period.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: clx.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
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
            style: TextStyle(
              color: clx.ink,
              fontSize: 16,
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
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clx.ink3,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
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
