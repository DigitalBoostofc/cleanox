import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/tokens.dart';
import '../vitrine_api.dart';
import 'vitrine_midia_repository.dart';

class VitrineMidiaEditorDialog extends StatefulWidget {
  const VitrineMidiaEditorDialog({
    required this.existing,
    required this.servicos,
    required this.onSave,
    super.key,
  });

  final VitrineMidiaItem? existing;
  final List<VitrineAdminServico> servicos;
  final Future<void> Function({
    required String chave,
    required String titulo,
    required String urlExterna,
    required int ordem,
    required bool ativo,
    required String servicoId,
    required String papel,
    required String parId,
    required String legenda,
    required double focoX,
    required double focoY,
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
  late final TextEditingController _parId;
  late final TextEditingController _legenda;
  late String _servicoId;
  late String _papel;
  late double _focoX;
  late double _focoY;
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
    _parId = TextEditingController(text: existing?.parId ?? '');
    _legenda = TextEditingController(text: existing?.legenda ?? '');
    _servicoId = existing?.servicoId ?? '';
    _papel = _servicoId.isEmpty
        ? ''
        : (existing?.papel.isNotEmpty == true ? existing!.papel : 'capa');
    _focoX = existing?.focoX ?? 50;
    _focoY = existing?.focoY ?? 50;
    _ativo = existing?.ativo ?? true;
  }

  @override
  void dispose() {
    _chave.dispose();
    _titulo.dispose();
    _url.dispose();
    _ordem.dispose();
    _parId.dispose();
    _legenda.dispose();
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
    final chave = _servicoId.isEmpty
        ? _chave.text.trim()
        : 'servico_${_servicoId}_${_papel.isEmpty ? 'galeria' : _papel}';
    if (chave.isEmpty) {
      setState(() => _error = 'Chave obrigatória para mídia global');
      return;
    }
    if ((_papel == 'antes' || _papel == 'depois') &&
        _parId.text.trim().isEmpty) {
      setState(() => _error = 'Informe o identificador do par antes/depois');
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
        servicoId: _servicoId,
        papel: _servicoId.isEmpty ? '' : _papel,
        parId: _parId.text.trim(),
        legenda: _legenda.text.trim(),
        focoX: _focoX,
        focoY: _focoY,
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
      title: Text(widget.existing == null ? 'Nova mídia' : 'Editar mídia'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _servicoId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Uso da foto',
                  helperText: 'Vincule a um serviço ou use como mídia global',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Global: hero, categoria ou oferta'),
                  ),
                  for (final servico in widget.servicos)
                    DropdownMenuItem(
                      value: servico.id,
                      child: Text(
                        servico.nome,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _servicoId = value ?? '';
                  _papel = _servicoId.isEmpty
                      ? ''
                      : (_papel.isEmpty ? 'capa' : _papel);
                }),
              ),
              if (_servicoId.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('vitrine-midia-papel'),
                  initialValue: _papel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Papel visual'),
                  items: const [
                    DropdownMenuItem(
                      value: 'capa',
                      child: Text('Capa principal'),
                    ),
                    DropdownMenuItem(value: 'galeria', child: Text('Galeria')),
                    DropdownMenuItem(value: 'antes', child: Text('Antes')),
                    DropdownMenuItem(value: 'depois', child: Text('Depois')),
                  ],
                  onChanged: (value) =>
                      setState(() => _papel = value ?? 'galeria'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _chave,
                enabled: _servicoId.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Chave global',
                  hintText: 'hero, categoria_sofa…',
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
              if (_servicoId.isNotEmpty) ...[
                TextField(
                  key: const Key('vitrine-midia-legenda'),
                  controller: _legenda,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Legenda da foto',
                    hintText: 'Explique o resultado mostrado',
                  ),
                ),
                if (_papel == 'antes' || _papel == 'depois')
                  TextField(
                    key: const Key('vitrine-midia-par'),
                    controller: _parId,
                    decoration: const InputDecoration(
                      labelText: 'Identificador do par',
                      hintText: 'Ex.: sofa-sala-1',
                      helperText: 'Use o mesmo valor nas fotos Antes e Depois',
                    ),
                  ),
                const SizedBox(height: 8),
                _FocusSlider(
                  label: 'Foco horizontal',
                  value: _focoX,
                  onChanged: (value) => setState(() => _focoX = value),
                ),
                _FocusSlider(
                  label: 'Foco vertical',
                  value: _focoY,
                  onChanged: (value) => setState(() => _focoY = value),
                ),
              ],
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

class _FocusSlider extends StatelessWidget {
  const _FocusSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 112, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, 100),
            max: 100,
            divisions: 20,
            label: '${value.round()}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text('${value.round()}%')),
      ],
    );
  }
}
