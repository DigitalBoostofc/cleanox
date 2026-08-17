import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../widgets/vitrine_oferta_estilo.dart';
import 'vitrine_midia_repository.dart';

Future<VitrineMidiaItem?> showVitrineOfertaFocoEditor(
  BuildContext context, {
  required VitrineMidiaRepository repo,
  required VitrineMidiaItem midia,
  required String titulo,
  String preco = '',
  String? precoDe,
  int? offPct,
  String badge = '',
}) {
  return showModalBottomSheet<VitrineMidiaItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _FocoEditor(
        repo: repo,
        midia: midia,
        titulo: titulo,
        preco: preco,
        precoDe: precoDe,
        offPct: offPct,
        badge: badge,
      ),
    ),
  );
}

class _FocoEditor extends StatefulWidget {
  const _FocoEditor({
    required this.repo,
    required this.midia,
    required this.titulo,
    required this.preco,
    this.precoDe,
    this.offPct,
    this.badge = '',
  });

  final VitrineMidiaRepository repo;
  final VitrineMidiaItem midia;
  final String titulo;
  final String preco;
  final String? precoDe;
  final int? offPct;
  final String badge;

  @override
  State<_FocoEditor> createState() => _FocoEditorState();
}

class _FocoEditorState extends State<_FocoEditor> {
  late VitrineOfertaEstilo _e;
  late final TextEditingController _titulo;
  late final TextEditingController _de;
  late final TextEditingController _por;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _e = VitrineOfertaEstilo.parse(
      '${widget.midia.focoX}',
      '${widget.midia.focoY}',
      widget.midia.legenda,
    );
    _titulo = TextEditingController(
      text: _e.titulo.trim().isEmpty ? widget.titulo : _e.titulo,
    );
    _de = TextEditingController(
      text: _e.deValor > 0 ? _reais(_e.deValor) : _soNumero(widget.precoDe),
    );
    _por = TextEditingController(
      text: _e.porValor > 0 ? _reais(_e.porValor) : _soNumero(widget.preco),
    );
  }

  @override
  void dispose() {
    _titulo.dispose();
    _de.dispose();
    _por.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final estilo = _e.copyWith(
      titulo: _titulo.text.trim(),
      deValor: _parseReais(_de.text),
      porValor: _parseReais(_por.text),
    );
    try {
      final saved = await widget.repo.update(
        widget.midia.id,
        focoX: estilo.x,
        focoY: estilo.y,
        legenda: estilo.writeInto(widget.midia.legenda),
      );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.midia.displayUrl ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Editar card',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ClxBrand.navy,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving ? null : _salvar,
                child: Text(_saving ? 'Salvando…' : 'Salvar'),
              ),
            ],
          ),
          const Text(
            'Arraste a foto depois do zoom. Troque o bloco azul e os textos.',
            style: TextStyle(fontSize: 12, color: ClxBrand.muted),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VitrineOfertaCardVisual(
              estilo: _previewEstilo,
              fotoUrl: url,
              titulo: widget.titulo,
              preco: _previewEstilo.precoPorLabel(widget.preco),
              precoDe: _previewEstilo.precoDeLabel(widget.precoDe),
              offPct: _previewEstilo.offPctLabel(widget.offPct),
              badge: widget.badge,
              onPanPhoto: (delta, box) {
                setState(() {
                  _e = _e.copyWith(
                    x: (_e.x - delta.dx * 100 / box.width / _e.zoom)
                        .clamp(0, 100),
                    y: (_e.y - delta.dy * 100 / box.height / _e.zoom)
                        .clamp(0, 100),
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Onde fica o azul',
            style: TextStyle(fontWeight: FontWeight.w800, color: ClxBrand.navy),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Foto à direita', VitrineOfertaLayout.right),
              _chip('Foto à esquerda', VitrineOfertaLayout.left),
              _chip('Faixa embaixo', VitrineOfertaLayout.bottom),
              _chip('Foto inteira', VitrineOfertaLayout.overlay),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Estilo do azul',
            style: TextStyle(fontWeight: FontWeight.w800, color: ClxBrand.navy),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _navy('Sólido', VitrineOfertaNavy.solid),
              _navy('Degradê', VitrineOfertaNavy.fade),
              _navy('Vidro', VitrineOfertaNavy.glass),
            ],
          ),
          if (_e.layout == VitrineOfertaLayout.left ||
              _e.layout == VitrineOfertaLayout.right)
            _slider(
              'Tamanho da foto',
              _e.split,
              0.34,
              0.66,
              (v) => setState(() => _e = _e.copyWith(split: v)),
            ),
          _slider(
            'Zoom',
            _e.zoom,
            0.8,
            2.6,
            (v) => setState(() => _e = _e.copyWith(zoom: v)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titulo,
            decoration: const InputDecoration(labelText: 'Título no card'),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar título'),
            value: _e.showTitle,
            onChanged: (v) => setState(() => _e = _e.copyWith(showTitle: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar preço'),
            value: _e.showPrice,
            onChanged: (v) => setState(() => _e = _e.copyWith(showPrice: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar De / por'),
            subtitle: const Text(r'De R$ riscado e valor da promoção'),
            value: _e.showDePor,
            onChanged: (v) => setState(() => _e = _e.copyWith(showDePor: v)),
          ),
          if (_e.showDePor) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _de,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: r'De R$',
                      hintText: '299,90',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _por,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: r'Por R$',
                      hintText: '199,90',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar tag'),
            value: _e.showBadge,
            onChanged: (v) => setState(() => _e = _e.copyWith(showBadge: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar Ver detalhes'),
            value: _e.showDetalhe,
            onChanged: (v) => setState(() => _e = _e.copyWith(showDetalhe: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar Adicionar'),
            value: _e.showAdd,
            onChanged: (v) => setState(() => _e = _e.copyWith(showAdd: v)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _e = const VitrineOfertaEstilo();
                _titulo.text = widget.titulo;
              }),
              child: const Text('Resetar'),
            ),
          ),
        ],
      ),
    );
  }

  VitrineOfertaEstilo get _previewEstilo => _e.copyWith(
        titulo: _titulo.text,
        deValor: _parseReais(_de.text),
        porValor: _parseReais(_por.text),
      );

  String _reais(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  String _soNumero(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return raw.replaceAll(RegExp(r'[R$\s]'), '').trim();
  }

  double _parseReais(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[R$\s]'), '');
    if (s.contains(',')) s = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  Widget _chip(String label, VitrineOfertaLayout layout) {
    final on = _e.layout == layout;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => _e = _e.copyWith(layout: layout)),
    );
  }

  Widget _navy(String label, VitrineOfertaNavy navy) {
    final on = _e.navy == navy;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => _e = _e.copyWith(navy: navy)),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ClxBrand.navy,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
