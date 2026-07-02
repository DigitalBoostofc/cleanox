/// config_atuacao_editor.dart — Editor da "Área de atuação" (config_atuacao).
///
/// Espelha o modal "Área de atuação" de `Clientes.tsx`: singleton com `estado`
/// (UF) + lista de `cidades` (cada uma `nome`, `principal`, `bairros[]`). Faz
/// UPSERT via `ConfigAtuacaoRepository` (interface congelada): `get()` devolve o
/// registro atual (ou null) e o editor decide entre `create`/`update`.
///
/// Igual ao React, mora DENTRO de Clientes (aberto pelo ícone de config da
/// toolbar) e é restrito a admin/gerente. Todos os estados: carregando, erro (com
/// retry), edição, salvando, sucesso. Componentes MD3 acessíveis + marca.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/models/config_atuacao.dart';
import '../data/painel_providers.dart';

/// Abre o editor de área de atuação. Resolve `true` se salvou.
Future<bool?> showConfigAtuacaoEditor(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: const ConfigAtuacaoEditor(),
      ),
    ),
  );
}

/// Cidade em edição (mutável, espelha `ConfigAtuacaoCidade`).
class _CidadeEdit {
  _CidadeEdit({
    required this.nome,
    required this.principal,
    required this.bairros,
  });
  String nome;
  bool principal;
  List<String> bairros;

  factory _CidadeEdit.from(ConfigAtuacaoCidade c) => _CidadeEdit(
    nome: c.nome,
    principal: c.principal,
    bairros: List<String>.from(c.bairros),
  );

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'principal': principal,
    'bairros': bairros,
  };
}

class ConfigAtuacaoEditor extends ConsumerStatefulWidget {
  const ConfigAtuacaoEditor({super.key});

  @override
  ConsumerState<ConfigAtuacaoEditor> createState() =>
      _ConfigAtuacaoEditorState();
}

class _ConfigAtuacaoEditorState extends ConsumerState<ConfigAtuacaoEditor> {
  final TextEditingController _estado = TextEditingController();
  final TextEditingController _novaCidade = TextEditingController();
  final List<TextEditingController> _bairroCtrls = [];

  List<_CidadeEdit> _cidades = [];
  String? _existingId;

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;
  bool _saveOk = false;
  String? _cidadeError;

  /// UF é obrigatória (2 letras) — sem ela o Salvar fica bloqueado.
  bool get _ufValid => _estado.text.trim().length == 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _estado.dispose();
    _novaCidade.dispose();
    for (final c in _bairroCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _saveOk = false;
    });
    try {
      final cfg = await ref.read(configAtuacaoRepositoryProvider).get();
      if (!mounted) return;
      _disposeBairroCtrls();
      setState(() {
        _existingId = cfg?.id;
        _estado.text = cfg?.estado ?? '';
        _cidades = [
          for (final c in cfg?.cidades ?? const []) _CidadeEdit.from(c),
        ];
        for (var i = 0; i < _cidades.length; i++) {
          _bairroCtrls.add(TextEditingController());
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Não foi possível carregar a área de atuação.';
      });
    }
  }

  void _disposeBairroCtrls() {
    for (final c in _bairroCtrls) {
      c.dispose();
    }
    _bairroCtrls.clear();
  }

  void _addCidade() {
    final nome = _novaCidade.text.trim();
    if (nome.isEmpty) return;
    final dup = _cidades.any((c) => c.nome.toLowerCase() == nome.toLowerCase());
    if (dup) {
      setState(() => _cidadeError = 'Cidade já adicionada.');
      return;
    }
    setState(() {
      _cidades.add(
        _CidadeEdit(nome: nome, principal: _cidades.isEmpty, bairros: []),
      );
      _bairroCtrls.add(TextEditingController());
      _novaCidade.clear();
      _cidadeError = null;
      _saveOk = false;
    });
  }

  void _removeCidade(int idx) {
    setState(() {
      final wasPrincipal = _cidades[idx].principal;
      _cidades.removeAt(idx);
      _bairroCtrls.removeAt(idx).dispose();
      if (wasPrincipal && _cidades.isNotEmpty) {
        _cidades[0].principal = true;
      }
      _saveOk = false;
    });
  }

  void _setPrincipal(int idx) {
    setState(() {
      for (var i = 0; i < _cidades.length; i++) {
        _cidades[i].principal = i == idx;
      }
      _saveOk = false;
    });
  }

  void _addBairro(int idx) {
    final bairro = _bairroCtrls[idx].text.trim();
    if (bairro.isEmpty) return;
    final dup = _cidades[idx].bairros.any(
      (b) => b.toLowerCase() == bairro.toLowerCase(),
    );
    if (dup) return;
    setState(() {
      _cidades[idx].bairros.add(bairro);
      _bairroCtrls[idx].clear();
      _saveOk = false;
    });
  }

  void _removeBairro(int cidadeIdx, int bairroIdx) {
    setState(() {
      _cidades[cidadeIdx].bairros.removeAt(bairroIdx);
      _saveOk = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
      _saveOk = false;
    });
    final estado = _estado.text.trim().toUpperCase();
    final payload = <String, dynamic>{
      'estado': estado.length > 2 ? estado.substring(0, 2) : estado,
      'cidades': [for (final c in _cidades) c.toJson()],
    };
    try {
      final repo = ref.read(configAtuacaoRepositoryProvider);
      if (_existingId != null) {
        await repo.update(_existingId!, payload);
      } else {
        final created = await repo.create(payload);
        _existingId = created.id;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveOk = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Não foi possível salvar a área de atuação.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  'Área de atuação',
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
                    : () => Navigator.of(context).maybePop(_saveOk),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Flexible(child: _body(clx)),
        Divider(height: 1, color: clx.line),
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClxButton(
                label: 'Fechar',
                variant: ClxButtonVariant.ghost,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(_saveOk),
              ),
              const SizedBox(width: ClxSpace.x3),
              ClxButton(
                label: _saveOk ? 'Salvo!' : 'Salvar',
                icon: _saveOk
                    ? Icons.check_circle_rounded
                    : Icons.check_rounded,
                loading: _saving,
                onPressed:
                    (_saving || _loading || _loadError != null || !_ufValid)
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(CleanoxColors clx) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(ClxSpace.x10),
        child: Center(child: Spinner(size: 24)),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(ClxSpace.x5),
        child: ErrorBanner(message: _loadError!, onRetry: _load),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ClxSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saveError != null) ...[
            ErrorBanner(message: _saveError!),
            const SizedBox(height: ClxSpace.x4),
          ],
          if (_saveOk) ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: clx.success),
                const SizedBox(width: ClxSpace.x2),
                Text(
                  'Área de atuação salva.',
                  style: TextStyle(
                    color: clx.success,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x4),
          ],

          // Estado (UF).
          Text(
            'Estado (UF)',
            style: TextStyle(
              color: clx.ink2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          SizedBox(
            width: 96,
            child: TextField(
              key: const ValueKey('atuacao-estado'),
              controller: _estado,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(2),
                _UpperCaseFormatter(),
              ],
              // Rebuild a cada tecla → reavalia o gate do Salvar (UF obrigatória).
              onChanged: (_) => setState(() => _saveOk = false),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'SP',
                errorText: _ufValid ? null : 'UF obrigatória',
              ),
            ),
          ),
          const SizedBox(height: ClxSpace.x5),

          // Cidades atendidas.
          Text(
            'CIDADES ATENDIDAS',
            style: TextStyle(
              color: clx.ink2,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),

          if (_cidades.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x3),
              child: Text(
                'Nenhuma cidade cadastrada.',
                style: TextStyle(color: clx.ink3, fontSize: 13.5),
              ),
            ),

          for (var i = 0; i < _cidades.length; i++) ...[
            _CidadeCard(
              cidade: _cidades[i],
              bairroController: _bairroCtrls[i],
              enabled: !_saving,
              onSetPrincipal: () => _setPrincipal(i),
              onRemove: () => _removeCidade(i),
              onAddBairro: () => _addBairro(i),
              onRemoveBairro: (bi) => _removeBairro(i, bi),
            ),
            const SizedBox(height: ClxSpace.x3),
          ],

          // Adicionar cidade.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('atuacao-nova-cidade'),
                  controller: _novaCidade,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_cidadeError != null) {
                      setState(() => _cidadeError = null);
                    }
                  },
                  onSubmitted: (_) => _addCidade(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Nome da nova cidade…',
                    errorText: _cidadeError,
                  ),
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              Padding(
                padding: const EdgeInsets.only(top: ClxSpace.x1),
                child: ClxButton(
                  label: 'Cidade',
                  icon: Icons.add_rounded,
                  variant: ClxButtonVariant.ghost,
                  onPressed: _saving ? null : _addCidade,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de uma cidade: nome + rádio "principal" + remover + chips de bairro.
class _CidadeCard extends StatelessWidget {
  const _CidadeCard({
    required this.cidade,
    required this.bairroController,
    required this.enabled,
    required this.onSetPrincipal,
    required this.onRemove,
    required this.onAddBairro,
    required this.onRemoveBairro,
  });

  final _CidadeEdit cidade;
  final TextEditingController bairroController;
  final bool enabled;
  final VoidCallback onSetPrincipal;
  final VoidCallback onRemove;
  final VoidCallback onAddBairro;
  final void Function(int bairroIdx) onRemoveBairro;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.bg2,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cidade.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Semantics(
                selected: cidade.principal,
                button: true,
                label: 'Cidade principal',
                child: Tooltip(
                  message: cidade.principal
                      ? 'Cidade principal'
                      : 'Definir como principal',
                  child: InkWell(
                    onTap: enabled ? onSetPrincipal : null,
                    borderRadius: ClxRadii.rPill,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ClxSpace.x2,
                        vertical: ClxSpace.x1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cidade.principal
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: cidade.principal ? clx.primary : clx.ink3,
                          ),
                          const SizedBox(width: ClxSpace.x1),
                          Text(
                            'Principal',
                            style: TextStyle(
                              color: cidade.principal ? clx.primary : clx.ink2,
                              fontSize: 12.5,
                              fontWeight: cidade.principal
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remover cidade',
                iconSize: 18,
                color: clx.error,
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),

          // Bairros (chips com remover).
          if (cidade.bairros.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x2),
              child: Text(
                'Nenhum bairro cadastrado.',
                style: TextStyle(color: clx.ink3, fontSize: 12.5),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x2),
              child: Wrap(
                spacing: ClxSpace.x2,
                runSpacing: ClxSpace.x2,
                children: [
                  for (var bi = 0; bi < cidade.bairros.length; bi++)
                    _BairroChip(
                      label: cidade.bairros[bi],
                      color: clx.primary,
                      enabled: enabled,
                      onRemove: () => onRemoveBairro(bi),
                    ),
                ],
              ),
            ),

          // Adicionar bairro.
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: bairroController,
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAddBairro(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Adicionar bairro…',
                  ),
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              IconButton(
                tooltip: 'Adicionar bairro',
                iconSize: 20,
                color: clx.primary,
                onPressed: enabled ? onAddBairro : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip de bairro com botão de remover (acessível).
class _BairroChip extends StatelessWidget {
  const _BairroChip({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onRemove,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: ClxSpace.x3,
        right: ClxSpace.x1,
        top: 2,
        bottom: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: ClxRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: ClxSpace.x1),
          InkWell(
            onTap: enabled ? onRemove : null,
            borderRadius: ClxRadii.rPill,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Tooltip(
                message: 'Remover $label',
                child: Icon(Icons.close_rounded, size: 13, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formatter que força maiúsculas (UF).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
