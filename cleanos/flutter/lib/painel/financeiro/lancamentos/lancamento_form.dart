/// lancamento_form.dart — Modal de criar/editar um Lançamento (`fin_lancamentos`).
///
/// Espelha `LancamentoFormModal.tsx`: tipo (receita/despesa), descrição, valor,
/// data (parede/BRT), conta, **categoria unificada** (raiz + sub no mesmo
/// dropdown — [FinCategoriaTreePicker]), status, vencimento, recorrência, forma
/// de pagamento, observação e anexos.
///
/// 🔒 ANTI-DESVIO: um lançamento criado no painel nasce `origem = 'manual'` e
/// NUNCA vira `via_os`. Na EDIÇÃO, `origem`/vínculo com OS NÃO são tocados (para
/// não fabricar/limpar um recebimento fantasma da OS). O ajuste de saldo é do
/// repo (incremental), não daqui.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/models/financeiro.dart';
import '../fin_categoria_picker.dart';
import '../fin_form_kit.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';

Future<bool?> showLancamentoForm(
  BuildContext context, {
  FinLancamento? editing,
  TipoLancamento? initialTipo,
}) => showFinModal<bool>(
  context,
  LancamentoForm(editing: editing, initialTipo: initialTipo),
);

class LancamentoForm extends ConsumerStatefulWidget {
  const LancamentoForm({super.key, this.editing, this.initialTipo});

  final FinLancamento? editing;

  /// Tipo pré-selecionado ao CRIAR (ex.: ação rápida "Nova receita"). Ignorado
  /// na edição (usa o tipo do registro).
  final TipoLancamento? initialTipo;

  @override
  ConsumerState<LancamentoForm> createState() => _LancamentoFormState();
}

class _LancamentoFormState extends ConsumerState<LancamentoForm> {
  late final TextEditingController _descricao;
  late final TextEditingController _valor;
  late final TextEditingController _data;
  late final TextEditingController _vencimento;
  late final TextEditingController _formaPagamento;
  late final TextEditingController _observacao;
  late final TextEditingController _tags;
  late final TextEditingController _parcelaAtual;
  late final TextEditingController _parcelasTotal;

  late TipoLancamento _tipo;
  String? _contaId;
  String? _categoriaId;
  String? _subcategoriaId;
  late LancamentoStatus _status;
  late RecorrenciaTipo _recorrencia;
  late List<Anexo> _anexos;

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final l = widget.editing;
    _descricao = TextEditingController(text: l?.descricao ?? '');
    _valor = TextEditingController(
      text: l == null ? '' : formatMoedaInput(l.valor),
    );
    _data = TextEditingController(text: l?.data ?? todayLocalDate());
    _vencimento = TextEditingController(text: l?.vencimento ?? '');
    _formaPagamento = TextEditingController(text: l?.formaPagamento ?? '');
    _observacao = TextEditingController(text: l?.observacao ?? '');
    _tags = TextEditingController(text: (l?.tags ?? const []).join(', '));
    _parcelaAtual = TextEditingController(
      text: (l?.parcelaAtual ?? 1).toString(),
    );
    _parcelasTotal = TextEditingController(
      text: (l?.parcelasTotal ?? 2).toString(),
    );
    _tipo = l?.tipo ?? widget.initialTipo ?? TipoLancamento.despesa;
    _contaId = l?.contaId.isNotEmpty == true ? l!.contaId : null;
    _categoriaId = l?.categoriaId.isNotEmpty == true ? l!.categoriaId : null;
    _subcategoriaId = l?.subcategoriaId;
    _status = l?.status ?? LancamentoStatus.pendente;
    _recorrencia = l?.recorrencia ?? RecorrenciaTipo.unica;
    _anexos = List<Anexo>.from(l?.anexos ?? const []);
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _data.dispose();
    _vencimento.dispose();
    _formaPagamento.dispose();
    _observacao.dispose();
    _tags.dispose();
    _parcelaAtual.dispose();
    _parcelasTotal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errs = <String, String>{};
    if (_descricao.text.trim().isEmpty) {
      errs['descricao'] = 'Descrição é obrigatória';
    }
    final valor = parseMoedaBr(_valor.text);
    if (valor == null || valor <= 0) errs['valor'] = 'Informe um valor válido';
    if (_data.text.trim().isEmpty) errs['data'] = 'Data é obrigatória';
    if (_contaId == null) errs['conta'] = 'Escolha uma conta';
    if (_categoriaId == null) errs['categoria'] = 'Escolha uma categoria';
    if (_recorrencia == RecorrenciaTipo.parcelada) {
      final total = int.tryParse(_parcelasTotal.text.trim());
      final atual = int.tryParse(_parcelaAtual.text.trim());
      if (total == null || total < 1) {
        errs['parcelas'] = 'Nº de parcelas deve ser um inteiro ≥ 1';
      } else if (atual == null || atual < 1 || atual > total) {
        errs['parcelas'] = 'Parcela atual deve estar entre 1 e $total';
      }
    }
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

    final data = <String, dynamic>{
      'tipo': _tipo.wire,
      'descricao': _descricao.text.trim(),
      'categoria_id': _categoriaId,
      'subcategoria_id': _subcategoriaId,
      'valor': valor,
      'conta_id': _contaId,
      'data': _data.text.trim(),
      'vencimento': _vencimento.text.trim().isEmpty
          ? null
          : _vencimento.text.trim(),
      'status': _status.wire,
      'recorrencia': _recorrencia.wire,
      // Parcelas só quando 'parcelada'; senão limpa (o registro deixa de ser parcela).
      if (_recorrencia == RecorrenciaTipo.parcelada) ...{
        'parcela_atual': int.parse(_parcelaAtual.text.trim()),
        'parcelas_total': int.parse(_parcelasTotal.text.trim()),
      } else ...{
        'parcela_atual': null,
        'parcelas_total': null,
      },
      'tags': _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      'forma_pagamento': _formaPagamento.text.trim().isEmpty
          ? null
          : _formaPagamento.text.trim(),
      'observacao': _observacao.text.trim().isEmpty
          ? null
          : _observacao.text.trim(),
      'anexos': _anexos.map((a) => a.toJson()).toList(),
      // origem só na CRIAÇÃO (anti-desvio): sempre 'manual'. Na edição não tocamos.
      if (!_isEdit) 'origem': OrigemLancamento.manual.wire,
    };
    try {
      final repo = ref.read(financeiroRepositoryProvider);
      if (_isEdit) {
        await repo.updateLancamento(widget.editing!.id, data);
      } else {
        await repo.createLancamento(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Não foi possível salvar o lançamento.';
        });
      }
    }
  }

  Future<void> _addAnexo() async {
    final result = await showDialog<Anexo>(
      context: context,
      builder: (_) => const _AnexoDialog(),
    );
    if (result != null) setState(() => _anexos.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];

    // Categorias do tipo atual (raiz + sub) — o picker monta a árvore.
    final catsDoTipo =
        categorias.where((c) => c.tipo == _tipo && !c.arquivada).toList();

    return FinModalScaffold(
      title: _isEdit ? 'Editar lançamento' : 'Novo lançamento',
      saving: _saving,
      error: _saveError,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tipo (receita/despesa).
          SegmentedButton<TipoLancamento>(
            segments: const [
              ButtonSegment(
                value: TipoLancamento.despesa,
                label: Text('Despesa'),
                icon: Icon(Icons.south_west_rounded, size: 16),
              ),
              ButtonSegment(
                value: TipoLancamento.receita,
                label: Text('Receita'),
                icon: Icon(Icons.north_east_rounded, size: 16),
              ),
            ],
            selected: {_tipo},
            showSelectedIcon: false,
            onSelectionChanged: _saving
                ? null
                : (s) => setState(() {
                    _tipo = s.first;
                    // Categorias são por tipo → limpa a seleção.
                    _categoriaId = null;
                    _subcategoriaId = null;
                  }),
          ),
          const SizedBox(height: ClxSpace.x4),
          FinField(
            label: 'Descrição',
            controller: _descricao,
            required: true,
            enabled: !_saving,
            hint: 'Ex.: Compra de material, Recebimento cliente',
            error: _errs['descricao'],
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _clearErr('descricao'),
          ),
          FinTwoCol(
            FinField(
              label: 'Valor',
              controller: _valor,
              required: true,
              enabled: !_saving,
              prefix: 'R\$ ',
              hint: '0,00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              error: _errs['valor'],
              onChanged: (_) => _clearErr('valor'),
            ),
            FinDateField(
              label: 'Data',
              controller: _data,
              required: true,
              enabled: !_saving,
              error: _errs['data'],
            ),
          ),
          FinTwoCol(
            FinDropdown<String>(
              label: 'Conta',
              required: true,
              value: _contaId,
              enabled: !_saving,
              error: _errs['conta'],
              hint: contas.isEmpty ? 'Nenhuma carteira' : 'Selecione…',
              items: contas.map((c) => c.id).toList(),
              itemLabel: (id) => contas
                  .firstWhere(
                    (c) => c.id == id,
                    orElse: () => FinConta(id: id, nome: id),
                  )
                  .nome,
              onChanged: (v) => setState(() {
                _contaId = v;
                _clearErr('conta');
              }),
            ),
            FinDropdown<LancamentoStatus>(
              label: 'Status',
              value: _status,
              enabled: !_saving,
              items: LancamentoStatus.values,
              itemLabel: statusLancamentoLabel,
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ),
          FinCategoriaTreePicker(
            categorias: catsDoTipo,
            categoriaId: _categoriaId,
            subcategoriaId: _subcategoriaId,
            required: true,
            enabled: !_saving,
            error: _errs['categoria'],
            onChanged: (catId, subId) => setState(() {
              _categoriaId = catId;
              _subcategoriaId = subId;
              _clearErr('categoria');
            }),
          ),
          FinTwoCol(
            FinDateField(
              label: 'Vencimento (opcional)',
              controller: _vencimento,
              enabled: !_saving,
            ),
            FinDropdown<RecorrenciaTipo>(
              label: 'Recorrência',
              value: _recorrencia,
              enabled: !_saving,
              items: RecorrenciaTipo.values,
              itemLabel: recorrenciaLabel,
              onChanged: (v) =>
                  setState(() => _recorrencia = v ?? _recorrencia),
            ),
          ),
          // Parcelas (só quando recorrência = Parcelada). As parcelas seguintes
          // não são geradas aqui (mesma decisão do web).
          if (_recorrencia == RecorrenciaTipo.parcelada) ...[
            FinTwoCol(
              FinField(
                label: 'Parcela atual',
                controller: _parcelaAtual,
                enabled: !_saving,
                hint: '1',
                keyboardType: TextInputType.number,
                onChanged: (_) => _clearErr('parcelas'),
              ),
              FinField(
                label: 'Total de parcelas',
                controller: _parcelasTotal,
                enabled: !_saving,
                hint: '2',
                keyboardType: TextInputType.number,
                onChanged: (_) => _clearErr('parcelas'),
              ),
            ),
            if (_errs['parcelas'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                child: Text(
                  _errs['parcelas']!,
                  style: tt.bodyMedium?.copyWith(color: clx.error),
                ),
              ),
          ],
          FinField(
            label: 'Forma de pagamento (opcional)',
            controller: _formaPagamento,
            enabled: !_saving,
            hint: 'Pix, Crédito, Dinheiro…',
          ),
          FinField(
            label: 'Tags (opcional)',
            controller: _tags,
            enabled: !_saving,
            hint: 'separe, por, vírgulas',
          ),
          FinField(
            label: 'Observação (opcional)',
            controller: _observacao,
            enabled: !_saving,
            maxLines: 2,
            hint: 'Notas adicionais…',
          ),
          if (_isEdit && widget.editing!.origem == OrigemLancamento.viaOs)
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x4),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 15, color: clx.info),
                  const SizedBox(width: ClxSpace.x2),
                  Expanded(
                    child: Text(
                      'Gerado pela OS ${widget.editing!.osNumero ?? ''} — '
                      'o vínculo é preservado.',
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ),
                ],
              ),
            ),
          _anexosSection(clx, tt),
        ],
      ),
    );
  }

  void _clearErr(String key) {
    if (_errs.containsKey(key)) setState(() => _errs.remove(key));
  }

  Widget _anexosSection(CleanoxColors clx, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Anexos',
              style: tt.bodyMedium?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _saving ? null : _addAnexo,
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Anexar'),
            ),
          ],
        ),
        if (_anexos.isEmpty)
          Text(
            'Nenhum comprovante anexado.',
            style: tt.bodyMedium?.copyWith(color: clx.ink3),
          )
        else
          for (var i = 0; i < _anexos.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: ClxSpace.x1),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 16, color: clx.ink3),
                  const SizedBox(width: ClxSpace.x2),
                  Expanded(
                    child: Text(
                      _anexos[i].nome.isEmpty
                          ? _anexos[i].url
                          : _anexos[i].nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    icon: Icon(Icons.close_rounded, size: 16, color: clx.ink3),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _anexos.removeAt(i)),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Diálogo simples para anexar um comprovante por nome + URL (o campo `anexos` é
/// JSON no PB; upload de arquivo nativo exigiria `file_picker` — fora do escopo).
class _AnexoDialog extends StatefulWidget {
  const _AnexoDialog();

  @override
  State<_AnexoDialog> createState() => _AnexoDialogState();
}

class _AnexoDialogState extends State<_AnexoDialog> {
  final _nome = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anexar comprovante'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FinField(label: 'Nome', controller: _nome, hint: 'Ex.: Nota fiscal'),
          FinField(
            label: 'URL',
            controller: _url,
            required: true,
            hint: 'https://…',
            keyboardType: TextInputType.url,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final url = _url.text.trim();
            if (url.isEmpty) return;
            Navigator.pop(
              context,
              Anexo(
                id: 'a${DateTime.now().microsecondsSinceEpoch}',
                nome: _nome.text.trim(),
                url: url,
              ),
            );
          },
          child: const Text('Anexar'),
        ),
      ],
    );
  }
}
