import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/tokens.dart';
import 'vitrine_midia_repository.dart';

/// Editor de mídia **global** da Vitrine (hero, categorias, ofertas).
///
/// Fotos de serviço NÃO entram aqui — cadastro em Painel → Serviços → Editar.
class VitrineMidiaEditorDialog extends StatefulWidget {
  const VitrineMidiaEditorDialog({
    required this.existing,
    required this.onSave,
    super.key,
  });

  final VitrineMidiaItem? existing;
  final Future<void> Function({
    required String chave,
    required String titulo,
    required String urlExterna,
    required int ordem,
    required bool ativo,
    List<int>? fileBytes,
    String? filename,
  })
  onSave;

  @override
  State<VitrineMidiaEditorDialog> createState() =>
      _VitrineMidiaEditorDialogState();
}

class _VitrineMidiaEditorDialogState extends State<VitrineMidiaEditorDialog> {
  late final TextEditingController _chave;
  late final TextEditingController _titulo;
  late final TextEditingController _url;
  late final TextEditingController _ordem;
  bool _ativo = true;
  bool _saving = false;
  String? _error;
  List<int>? _bytes;
  String? _filename;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _chave = TextEditingController(text: existing?.chave ?? 'hero');
    _titulo = TextEditingController(text: existing?.titulo ?? '');
    _url = TextEditingController(text: existing?.urlExterna ?? '');
    _ordem = TextEditingController(text: '${existing?.ordem ?? 0}');
    _ativo = existing?.ativo ?? true;
  }

  @override
  void dispose() {
    _chave.dispose();
    _titulo.dispose();
    _url.dispose();
    _ordem.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (selected == null) return;
    final bytes = await selected.readAsBytes();
    setState(() {
      _bytes = bytes;
      _filename = selected.name;
    });
  }

  Future<void> _save() async {
    final chave = _chave.text.trim();
    if (chave.isEmpty) {
      setState(() => _error = 'Chave obrigatória (ex.: hero, categoria_sofa)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        chave: chave,
        titulo: _titulo.text.trim(),
        urlExterna: _url.text.trim(),
        ordem: int.tryParse(_ordem.text) ?? 0,
        ativo: _ativo,
        fileBytes: _bytes,
        filename: _filename,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nova mídia global' : 'Editar mídia'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Só mídia global (hero, categoria, oferta). '
                'Fotos de serviço: Serviços → Editar → Fotos na Vitrine.',
                style: TextStyle(fontSize: 12, color: ClxBrand.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _chave,
                decoration: const InputDecoration(
                  labelText: 'Chave',
                  hintText: 'hero, categoria_sofa…',
                  helperText: 'Usada pelo site para localizar a imagem',
                ),
              ),
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título interno'),
              ),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'URL externa (opcional)',
                ),
              ),
              TextField(
                controller: _ordem,
                decoration: const InputDecoration(labelText: 'Ordem'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.upload),
                      label: Text(
                        _filename ?? 'Escolher foto',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_bytes != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${(_bytes!.length / 1024).toStringAsFixed(0)} KB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ClxBrand.muted,
                      ),
                    ),
                  ],
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo na vitrine'),
                value: _ativo,
                onChanged: (value) => setState(() => _ativo = value),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '…' : 'Salvar'),
        ),
      ],
    );
  }
}
