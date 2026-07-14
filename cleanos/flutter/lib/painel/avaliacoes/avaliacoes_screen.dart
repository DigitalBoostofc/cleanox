/// avaliacoes_screen.dart — Avaliações das OS no Painel (admin/gerente).
///
/// Espelha `Avaliacoes.tsx`: ACORDEÃO por profissional. Cada profissional é uma
/// linha com nome + média em estrelas + contagem; ao expandir (só quem tem
/// avaliação), abre a lista das avaliações DELE, paginada com "Ver mais". O motivo
/// aparece quando o cliente comentou, ou "sem comentário" para notas baixas (1–3).
///
/// MD3: superfícies tonais + `outline-variant` (clx.line) nas divisórias, raios do
/// design system, chevron que gira ao abrir, alvos de toque ≥ 48dp. PT-BR, BRT.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import 'avaliacoes_controller.dart';

class AvaliacoesScreen extends ConsumerWidget {
  const AvaliacoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avaliacoesControllerProvider);
    return Column(
      children: [
        _Toolbar(onRefresh: ref.read(avaliacoesControllerProvider.notifier).refresh),
        Expanded(child: _body(context, ref, state)),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AvaliacoesState state) {
    if (state.loading) return const Center(child: Spinner(size: 26));
    if (state.error != null && state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () =>
                  ref.read(avaliacoesControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }
    if (state.isEmpty) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Nenhum profissional cadastrado',
        message: 'Cadastre profissionais na tela de Usuários.',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(avaliacoesControllerProvider.notifier).refresh(),
      color: context.clx.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(ClxSpace.x4),
        itemCount: state.profissionais.length,
        itemBuilder: (context, i) {
          final prof = state.profissionais[i];
          final isOpen = state.openId == prof.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: ClxSpace.x3),
            child: _AccordionItem(
              prof: prof,
              stats: state.statsOf(prof.id),
              isOpen: isOpen,
              reviews: isOpen ? state.reviews : const [],
              reviewsLoading: isOpen && state.reviewsLoading,
              reviewsError: isOpen ? state.reviewsError : null,
              hasMore: isOpen && state.hasMore,
              onToggle: () =>
                  ref.read(avaliacoesControllerProvider.notifier).toggle(prof.id),
              onLoadMore: () =>
                  ref.read(avaliacoesControllerProvider.notifier).loadMore(),
            ),
          );
        },
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x4,
        ClxSpace.x6,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          const Spacer(),
          ClxButton(
            label: 'Atualizar',
            variant: ClxButtonVariant.ghost,
            icon: Icons.refresh_rounded,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// Um item do acordeão: cabeçalho (nome + média) + corpo (avaliações do prof).
class _AccordionItem extends StatelessWidget {
  const _AccordionItem({
    required this.prof,
    required this.stats,
    required this.isOpen,
    required this.reviews,
    required this.reviewsLoading,
    required this.reviewsError,
    required this.hasMore,
    required this.onToggle,
    required this.onLoadMore,
  });

  final User prof;
  final RatingStats? stats;
  final bool isOpen;
  final List<OrdemServico> reviews;
  final bool reviewsLoading;
  final String? reviewsError;
  final bool hasMore;
  final VoidCallback onToggle;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final hasRatings = stats != null;
    return Container(
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: ClxRadii.rLg,
        border: Border.all(color: clx.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho — só clicável se houver avaliações.
          InkWell(
            onTap: hasRatings ? onToggle : null,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ClxLayout.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ClxSpace.x4,
                vertical: ClxSpace.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prof.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: clx.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (hasRatings)
                          Row(
                            children: [
                              StarRating(
                                value: stats!.media.roundToDouble(),
                                size: 14,
                              ),
                              const SizedBox(width: ClxSpace.x2),
                              Text(
                                '${stats!.media.toStringAsFixed(1)} '
                                '(${stats!.total} '
                                'avalia${stats!.total != 1 ? 'ções' : 'ção'})',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                              ),
                            ],
                          )
                        else
                          Text(
                            'sem avaliações ainda',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                          ),
                      ],
                    ),
                  ),
                  if (hasRatings)
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: ClxMotion.standardDuration,
                      curve: ClxMotion.standard,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: clx.ink3,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expansão animada com os motion tokens MD3 (emphasized decelerate).
          AnimatedSize(
            duration: ClxMotion.emphasizedDuration,
            curve: ClxMotion.emphasized,
            alignment: Alignment.topCenter,
            child: !isOpen
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      Divider(height: 1, color: clx.line),
                      _AccordionBody(
                        reviews: reviews,
                        reviewsLoading: reviewsLoading,
                        reviewsError: reviewsError,
                        hasMore: hasMore,
                        onLoadMore: onLoadMore,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccordionBody extends StatelessWidget {
  const _AccordionBody({
    required this.reviews,
    required this.reviewsLoading,
    required this.reviewsError,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<OrdemServico> reviews;
  final bool reviewsLoading;
  final String? reviewsError;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.all(ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reviewsError != null) ...[
            ErrorBanner(message: reviewsError!),
            const SizedBox(height: ClxSpace.x3),
          ],
          if (reviews.isEmpty && !reviewsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x3),
              child: Text(
                'Nenhuma avaliação encontrada.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink3),
              ),
            )
          else
            for (final os in reviews) ...[
              _ReviewCard(os: os),
              const SizedBox(height: ClxSpace.x2),
            ],
          if (reviewsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ClxSpace.x3),
              child: Center(child: Spinner(size: 18)),
            ),
          if (!reviewsLoading && hasMore)
            Padding(
              padding: const EdgeInsets.only(top: ClxSpace.x2),
              child: Center(
                child: ClxButton(
                  label: 'Ver mais',
                  variant: ClxButtonVariant.ghost,
                  onPressed: onLoadMore,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cartão de uma avaliação: nota + data + serviço/cliente/data + motivo.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.os});
  final OrdemServico os;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final nota = os.avaliacaoNota ?? 0;
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(color: clx.bg2, borderRadius: ClxRadii.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(value: nota, size: 15),
              const Spacer(),
              Text(
                os.avaliacaoEm == null ? '—' : formatDateTime(os.avaliacaoEm!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.ink3),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          // Meta: serviço · cliente · data do serviço.
          Wrap(
            spacing: ClxSpace.x2,
            runSpacing: ClxSpace.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _meta(context, clx, os.tipoServicoNome ?? '—', bold: true),
              _sep(context, clx),
              _meta(context, clx, os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao),
              _sep(context, clx),
              _meta(context, clx, formatDateTime(os.dataHora)),
            ],
          ),
          if (_comentario(os) case final texto?) ...[
            const SizedBox(height: ClxSpace.x2),
            Text(
              texto,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: os.avaliacaoMotivo == null ? clx.ink3 : clx.ink2,
                height: 1.5,
                fontStyle: os.avaliacaoMotivo == null
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Motivo/comentário: o texto real, ou "sem comentário" quando a nota é baixa
  /// (1–3) e o cliente não justificou; `null` esconde a linha (notas altas).
  String? _comentario(OrdemServico os) {
    final motivo = os.avaliacaoMotivo?.trim();
    if (motivo != null && motivo.isNotEmpty) return motivo;
    final nota = os.avaliacaoNota ?? 0;
    if (nota >= 1 && nota <= 3) return 'sem comentário';
    return null;
  }

  Widget _meta(BuildContext context, CleanoxColors clx, String text, {bool bold = false}) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: bold ? clx.ink : clx.ink2,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    ),
  );

  Widget _sep(BuildContext context, CleanoxColors clx) =>
      Text('·', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3));
}
