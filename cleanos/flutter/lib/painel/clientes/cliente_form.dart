/// cliente_form.dart — Formulário de criar/editar Cliente (🔒 COFRE).
///
/// Espelha o modal de `Clientes.tsx`: nome único (split em nome+sobrenome no save),
/// telefone/CEP com máscara, endereço, toggle ativo e observações, com validação.
/// Mostrado via [showClienteForm] — Dialog centrado no desktop (padrão do Painel,
/// Flutter Web) com largura limitada; corpo rolável + rodapé fixo de ações.
///
/// Consome `clientesRepositoryProvider` (interface do core). Retorna `true` quando
/// salvou (o caller recarrega a lista).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/cliente.dart';
import '../data/painel_providers.dart';

/// Abre o formulário de cliente. [editing] nulo = criar. Resolve `true` se salvou.
Future<bool?> showClienteForm(BuildContext context, {Cliente? editing}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: ClienteForm(editing: editing),
      ),
    ),
  );
}

class ClienteForm extends ConsumerStatefulWidget {
  const ClienteForm({super.key, this.editing});

  final Cliente? editing;

  @override
  ConsumerState<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends ConsumerState<ClienteForm> {
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  late final TextEditingController _cep;
  late final TextEditingController _rua;
  late final TextEditingController _complemento;
  late final TextEditingController _bairro;
  late final TextEditingController _cidade;
  late final TextEditingController _estado;
  late final TextEditingController _observacoes;

  bool _ativo = true;
  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    _nome = TextEditingController(
      text: c == null
          ? ''
          : [c.nome, c.sobrenome].where((s) => (s ?? '').isNotEmpty).join(' '),
    );
    _telefone = TextEditingController(
      text: c == null ? '' : maskPhoneBR(c.telefone),
    );
    _email = TextEditingController(text: c?.email ?? '');
    _cep = TextEditingController(
      text: c == null ? '' : maskCEP(c.enderecoCep ?? ''),
    );
    _rua = TextEditingController(text: c?.enderecoRua ?? '');
    _complemento = TextEditingController(text: c?.enderecoComplemento ?? '');
    _bairro = TextEditingController(text: c?.enderecoBairro ?? '');
    _cidade = TextEditingController(text: c?.enderecoCidade ?? '');
    _estado = TextEditingController(text: c?.enderecoEstado ?? '');
    _observacoes = TextEditingController(text: c?.observacoes ?? '');
    _ativo = c?.ativo ?? true;
  }

  @override
  void dispose() {
    for (final ctrl in [
      _nome,
      _telefone,
      _email,
      _cep,
      _rua,
      _complemento,
      _bairro,
      _cidade,
      _estado,
      _observacoes,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Map<String, String> _validate() {
    final errs = <String, String>{};
    if (_nome.text.trim().isEmpty) errs['nome'] = 'Nome é obrigatório';
    final tel = onlyDigitsPhone(_telefone.text);
    if (tel.length < 10) {
      errs['telefone'] = tel.isEmpty
          ? 'Telefone é obrigatório'
          : 'Telefone incompleto — informe DDD + número';
    }
    if (_bairro.text.trim().isEmpty) errs['bairro'] = 'Bairro é obrigatório';
    final email = _email.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      errs['email'] = 'E-mail inválido';
    }
    return errs;
  }

  Future<void> _save() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() {
        _errs
          ..clear()
          ..addAll(errs);
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _errs.clear();
    });
    final parts = splitNome(_nome.text);
    final payload = <String, dynamic>{
      'nome': parts.nome,
      'sobrenome': parts.sobrenome,
      'telefone': _telefone.text.trim(),
      'email': _email.text.trim(),
      'endereco_rua': _rua.text.trim(),
      'endereco_numero': '',
      'endereco_complemento': _complemento.text.trim(),
      'endereco_bairro': _bairro.text.trim(),
      'endereco_cidade': _cidade.text.trim(),
      'endereco_estado': _estado.text.trim(),
      'endereco_cep': _cep.text.trim(),
      'ativo': _ativo,
      'observacoes': _observacoes.text.trim(),
    };
    try {
      final repo = ref.read(clientesRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.editing!.id, payload);
      } else {
        await repo.create(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _isEdit
              ? 'Não foi possível salvar as alterações.'
              : 'Não foi possível criar o cliente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x5,
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? 'Editar cliente' : 'Novo cliente',
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        // Corpo rolável.
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saveError != null) ...[
                  ErrorBanner(message: _saveError!),
                  const SizedBox(height: ClxSpace.x4),
                ],
                _field(
                  label: 'Nome',
                  required: true,
                  controller: _nome,
                  errorKey: 'nome',
                  hint: 'Carlos Silva',
                  textCapitalization: TextCapitalization.words,
                ),
                _twoCol(
                  _field(
                    label: 'Telefone',
                    required: true,
                    controller: _telefone,
                    errorKey: 'telefone',
                    hint: '(85) 99999-9999',
                    keyboardType: TextInputType.phone,
                    onChanged: (v) {
                      final masked = maskPhoneBR(v);
                      if (masked != v) {
                        _telefone.value = TextEditingValue(
                          text: masked,
                          selection: TextSelection.collapsed(
                            offset: masked.length,
                          ),
                        );
                      }
                    },
                  ),
                  _field(
                    label: 'E-mail',
                    controller: _email,
                    errorKey: 'email',
                    hint: 'cliente@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                _twoCol(
                  _field(
                    label: 'CEP',
                    controller: _cep,
                    hint: '00000-000',
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final masked = maskCEP(v);
                      if (masked != v) {
                        _cep.value = TextEditingValue(
                          text: masked,
                          selection: TextSelection.collapsed(
                            offset: masked.length,
                          ),
                        );
                      }
                    },
                  ),
                  _ativoToggle(clx),
                ),
                _field(
                  label: 'Rua e número',
                  controller: _rua,
                  hint: 'Rua das Flores, 123',
                ),
                _twoCol(
                  _field(
                    label: 'Complemento',
                    controller: _complemento,
                    hint: 'Apto 4B',
                  ),
                  _field(
                    label: 'Bairro',
                    required: true,
                    controller: _bairro,
                    errorKey: 'bairro',
                    hint: 'Centro',
                  ),
                ),
                _twoCol(
                  _field(
                    label: 'Cidade',
                    controller: _cidade,
                    hint: 'São Paulo',
                  ),
                  _field(
                    label: 'Estado (UF)',
                    controller: _estado,
                    hint: 'SP',
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                _field(
                  label: 'Observações',
                  controller: _observacoes,
                  hint: 'Informações adicionais sobre o cliente…',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: clx.line),
        // Rodapé.
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClxButton(
                label: 'Cancelar',
                variant: ClxButtonVariant.ghost,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: ClxSpace.x3),
              ClxButton(
                label: 'Salvar',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Coluna dupla responsiva (empilha < 480px).
  Widget _twoCol(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 480) {
          return Column(children: [a, b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: ClxSpace.x3),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    bool required = false,
    String? errorKey,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    final clx = context.clx;
    final err = errorKey == null ? null : _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: TextStyle(
                color: clx.ink2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: clx.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            maxLength: maxLength,
            enabled: !_saving,
            onChanged: (v) {
              if (err != null) setState(() => _errs.remove(errorKey));
              onChanged?.call(v);
            },
            inputFormatters: maxLength != null
                ? [LengthLimitingTextInputFormatter(maxLength)]
                : null,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              counterText: '',
              errorText: err,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ativoToggle(CleanoxColors clx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: TextStyle(
              color: clx.ink2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          Row(
            children: [
              Switch(
                value: _ativo,
                activeThumbColor: clx.primary,
                onChanged: _saving ? null : (v) => setState(() => _ativo = v),
              ),
              const SizedBox(width: ClxSpace.x2),
              Text(
                _ativo ? 'Cliente ativo' : 'Cliente inativo',
                style: TextStyle(color: clx.ink2, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
