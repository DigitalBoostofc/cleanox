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
  late TipoLancamento _tipo;
  String? _contaId;
  String? _categoriaId;
  String? _subcategoriaId;
  late LancamentoStatus _status;
  late List<Anexo> _anexos;

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  // Extras recolhidos (estilo Organizze) — só abrem se o usuário pedir.
  bool _showRepetir = false;
  bool _showObs = false;
  bool _showAnexos = false;
  bool _showTags = false;
  bool _showAvancado = false;

  /// Painel "Repetir" (Organizze): fixa × parcelado + período.
  _RepetirModo _repetirModo = _RepetirModo.fixa;
  _PeriodoFreq _freqFixa = _PeriodoFreq.mensal;
  int _parcelasN = 2;
  _PeriodoFreq _parcelaUnidade = _PeriodoFreq.mensal;

  bool get _isEdit => widget.editing != null;

  String get _title {
    if (_isEdit) {
      return _tipo == TipoLancamento.receita
          ? 'Editar receita'
          : 'Editar despesa';
    }
    return _tipo == TipoLancamento.receita ? 'Nova receita' : 'Nova despesa';
  }

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
    _tipo = l?.tipo ?? widget.initialTipo ?? TipoLancamento.despesa;
    _contaId = l?.contaId.isNotEmpty == true ? l!.contaId : null;
    _categoriaId = l?.categoriaId.isNotEmpty == true ? l!.categoriaId : null;
    _subcategoriaId = l?.subcategoriaId;
    // Novo lançamento: default PAGO (lançamento rápido, como Organizze).
    _status = l?.status ?? LancamentoStatus.pago;
    _anexos = List<Anexo>.from(l?.anexos ?? const []);
    // Na edição, abre seções que já têm conteúdo.
    if (l != null) {
      _showRepetir = l.recorrencia != RecorrenciaTipo.unica;
      _showObs = (l.observacao?.trim().isNotEmpty ?? false);
      _showTags = l.tags.isNotEmpty;
      _showAnexos = l.anexos.isNotEmpty;
      _showAvancado = l.status != LancamentoStatus.pago ||
          (l.vencimento?.isNotEmpty ?? false) ||
          (l.formaPagamento?.isNotEmpty ?? false);
      if (l.recorrencia == RecorrenciaTipo.parcelada) {
        _repetirModo = _RepetirModo.parcelada;
        _parcelasN = (l.parcelasTotal != null && l.parcelasTotal! >= 2)
            ? l.parcelasTotal!
            : 2;
      } else if (l.recorrencia == RecorrenciaTipo.fixa ||
          l.recorrencia == RecorrenciaTipo.recorrente) {
        _repetirModo = _RepetirModo.fixa;
        _freqFixa = _periodoFromFrequencia(l.frequenciaEfetiva);
      }
    }
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
    super.dispose();
  }

  /// Recorrência efetiva a gravar (unica se o painel estiver fechado).
  RecorrenciaTipo get _recorrenciaEfetiva {
    if (!_showRepetir) return RecorrenciaTipo.unica;
    return _repetirModo == _RepetirModo.fixa
        ? RecorrenciaTipo.fixa
        : RecorrenciaTipo.parcelada;
  }

  /// [andAnother]: salva e limpa o form (só criação), sem fechar o modal.
  Future<void> _save({bool andAnother = false}) async {
    final errs = <String, String>{};
    if (_descricao.text.trim().isEmpty) {
      errs['descricao'] = 'Descrição é obrigatória';
    }
    final valor = parseMoedaBr(_valor.text);
    if (valor == null || valor <= 0) errs['valor'] = 'Informe um valor válido';
    if (_data.text.trim().isEmpty) errs['data'] = 'Data é obrigatória';
    if (_contaId == null) errs['conta'] = 'Escolha uma conta';
    if (_categoriaId == null) errs['categoria'] = 'Escolha uma categoria';
    if (_showRepetir &&
        _repetirModo == _RepetirModo.parcelada &&
        _parcelasN < 2) {
      errs['parcelas'] = 'Informe ao menos 2 parcelas';
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

    final rec = _recorrenciaEfetiva;
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final baseBody = <String, dynamic>{
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
      'recorrencia': rec.wire,
      // Frequência da série (semanal, mensal…) — só em fixa/recorrente.
      'frequencia': (rec == RecorrenciaTipo.fixa ||
              rec == RecorrenciaTipo.recorrente)
          ? _frequenciaFromPeriodo(_freqFixa).wire
          : null,
      if (rec == RecorrenciaTipo.parcelada) ...{
        'parcela_atual': _isEdit ? (widget.editing!.parcelaAtual ?? 1) : 1,
        'parcelas_total': _parcelasN,
      } else ...{
        'parcela_atual': null,
        'parcelas_total': null,
      },
      'tags': tags,
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
        await repo.updateLancamento(widget.editing!.id, baseBody);
      } else if (rec == RecorrenciaTipo.parcelada) {
        // Cria TODAS as parcelas (Organizze): divide o valor e avança a data.
        final valores = _dividirParcelas(valor!, _parcelasN);
        final baseDate = _parseYmd(_data.text.trim()) ?? DateTime.now();
        final baseVenc = _vencimento.text.trim().isEmpty
            ? null
            : _parseYmd(_vencimento.text.trim());
        for (var i = 0; i < _parcelasN; i++) {
          final dataI = _formatYmd(
            _addPeriodo(baseDate, i, _parcelaUnidade),
          );
          final vencI = baseVenc == null
              ? null
              : _formatYmd(_addPeriodo(baseVenc, i, _parcelaUnidade));
          await repo.createLancamento({
            ...baseBody,
            'valor': valores[i],
            'data': dataI,
            'vencimento': vencI,
            'parcela_atual': i + 1,
            'parcelas_total': _parcelasN,
            // 1ª parcela herda o status escolhido; demais ficam previstas.
            'status': i == 0
                ? _status.wire
                : LancamentoStatus.previsto.wire,
          });
        }
      } else {
        final criado = await repo.createLancamento(baseBody);
        // Fixa/recorrente: já cria os próximos 12 meses como previstos.
        if (rec == RecorrenciaTipo.fixa || rec == RecorrenciaTipo.recorrente) {
          await repo.materializarRecorrenciaAFrente(criado);
        }
      }
      if (!mounted) return;
      if (andAnother && !_isEdit) {
        // Mantém data/conta/categoria; limpa o que muda a cada lançamento.
        setState(() {
          _descricao.clear();
          _valor.clear();
          _observacao.clear();
          _tags.clear();
          _formaPagamento.clear();
          _vencimento.clear();
          _anexos = [];
          _showObs = false;
          _showTags = false;
          _showAnexos = false;
          _showRepetir = false;
          _showAvancado = false;
          _repetirModo = _RepetirModo.fixa;
          _freqFixa = _PeriodoFreq.mensal;
          _parcelasN = 2;
          _parcelaUnidade = _PeriodoFreq.mensal;
          _status = LancamentoStatus.pago;
          _saving = false;
        });
        return;
      }
      Navigator.of(context).pop(true);
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
    final contas = (ref.watch(finContasProvider).valueOrNull ?? const [])
        .where((c) => c.ativo)
        .toList();
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];

    // Auto-seleciona a única/primeira conta ativa (Organizze pré-preenche).
    if (_contaId == null && contas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _contaId == null && contas.isNotEmpty) {
          setState(() => _contaId = contas.first.id);
        }
      });
    }

    final catsDoTipo =
        categorias.where((c) => c.tipo == _tipo && !c.arquivada).toList();

    return FinModalScaffold(
      title: _title,
      saving: _saving,
      error: _saveError,
      onSave: () => _save(),
      organizzeFooter: true,
      onSaveAndAnother: _isEdit ? null : () => _save(andAnother: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Troca despesa/receita só se o form não veio com tipo pré-fixo
          // (atalhos da visão geral já fixam o tipo).
          if (!_isEdit && widget.initialTipo == null) ...[
            SegmentedButton<TipoLancamento>(
              segments: const [
                ButtonSegment(
                  value: TipoLancamento.despesa,
                  label: Text('Despesa'),
                  icon: Icon(Icons.remove_rounded, size: 16),
                ),
                ButtonSegment(
                  value: TipoLancamento.receita,
                  label: Text('Receita'),
                  icon: Icon(Icons.add_rounded, size: 16),
                ),
              ],
              selected: {_tipo},
              showSelectedIcon: false,
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() {
                      _tipo = s.first;
                      _categoriaId = null;
                      _subcategoriaId = null;
                    }),
            ),
            const SizedBox(height: ClxSpace.x4),
          ],
          // ── Essencial (Organizze) ────────────────────────────────────
          FinField(
            label: 'Descrição',
            controller: _descricao,
            required: true,
            enabled: !_saving,
            hint: 'O que é este lançamento?',
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
          ),
          // ── Extras em ícones (Organizze: Repetir / Obs / Anexo / Tags) ─
          Padding(
            padding: const EdgeInsets.only(
              top: ClxSpace.x2,
              bottom: ClxSpace.x3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ExtraChip(
                  icon: Icons.repeat_rounded,
                  label: 'Repetir',
                  active: _showRepetir,
                  onTap: () => setState(() {
                    _showRepetir = !_showRepetir;
                    // Ao abrir, default Organizze: fixa mensal.
                    if (_showRepetir &&
                        _repetirModo == _RepetirModo.fixa &&
                        !_isEdit) {
                      _freqFixa = _PeriodoFreq.mensal;
                    }
                  }),
                ),
                _ExtraChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Observação',
                  active: _showObs,
                  onTap: () => setState(() => _showObs = !_showObs),
                ),
                _ExtraChip(
                  icon: Icons.attach_file_rounded,
                  label: 'Anexo',
                  active: _showAnexos,
                  onTap: () => setState(() => _showAnexos = !_showAnexos),
                ),
                _ExtraChip(
                  icon: Icons.sell_outlined,
                  label: 'Tags',
                  active: _showTags,
                  onTap: () => setState(() => _showTags = !_showTags),
                ),
                _ExtraChip(
                  icon: Icons.tune_rounded,
                  label: 'Mais',
                  active: _showAvancado,
                  onTap: () => setState(() => _showAvancado = !_showAvancado),
                ),
              ],
            ),
          ),
          if (_showRepetir) _repetirPanel(clx, tt),
          if (_showObs)
            FinField(
              label: 'Observação',
              controller: _observacao,
              enabled: !_saving,
              maxLines: 2,
              hint: 'Notas adicionais…',
            ),
          if (_showTags)
            FinField(
              label: 'Tags',
              controller: _tags,
              enabled: !_saving,
              hint: 'separe, por, vírgulas',
            ),
          if (_showAnexos) _anexosSection(clx, tt),
          if (_showAvancado) ...[
            FinTwoCol(
              FinDropdown<LancamentoStatus>(
                label: 'Status',
                value: _status,
                enabled: !_saving,
                items: LancamentoStatus.values,
                itemLabel: statusLancamentoLabel,
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              FinDateField(
                label: 'Vencimento',
                controller: _vencimento,
                enabled: !_saving,
              ),
            ),
            FinField(
              label: 'Forma de pagamento',
              controller: _formaPagamento,
              enabled: !_saving,
              hint: 'Pix, Crédito, Dinheiro…',
            ),
          ],
          if (_isEdit && widget.editing!.origem == OrigemLancamento.viaOs)
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x2),
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
        ],
      ),
    );
  }

  void _clearErr(String key) {
    if (_errs.containsKey(key)) setState(() => _errs.remove(key));
  }

  /// Painel "Repetir" estilo Organizze: rádio fixa/parcelado + dropdowns.
  Widget _repetirPanel(CleanoxColors clx, TextTheme tt) {
    final tipoNome =
        _tipo == TipoLancamento.receita ? 'receita' : 'despesa';
    final valor = parseMoedaBr(_valor.text);
    final valores = valor != null && valor > 0
        ? _dividirParcelas(valor, _parcelasN)
        : null;
    final parcelaFmt = valores == null
        ? null
        : formatCurrency(valores.first);

    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Repetir',
            style: tt.bodyMedium?.copyWith(
              color: clx.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          _RepetirRadio(
            selected: _repetirModo == _RepetirModo.fixa,
            label: 'é uma $tipoNome fixa',
            enabled: !_saving,
            onTap: () => setState(() => _repetirModo = _RepetirModo.fixa),
          ),
          _RepetirRadio(
            selected: _repetirModo == _RepetirModo.parcelada,
            label: 'é um lançamento parcelado em',
            enabled: !_saving,
            onTap: () =>
                setState(() => _repetirModo = _RepetirModo.parcelada),
          ),
          const SizedBox(height: ClxSpace.x2),
          if (_repetirModo == _RepetirModo.fixa)
            _OrgSelect<_PeriodoFreq>(
              value: _freqFixa,
              enabled: !_saving,
              items: _PeriodoFreq.values,
              itemLabel: (p) => p.labelSingular,
              onChanged: (v) => setState(() => _freqFixa = v),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _OrgSelect<int>(
                    value: _parcelasN,
                    enabled: !_saving,
                    items: List<int>.generate(47, (i) => i + 2), // 2..48
                    itemLabel: (n) => '$n',
                    onChanged: (v) => setState(() {
                      _parcelasN = v;
                      _clearErr('parcelas');
                    }),
                  ),
                ),
                const SizedBox(width: ClxSpace.x2),
                Expanded(
                  flex: 3,
                  child: _OrgSelect<_PeriodoFreq>(
                    value: _parcelaUnidade,
                    enabled: !_saving,
                    items: _PeriodoFreq.values,
                    itemLabel: (p) => p.labelPlural,
                    onChanged: (v) => setState(() => _parcelaUnidade = v),
                  ),
                ),
              ],
            ),
            if (_errs['parcelas'] != null)
              Padding(
                padding: const EdgeInsets.only(top: ClxSpace.x1),
                child: Text(
                  _errs['parcelas']!,
                  style: tt.bodyMedium?.copyWith(color: clx.error),
                ),
              ),
            if (parcelaFmt != null) ...[
              const SizedBox(height: ClxSpace.x2),
              Text(
                'Serão lançadas $_parcelasN parcelas de $parcelaFmt.',
                style: tt.bodyMedium?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Em caso de divisão não exata, a sobra será somada à primeira '
                'parcela.',
                style: tt.bodySmall?.copyWith(color: clx.ink3),
              ),
            ],
          ],
        ],
      ),
    );
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

/* ─────────────────────── Repetir (Organizze) ─────────────────────── */

enum _RepetirModo { fixa, parcelada }

/// Frequência / unidade de período (mesmos valores, rótulos singular e plural).
enum _PeriodoFreq {
  anual,
  semestral,
  trimestral,
  bimestral,
  mensal,
  quinzenal,
  semanal,
  diario;

  String get labelSingular => switch (this) {
        anual => 'Anual',
        semestral => 'Semestral',
        trimestral => 'Trimestral',
        bimestral => 'Bimestral',
        mensal => 'Mensal',
        quinzenal => 'Quinzenal',
        semanal => 'Semanal',
        diario => 'Diário',
      };

  String get labelPlural => switch (this) {
        anual => 'Anos',
        semestral => 'Semestres',
        trimestral => 'Trimestres',
        bimestral => 'Bimestres',
        mensal => 'Meses',
        quinzenal => 'Quinzenas',
        semanal => 'Semanas',
        diario => 'Dias',
      };
}

FrequenciaRecorrencia _frequenciaFromPeriodo(_PeriodoFreq p) => switch (p) {
      _PeriodoFreq.diario => FrequenciaRecorrencia.diario,
      _PeriodoFreq.semanal => FrequenciaRecorrencia.semanal,
      _PeriodoFreq.quinzenal => FrequenciaRecorrencia.quinzenal,
      _PeriodoFreq.mensal => FrequenciaRecorrencia.mensal,
      _PeriodoFreq.bimestral => FrequenciaRecorrencia.bimestral,
      _PeriodoFreq.trimestral => FrequenciaRecorrencia.trimestral,
      _PeriodoFreq.semestral => FrequenciaRecorrencia.semestral,
      _PeriodoFreq.anual => FrequenciaRecorrencia.anual,
    };

_PeriodoFreq _periodoFromFrequencia(FrequenciaRecorrencia f) => switch (f) {
      FrequenciaRecorrencia.diario => _PeriodoFreq.diario,
      FrequenciaRecorrencia.semanal => _PeriodoFreq.semanal,
      FrequenciaRecorrencia.quinzenal => _PeriodoFreq.quinzenal,
      FrequenciaRecorrencia.mensal => _PeriodoFreq.mensal,
      FrequenciaRecorrencia.bimestral => _PeriodoFreq.bimestral,
      FrequenciaRecorrencia.trimestral => _PeriodoFreq.trimestral,
      FrequenciaRecorrencia.semestral => _PeriodoFreq.semestral,
      FrequenciaRecorrencia.anual => _PeriodoFreq.anual,
    };

/// Divide [total] em [n] parcelas em centavos; sobra na 1ª (Organizze).
List<double> _dividirParcelas(double total, int n) {
  if (n < 1) return [total];
  final cents = (total * 100).round();
  final base = cents ~/ n;
  final resto = cents - base * n;
  return [
    for (var i = 0; i < n; i++) (base + (i == 0 ? resto : 0)) / 100.0,
  ];
}

DateTime? _parseYmd(String s) {
  if (s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(5, 7));
  final d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _formatYmd(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)}';
}

DateTime _addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final y = d.year + total ~/ 12;
  final mo = total % 12 + 1;
  final lastDay = DateTime(y, mo + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(y, mo, day);
}

DateTime _addPeriodo(DateTime d, int steps, _PeriodoFreq p) {
  if (steps == 0) return d;
  return switch (p) {
    _PeriodoFreq.diario => d.add(Duration(days: steps)),
    _PeriodoFreq.semanal => d.add(Duration(days: 7 * steps)),
    _PeriodoFreq.quinzenal => d.add(Duration(days: 15 * steps)),
    _PeriodoFreq.mensal => _addMonths(d, steps),
    _PeriodoFreq.bimestral => _addMonths(d, steps * 2),
    _PeriodoFreq.trimestral => _addMonths(d, steps * 3),
    _PeriodoFreq.semestral => _addMonths(d, steps * 6),
    _PeriodoFreq.anual => _addMonths(d, steps * 12),
  };
}

/// Rádio compacto (check verde quando selecionado).
class _RepetirRadio extends StatelessWidget {
  const _RepetirRadio({
    required this.selected,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: ClxRadii.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 22,
              color: selected ? clx.success : clx.ink3,
            ),
            const SizedBox(width: ClxSpace.x2),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: clx.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown compacto com borda (estilo select do Organizze).
class _OrgSelect<T> extends StatelessWidget {
  const _OrgSelect({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        filled: true,
        fillColor: clx.bg,
        border: OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: BorderSide(color: clx.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: BorderSide(color: clx.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: BorderSide(color: clx.primary, width: 1.5),
        ),
      ),
      items: [
        for (final it in items)
          DropdownMenuItem<T>(
            value: it,
            child: Text(
              itemLabel(it),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
    );
  }
}

/// Chip circular de extra (Repetir / Obs / Anexo / Tags / Mais).
class _ExtraChip extends StatelessWidget {
  const _ExtraChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final fg = active ? clx.primary : clx.ink3;
    final bg = active
        ? clx.primary.withValues(alpha: 0.14)
        : clx.bg2;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rLg,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? clx.primary : clx.line,
                ),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
