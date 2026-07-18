/// mapa_screen.dart — Aba "Mapa": rota do dia com pins numerados.
///
/// Lista as OS de HOJE (atribuída + em andamento) com endereço, na ordem de
/// `data_hora`, e fixa um pin numerado no mapa (OSM via flutter_map). Coords
/// vêm da rota server-side `GET /api/cleanos/prof/mapa-hoje` (geocode se
/// faltar). "Abrir rota do dia" monta o Google Maps multi-parada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/env/env.dart';
import '../../core/models/collections.dart';
import '../data/prof_providers.dart';
import '../location/tracking_controls.dart';
import '../../core/models/ordem_servico.dart';

/// Pin do mapa do dia (DTO da rota /prof/mapa-hoje).
class MapaDiaPin {
  const MapaDiaPin({
    required this.seq,
    required this.osId,
    required this.nome,
    required this.hora,
    required this.endereco,
    required this.status,
    this.tipoServico = '',
    this.bairro = '',
    this.lat,
    this.lng,
  });

  final int seq;
  final String osId;
  final String nome;
  final String hora;
  final String endereco;
  final String status;
  final String tipoServico;
  final String bairro;
  final double? lat;
  final double? lng;

  bool get hasCoords =>
      lat != null && lng != null && lat != 0 && lng != 0;

  factory MapaDiaPin.fromJson(Map<String, dynamic> j) {
    double? d(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return MapaDiaPin(
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      osId: '${j['osId'] ?? ''}',
      nome: '${j['nome'] ?? '—'}',
      hora: '${j['hora'] ?? '—'}',
      endereco: '${j['endereco'] ?? ''}',
      status: '${j['status'] ?? ''}',
      tipoServico: '${j['tipoServico'] ?? ''}',
      bairro: '${j['bairro'] ?? ''}',
      lat: d(j['lat']),
      lng: d(j['lng']),
    );
  }
}

class MapaDiaResult {
  const MapaDiaResult({required this.dia, required this.pins});
  final String dia;
  final List<MapaDiaPin> pins;
}

/// OS do dia do profissional para o mapa (ordem da agenda).
final mapaHojeProvider = FutureProvider.autoDispose<MapaDiaResult>((ref) async {
  final id = ref.watch(currentProfIdProvider);
  if (id == null) return const MapaDiaResult(dia: '', pins: []);
  ref.watch(ordensRealtimeProvider);
  final pb = ref.watch(pocketBaseProvider);
  final res = await pb.send<Map<String, dynamic>>(
    '/api/cleanos/prof/mapa-hoje',
    method: 'GET',
  );
  final raw = res['pins'];
  final pins = <MapaDiaPin>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        pins.add(MapaDiaPin.fromJson(Map<String, dynamic>.from(item)));
      }
    }
  }
  return MapaDiaResult(dia: '${res['dia'] ?? ''}', pins: pins);
});

/// URL Google Maps com paradas na ordem da sequência (1 → 2 → … → N).
String mapsDirUrl(List<MapaDiaPin> pins) {
  final withAddr = [
    for (final p in pins)
      if (p.endereco.trim().isNotEmpty) p,
  ];
  if (withAddr.isEmpty) return 'https://www.google.com/maps';
  if (withAddr.length == 1) {
    final q = Uri.encodeComponent(withAddr.first.endereco);
    return 'https://www.google.com/maps/search/?api=1&query=$q';
  }
  final dest = Uri.encodeComponent(withAddr.last.endereco);
  final wps = withAddr
      .sublist(0, withAddr.length - 1)
      .map((p) => Uri.encodeComponent(p.endereco))
      .join('|');
  return 'https://www.google.com/maps/dir/?api=1'
      '&origin=Current+Location'
      '&destination=$dest'
      '&waypoints=$wps'
      '&travelmode=driving';
}

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  Future<void> _abrirUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
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
    final async = ref.watch(mapaHojeProvider);

    return RefreshIndicator(
      color: clx.primary,
      onRefresh: () => ref.refresh(mapaHojeProvider.future),
      child: async.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Spinner(size: 24)),
          ],
        ),
        error: (err, _) {
          final msg = err is ClientException
              ? 'Não foi possível carregar o mapa do dia.'
              : 'Não foi possível carregar o mapa do dia.';
          return ListView(
            padding: const EdgeInsets.all(ClxSpace.x4),
            children: [
              ErrorBanner(
                message: msg,
                onRetry: () => ref.invalidate(mapaHojeProvider),
              ),
            ],
          );
        },
        data: (data) {
          if (data.pins.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.map_outlined,
                  title: 'Nenhum serviço com endereço hoje',
                  message:
                      'Quando houver OS atribuídas ou em andamento no dia, '
                      'os pins aparecem aqui na ordem da agenda.',
                ),
              ],
            );
          }
          return _MapaDiaBody(
            data: data,
            onOpenPin: (p) => _abrirUrl(
              context,
              'https://www.google.com/maps/search/?api=1&query='
              '${Uri.encodeComponent(p.endereco)}',
            ),
            onOpenRotaDia: () => _abrirUrl(context, mapsDirUrl(data.pins)),
          );
        },
      ),
    );
  }
}

class _MapaDiaBody extends StatelessWidget {
  const _MapaDiaBody({
    required this.data,
    required this.onOpenPin,
    required this.onOpenRotaDia,
  });

  final MapaDiaResult data;
  final ValueChanged<MapaDiaPin> onOpenPin;
  final VoidCallback onOpenRotaDia;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final comCoords = [for (final p in data.pins) if (p.hasCoords) p];
    final center = comCoords.isNotEmpty
        ? LatLng(comCoords.first.lat!, comCoords.first.lng!)
        : const LatLng(-3.7172, -38.5433); // Fortaleza fallback

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        Text(
          'Roteiro de hoje${data.dia.isNotEmpty ? ' · ${data.dia}' : ''}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          '${data.pins.length} serviço${data.pins.length == 1 ? '' : 's'} '
          'na ordem da agenda (1 → ${data.pins.length}).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: clx.ink3,
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        // Mapa
        ClipRRect(
          borderRadius: ClxRadii.rLg,
          child: SizedBox(
            height: 280,
            child: comCoords.isEmpty
                ? Container(
                    color: clx.bg2,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(ClxSpace.x4),
                    child: Text(
                      'Não foi possível posicionar os pins no mapa '
                      '(geocode indisponível). Use a lista e “Abrir rota do dia”.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: clx.ink3,
                      ),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: comCoords.length == 1 ? 14 : 12,
                      initialCameraFit: comCoords.length > 1
                          ? CameraFit.coordinates(
                              coordinates: [
                                for (final p in comCoords)
                                  LatLng(p.lat!, p.lng!),
                              ],
                              padding: const EdgeInsets.all(40),
                            )
                          : null,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'br.com.wenox.cleanos',
                      ),
                      MarkerLayer(
                        markers: [
                          for (final p in comCoords)
                            Marker(
                              point: LatLng(p.lat!, p.lng!),
                              width: 40,
                              height: 40,
                              child: _NumberPin(
                                n: p.seq,
                                emAndamento:
                                    p.status == OSStatus.emAndamento.wire,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        ClxButton(
          label: 'Abrir rota do dia no Google Maps',
          variant: ClxButtonVariant.secondary,
          icon: Icons.route_outlined,
          expand: true,
          onPressed: onOpenRotaDia,
        ),
        const SizedBox(height: ClxSpace.x4),
        Text(
          'Sequência',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        for (final p in data.pins) ...[
          _PinListTile(pin: p, onOpen: () => onOpenPin(p)),
          const SizedBox(height: ClxSpace.x2),
        ],
        // Tracking só se houver OS em andamento e flag on.
        if (Env.trackingEnabled)
          for (final p in data.pins)
            if (p.status == OSStatus.emAndamento.wire)
              Padding(
                padding: const EdgeInsets.only(top: ClxSpace.x2),
                child: TrackingControls(
                  os: OrdemServico(
                    id: p.osId,
                    nomeCurto: p.nome,
                    status: OSStatus.emAndamento,
                    enderecoLiberado: p.endereco,
                  ),
                ),
              ),
        const SizedBox(height: ClxSpace.x3),
        Text(
          'Os números seguem o horário agendado. '
          '“Abrir rota do dia” monta o trajeto 1 → 2 → … no Google Maps.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: clx.ink3,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Cores distintas por sequência (1, 2, 3… cicla se passar de 8).
Color pinColorForSeq(int n) {
  const palette = <Color>[
    Color(0xFF0D9488), // teal
    Color(0xFF2563EB), // blue
    Color(0xFFD97706), // amber
    Color(0xFFDC2626), // red
    Color(0xFF7C3AED), // violet
    Color(0xFF059669), // green
    Color(0xFFDB2777), // pink
    Color(0xFFEA580C), // orange
  ];
  final i = n <= 0 ? 0 : (n - 1) % palette.length;
  return palette[i];
}

/// Círculo com o número da sequência — mesmo visual no mapa e no card.
class _NumberPin extends StatelessWidget {
  const _NumberPin({
    required this.n,
    this.emAndamento = false,
    this.size = 36,
  });

  final int n;
  final bool emAndamento;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = pinColorForSeq(n);
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: emAndamento ? const Color(0xFFFBBF24) : Colors.white,
            width: emAndamento ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$n',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size >= 36 ? 15 : 13,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PinListTile extends StatelessWidget {
  const _PinListTile({required this.pin, required this.onOpen});
  final MapaDiaPin pin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final emAndamento = pin.status == OSStatus.emAndamento.wire;
    final pinColor = pinColorForSeq(pin.seq);
    return Material(
      color: clx.bg,
      borderRadius: ClxRadii.rMd,
      child: InkWell(
        onTap: onOpen,
        borderRadius: ClxRadii.rMd,
        child: Container(
          padding: const EdgeInsets.all(ClxSpace.x3),
          decoration: BoxDecoration(
            borderRadius: ClxRadii.rMd,
            border: Border.all(
              color: emAndamento ? pinColor : clx.line,
              width: emAndamento ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Número no lugar do ícone quebrado — mesma cor do pin do mapa.
              _NumberPin(n: pin.seq, emAndamento: emAndamento, size: 40),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pin.hora} · ${pin.nome}',
                      style: tt.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (pin.tipoServico.isNotEmpty || pin.bairro.isNotEmpty)
                      Text(
                        [
                          if (pin.tipoServico.isNotEmpty) pin.tipoServico,
                          if (pin.bairro.isNotEmpty) pin.bairro,
                        ].join(' · '),
                        style: tt.bodySmall?.copyWith(color: clx.ink2),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      pin.endereco,
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                    if (!pin.hasCoords)
                      Text(
                        'Pin no mapa indisponível — toque para abrir no Maps',
                        style: tt.labelSmall?.copyWith(color: clx.warning),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
