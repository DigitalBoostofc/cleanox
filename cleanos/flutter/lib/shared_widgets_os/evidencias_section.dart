/// evidencias_section.dart — Evidências do serviço (fotos antes/durante/depois).
///
/// Widget GENÉRICO e CONTROLADO (dono: Time B, reusável pelo Painel): recebe a
/// lista de [EvidenciaFoto] + callbacks; NÃO conhece image_picker nem o PocketBase.
/// Quem materializa (pick + upload otimista + persistência offline) é o pai
/// (a tela de execução, via a fila de upload). Porte de
/// `components/os/EvidenciasSection.tsx`.
///
/// Renderização da imagem: `url` http(s) → rede (com cache); caso contrário é
/// tratado como CAMINHO LOCAL de arquivo (preview otimista antes do upload).
library;

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../core/models/os_execucao.dart';
import 'labels.dart';

/// Tipo de vínculo de uma evidência.
enum VinculoKind { checklist, observacao, adicional }

/// Vínculo resolvido (tipo + id).
class Vinculo {
  const Vinculo(this.kind, this.id);
  final VinculoKind kind;
  final String id;
}

/// Opção rotulável para o seletor de vínculo (item de checklist/obs/adicional).
class VinculoOption {
  const VinculoOption({
    required this.kind,
    required this.id,
    required this.label,
  });
  final VinculoKind kind;
  final String id;
  final String label;
}

class EvidenciasSection extends StatelessWidget {
  const EvidenciasSection({
    super.key,
    required this.fotos,
    required this.onPick,
    required this.onRemove,
    required this.onLegenda,
    this.onVinculo,
    this.vinculoOptions = const [],
    this.pendingIds = const {},
    this.failedIds = const {},
    this.deletingId,
    this.onRetry,
    this.disabled = false,
  });

  final List<EvidenciaFoto> fotos;

  /// Solicita adicionar fotos de uma fase (o pai abre a câmera/galeria).
  final ValueChanged<FaseFoto> onPick;
  final ValueChanged<String> onRemove;

  /// (id, legenda) — o pai faz debounce/persistência.
  final void Function(String id, String legenda) onLegenda;

  /// (id, vínculo|null) — opcional; escondido se [vinculoOptions] vazio.
  final void Function(String id, Vinculo? vinculo)? onVinculo;
  final List<VinculoOption> vinculoOptions;

  /// IDs em upload (overlay "Enviando…").
  final Set<String> pendingIds;

  /// IDs cujo upload falhou (mostra "Reenviar").
  final Set<String> failedIds;
  final String? deletingId;
  final ValueChanged<String>? onRetry;
  final bool disabled;

  static const List<FaseFoto> _fases = [
    FaseFoto.antes,
    FaseFoto.durante,
    FaseFoto.depois,
  ];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Evidências do serviço',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          'Registre fotos do antes, durante e depois. Toque numa foto para '
          'legendar ou vincular a um item do serviço.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
        ),
        for (final fase in _fases) ...[
          const SizedBox(height: ClxSpace.x4),
          _FaseGrupo(
            fase: fase,
            fotos: fotos.where((f) => f.fase == fase).toList(),
            onPick: disabled ? null : () => onPick(fase),
            onRemove: onRemove,
            onLegenda: onLegenda,
            onVinculo: onVinculo,
            vinculoOptions: vinculoOptions,
            pendingIds: pendingIds,
            failedIds: failedIds,
            deletingId: deletingId,
            onRetry: onRetry,
          ),
        ],
      ],
    );
  }
}

class _FaseGrupo extends StatelessWidget {
  const _FaseGrupo({
    required this.fase,
    required this.fotos,
    required this.onPick,
    required this.onRemove,
    required this.onLegenda,
    required this.onVinculo,
    required this.vinculoOptions,
    required this.pendingIds,
    required this.failedIds,
    required this.deletingId,
    required this.onRetry,
  });

  final FaseFoto fase;
  final List<EvidenciaFoto> fotos;
  final VoidCallback? onPick;
  final ValueChanged<String> onRemove;
  final void Function(String, String) onLegenda;
  final void Function(String, Vinculo?)? onVinculo;
  final List<VinculoOption> vinculoOptions;
  final Set<String> pendingIds;
  final Set<String> failedIds;
  final String? deletingId;
  final ValueChanged<String>? onRetry;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              faseFotoLabel(fase),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (fotos.isNotEmpty) ...[
              const SizedBox(width: ClxSpace.x2),
              ClxChip(
                label: '${fotos.length}',
                color: clx.primary,
                dense: true,
              ),
            ],
            const Spacer(),
            if (onPick != null)
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Adicionar foto'),
                style: TextButton.styleFrom(
                  foregroundColor: clx.accent,
                  minimumSize: const Size(0, ClxLayout.minTouchTarget),
                ),
              ),
          ],
        ),
        const SizedBox(height: ClxSpace.x2),
        if (fotos.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: clx.bg2,
              borderRadius: ClxRadii.rMd,
              border: Border.all(
                color: clx.line2,
                style: BorderStyle.solid,
                width: 1,
              ),
            ),
            child: Text(
              'Nenhuma foto de ${faseFotoLabel(fase).toLowerCase()}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 236,
              crossAxisSpacing: ClxSpace.x3,
              mainAxisSpacing: ClxSpace.x3,
            ),
            itemCount: fotos.length,
            itemBuilder: (context, i) {
              final f = fotos[i];
              return _FotoCard(
                foto: f,
                uploading: pendingIds.contains(f.id),
                failed: failedIds.contains(f.id),
                deleting: deletingId == f.id,
                onRemove: () => onRemove(f.id),
                onLegenda: (v) => onLegenda(f.id, v),
                onVinculo: onVinculo == null
                    ? null
                    : (v) => onVinculo!(f.id, v),
                vinculoOptions: vinculoOptions,
                onRetry: onRetry == null ? null : () => onRetry!(f.id),
              );
            },
          ),
      ],
    );
  }
}

class _FotoCard extends StatelessWidget {
  const _FotoCard({
    required this.foto,
    required this.uploading,
    required this.failed,
    required this.deleting,
    required this.onRemove,
    required this.onLegenda,
    required this.onVinculo,
    required this.vinculoOptions,
    required this.onRetry,
  });

  final EvidenciaFoto foto;
  final bool uploading;
  final bool failed;
  final bool deleting;
  final VoidCallback onRemove;
  final ValueChanged<String> onLegenda;
  final ValueChanged<Vinculo?>? onVinculo;
  final List<VinculoOption> vinculoOptions;
  final VoidCallback? onRetry;

  Vinculo? get _vinculo {
    if ((foto.checklistItemId ?? '').isNotEmpty) {
      return Vinculo(VinculoKind.checklist, foto.checklistItemId!);
    }
    if ((foto.observacaoId ?? '').isNotEmpty) {
      return Vinculo(VinculoKind.observacao, foto.observacaoId!);
    }
    if ((foto.adicionalId ?? '').isNotEmpty) {
      return Vinculo(VinculoKind.adicional, foto.adicionalId!);
    }
    return null;
  }

  bool get _isNetwork =>
      foto.url.startsWith('http://') || foto.url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final busy = uploading || deleting;
    final v = _vinculo;
    final selectedValue = v == null ? '' : '${v.kind.name}:${v.id}';

    return ClxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ClxRadii.lg),
                  ),
                  child: _isNetwork
                      ? CachedNetworkImage(
                          imageUrl: foto.url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              ColoredBox(color: clx.bg3, child: const Center()),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: clx.bg3,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: clx.ink3,
                            ),
                          ),
                        )
                      : Image.file(
                          File(foto.url),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: clx.bg3,
                            child: Icon(Icons.image_outlined, color: clx.ink3),
                          ),
                        ),
                ),
                if (busy)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Spinner(size: 20, color: Colors.white),
                        const SizedBox(height: ClxSpace.x1),
                        Text(
                          uploading ? 'Enviando…' : 'Removendo…',
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (failed && !busy)
                  Container(
                    color: Colors.black.withValues(alpha: 0.62),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(height: ClxSpace.x1),
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Reenviar'),
                          ),
                      ],
                    ),
                  ),
                if (!busy)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Remover foto',
                        iconSize: 18,
                        color: Colors.white,
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ClxSpace.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: foto.legenda ?? '',
                  enabled: !busy,
                  onChanged: onLegenda,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Descreva a foto…',
                  ),
                ),
                if (onVinculo != null && vinculoOptions.isNotEmpty) ...[
                  const SizedBox(height: ClxSpace.x2),
                  DropdownButtonFormField<String>(
                    initialValue: selectedValue.isEmpty ? null : selectedValue,
                    isExpanded: true,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: clx.ink),
                    decoration: const InputDecoration(isDense: true),
                    hint: const Text('Sem vínculo'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Sem vínculo'),
                      ),
                      for (final opt in vinculoOptions)
                        DropdownMenuItem(
                          value: '${opt.kind.name}:${opt.id}',
                          child: Text(
                            opt.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy ? null : (raw) => onVinculo!(_parse(raw)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Vinculo? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final idx = raw.indexOf(':');
    if (idx == -1) return null;
    final kind = raw.substring(0, idx);
    final id = raw.substring(idx + 1);
    if (id.isEmpty) return null;
    return switch (kind) {
      'checklist' => Vinculo(VinculoKind.checklist, id),
      'observacao' => Vinculo(VinculoKind.observacao, id),
      'adicional' => Vinculo(VinculoKind.adicional, id),
      _ => null,
    };
  }
}
