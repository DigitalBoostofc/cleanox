import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';

class VitrineServicoEditorDialog extends StatefulWidget {
  const VitrineServicoEditorDialog({
    required this.servico,
    required this.onSave,
    super.key,
  });

  final VitrineAdminServico servico;
  final Future<void> Function(Map<String, dynamic> draft) onSave;

  @override
  State<VitrineServicoEditorDialog> createState() =>
      _VitrineServicoEditorDialogState();
}

class _VitrineServicoEditorDialogState
    extends State<VitrineServicoEditorDialog> {
  late final TextEditingController _titulo;
  late final TextEditingController _descricao;
  late final TextEditingController _badge;
  late final TextEditingController _cta;
  late final TextEditingController _ordem;
  late VitrineServicoLayout _layout;
  late VitrinePrecoModo _precoModo;
  late bool _vitrine;
  late bool _destaque;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final servico = widget.servico;
    _titulo = TextEditingController(text: servico.vitrineTitulo);
    _descricao = TextEditingController(text: servico.vitrineDescricao);
    _badge = TextEditingController(text: servico.vitrineBadge);
    _cta = TextEditingController(text: servico.vitrineCta);
    _ordem = TextEditingController(text: '${servico.vitrineOrdem}');
    _layout = servico.layout;
    _precoModo = servico.precoModo;
    _vitrine = servico.vitrine;
    _destaque = servico.vitrineDestaque;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _badge.dispose();
    _cta.dispose();
    _ordem.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'vitrine': _vitrine,
        'vitrine_destaque': _destaque,
        'vitrine_layout': _layout.apiValue,
        'vitrine_titulo': _titulo.text.trim(),
        'vitrine_descricao': _descricao.text.trim(),
        'vitrine_badge': _badge.text.trim(),
        'vitrine_cta': _cta.text.trim(),
        'vitrine_preco_modo': _precoModo.apiValue,
        'vitrine_ordem': int.tryParse(_ordem.text) ?? 0,
      });
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
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Personalizar serviço',
                      style: TextStyle(
                        color: ClxBrand.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                widget.servico.nome,
                style: const TextStyle(color: ClxBrand.muted),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final editor = _EditorFields(
                      titulo: _titulo,
                      descricao: _descricao,
                      badge: _badge,
                      cta: _cta,
                      ordem: _ordem,
                      layout: _layout,
                      precoModo: _precoModo,
                      vitrine: _vitrine,
                      destaque: _destaque,
                      error: _error,
                      onChanged: () => setState(() {}),
                      onLayout: (value) => setState(() => _layout = value),
                      onPreco: (value) => setState(() => _precoModo = value),
                      onVitrine: (value) => setState(() => _vitrine = value),
                      onDestaque: (value) => setState(() => _destaque = value),
                    );
                    final preview = _ServicoPreview(
                      servico: widget.servico,
                      titulo: _titulo.text,
                      descricao: _descricao.text,
                      badge: _badge.text,
                      cta: _cta.text,
                      layout: _layout,
                      precoModo: _precoModo,
                    );
                    if (constraints.maxWidth < 760) {
                      return ListView(
                        children: [editor, const SizedBox(height: 18), preview],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SingleChildScrollView(child: editor)),
                        const SizedBox(width: 24),
                        SizedBox(width: 330, child: preview),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  );
                  final save = FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Salvar personalização'),
                  );
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [save, cancel],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [cancel, const SizedBox(width: 8), save],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorFields extends StatelessWidget {
  const _EditorFields({
    required this.titulo,
    required this.descricao,
    required this.badge,
    required this.cta,
    required this.ordem,
    required this.layout,
    required this.precoModo,
    required this.vitrine,
    required this.destaque,
    required this.onChanged,
    required this.onLayout,
    required this.onPreco,
    required this.onVitrine,
    required this.onDestaque,
    this.error,
  });

  final TextEditingController titulo;
  final TextEditingController descricao;
  final TextEditingController badge;
  final TextEditingController cta;
  final TextEditingController ordem;
  final VitrineServicoLayout layout;
  final VitrinePrecoModo precoModo;
  final bool vitrine;
  final bool destaque;
  final VoidCallback onChanged;
  final ValueChanged<VitrineServicoLayout> onLayout;
  final ValueChanged<VitrinePrecoModo> onPreco;
  final ValueChanged<bool> onVitrine;
  final ValueChanged<bool> onDestaque;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Como este serviço aparece',
          style: TextStyle(color: ClxBrand.navy, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<VitrineServicoLayout>(
          initialValue: layout,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Formato visual'),
          items: [
            for (final value in VitrineServicoLayout.values)
              DropdownMenuItem(value: value, child: Text(_layoutLabel(value))),
          ],
          onChanged: (value) {
            if (value != null) onLayout(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<VitrinePrecoModo>(
          initialValue: precoModo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Preço na vitrine'),
          items: [
            for (final value in VitrinePrecoModo.values)
              DropdownMenuItem(value: value, child: Text(_precoLabel(value))),
          ],
          onChanged: (value) {
            if (value != null) onPreco(value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('vitrine-servico-titulo'),
          controller: titulo,
          onChanged: (_) => onChanged(),
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'Título comercial',
            hintText: 'Vazio usa o nome do serviço',
          ),
        ),
        TextField(
          key: const Key('vitrine-servico-descricao'),
          controller: descricao,
          onChanged: (_) => onChanged(),
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descrição comercial',
            hintText: 'Benefício e resultado para o cliente',
          ),
        ),
        TextField(
          key: const Key('vitrine-servico-badge'),
          controller: badge,
          onChanged: (_) => onChanged(),
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Badge',
            hintText: 'Mais escolhido, Premium…',
          ),
        ),
        TextField(
          key: const Key('vitrine-servico-cta'),
          controller: cta,
          onChanged: (_) => onChanged(),
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Texto do botão',
            hintText: 'Adicionar',
          ),
        ),
        TextField(
          key: const Key('vitrine-servico-ordem'),
          controller: ordem,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ordem de exibição',
            helperText: 'Números menores aparecem primeiro',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Exibir na Vitrine'),
          value: vitrine,
          onChanged: onVitrine,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Destaque na home'),
          value: destaque,
          onChanged: onDestaque,
        ),
        if (error != null)
          Text(error!, style: TextStyle(color: Colors.red.shade700)),
      ],
    );
  }
}

class _ServicoPreview extends StatelessWidget {
  const _ServicoPreview({
    required this.servico,
    required this.titulo,
    required this.descricao,
    required this.badge,
    required this.cta,
    required this.layout,
    required this.precoModo,
  });

  final VitrineAdminServico servico;
  final String titulo;
  final String descricao;
  final String badge;
  final String cta;
  final VitrineServicoLayout layout;
  final VitrinePrecoModo precoModo;

  @override
  Widget build(BuildContext context) {
    final displayTitle = titulo.trim().isEmpty ? servico.nome : titulo.trim();
    final displayDescription = descricao.trim().isEmpty
        ? 'Descrição do resultado e dos diferenciais do serviço.'
        : descricao.trim();
    final compact = layout == VitrineServicoLayout.compacto;
    final imageHeight = layout == VitrineServicoLayout.destaque ? 190.0 : 130.0;
    return Container(
      key: const Key('vitrine-servico-preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PREVIEW',
            style: TextStyle(
              color: ClxBrand.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x120B1D34), blurRadius: 18),
              ],
            ),
            child: compact
                ? _compact(displayTitle)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: imageHeight,
                        child: layout == VitrineServicoLayout.antesDepois
                            ? Row(
                                children: [
                                  Expanded(child: _imagePlaceholder('ANTES')),
                                  Expanded(child: _imagePlaceholder('DEPOIS')),
                                ],
                              )
                            : _imagePlaceholder('FOTO DO SERVIÇO'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _content(displayTitle, displayDescription),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _compact(String title) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFE8F4F6),
          child: Icon(Icons.auto_awesome, color: ClxBrand.cyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: ClxBrand.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.add_circle, color: ClxBrand.cyan),
      ],
    ),
  );

  Widget _imagePlaceholder(String label) => Container(
    color: ClxBrand.navy,
    alignment: Alignment.center,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _content(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (badge.trim().isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge.trim(),
            style: const TextStyle(
              color: ClxBrand.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      Text(
        title,
        style: const TextStyle(
          color: ClxBrand.navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: ClxBrand.muted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              _priceText(precoModo, servico.valorBase),
              style: const TextStyle(
                color: ClxBrand.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {},
            child: Text(cta.trim().isEmpty ? 'Adicionar' : cta.trim()),
          ),
        ],
      ),
    ],
  );
}

String _layoutLabel(VitrineServicoLayout value) => switch (value) {
  VitrineServicoLayout.destaque => 'Destaque amplo',
  VitrineServicoLayout.fotografico => 'Card fotográfico',
  VitrineServicoLayout.antesDepois => 'Antes e depois',
  VitrineServicoLayout.compacto => 'Compacto',
};

String _precoLabel(VitrinePrecoModo value) => switch (value) {
  VitrinePrecoModo.valor => 'Mostrar valor',
  VitrinePrecoModo.aPartirDe => 'Mostrar “a partir de”',
  VitrinePrecoModo.sobAvaliacao => 'Sob avaliação',
  VitrinePrecoModo.ocultar => 'Ocultar preço',
};

String _priceText(VitrinePrecoModo mode, double value) => switch (mode) {
  VitrinePrecoModo.valor => formatCurrency(value),
  VitrinePrecoModo.aPartirDe => 'A partir de ${formatCurrency(value)}',
  VitrinePrecoModo.sobAvaliacao => 'Sob avaliação',
  VitrinePrecoModo.ocultar => '',
};
