/// mapa_screen.dart — Aba "Mapa" (Slice B3): serviço ativo + abrir no Google Maps.
///
/// Espelha `Mapa.tsx`: mostra a OS em andamento (endereço liberado) com botão
/// "Abrir no Google Maps" (url_launcher). Quando `Env.trackingEnabled` (B4/gate
/// G-5), embute os controles de tracking (a caminho / cheguei). O endereço só é
/// exibido enquanto a OS está em andamento — anti-desvio garantido pelo servidor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/env/env.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../data/prof_filters.dart';
import '../data/prof_providers.dart';
import '../location/tracking_controls.dart';

/// OS ativa do profissional (em andamento, mais recente). Null se nenhuma.
final activeOSProvider = FutureProvider.autoDispose<OrdemServico?>((ref) async {
  final id = ref.watch(currentProfIdProvider);
  if (id == null) return null;
  // Re-busca quando um evento realtime chega (mantém o mapa fresco).
  ref.watch(ordensRealtimeProvider);
  final repo = ref.watch(ordensRepositoryProvider);
  // A-04: filtro via prof_filters (escaping pbStringLiteral, sem interpolação).
  final res = await repo.list(
    perPage: 5,
    sort: '-updated',
    filter: profOsEmAndamentoFilter(id),
  );
  return res.items.isEmpty ? null : res.items.first;
});

String _mapsUrl(String address) =>
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  Future<void> _abrirMaps(BuildContext context, String address) async {
    final uri = Uri.parse(_mapsUrl(address));
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showClxToast(
        context,
        'Não foi possível abrir o Google Maps.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final async = ref.watch(activeOSProvider);

    // Título "Mapa" + avatar ficam no cabeçalho fixo do [ProfShell].
    return RefreshIndicator(
      color: clx.primary,
      onRefresh: () => ref.refresh(activeOSProvider.future),
      child: async.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Spinner(size: 24)),
          ],
        ),
        error: (_, __) => ListView(
          padding: const EdgeInsets.all(ClxSpace.x4),
          children: [
            ErrorBanner(
              message: 'Não foi possível carregar o mapa.',
              onRetry: () => ref.invalidate(activeOSProvider),
            ),
          ],
        ),
        data: (os) {
          if (os == null || (os.enderecoLiberado ?? '').isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.map_outlined,
                  title: 'Nenhum serviço ativo',
                  message:
                      'O mapa mostra OS com endereço liberado (atribuídas e em andamento). "Iniciar '
                      'serviço" na aba Serviços.',
                ),
              ],
            );
          }
          return _ActiveCard(
            os: os,
            onOpenMaps: () => _abrirMaps(context, os.enderecoLiberado!),
          );
        },
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.os, required this.onOpenMaps});

  final OrdemServico os;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        Container(
          decoration: BoxDecoration(
            color: clx.bg,
            borderRadius: ClxRadii.rLg,
            border: Border.all(color: clx.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: clx.statusEmAndamento),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(ClxSpace.x4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SERVIÇO EM ANDAMENTO',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: clx.statusEmAndamento,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                        ),
                        const SizedBox(height: ClxSpace.x2),
                        Text(
                          '${formatHour(os.dataHora)} — ${os.nomeCurto}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: clx.ink,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                        if ((os.tipoServicoNome ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              os.tipoServicoNome!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(color: clx.ink2),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${os.bairro} · ${formatCurrency(os.valorServico ?? 0)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: clx.ink3),
                          ),
                        ),
                        const SizedBox(height: ClxSpace.x3),
                        Container(
                          padding: const EdgeInsets.all(ClxSpace.x3),
                          decoration: BoxDecoration(
                            color: clx.primary.withValues(alpha: 0.07),
                            borderRadius: ClxRadii.rMd,
                            border: Border.all(
                              color: clx.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: clx.primary2,
                              ),
                              const SizedBox(width: ClxSpace.x2),
                              Expanded(
                                child: Text(
                                  os.enderecoLiberado!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(color: clx.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: ClxSpace.x3),
                        ClxButton(
                          label: 'Abrir no Google Maps',
                          variant: ClxButtonVariant.secondary,
                          icon: Icons.map_outlined,
                          expand: true,
                          onPressed: onOpenMaps,
                        ),
                        // B4: controles de tracking (só quando Env.trackingEnabled).
                        if (Env.trackingEnabled) ...[
                          const SizedBox(height: ClxSpace.x3),
                          TrackingControls(os: os),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        Text(
          'O endereço é liberado apenas enquanto o serviço está em andamento.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: clx.ink3, height: 1.5),
        ),
      ],
    );
  }
}
