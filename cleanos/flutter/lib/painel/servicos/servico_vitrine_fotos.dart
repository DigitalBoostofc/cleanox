/// Seção de fotos da Vitrine no editor de serviço do painel.
///
/// Grava em `vitrine_midia` com `servico` = id do serviço. A Vitrine pública
/// já resolve capa/galeria via `bootstrap.capaDoServico` / `midiaDoServico`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../vitrine/admin/vitrine_midia_repository.dart';

class ServicoVitrineFotosSection extends ConsumerStatefulWidget {
  const ServicoVitrineFotosSection({
    super.key,
    required this.servicoId,
    required this.servicoNome,
    this.enabled = true,
  });

  final String servicoId;
  final String servicoNome;
  final bool enabled;

  @override
  ConsumerState<ServicoVitrineFotosSection> createState() =>
      _ServicoVitrineFotosSectionState();
}

class _ServicoVitrineFotosSectionState
    extends ConsumerState<ServicoVitrineFotosSection> {
  late final VitrineMidiaRepository _repo;
  List<VitrineMidiaItem> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = VitrineMidiaRepository(ref.read(pocketBaseProvider));
    _reload();
  }

  @override
  void didUpdateWidget(covariant ServicoVitrineFotosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servicoId != widget.servicoId) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listByServico(widget.servicoId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar as fotos: $e';
      });
    }
  }

  Future<void> _addPhotos() async {
    if (!widget.enabled || _busy) return;
    final picker = ImagePicker();
    final selected = await picker.pickMultiImage(
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (selected.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var ordem = _items.isEmpty
          ? 0
          : _items.map((e) => e.ordem).reduce((a, b) => a > b ? a : b) + 1;
      final hasCapa = _items.any((e) => e.papel == 'capa');
      var firstIsCapa = !hasCapa;
      for (final file in selected) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = file.name.trim().isEmpty ? 'foto.jpg' : file.name;
        final papel = firstIsCapa ? 'capa' : 'galeria';
        firstIsCapa = false;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await _repo.create(
          chave: 'servico_${widget.servicoId}_${papel}_$stamp',
          titulo: widget.servicoNome.trim().isEmpty
              ? 'Foto do serviço'
              : widget.servicoNome.trim(),
          ordem: ordem++,
          ativo: true,
          servicoId: widget.servicoId,
          papel: papel,
          fileBytes: bytes,
          filename: name,
        );
        // tiny delay so chave stays unique if clock stalls
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha ao enviar foto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCapa(VitrineMidiaItem item) async {
    if (!widget.enabled || _busy || item.papel == 'capa') return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (final other in _items) {
        if (other.id == item.id) continue;
        if (other.papel == 'capa') {
          await _repo.update(other.id, papel: 'galeria');
        }
      }
      await _repo.update(item.id, papel: 'capa', ordem: 0);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível definir a capa: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(VitrineMidiaItem item) async {
    if (!widget.enabled || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text(
          'A foto deixa de aparecer na Vitrine. Esta ação não desfaz o '
          'agendamento de clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.delete(item.id);
      // se removeu a capa, promove a primeira restante
      final rest = _items.where((e) => e.id != item.id).toList();
      if (item.papel == 'capa' && rest.isNotEmpty) {
        await _repo.update(rest.first.id, papel: 'capa', ordem: 0);
      }
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha ao remover: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fotos usadas no card deste serviço em agendar.cleanox.com.br. '
          'A capa é a principal; as demais entram na galeria.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: clx.ink2,
              ),
        ),
        const SizedBox(height: ClxSpace.x3),
        if (_error != null) ...[
          ErrorBanner(message: _error!, onRetry: _reload),
          const SizedBox(height: ClxSpace.x3),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Spinner(size: 22)),
          )
        else if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(ClxSpace.x4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ClxRadii.md),
              border: Border.all(color: clx.line),
              color: clx.bg2,
            ),
            child: Text(
              'Nenhuma foto ainda. Toque em “Adicionar fotos” para enviar '
              'uma ou várias imagens.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: clx.ink2,
                  ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in _items) _thumb(clx, item),
            ],
          ),
        const SizedBox(height: ClxSpace.x4),
        Align(
          alignment: Alignment.centerLeft,
          child: ClxButton(
            label: _busy ? 'Aguarde…' : 'Adicionar fotos',
            icon: Icons.add_photo_alternate_outlined,
            variant: ClxButtonVariant.secondary,
            loading: _busy,
            onPressed: (!widget.enabled || _busy) ? null : _addPhotos,
          ),
        ),
      ],
    );
  }

  Widget _thumb(CleanoxColors clx, VitrineMidiaItem item) {
    final url = item.displayUrl;
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ClxRadii.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: clx.bg3),
                  if (url != null && url.isNotEmpty)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: clx.ink3),
                      ),
                    )
                  else
                    Center(
                      child: Icon(Icons.image_outlined, color: clx.ink3),
                    ),
                  if (item.papel == 'capa')
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: clx.ink.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Capa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (item.papel != 'capa')
                Expanded(
                  child: TextButton(
                    onPressed:
                        (!widget.enabled || _busy) ? null : () => _setCapa(item),
                    child: const Text('Usar como capa', maxLines: 1),
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),
              IconButton(
                tooltip: 'Remover',
                onPressed:
                    (!widget.enabled || _busy) ? null : () => _delete(item),
                icon: Icon(Icons.delete_outline, color: clx.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
