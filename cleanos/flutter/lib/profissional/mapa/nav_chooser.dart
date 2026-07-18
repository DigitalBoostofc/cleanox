/// nav_chooser.dart — Escolhe app de navegação (Google Maps / Waze / sistema).
///
/// Usado após "Em deslocamento": destino já configurado; o profissional escolhe
/// o app. Deep-links:
///  - Google: maps/dir com destination lat,lng ou endereço
///  - Waze: waze.com/ul navigate
///  - Sistema (Android): geo: → sheet nativo de apps de mapa
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/design.dart';

/// Destino para navegação externa.
class NavDestino {
  const NavDestino({required this.endereco, this.lat, this.lng});

  final String endereco;
  final double? lat;
  final double? lng;

  bool get hasCoords =>
      lat != null && lng != null && lat != 0 && lng != 0;
}

/// Sheet: Google Maps · Waze · Outros apps (geo).
Future<void> showNavChooser(
  BuildContext context, {
  required NavDestino dest,
}) async {
  if (!context.mounted) return;
  final clx = context.clx;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: clx.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: clx.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Abrir navegação',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: clx.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dest.endereco,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: clx.ink2,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.map_rounded, color: clx.primary),
                title: const Text('Google Maps'),
                subtitle: const Text('Navegação com o endereço de destino'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openGoogle(dest);
                },
              ),
              ListTile(
                leading: Icon(Icons.navigation_rounded, color: clx.info),
                title: const Text('Waze'),
                subtitle: const Text('Navegação Waze até o destino'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openWaze(dest);
                },
              ),
              ListTile(
                leading: Icon(Icons.apps_rounded, color: clx.ink2),
                title: const Text('Outros apps de mapa'),
                subtitle: const Text('Lista de apps instalados no aparelho'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openGeo(dest);
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _launch(Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    // Fallback browser
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}

Future<void> _openGoogle(NavDestino d) async {
  final Uri uri;
  if (d.hasCoords) {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${d.lat},${d.lng}'
      '&travelmode=driving',
    );
  } else {
    final q = Uri.encodeComponent(d.endereco);
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$q&travelmode=driving',
    );
  }
  await _launch(uri);
}

Future<void> _openWaze(NavDestino d) async {
  final Uri uri;
  if (d.hasCoords) {
    uri = Uri.parse(
      'https://waze.com/ul?ll=${d.lat},${d.lng}&navigate=yes',
    );
  } else {
    final q = Uri.encodeComponent(d.endereco);
    uri = Uri.parse('https://waze.com/ul?q=$q&navigate=yes');
  }
  await _launch(uri);
}

Future<void> _openGeo(NavDestino d) async {
  final Uri uri;
  if (d.hasCoords) {
    uri = Uri.parse('geo:${d.lat},${d.lng}?q=${d.lat},${d.lng}(${Uri.encodeComponent(d.endereco)})');
  } else {
    uri = Uri.parse('geo:0,0?q=${Uri.encodeComponent(d.endereco)}');
  }
  await _launch(uri);
}
