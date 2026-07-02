/// servico_editor.dart — Editor full-page do serviço (criar/editar).
///
/// Espelha `ServicoEditorPage.tsx`: informações principais (categoria/grupo/nome,
/// valor/tipo de valor, tempo médio, status), observação, CHECKLIST padrão (com
/// itens obrigatórios/ordem via [ChecklistEditor]) e orientações pré/pós. Validação
/// completa + todos os estados (loading/erro/salvando). Rota deep-linkável
/// (`/painel/servicos/novo` e `/painel/servicos/:id`) empilhada no navigator RAIZ
/// (tela cheia) — por isso traz o próprio `Scaffold` + cabeçalho com voltar.
/// Ao salvar, `Navigator.pop(true)` devolve o resultado ao `context.push` da lista.
///
/// Grava via `ServicosRepository` (core): monta o payload snake_case (espelha
/// `servicoToPB` — inclui os legados `preco_base`/`ativo`). O slug único é resolvido
/// na camada de dados (`PbServicosRepository.create`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/models/servico.dart';
import '../data/painel_providers.dart';
import 'checklist_editor.dart';
import 'servicos_labels.dart';

class ServicoEditorScreen extends ConsumerStatefulWidget {
  const ServicoEditorScreen({super.key, this.servicoId});

  final String? servicoId;

  @override
  ConsumerState<ServicoEditorScreen> createState() =>
      _ServicoEditorScreenState();
}

class _ServicoEditorScreenState extends ConsumerState<ServicoEditorScreen> {
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _tempoMedio = TextEditingController();
  final TextEditingController _observacao = TextEditingController();
  final TextEditingController _orientacoesPre = TextEditingController();
  final TextEditingController _orientacoesPos = TextEditingController();

  Categoria _categoria = Categoria.veicular;
  Grupo _grupo = Grupo.plano;
  TipoValor _tipoValor = TipoValor.fixo;
  ServicoStatus _status = ServicoStatus.ativo;
  int _valorBaseCents = 0;
  int _valorBaseMaxCents = 0;
  List<ChecklistTemplateItem> _checklist = const [];

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  bool get _isEdit => widget.servicoId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nome.dispose();
    _tempoMedio.dispose();
    _observacao.dispose();
    _orientacoesPre.dispose();
    _orientacoesPos.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.servicoId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await ref.read(servicosRepositoryProvider).getOne(id);
      if (!mounted) return;
      setState(() {
        _categoria = s.categoria ?? Categoria.veicular;
        _grupo = s.grupo ?? Grupo.outros;
        _nome.text = s.nome;
        _valorBaseCents = (s.valorBase * 100).round();
        _valorBaseMaxCents = ((s.valorBaseMax ?? 0) * 100).round();
        _tipoValor = s.tipoValor ?? TipoValor.fixo;
        _tempoMedio.text = s.tempoMedioLabel ?? '';
        _status = s.status ?? ServicoStatus.ativo;
        _observacao.text = s.observacao ?? '';
        _checklist = s.checklistPadrao;
        _orientacoesPre.text = s.orientacoesPre ?? '';
        _orientacoesPos.text = s.orientacoesPos ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Não foi possível carregar o serviço.';
        });
      }
    }
  }

  Map<String, String> _validate() {
    final errs = <String, String>{};
    if (_nome.text.trim().isEmpty) errs['nome'] = 'Nome é obrigatório.';
    if (_tipoValor == TipoValor.faixa &&
        _valorBaseMaxCents <= _valorBaseCents) {
      errs['valorMax'] = 'O valor máximo deve ser maior que o mínimo.';
    }
    return errs;
  }

  Map<String, dynamic> _buildPayload() {
    // Normaliza o checklist: descarta itens sem título, IDs estáveis, ordem 1-based.
    final checklist = <Map<String, dynamic>>[];
    var ordem = 1;
    for (final c in _checklist) {
      final titulo = c.titulo.trim();
      if (titulo.isEmpty) continue;
      checklist.add({
        'id': 'chk_${widget.servicoId ?? 'new'}_$ordem',
        'titulo': titulo,
        'ordem': ordem,
        'obrigatorio': c.obrigatorio,
      });
      ordem++;
    }
    final tempoLabel = _tempoMedio.text.trim();
    final valorBase = _valorBaseCents / 100;
    return <String, dynamic>{
      'categoria': _categoria.wire,
      'grupo': _grupo.wire,
      'nome': _nome.text.trim(),
      'valor_base': valorBase,
      'preco_base': valorBase, // 🔁 legado sincronizado
      'valor_base_max': _tipoValor == TipoValor.faixa
          ? _valorBaseMaxCents / 100
          : 0,
      'tipo_valor': _tipoValor.wire,
      'tempo_medio_min': parseTempoMedio(tempoLabel) ?? 0,
      'tempo_medio_label': tempoLabel,
      'status': _status.wire,
      'ativo': _status == ServicoStatus.ativo, // 🔁 legado sincronizado
      'observacao': _observacao.text.trim(),
      'checklist_padrao': checklist,
      'orientacoes_pre': _orientacoesPre.text.trim(),
      'orientacoes_pos': _orientacoesPos.text.trim(),
      'adicionais_relacionados': <String>[],
    };
  }

  Future<void> _save() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() {
        _errs
          ..clear()
          ..addAll(errs);
        _saveError = 'Verifique os campos destacados antes de salvar.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _errs.clear();
    });
    try {
      final repo = ref.read(servicosRepositoryProvider);
      final payload = _buildPayload();
      if (_isEdit) {
        await repo.update(widget.servicoId!, payload);
      } else {
        await repo.create(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Não foi possível salvar o serviço. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(
        child: Column(
          children: [
            _header(clx),
            Divider(height: 1, color: clx.line),
            Expanded(child: _body(clx)),
          ],
        ),
      ),
    );
  }

  Widget _header(CleanoxColors clx) {
    return Container(
      color: clx.bg,
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Editar serviço' : 'Novo serviço',
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Usado em orçamento, agendamento e OS.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: clx.ink3, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (!_loading && _loadError == null) ...[
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
        ],
      ),
    );
  }

  Widget _body(CleanoxColors clx) {
    if (_loading) return const Center(child: Spinner(size: 26));
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(message: _loadError!, onRetry: _load),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ClxSpace.x5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saveError != null) ...[
                ErrorBanner(message: _saveError!),
                const SizedBox(height: ClxSpace.x4),
              ],
              _card(
                clx,
                title: 'Informações principais',
                child: _infoSection(clx),
              ),
              const SizedBox(height: ClxSpace.x4),
              _card(
                clx,
                title: 'Observação comercial / técnica',
                child: _multiline(
                  _observacao,
                  hint:
                      'Detalhes comerciais ou técnicos que ajudam a equipe e '
                      'o cliente…',
                ),
              ),
              const SizedBox(height: ClxSpace.x4),
              _card(
                clx,
                title: 'Checklist padrão do serviço',
                subtitle:
                    'Itens que a equipe marca durante a execução. '
                    'Marque como obrigatórios os que travam a conclusão da OS.',
                child: ChecklistEditor(
                  items: _checklist,
                  enabled: !_saving,
                  onChanged: (items) => _checklist = items,
                ),
              ),
              const SizedBox(height: ClxSpace.x4),
              _card(
                clx,
                title: 'Orientações pré-serviço',
                child: _multiline(
                  _orientacoesPre,
                  hint:
                      'Ex.: Garantir ponto de energia e água. Remover objetos '
                      'pessoais…',
                ),
              ),
              const SizedBox(height: ClxSpace.x4),
              _card(
                clx,
                title: 'Orientações pós-serviço',
                child: _multiline(
                  _orientacoesPos,
                  hint:
                      'Ex.: Tempo de secagem de 2 a 6h. Até 3 dias para '
                      'intercorrências…',
                ),
              ),
              const SizedBox(height: ClxSpace.x8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(CleanoxColors clx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _twoCol(
          _dropdownField<Categoria>(
            label: 'Categoria',
            value: _categoria,
            items: Categoria.values,
            labelOf: categoriaLabel,
            onChanged: (v) => setState(() => _categoria = v),
          ),
          _dropdownField<Grupo>(
            label: 'Grupo',
            value: _grupo,
            items: Grupo.values,
            labelOf: grupoLabel,
            onChanged: (v) => setState(() => _grupo = v),
          ),
        ),
        _textField(
          label: 'Nome do serviço',
          required: true,
          controller: _nome,
          errorKey: 'nome',
          hint: 'Cleanox Premium',
          textCapitalization: TextCapitalization.words,
        ),
        _twoCol(
          _dropdownField<TipoValor>(
            label: 'Tipo de valor',
            value: _tipoValor,
            items: TipoValor.values,
            labelOf: tipoValorLabel,
            onChanged: (v) => setState(() {
              _tipoValor = v;
              if (v != TipoValor.faixa) _errs.remove('valorMax');
            }),
          ),
          _textFieldRaw(
            label: 'Tempo médio',
            controller: _tempoMedio,
            hint: '3h a 4h',
          ),
        ),
        if (_tipoValor == TipoValor.faixa)
          _twoCol(
            _moneyField(
              label: 'Valor mínimo',
              cents: _valorBaseCents,
              onChanged: (c) => setState(() => _valorBaseCents = c),
            ),
            _moneyField(
              label: 'Valor máximo',
              cents: _valorBaseMaxCents,
              errorKey: 'valorMax',
              onChanged: (c) => setState(() {
                _valorBaseMaxCents = c;
                _errs.remove('valorMax');
              }),
            ),
          )
        else
          _moneyField(
            label: 'Valor base',
            cents: _valorBaseCents,
            onChanged: (c) => setState(() => _valorBaseCents = c),
          ),
        const SizedBox(height: ClxSpace.x2),
        _statusRow(clx),
      ],
    );
  }

  Widget _statusRow(CleanoxColors clx) {
    final ativo = _status == ServicoStatus.ativo;
    return Row(
      children: [
        Switch(
          value: ativo,
          activeThumbColor: clx.primary,
          onChanged: _saving
              ? null
              : (v) => setState(
                  () =>
                      _status = v ? ServicoStatus.ativo : ServicoStatus.inativo,
                ),
        ),
        const SizedBox(width: ClxSpace.x2),
        Expanded(
          child: Text(
            ativo
                ? 'Serviço ativo e disponível para orçamento e OS.'
                : 'Serviço inativo — não aparece em novos orçamentos e OS.',
            style: TextStyle(color: clx.ink2, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  /* ---- Building blocks ---- */

  Widget _card(
    CleanoxColors clx, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x5),
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: ClxRadii.rLg,
        border: Border.all(color: clx.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: clx.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: ClxSpace.x1),
            Text(
              subtitle,
              style: TextStyle(color: clx.ink3, fontSize: 12.5, height: 1.4),
            ),
          ],
          const SizedBox(height: ClxSpace.x4),
          child,
        ],
      ),
    );
  }

  Widget _twoCol(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 520) return Column(children: [a, b]);
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

  Widget _label(String text, {bool required = false}) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x1),
      child: Text.rich(
        TextSpan(
          text: text,
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
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    String? errorKey,
    String? hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final err = errorKey == null ? null : _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextField(
            controller: controller,
            enabled: !_saving,
            textCapitalization: textCapitalization,
            onChanged: (_) {
              if (err != null) setState(() => _errs.remove(errorKey));
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              errorText: err,
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de texto sem padding inferior (para uso dentro de _twoCol alinhado).
  Widget _textFieldRaw({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: controller,
            enabled: !_saving,
            decoration: InputDecoration(isDense: true, hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _multiline(TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(isDense: true, hintText: hint),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final it in items)
                DropdownMenuItem(value: it, child: Text(labelOf(it))),
            ],
            onChanged: _saving ? null : (v) => v == null ? null : onChanged(v),
          ),
        ],
      ),
    );
  }

  Widget _moneyField({
    required String label,
    required int cents,
    String? errorKey,
    required ValueChanged<int> onChanged,
  }) {
    final err = errorKey == null ? null : _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          _MoneyField(
            cents: cents,
            enabled: !_saving,
            errorText: err,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Campo monetário controlado por CENTAVOS (espelha centsToDisplay/rawToCents).
/// Digitação empurra os dígitos da direita para a esquerda (R$ 0,00 → 0,01 → …).
class _MoneyField extends StatefulWidget {
  const _MoneyField({
    required this.cents,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  final int cents;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _display(widget.cents));
  }

  @override
  void didUpdateWidget(covariant _MoneyField old) {
    super.didUpdateWidget(old);
    // Mantém sincronizado quando o pai reseta o valor (ex.: troca de serviço).
    final want = _display(widget.cents);
    if (_ctrl.text != want && _rawToCents(_ctrl.text) != widget.cents) {
      _ctrl.value = TextEditingValue(
        text: want,
        selection: TextSelection.collapsed(offset: want.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _display(int cents) {
    final v = cents / 100;
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    // separador de milhar
    final parts = s.split(',');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $intPart,${parts[1]}';
  }

  static int _rawToCents(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;
    return trimmed.isEmpty ? 0 : int.parse(trimmed);
  }

  void _onChanged(String value) {
    final cents = _rawToCents(value);
    final display = _display(cents);
    _ctrl.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
    widget.onChanged(cents);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
      onChanged: _onChanged,
      decoration: InputDecoration(isDense: true, errorText: widget.errorText),
    );
  }
}
