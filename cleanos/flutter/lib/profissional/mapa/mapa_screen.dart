/// mapa_screen.dart — Aba "Mapa": pins fixos do dia + deslocamento planejado.
///
/// Lista TODAS as OS de HOJE (atribuída + em andamento + concluída) com endereço,
/// na ordem de `data_hora`, pins numerados no mapa (OSM). O 1º "Em deslocamento"
/// grava a partida; o card mostra km planejado: partida → OS… → volta à partida.
/// Rota: `GET /api/cleanos/prof/mapa-hoje`.
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
import '../../core/models/ordem_servico.dart';
import '../data/prof_providers.dart';
import '../location/tracking_controls.dart';
import 'map_pin_widget.dart';

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

class MapaPartida {
  const MapaPartida({required this.lat, required this.lng, this.em = ''});
  final double lat;
  final double lng;
  final String em;

  factory MapaPartida.fromJson(Map<String, dynamic> j) {
    double d(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return MapaPartida(
      lat: d(j['lat']),
      lng: d(j['lng']),
      em: '${j['em'] ?? ''}',
    );
  }
}

class MapaDeslocamento {
  const MapaDeslocamento({
    required this.km,
    required this.metros,
    this.fonte = '',
    this.incluiRetorno = true,
  });
  final double km;
  final int metros;
  final String fonte;
  final bool incluiRetorno;

  factory MapaDeslocamento.fromJson(Map<String, dynamic> j) {
    return MapaDeslocamento(
      km: (j['km'] is num)
          ? (j['km'] as num).toDouble()
          : double.tryParse('${j['km']}') ?? 0,
      metros: (j['metros'] as num?)?.toInt() ?? 0,
      fonte: '${j['fonte'] ?? ''}',
      incluiRetorno: j['incluiRetorno'] != false,
    );
  }
}

class MapaDiaResult {
  const MapaDiaResult({
    required this.dia,
    required this.pins,
    this.partida,
    this.deslocamento,
  });
  final String dia;
  final List<MapaDiaPin> pins;
  final MapaPartida? partida;
  final MapaDeslocamento? deslocamento;
}

/// OS do dia do profissional para o mapa (ordem da agenda).
final mapaHojeProvider = FutureProvider.autoDispose<MapaDiaResult>((ref) async {
  final id = ref.watch(currentProfIdProvider);
  if (id == null) {
    return const MapaDiaResult(dia: '', pins: []);
  }
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
  MapaPartida? partida;
  final rawPartida = res['partida'];
  if (rawPartida is Map) {
    final p = MapaPartida.fromJson(Map<String, dynamic>.from(rawPartida));
    if (p.lat != 0 && p.lng != 0) partida = p;
  }
  MapaDeslocamento? desloc;
  final rawDesl = res['deslocamento'];
  if (rawDesl is Map) {
    final d = MapaDeslocamento.fromJson(Map<String, dynamic>.from(rawDesl));
    if (d.km > 0) desloc = d;
  }
  return MapaDiaResult(
    dia: '${res['dia'] ?? ''}',
    pins: pins,
    partida: partida,
    deslocamento: desloc,
  );
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
                      'Quando houver OS no dia (atribuídas, em andamento ou '
                      'concluídas), os pins aparecem aqui na ordem da agenda.',
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
  });

  final MapaDiaResult data;
  final ValueChanged<MapaDiaPin> onOpenPin;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final comCoords = [for (final p in data.pins) if (p.hasCoords) p];
    final partida = data.partida;
    final fitPoints = <LatLng>[
      if (partida != null) LatLng(partida.lat, partida.lng),
      for (final p in comCoords) LatLng(p.lat!, p.lng!),
    ];
    final center = fitPoints.isNotEmpty
        ? fitPoints.first
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
        _DeslocamentoCard(
          partida: partida,
          deslocamento: data.deslocamento,
          nServicos: data.pins.length,
        ),
        const SizedBox(height: ClxSpace.x3),
        // Mapa
        ClipRRect(
          borderRadius: ClxRadii.rLg,
          child: SizedBox(
            height: 300,
            child: fitPoints.isEmpty
                ? Container(
                    color: clx.bg2,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(ClxSpace.x4),
                    child: Text(
                      'Não foi possível posicionar os pins no mapa '
                      '(geocode indisponível). Toque um endereço na lista '
                      'para abrir no Google Maps.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: clx.ink3,
                      ),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: fitPoints.length == 1 ? 14 : 12,
                      initialCameraFit: fitPoints.length > 1
                          ? CameraFit.coordinates(
                              coordinates: fitPoints,
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
                          if (partida != null)
                            Marker(
                              point: LatLng(partida.lat, partida.lng),
                              width: 44,
                              height: 56,
                              alignment: Alignment.bottomCenter,
                              child: const MapLetterPin(
                                letter: 'P',
                                color: Color(0xFF0F766E),
                                bounce: false,
                              ),
                            ),
                          for (final p in comCoords)
                            Marker(
                              point: LatLng(p.lat!, p.lng!),
                              width: 44,
                              height: 56,
                              alignment: Alignment.bottomCenter,
                              child: MapNumberPin(
                                n: p.seq,
                                color: pinColorForStatus(p.status, p.seq),
                                emAndamento:
                                    p.status == OSStatus.emAndamento.wire,
                                bounce:
                                    p.status == OSStatus.emAndamento.wire,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
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
          'Pins fixos de todas as OS do dia. O km do dia é a rota planejada '
          'a partir do ponto em que você tocou Em deslocamento pela 1ª vez, '
          'passando por cada serviço e voltando à partida.',
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

class _DeslocamentoCard extends StatelessWidget {
  const _DeslocamentoCard({
    required this.partida,
    required this.deslocamento,
    required this.nServicos,
  });

  final MapaPartida? partida;
  final MapaDeslocamento? deslocamento;
  final int nServicos;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final hasKm = deslocamento != null && deslocamento!.km > 0;
    final hasPartida = partida != null;

    return Container(
      padding: const EdgeInsets.all(ClxSpace.x4),
      decoration: BoxDecoration(
        color: hasKm ? clx.primary.withValues(alpha: 0.08) : clx.bg2,
        borderRadius: ClxRadii.rLg,
        border: Border.all(
          color: hasKm ? clx.primary.withValues(alpha: 0.25) : clx.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasKm ? clx.primary : clx.bg3,
              borderRadius: ClxRadii.rMd,
            ),
            child: Icon(
              Icons.route_rounded,
              color: hasKm ? Colors.white : clx.ink3,
              size: 24,
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasKm
                      ? 'Deslocamento do dia · ${deslocamento!.km.toStringAsFixed(1).replaceAll('.', ',')} km'
                      : hasPartida
                      ? 'Deslocamento do dia'
                      : 'Ponto de partida',
                  style: tt.titleSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasKm
                      ? 'Partida → $nServicos serviço${nServicos == 1 ? '' : 's'} → volta'
                      : hasPartida
                      ? 'Partida marcada. Aguardando coords dos serviços…'
                      : 'Toque em Em deslocamento na 1ª OS para marcar a '
                          'partida e calcular o km do dia (ida e volta).',
                  style: tt.bodySmall?.copyWith(
                    color: clx.ink3,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cores por status (concluída=verde; em andamento=destaque; senão paleta seq).
Color pinColorForStatus(String status, int seq) {
  if (status == OSStatus.concluida.wire) {
    return const Color(0xFF059669); // green
  }
  if (status == OSStatus.emAndamento.wire) {
    return const Color(0xFF2563EB); // blue destaque
  }
  return pinColorForSeq(seq);
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

class _PinListTile extends StatelessWidget {
  const _PinListTile({required this.pin, required this.onOpen});
  final MapaDiaPin pin;
  final VoidCallback onOpen;

  String get _statusLabel {
    if (pin.status == OSStatus.concluida.wire) return 'Concluída';
    if (pin.status == OSStatus.emAndamento.wire) return 'Em andamento';
    if (pin.status == OSStatus.atribuida.wire) return 'Atribuída';
    return pin.status;
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final emAndamento = pin.status == OSStatus.emAndamento.wire;
    final concluida = pin.status == OSStatus.concluida.wire;
    final pinColor = pinColorForStatus(pin.status, pin.seq);
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
              color: emAndamento || concluida ? pinColor : clx.line,
              width: emAndamento ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MapNumberPin(
                n: pin.seq,
                color: pinColor,
                emAndamento: emAndamento,
                size: 36,
                bounce: false,
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${pin.hora} · ${pin.nome}',
                            style: tt.titleSmall?.copyWith(
                              color: clx.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pinColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel,
                            style: tt.labelSmall?.copyWith(
                              color: pinColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
