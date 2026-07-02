/// avaliacoes_screen.dart — Avaliações das OS no Painel (admin/gerente).
///
/// Espelha `Avaliacoes.tsx` com as mitigações Flutter Web (§4): lista das OS
/// avaliadas (StarRating do core, motivo/comentário, cliente/serviço/data em BRT),
/// filtros NO SERVIDOR (nota/período), cartão de média, scroll infinito
/// virtualizado (`getList`, nunca `getFullList`) e todos os estados
/// (carregando / vazio / erro / sem-filtro).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import 'avaliacoes_controller.dart';

const double _kCardBreakpoint = 720;

class AvaliacoesScreen extends ConsumerStatefulWidget {
  const AvaliacoesScreen({super.key});

  @override
  ConsumerState<AvaliacoesScreen> createState() => _AvaliacoesScreenState();
}

class _AvaliacoesScreenState extends ConsumerState<AvaliacoesScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(avaliacoesControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(avaliacoesControllerProvider);
    return Column(
      children: [
        _Toolbar(state: state),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(AvaliacoesState state) {
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
      return EmptyState(
        icon: state.hasFilters
            ? Icons.search_off_rounded
            : Icons.star_outline_rounded,
        title: state.hasFilters
            ? 'Nenhuma avaliação encontrada'
            : 'Nenhuma avaliação ainda',
        message: state.hasFilters
            ? 'Tente ajustar o filtro de nota ou de período.'
            : 'As avaliações aparecem aqui após os clientes responderem à '
                  'pesquisa de satisfação.',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= _kCardBreakpoint;
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(avaliacoesControllerProvider.notifier).refresh(),
          color: context.clx.primary,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(ClxSpace.x4),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(ClxSpace.x4),
                  child: Center(child: Spinner(size: 20)),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                child: _ReviewCard(os: state.items[i], wide: wide),
              );
            },
          ),
        );
      },
    );
  }
}

/// Barra de filtros + resumo (média). No mobile empilha; no desktop, em linha.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.state});
  final AvaliacoesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final notifier = ref.read(avaliacoesControllerProvider.notifier);
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
      child: Wrap(
        spacing: ClxSpace.x3,
        runSpacing: ClxSpace.x3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MediaResumo(state: state),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<int?>(
              initialValue: state.nota,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Todas as notas'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todas as notas'),
                ),
                for (final n in const [5, 4, 3, 2, 1])
                  DropdownMenuItem(
                    value: n,
                    child: Text('$n estrela${n == 1 ? '' : 's'}'),
                  ),
              ],
              onChanged: (v) => notifier.setNota(v),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<AvaliacoesPeriodo>(
              initialValue: state.periodo,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final p in AvaliacoesPeriodo.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) {
                if (v != null) notifier.setPeriodo(v);
              },
            ),
          ),
          ClxButton(
            label: 'Atualizar',
            variant: ClxButtonVariant.ghost,
            icon: Icons.refresh_rounded,
            onPressed: notifier.refresh,
          ),
        ],
      ),
    );
  }
}

/// Cartão-resumo: média em estrelas + contagem do conjunto filtrado.
class _MediaResumo extends StatelessWidget {
  const _MediaResumo({required this.state});
  final AvaliacoesState state;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final media = state.media;
    final total = state.totalItems;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(color: clx.bg3, borderRadius: ClxRadii.rMd),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (media != null) ...[
            StarRating(value: media.roundToDouble(), size: 18),
            const SizedBox(width: ClxSpace.x2),
            Text(
              media.toStringAsFixed(1),
              style: TextStyle(
                color: clx.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
          ] else
            Icon(Icons.star_outline_rounded, size: 18, color: clx.ink3),
          Text(
            media == null
                ? 'Sem avaliações'
                : '$total avalia${total == 1 ? 'ção' : 'ções'}'
                      '${state.mediaAproximada ? '+' : ''}',
            style: TextStyle(color: clx.ink3, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Cartão de uma avaliação: nota + data + serviço/cliente/data + motivo.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.os, required this.wide});
  final OrdemServico os;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final nota = os.avaliacaoNota ?? 0;
    final prof = os.expand?.profissional?.displayName;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(value: nota, size: 16),
              const Spacer(),
              Text(
                os.avaliacaoEm == null ? '—' : formatDateTime(os.avaliacaoEm!),
                style: TextStyle(color: clx.ink3, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          // Meta: serviço · cliente · data do serviço (+ profissional se largo).
          Wrap(
            spacing: ClxSpace.x2,
            runSpacing: ClxSpace.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _meta(clx, os.tipoServicoNome ?? '—', bold: true),
              _sep(clx),
              _meta(clx, os.nomeCurto.isEmpty ? '—' : os.nomeCurto),
              _sep(clx),
              _meta(clx, formatDateTime(os.dataHora)),
              if (wide && prof != null && prof != '—') ...[
                _sep(clx),
                _meta(clx, prof),
              ],
            ],
          ),
          if (_comentario(os) case final texto?) ...[
            const SizedBox(height: ClxSpace.x3),
            Text(
              texto,
              style: TextStyle(
                color: os.avaliacaoMotivo == null ? clx.ink3 : clx.ink2,
                fontSize: 13.5,
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

  Widget _meta(CleanoxColors clx, String text, {bool bold = false}) => Text(
    text,
    style: TextStyle(
      color: bold ? clx.ink : clx.ink2,
      fontSize: 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    ),
  );

  Widget _sep(CleanoxColors clx) =>
      Text('·', style: TextStyle(color: clx.ink3, fontSize: 13));
}
