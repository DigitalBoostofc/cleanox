/// pontos_fisicos_editor.dart — CRUD de pontos físicos (endereços da empresa).
///
/// Aberto a partir da toolbar de Clientes (ao lado de Área de atuação).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ponto_fisico.dart';
import '../data/painel_providers.dart';

Future<bool?> showPontosFisicosEditor(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: const _PontosFisicosEditor(),
      ),
    ),
  );
}

class _PontosFisicosEditor extends ConsumerStatefulWidget {
  const _PontosFisicosEditor();

  @override
  ConsumerState<_PontosFisicosEditor> createState() =>
      _PontosFisicosEditorState();
}

class _PontosFisicosEditorState extends ConsumerState<_PontosFisicosEditor> {
  List<PontoFisico> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(pontosFisicosRepositoryProvider).list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openForm([PontoFisico? existing]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PontoFormDialog(existing: existing),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _delete(PontoFisico p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir ponto físico?'),
        content: Text(p.nome),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(pontosFisicosRepositoryProvider).delete(p.id);
      if (mounted) await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pontos físicos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ClxBrand.navy,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Endereços da empresa (loja, galpão…). Na OS, escolha '
            '“Ponto físico” para usar esse endereço em vez do do cliente.',
            style: TextStyle(color: ClxBrand.muted, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Novo ponto'),
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  TextButton(onPressed: _reload, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (_items.isEmpty)
                  Card(
                    color: clx.bg2,
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum ponto cadastrado. Ex.: “Galpão Centro”.',
                      ),
                    ),
                  ),
                for (final p in _items)
                  Card(
                    child: ListTile(
                      title: Text(
                        p.nome,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${p.enderecoResumo}${p.ativo ? '' : ' · INATIVO'}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openForm(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(p),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PontoFormDialog extends ConsumerStatefulWidget {
  const _PontoFormDialog({this.existing});
  final PontoFisico? existing;

  @override
  ConsumerState<_PontoFormDialog> createState() => _PontoFormDialogState();
}

class _PontoFormDialogState extends ConsumerState<_PontoFormDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _cep;
  late final TextEditingController _rua;
  late final TextEditingController _numero;
  late final TextEditingController _comp;
  late final TextEditingController _bairro;
  late final TextEditingController _cidade;
  late final TextEditingController _estado;
  late final TextEditingController _obs;
  bool _ativo = true;
  bool _saving = false;
  bool _cepLoading = false;
  String? _error;
  String? _cepWarning;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nome = TextEditingController(text: e?.nome ?? '');
    _cep = TextEditingController(
      text: e == null || e.enderecoCep.isEmpty ? '' : maskCEP(e.enderecoCep),
    );
    _rua = TextEditingController(text: e?.enderecoRua ?? '');
    _numero = TextEditingController(text: e?.enderecoNumero ?? '');
    _comp = TextEditingController(text: e?.enderecoComplemento ?? '');
    _bairro = TextEditingController(text: e?.enderecoBairro ?? '');
    _cidade = TextEditingController(text: e?.enderecoCidade ?? '');
    _estado = TextEditingController(text: e?.enderecoEstado ?? '');
    _obs = TextEditingController(text: e?.observacoes ?? '');
    _ativo = e?.ativo ?? true;
  }

  @override
  void dispose() {
    _nome.dispose();
    _cep.dispose();
    _rua.dispose();
    _numero.dispose();
    _comp.dispose();
    _bairro.dispose();
    _cidade.dispose();
    _estado.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _handleCep(String raw) async {
    final masked = maskCEP(raw);
    if (masked != _cep.text) {
      _cep.value = TextEditingValue(
        text: masked,
        selection: TextSelection.collapsed(offset: masked.length),
      );
    }
    if (_cepWarning != null) setState(() => _cepWarning = null);
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    setState(() => _cepLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://viacep.com.br/ws/$digits/json/'),
      );
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['erro'] == true) {
        setState(() => _cepWarning = 'CEP não encontrado.');
        return;
      }
      setState(() {
        _rua.text = (data['logradouro'] as String?) ?? _rua.text;
        _bairro.text = (data['bairro'] as String?) ?? _bairro.text;
        _cidade.text = (data['localidade'] as String?) ?? _cidade.text;
        _estado.text = ((data['uf'] as String?) ?? _estado.text).toUpperCase();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _cepWarning = 'Não foi possível consultar o CEP.');
      }
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  Future<void> _save() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do ponto');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'nome': _nome.text.trim(),
      'endereco_cep': _cep.text.replaceAll(RegExp(r'\D'), ''),
      'endereco_rua': _rua.text.trim(),
      'endereco_numero': _numero.text.trim(),
      'endereco_complemento': _comp.text.trim(),
      'endereco_bairro': _bairro.text.trim(),
      'endereco_cidade': _cidade.text.trim(),
      'endereco_estado': _estado.text.trim().toUpperCase(),
      'ativo': _ativo,
      'observacoes': _obs.text.trim(),
    };
    try {
      final repo = ref.read(pontosFisicosRepositoryProvider);
      if (widget.existing == null) {
        await repo.create(body);
      } else {
        await repo.update(widget.existing!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
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
    return AlertDialog(
      title: Text(widget.existing == null ? 'Novo ponto físico' : 'Editar ponto'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nome,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Galpão Centro, Loja…',
                ),
              ),
              TextField(
                controller: _cep,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'CEP',
                  helperText: _cepLoading
                      ? 'Buscando…'
                      : (_cepWarning ?? 'Preenche rua/bairro/cidade'),
                  helperStyle: TextStyle(
                    color: _cepWarning != null
                        ? Colors.orange.shade800
                        : null,
                  ),
                ),
                onChanged: _handleCep,
              ),
              TextField(
                controller: _rua,
                decoration: const InputDecoration(labelText: 'Rua'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numero,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _comp,
                      decoration: const InputDecoration(
                        labelText: 'Complemento',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _bairro,
                decoration: const InputDecoration(labelText: 'Bairro'),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _cidade,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _estado,
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'UF',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _obs,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
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
