/// cliente_form.dart — Formulário de criar/editar Cliente (🔒 COFRE).
///
/// Espelha o modal de `Clientes.tsx`: nome único (split em nome+sobrenome no save),
/// telefone/CEP com máscara, endereço, toggle ativo e observações, com validação.
/// Recursos espelhados do React: autofill de endereço por CEP (ViaCEP), cidade/UF
/// pré-preenchidos + sugestões de bairro a partir da `config_atuacao`, e o toggle
/// "Gerar OS" (só na criação) que já cria uma OS para o cliente recém-cadastrado.
/// Mostrado via [showClienteForm] — Dialog centrado no desktop (padrão do Painel,
/// Flutter Web) com largura limitada; corpo rolável + rodapé fixo de ações.
///
/// Consome `clientesRepositoryProvider` (interface do core). Retorna `true` quando
/// salvou (o caller recarrega a lista).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/auth_providers.dart' show ordensRepositoryProvider;
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/cliente.dart';
import '../../core/models/collections.dart';
import '../../core/models/config_atuacao.dart';
import '../data/painel_providers.dart';
import '../ordens/ordens_controller.dart';
import 'os_inline_section.dart';

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

  /// Origem do lead selecionada (slug). `null` = não informado.
  String? _origem;

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  /// Área de atuação (estado + cidades/bairros sugeridos). Carregada no boot.
  ConfigAtuacao? _config;

  /// Estado do autofill por CEP (ViaCEP).
  bool _cepLoading = false;
  String? _cepWarning;

  /// "Gerar OS" — só no modo criação; revela a seção de OS embutida.
  bool _gerarOs = false;
  final GlobalKey<OsInlineSectionState> _osKey =
      GlobalKey<OsInlineSectionState>();

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
    _origem = (c?.origem ?? '').isEmpty ? null : c!.origem;
    _loadConfig();
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

  /// Carrega a `config_atuacao`. Na criação, pré-preenche cidade principal + UF
  /// (espelha `openCreate` do React). Falha silenciosa → segue com campos livres.
  Future<void> _loadConfig() async {
    try {
      final cfg = await ref.read(configAtuacaoRepositoryProvider).get();
      if (!mounted) return;
      setState(() => _config = cfg);
      if (_isEdit || cfg == null) return;
      ConfigAtuacaoCidade? principal;
      for (final cidade in cfg.cidades) {
        if (cidade.principal) {
          principal = cidade;
          break;
        }
      }
      if (_cidade.text.trim().isEmpty && principal != null) {
        _cidade.text = principal.nome;
      }
      if (_estado.text.trim().isEmpty && cfg.estado.isNotEmpty) {
        _estado.text = cfg.estado;
      }
      if (principal != null || cfg.estado.isNotEmpty) setState(() {});
    } catch (_) {
      /* config indisponível — o formulário funciona com campos livres */
    }
  }

  /* ─── Derivações da área de atuação (espelham o React) ─── */

  List<ConfigAtuacaoCidade> get _configCidades =>
      _config?.cidades ?? const [];
  bool get _hasCidades => _configCidades.isNotEmpty;

  /// Bairros sugeridos para a cidade atualmente selecionada (datalist do React).
  List<String> get _bairrosSugeridos {
    final cidade = _cidade.text.trim();
    for (final c in _configCidades) {
      if (c.nome == cidade) return c.bairros;
    }
    return const [];
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

  /// Autofill de endereço por CEP (ViaCEP). Ao completar 8 dígitos, consulta a
  /// API pública e preenche rua/bairro/cidade/UF. Espelha `handleCEPChange`.
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
        _rua.text = (data['logradouro'] as String?) ?? '';
        _bairro.text = (data['bairro'] as String?) ?? '';
        _cidade.text = (data['localidade'] as String?) ?? '';
        _estado.text = (data['uf'] as String?) ?? '';
        if ((data['bairro'] as String? ?? '').isNotEmpty) {
          _errs.remove('bairro');
        }
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
    final errs = _validate();
    final osValid = (!_isEdit && _gerarOs)
        ? (_osKey.currentState?.validate() ?? false)
        : true;
    if (errs.isNotEmpty || !osValid) {
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
      'origem': _origem ?? '',
      'observacoes': _observacoes.text.trim(),
    };
    try {
      final repo = ref.read(clientesRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.editing!.id, payload);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      final novo = await repo.create(payload);
      // "Gerar OS": cria a ordem para o cliente recém-criado (espelha o React).
      if (_gerarOs) {
        final os = _osKey.currentState;
        if (os != null) {
          final hasProf = os.profissionalId.isNotEmpty;
          final valor =
              double.tryParse(os.valorServico.replaceAll(',', '.')) ?? 0;
          try {
            await ref.read(ordensRepositoryProvider).create({
              'cliente': novo.id,
              'servico': os.servicoId.isEmpty ? null : os.servicoId,
              'tipo_servico_nome': os.tipoServicoNome,
              'data_hora': localInputToPBDate(
                '${os.dataDate}T${os.horaH}:${os.horaM}',
              ),
              'valor_servico': valor,
              'profissional': hasProf ? os.profissionalId : null,
              'status': hasProf
                  ? OSStatus.atribuida.wire
                  : OSStatus.agendada.wire,
              'observacoes': os.observacoes,
            });
          } catch (_) {
            // Cliente criado, mas a OS falhou — informa sem descartar o cliente.
            if (mounted) {
              setState(() {
                _saving = false;
                _saveError =
                    'Cliente criado, mas houve um erro ao gerar a OS.';
              });
            }
            return;
          }
          // OS criada por aqui não passa pelo controller da lista de OS, e o
          // shell mantém aquela aba viva (IndexedStack) com estado velho —
          // então avisamos a lista/contadores pra refletir sem refresh manual.
          ref.read(ordensControllerProvider.notifier).refresh();
          ref.invalidate(ordensCountsProvider);
        }
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink,
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
                _twoCol(_cepField(clx), _ativoToggle(clx)),
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
                _bairroChips(clx),
                _twoCol(
                  _cidadeField(clx),
                  _field(
                    label: 'Estado (UF)',
                    controller: _estado,
                    hint: 'SP',
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                _origemField(clx),
                _field(
                  label: 'Observações',
                  controller: _observacoes,
                  hint: 'Informações adicionais sobre o cliente…',
                  maxLines: 3,
                ),
                // Toggle "Gerar OS" + seção — só na criação (espelha o React).
                if (!_isEdit) ...[
                  _gerarOsToggle(clx),
                  if (_gerarOs) ...[
                    const SizedBox(height: ClxSpace.x4),
                    _osSectionHeader(clx),
                    const SizedBox(height: ClxSpace.x4),
                    OsInlineSection(key: _osKey, enabled: !_saving),
                  ],
                ],
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

  Widget _fieldLabel(String label, {bool required = false}) {
    final clx = context.clx;
    return Text.rich(
      TextSpan(
        text: label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: clx.ink2,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            TextSpan(text: ' *', style: TextStyle(color: clx.error)),
        ],
      ),
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
    final err = errorKey == null ? null : _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, required: required),
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

  /// Campo CEP com autofill (ViaCEP) e indicador de "buscando…"/aviso.
  Widget _cepField(CleanoxColors clx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _fieldLabel('CEP'),
              if (_cepLoading) ...[
                const SizedBox(width: ClxSpace.x2),
                const Spinner(size: 11),
                const SizedBox(width: ClxSpace.x1),
                Text(
                  'buscando…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.ink3),
                ),
              ],
            ],
          ),
          const SizedBox(height: ClxSpace.x1),
          TextField(
            controller: _cep,
            keyboardType: TextInputType.number,
            enabled: !_saving,
            onChanged: _handleCep,
            decoration: InputDecoration(
              isDense: true,
              hintText: '00000-000',
              errorText: _cepWarning,
            ),
          ),
        ],
      ),
    );
  }

  /// Chips de bairro sugeridos pela área de atuação (equivalente ao datalist).
  Widget _bairroChips(CleanoxColors clx) {
    final sugeridos = _bairrosSugeridos;
    if (sugeridos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bairros da área de atuação',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x2),
          Wrap(
            spacing: ClxSpace.x2,
            runSpacing: ClxSpace.x2,
            children: [
              for (final b in sugeridos)
                _SuggestionChip(
                  label: b,
                  selected: _bairro.text.trim() == b,
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          _bairro.text = b;
                          _errs.remove('bairro');
                        }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cidade: dropdown quando há cidades na área de atuação (espelha o `<select>`
  /// do React, que injeta a cidade atual como opção extra se não estiver na
  /// lista); input livre caso contrário.
  Widget _cidadeField(CleanoxColors clx) {
    if (!_hasCidades) {
      return _field(label: 'Cidade', controller: _cidade, hint: 'São Paulo');
    }
    final current = _cidade.text.trim();
    final hasCurrentInList = _configCidades.any((c) => c.nome == current);
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Cidade'),
          const SizedBox(height: ClxSpace.x1),
          DropdownButtonFormField<String>(
            // Key inclui o valor → recria o campo quando o CEP preenche a cidade
            // programaticamente (o FormField não observa mudanças externas).
            key: ValueKey('cliente-cidade-$current'),
            initialValue: current,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Selecionar —')),
              for (final c in _configCidades)
                DropdownMenuItem(
                  value: c.nome,
                  child: Text(c.nome, overflow: TextOverflow.ellipsis),
                ),
              if (current.isNotEmpty && !hasCurrentInList)
                DropdownMenuItem(
                  value: current,
                  child: Text(current, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() => _cidade.text = v ?? ''),
          ),
        ],
      ),
    );
  }

  /// Dropdown "Origem" — de onde veio o lead. Opcional (permite "— Selecionar —").
  Widget _origemField(CleanoxColors clx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Origem'),
          const SizedBox(height: ClxSpace.x1),
          DropdownButtonFormField<String>(
            initialValue: _origem ?? '',
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Selecionar —')),
              for (final (slug, rotulo) in Cliente.origemOpcoes)
                DropdownMenuItem(value: slug, child: Text(rotulo)),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(
                    () => _origem = (v == null || v.isEmpty) ? null : v,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: clx.ink2,
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Toggle "Gerar OS" (criação): revela a seção de OS embutida.
  Widget _gerarOsToggle(CleanoxColors clx) {
    return Row(
      children: [
        Switch(
          value: _gerarOs,
          activeThumbColor: clx.primary,
          onChanged: _saving ? null : (v) => setState(() => _gerarOs = v),
        ),
        const SizedBox(width: ClxSpace.x2),
        Text(
          'Gerar OS',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: clx.ink2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _osSectionHeader(CleanoxColors clx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: clx.line),
        const SizedBox(height: ClxSpace.x3),
        Text(
          'ORDEM DE SERVIÇO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: clx.ink3,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// Chip clicável de sugestão de bairro (marca o selecionado com o accent).
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = selected ? clx.primary : clx.ink2;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rPill,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x1,
        ),
        decoration: BoxDecoration(
          color: selected
              ? clx.primary.withValues(alpha: 0.12)
              : clx.bg2,
          borderRadius: ClxRadii.rPill,
          border: Border.all(color: selected ? clx.primary : clx.line),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
