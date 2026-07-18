/// rota_in_app_sheet.dart — "Ver rota" in-app (mapa + distância/ETA).
///
/// Não abre o Google Maps externo. Usa:
///  - GET /api/cleanos/os/{id}/rota → destino geocodificado
///  - geolocator → posição atual (degrada se negada)
///  - OSRM público → distância, tempo e polyline (sem chave)
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/ordem_servico.dart';
import 'map_pin_widget.dart';

/// Abre a tela de rota in-app (fullscreen dialog).
Future<void> openRotaInApp(BuildContext context, OrdemServico os) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RotaInAppPage(os: os),
    ),
  );
}

class RotaDestino {
  const RotaDestino({
    required this.osId,
    required this.nome,
    required this.endereco,
    this.lat,
    this.lng,
    this.bairro = '',
    this.tipoServico = '',
  });

  final String osId;
  final String nome;
  final String endereco;
  final double? lat;
  final double? lng;
  final String bairro;
  final String tipoServico;

  bool get hasCoords =>
      lat != null && lng != null && lat != 0 && lng != 0;

  factory RotaDestino.fromJson(Map<String, dynamic> j) {
    double? d(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return RotaDestino(
      osId: '${j['osId'] ?? ''}',
      nome: '${j['nome'] ?? '—'}',
      endereco: '${j['endereco'] ?? ''}',
      lat: d(j['lat']),
      lng: d(j['lng']),
      bairro: '${j['bairro'] ?? ''}',
      tipoServico: '${j['tipoServico'] ?? ''}',
    );
  }
}

class RotaOsrm {
  const RotaOsrm({
    required this.distanceM,
    required this.durationS,
    this.path = const [],
  });

  final double distanceM;
  final double durationS;
  final List<LatLng> path;
}

/// Formata metros → "1,2 km" / "350 m".
String formatDistancia(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  final t = km >= 10
      ? km.toStringAsFixed(0)
      : km.toStringAsFixed(1).replaceAll('.', ',');
  return '$t km';
}

/// Formata segundos → "12 min" / "1 h 05 min".
String formatDuracao(double seconds) {
  final min = (seconds / 60).ceil();
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  if (m == 0) return '$h h';
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

/// Haversine (metros) — fallback se OSRM falhar.
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Rota OSRM (API pública). Retorna null se falhar.
Future<RotaOsrm?> fetchOsrmRoute({
  required LatLng origin,
  required LatLng dest,
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final owned = client == null;
  try {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${dest.longitude},${dest.latitude}'
      '?overview=simplified&geometries=geojson',
    );
    final res = await c.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final r0 = routes.first;
    if (r0 is! Map) return null;
    final dist = (r0['distance'] as num?)?.toDouble() ?? 0;
    final dur = (r0['duration'] as num?)?.toDouble() ?? 0;
    final path = <LatLng>[];
    final geom = r0['geometry'];
    if (geom is Map && geom['coordinates'] is List) {
      for (final c0 in geom['coordinates'] as List) {
        if (c0 is List && c0.length >= 2) {
          final lon = (c0[0] as num).toDouble();
          final lat = (c0[1] as num).toDouble();
          path.add(LatLng(lat, lon));
        }
      }
    }
    if (dist <= 0) return null;
    return RotaOsrm(distanceM: dist, durationS: dur, path: path);
  } catch (_) {
    return null;
  } finally {
    if (owned) c.close();
  }
}

class RotaInAppPage extends ConsumerStatefulWidget {
  const RotaInAppPage({super.key, required this.os});

  final OrdemServico os;

  @override
  ConsumerState<RotaInAppPage> createState() => _RotaInAppPageState();
}

class _RotaInAppPageState extends ConsumerState<RotaInAppPage> {
  bool _loading = true;
  String? _error;
  RotaDestino? _dest;
  LatLng? _origin;
  RotaOsrm? _route;
  bool _locDenied = false;
  bool _usingHaversine = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pb = ref.read(pocketBaseProvider);
      final res = await pb.send<Map<String, dynamic>>(
        '/api/cleanos/os/${widget.os.id}/rota',
        method: 'GET',
      );
      final dest = RotaDestino.fromJson(res);
      if (!dest.hasCoords) {
        if (mounted) {
          setState(() {
            _dest = dest;
            _loading = false;
            _error = 'Não foi possível localizar o endereço no mapa.';
          });
        }
        return;
      }

      LatLng? origin;
      var denied = false;
      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 12),
              ),
            );
            origin = LatLng(pos.latitude, pos.longitude);
          } else {
            denied = true;
          }
        } else {
          denied = true;
        }
      } catch (_) {
        denied = true;
      }

      RotaOsrm? route;
      var haversine = false;
      if (origin != null) {
        route = await fetchOsrmRoute(
          origin: origin,
          dest: LatLng(dest.lat!, dest.lng!),
        );
        if (route == null) {
          final m = haversineM(
            origin.latitude,
            origin.longitude,
            dest.lat!,
            dest.lng!,
          );
          // ~28 km/h média urbana estimada
          final s = (m / (28 * 1000 / 3600));
          route = RotaOsrm(distanceM: m, durationS: s, path: const []);
          haversine = true;
        }
      }

      if (!mounted) return;
      setState(() {
        _dest = dest;
        _origin = origin;
        _route = route;
        _locDenied = denied && origin == null;
        _usingHaversine = haversine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar a rota.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final os = widget.os;
    final dest = _dest;

    return Scaffold(
      backgroundColor: clx.bg2,
      appBar: AppBar(
        title: const Text('Rota'),
        backgroundColor: clx.bg,
        foregroundColor: clx.ink,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : _error != null && dest == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ClxSpace.x5),
                    child: ErrorBanner(message: _error!, onRetry: _load),
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _buildMap(clx)),
                    _buildInfo(context, clx, os, dest),
                  ],
                ),
    );
  }

  Widget _buildMap(CleanoxColors clx) {
    final dest = _dest;
    if (dest == null || !dest.hasCoords) {
      return Container(
        color: clx.bg3,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(ClxSpace.x4),
        child: Text(
          _error ?? 'Mapa indisponível',
          textAlign: TextAlign.center,
          style: TextStyle(color: clx.ink3),
        ),
      );
    }

    final destPt = LatLng(dest.lat!, dest.lng!);
    final origin = _origin;
    final path = _route?.path ?? const <LatLng>[];
    final points = <LatLng>[
      if (origin != null) origin,
      ...path,
      destPt,
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: destPt,
        initialZoom: origin == null ? 15 : 13,
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.fromLTRB(48, 48, 48, 48),
              )
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'br.com.wenox.cleanos',
        ),
        if (path.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: path,
                strokeWidth: 4.5,
                color: clx.primary.withValues(alpha: 0.85),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (origin != null)
              Marker(
                point: origin,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: clx.info,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            Marker(
              point: destPt,
              width: 48,
              height: 60,
              alignment: Alignment.bottomCenter,
              child: MapDestPin(
                color: clx.primary,
                size: 48,
                bounce: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfo(
    BuildContext context,
    CleanoxColors clx,
    OrdemServico os,
    RotaDestino? dest,
  ) {
    final tt = Theme.of(context).textTheme;
    final route = _route;

    return Material(
      color: clx.bg,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x4,
            ClxSpace.x3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dest?.nome ?? os.nomeCurto,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: clx.ink,
                ),
              ),
              if ((dest?.tipoServico ?? os.tipoServicoNome ?? '').isNotEmpty)
                Text(
                  dest?.tipoServico ?? os.tipoServicoNome ?? '',
                  style: tt.bodySmall?.copyWith(color: clx.ink2),
                ),
              const SizedBox(height: ClxSpace.x2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: clx.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dest?.endereco ?? os.enderecoLiberado ?? '—',
                      style: tt.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ClxSpace.x3),
              if (route != null)
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.straighten_rounded,
                        label: 'Distância',
                        value: formatDistancia(route.distanceM),
                        hint: _usingHaversine ? 'linha reta (aprox.)' : 'por via',
                      ),
                    ),
                    const SizedBox(width: ClxSpace.x2),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.schedule_rounded,
                        label: 'Tempo est.',
                        value: formatDuracao(route.durationS),
                        hint: _usingHaversine ? 'estimado' : 'sem trânsito',
                      ),
                    ),
                  ],
                )
              else if (_locDenied)
                Container(
                  padding: const EdgeInsets.all(ClxSpace.x3),
                  decoration: BoxDecoration(
                    color: clx.warningBg,
                    borderRadius: ClxRadii.rMd,
                  ),
                  child: Text(
                    'Ative a localização do aparelho para ver distância e '
                    'tempo até o destino.',
                    style: tt.bodySmall?.copyWith(color: clx.ink2),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: tt.bodySmall?.copyWith(color: clx.warning),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.bg3,
        borderRadius: ClxRadii.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: clx.ink3),
              const SizedBox(width: 4),
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: clx.ink3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink,
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: tt.labelSmall?.copyWith(color: clx.ink3),
            ),
        ],
      ),
    );
  }
}
