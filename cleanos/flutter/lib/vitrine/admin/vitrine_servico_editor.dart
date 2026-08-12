import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';
import 'vitrine_midia_repository.dart';

class VitrineServicoEditorDialog extends StatefulWidget {
  const VitrineServicoEditorDialog({
    required this.servico,
    required this.midiaRepo,
    required this.onSave,
    super.key,
  });

  final VitrineAdminServico servico;
  final VitrineMidiaRepository midiaRepo;
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

  List<VitrineMidiaItem> _fotos = const [];
  bool _fotosLoading = true;
  String? _fotosError;
  bool _fotosBusy = false;

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
    _loadFotos();
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

  Future<void> _loadFotos() async {
    setState(() {
      _fotosLoading = true;
      _fotosError = null;
    });
    try {
      final list = await widget.midiaRepo.listByServico(widget.servico.id);
      if (!mounted) return;
      setState(() {
        _fotos = list;
        _fotosLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fotosLoading = false;
        _fotosError = 'Não foi possível carregar as fotos: $e';
      });
    }
  }

  String get _pairId => 'servico_${widget.servico.id}';

  Future<void> _setPapel(VitrineMidiaItem item, String papel) async {
    if (_fotosBusy) return;
    setState(() {
      _fotosBusy = true;
      _fotosError = null;
    });
    try {
      // Uma capa / um antes / um depois por serviço.
      if (papel == 'capa' || papel == 'antes' || papel == 'depois') {
        for (final other in _fotos) {
          if (other.id == item.id) continue;
          if (other.papel == papel) {
            await widget.midiaRepo.update(
              other.id,
              papel: 'galeria',
              parId: '',
            );
          }
        }
      }

      final parId = (papel == 'antes' || papel == 'depois') ? _pairId : '';
      await widget.midiaRepo.update(
        item.id,
        papel: papel,
        parId: parId,
        ordem: papel == 'capa' ? 0 : item.ordem,
      );

      // Alinha o par do “outro lado” se já existir.
      if (papel == 'antes' || papel == 'depois') {
        final otherRole = papel == 'antes' ? 'depois' : 'antes';
        for (final other in _fotos) {
          if (other.id == item.id) continue;
          if (other.papel == otherRole) {
            await widget.midiaRepo.update(other.id, parId: _pairId);
          }
        }
      }

      await _loadFotos();
    } catch (e) {
      if (!mounted) return;
      setState(() => _fotosError = 'Falha ao definir papel da foto: $e');
    } finally {
      if (mounted) setState(() => _fotosBusy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_layout == VitrineServicoLayout.antesDepois) {
        final hasAntes = _fotos.any((f) => f.papel == 'antes');
        final hasDepois = _fotos.any((f) => f.papel == 'depois');
        if (_fotos.isNotEmpty && (!hasAntes || !hasDepois)) {
          setState(() {
            _saving = false;
            _error =
                'No formato Antes e depois, marque uma foto como Antes e '
                'outra como Depois (ou cadastre fotos no serviço).';
          });
          return;
        }
      }
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

  VitrineMidiaItem? get _capa {
    for (final f in _fotos) {
      if (f.papel == 'capa') return f;
    }
    return _fotos.isEmpty ? null : _fotos.first;
  }

  VitrineMidiaItem? get _antes {
    for (final f in _fotos) {
      if (f.papel == 'antes') return f;
    }
    return null;
  }

  VitrineMidiaItem? get _depois {
    for (final f in _fotos) {
      if (f.papel == 'depois') return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
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
                      fotos: _fotos,
                      fotosLoading: _fotosLoading,
                      fotosError: _fotosError,
                      fotosBusy: _fotosBusy,
                      onChanged: () => setState(() {}),
                      onLayout: (value) => setState(() => _layout = value),
                      onPreco: (value) => setState(() => _precoModo = value),
                      onVitrine: (value) => setState(() => _vitrine = value),
                      onDestaque: (value) => setState(() => _destaque = value),
                      onSetPapel: _setPapel,
                      onReloadFotos: _loadFotos,
                    );
                    final preview = _ServicoPreview(
                      servico: widget.servico,
                      titulo: _titulo.text,
                      descricao: _descricao.text,
                      badge: _badge.text,
                      cta: _cta.text,
                      layout: _layout,
                      precoModo: _precoModo,
                      capa: _capa,
                      antes: _antes,
                      depois: _depois,
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
    required this.fotos,
    required this.fotosLoading,
    required this.fotosBusy,
    required this.onSetPapel,
    required this.onReloadFotos,
    this.fotosError,
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
  final List<VitrineMidiaItem> fotos;
  final bool fotosLoading;
  final bool fotosBusy;
  final String? fotosError;
  final Future<void> Function(VitrineMidiaItem item, String papel) onSetPapel;
  final VoidCallback onReloadFotos;
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
        const SizedBox(height: 8),
        _FotosDoServicoSection(
          layout: layout,
          fotos: fotos,
          loading: fotosLoading,
          busy: fotosBusy,
          error: fotosError,
          onSetPapel: onSetPapel,
          onReload: onReloadFotos,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ),
      ],
    );
  }
}

class _FotosDoServicoSection extends StatelessWidget {
  const _FotosDoServicoSection({
    required this.layout,
    required this.fotos,
    required this.loading,
    required this.busy,
    required this.onSetPapel,
    required this.onReload,
    this.error,
  });

  final VitrineServicoLayout layout;
  final List<VitrineMidiaItem> fotos;
  final bool loading;
  final bool busy;
  final String? error;
  final Future<void> Function(VitrineMidiaItem item, String papel) onSetPapel;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final needsPair = layout == VitrineServicoLayout.antesDepois;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Fotos do serviço',
                style: TextStyle(
                  color: ClxBrand.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar fotos',
              onPressed: busy ? null : onReload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          needsPair
              ? 'Escolha qual foto é Antes e qual é Depois. '
                  'Upload de novas fotos: Serviços → Editar → Fotos na Vitrine.'
              : 'Defina a capa e o papel de cada foto. '
                  'Upload: Serviços → Editar → Fotos na Vitrine.',
          style: const TextStyle(fontSize: 12, color: ClxBrand.muted),
        ),
        const SizedBox(height: 10),
        if (error != null) ...[
          Text(error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          const SizedBox(height: 8),
        ],
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (fotos.isEmpty)
          Container(
            key: const Key('vitrine-servico-fotos-empty'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDCE5EC)),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF8FAFC),
            ),
            child: const Text(
              'Nenhuma foto neste serviço ainda. '
              'Abra Serviços → Editar → Fotos na Vitrine e envie as imagens.',
              style: TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final foto in fotos)
                _FotoPapelCard(
                  foto: foto,
                  busy: busy,
                  highlightAntesDepois: needsPair,
                  onPapel: (papel) => onSetPapel(foto, papel),
                ),
            ],
          ),
      ],
    );
  }
}

class _FotoPapelCard extends StatelessWidget {
  const _FotoPapelCard({
    required this.foto,
    required this.busy,
    required this.onPapel,
    this.highlightAntesDepois = false,
  });

  final VitrineMidiaItem foto;
  final bool busy;
  final bool highlightAntesDepois;
  final ValueChanged<String> onPapel;

  @override
  Widget build(BuildContext context) {
    final url = foto.displayUrl;
    final papel = foto.papel.isEmpty ? 'galeria' : foto.papel;
    return SizedBox(
      width: 168,
      child: Container(
        key: Key('vitrine-servico-foto-${foto.id}'),
        decoration: BoxDecoration(
          border: Border.all(
            color: papel == 'capa' || papel == 'antes' || papel == 'depois'
                ? ClxBrand.cyan
                : const Color(0xFFDCE5EC),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: url == null || url.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFE8F4F6),
                      child: Icon(Icons.image_outlined, color: ClxBrand.cyan),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE2E8F0),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: DropdownButtonFormField<String>(
                key: Key('vitrine-servico-foto-papel-${foto.id}'),
                initialValue: papel,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Papel',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: 'capa', child: Text('Capa')),
                  const DropdownMenuItem(
                    value: 'galeria',
                    child: Text('Galeria'),
                  ),
                  DropdownMenuItem(
                    value: 'antes',
                    child: Text(
                      highlightAntesDepois ? 'Antes ★' : 'Antes',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'depois',
                    child: Text(
                      highlightAntesDepois ? 'Depois ★' : 'Depois',
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) onPapel(value);
                      },
              ),
            ),
          ],
        ),
      ),
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
    this.capa,
    this.antes,
    this.depois,
  });

  final VitrineAdminServico servico;
  final String titulo;
  final String descricao;
  final String badge;
  final String cta;
  final VitrineServicoLayout layout;
  final VitrinePrecoModo precoModo;
  final VitrineMidiaItem? capa;
  final VitrineMidiaItem? antes;
  final VitrineMidiaItem? depois;

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
                                  Expanded(
                                    child: _photoOrLabel(
                                      antes?.displayUrl,
                                      'ANTES',
                                    ),
                                  ),
                                  Expanded(
                                    child: _photoOrLabel(
                                      depois?.displayUrl,
                                      'DEPOIS',
                                    ),
                                  ),
                                ],
                              )
                            : _photoOrLabel(
                                capa?.displayUrl,
                                'FOTO DO SERVIÇO',
                              ),
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
        ClipOval(
          child: SizedBox(
            width: 40,
            height: 40,
            child: capa?.displayUrl != null && capa!.displayUrl!.isNotEmpty
                ? Image.network(capa!.displayUrl!, fit: BoxFit.cover)
                : const ColoredBox(
                    color: Color(0xFFE8F4F6),
                    child: Icon(Icons.auto_awesome, color: ClxBrand.cyan),
                  ),
          ),
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

  Widget _photoOrLabel(String? url, String label) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _imagePlaceholder(label),
      );
    }
    return _imagePlaceholder(label);
  }

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
