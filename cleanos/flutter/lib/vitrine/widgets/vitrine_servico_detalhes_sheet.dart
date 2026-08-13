/// Popup flutuante de detalhes do serviço na Vitrine pública.
library;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../vitrine_api.dart';
import 'vitrine_ui.dart';

/// Abre painel com capa, título e o que o serviço inclui.
Future<void> showVitrineServicoDetalhes(
  BuildContext context, {
  required VitrineServico servico,
  required List<VitrineMidia> media,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(ctx).top + 12,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: VitrineUi.contentMaxWidth,
              maxHeight: h * 0.92,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: _VitrineServicoDetalhesBody(
                servico: servico,
                media: media,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _VitrineServicoDetalhesBody extends StatelessWidget {
  const _VitrineServicoDetalhesBody({
    required this.servico,
    required this.media,
  });

  final VitrineServico servico;
  final List<VitrineMidia> media;

  String get _detalhes {
    final t = servico.descricaoComercial.trim();
    if (t.isNotEmpty) return t;
    return 'Sem detalhes cadastrados para este serviço.';
  }

  String? get _capaUrl {
    for (final m in media) {
      if (m.papel == 'capa' && m.url.trim().isNotEmpty) return m.url.trim();
    }
    for (final m in media) {
      if (m.url.trim().isNotEmpty) return m.url.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _capaUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _headerFallback(),
                )
              else
                _headerFallback(),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: Key('vitrine-detalhes-fechar-${servico.id}'),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
            children: [
              Text(
                servico.tituloComercial,
                key: Key('vitrine-detalhes-titulo-${servico.id}'),
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: ClxBrand.navy,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Detalhes',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: ClxBrand.cyan,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _detalhes,
                key: Key('vitrine-detalhes-corpo-${servico.id}'),
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 15,
                  height: 1.55,
                  color: ClxBrand.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerFallback() => Container(
        color: const Color(0xFFE8F4F6),
        alignment: Alignment.center,
        child: const Icon(
          Icons.cleaning_services_rounded,
          size: 56,
          color: ClxBrand.cyan,
        ),
      );
}
