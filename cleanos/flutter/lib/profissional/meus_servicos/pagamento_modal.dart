/// pagamento_modal.dart — Modal de "registrar pagamento" (bottom sheet mobile).
///
/// Valor cobrado **por linha** (principal + extras) + forma de pagamento.
/// A soma vira `valor_pago` (base da comissão e do caixa). O profissional
/// pode negociar abaixo da tabela — os valores por linha são gravados de
/// volta em `valor_servico` / `adicionais[].valor`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/os_execucao.dart';

/// Resultado do modal de pagamento.
class PagamentoResult {
  const PagamentoResult({
    required this.valorPago,
    required this.forma,
    required this.outro,
    required this.valorServico,
    required this.adicionais,
  });

  final double valorPago;
  final FormaPagamento forma;
  final String outro;

  /// Valor cobrado do serviço principal (negociável).
  final double valorServico;

  /// Lista completa de adicionais com valores cobrados atualizados.
  final List<ServicoAdicionalOS> adicionais;
}

/// Abre o sheet de pagamento. [onSubmit] persiste (pode lançar).
Future<void> showPagamentoModal(
  BuildContext context, {
  required OrdemServico os,
  required Future<void> Function(PagamentoResult result) onSubmit,
}) {
  return showClxSheet<void>(
    context,
    title: 'Registrar pagamento',
    child: _PagamentoForm(os: os, onSubmit: onSubmit),
  );
}

String _fmtValor(double v) =>
    v > 0 || v == 0 ? v.toStringAsFixed(2).replaceAll('.', ',') : '';

double? _parseValor(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final n = double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
  return n;
}

class _PagamentoForm extends StatefulWidget {
  const _PagamentoForm({required this.os, required this.onSubmit});

  final OrdemServico os;
  final Future<void> Function(PagamentoResult result) onSubmit;

  @override
  State<_PagamentoForm> createState() => _PagamentoFormState();
}

class _PagamentoFormState extends State<_PagamentoForm> {
  late final TextEditingController _principalCtrl;
  late final List<TextEditingController> _extraCtrls;
  late final List<ServicoAdicionalOS> _extrasCobraveis;
  late final TextEditingController _outroCtrl;
  FormaPagamento? _forma;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final os = widget.os;
    _extrasCobraveis = [
      for (final a in os.adicionais)
        if (a.aprovacao == AprovacaoStatus.aprovado ||
            a.aprovacao == AprovacaoStatus.naoRequer)
          a,
    ];

    // Se já há valor_pago e bate com a tabela, usa tabela; se há pago
    // diferente, pré-preenche principal com valor_servico e extras com
    // tabela (usuário ajusta). Se valor_pago == valorTotal, linhas = tabela.
    final principal = os.valorServico ?? 0;
    _principalCtrl = TextEditingController(text: _fmtValor(principal));
    _extraCtrls = [
      for (final a in _extrasCobraveis)
        TextEditingController(text: _fmtValor(a.valor * a.quantidade)),
    ];
    // Se já registrou um total diferente e só tem 1 linha (sem extras),
    // preenche a linha com o valor pago.
    if (_extrasCobraveis.isEmpty &&
        (os.valorPago ?? 0) > 0 &&
        ((os.valorPago! - principal).abs() > 0.009)) {
      _principalCtrl.text = _fmtValor(os.valorPago!);
    }

    _outroCtrl = TextEditingController(
      text: os.formaPagamentoOutro ?? '',
    );
    _forma = os.formaPagamento;
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    for (final c in _extraCtrls) {
      c.dispose();
    }
    _outroCtrl.dispose();
    super.dispose();
  }

  double _valorUnitarioExtra(ServicoAdicionalOS a, double subtotal) {
    final q = a.quantidade <= 0 ? 1 : a.quantidade;
    return ((subtotal / q) * 100).roundToDouble() / 100;
  }

  double get _totalLinhas {
    final p = _parseValor(_principalCtrl.text) ?? 0;
    var sum = p;
    for (final c in _extraCtrls) {
      sum += _parseValor(c.text) ?? 0;
    }
    // descontos de tabela ainda reduzem? Orçamento os.descontos: o total
    // cobrado é a soma das linhas (já negociadas). Não subtrai de novo.
    return (sum * 100).roundToDouble() / 100;
  }

  void _usarTabela() {
    setState(() {
      _principalCtrl.text = _fmtValor(widget.os.valorServico ?? 0);
      for (var i = 0; i < _extrasCobraveis.length; i++) {
        final a = _extrasCobraveis[i];
        _extraCtrls[i].text = _fmtValor(a.valor * a.quantidade);
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    final principal = _parseValor(_principalCtrl.text);
    // Campo vazio em OS refazer = R$ 0 (cortesia/garantia).
    final principalEmpty = _principalCtrl.text.trim().isEmpty;
    final principalValor = principalEmpty && widget.os.refazer
        ? 0.0
        : (principal ?? -1);

    if (principalValor < 0) {
      setState(() => _error = 'Informe o valor do serviço principal.');
      return;
    }

    final extrasValores = <double>[];
    for (var i = 0; i < _extraCtrls.length; i++) {
      final v = _parseValor(_extraCtrls[i].text);
      if (v == null || v < 0) {
        setState(() => _error = 'Informe o valor de cada serviço extra.');
        return;
      }
      extrasValores.add(v);
    }

    final total = _totalLinhas;
    // Refazer aceita valor 0; OS normal exige valor > 0.
    if (total < 0 || (total == 0 && !widget.os.refazer)) {
      setState(() => _error = 'Informe o valor pago.');
      return;
    }
    if (total > 0 && _forma == null) {
      setState(() => _error = 'Selecione a forma de pagamento.');
      return;
    }
    final forma = _forma ?? FormaPagamento.outros;
    final outro = forma == FormaPagamento.outros
        ? (total <= 0 && widget.os.refazer
              ? (_outroCtrl.text.trim().isEmpty
                    ? 'Refazer / sem cobrança'
                    : _outroCtrl.text.trim())
              : _outroCtrl.text.trim())
        : '';
    if (total > 0 && forma == FormaPagamento.outros && outro.isEmpty) {
      setState(() => _error = 'Descreva a forma de pagamento em "Outros".');
      return;
    }

    // Atualiza valores unitários dos extras (subtotal / quantidade).
    final novosAdicionais = <ServicoAdicionalOS>[
      for (final a in widget.os.adicionais)
        if (_extrasCobraveis.any((e) => e.id == a.id))
          a.copyWith(
            valor: _valorUnitarioExtra(
              a,
              extrasValores[_extrasCobraveis.indexWhere((e) => e.id == a.id)],
            ),
          )
        else
          a,
    ];

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        PagamentoResult(
          valorPago: total,
          forma: forma,
          outro: outro,
          valorServico: principalValor,
          adicionais: novosAdicionais,
        ),
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (err) {
      if (mounted) {
        setState(() => _error = describeOSError(err).message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final os = widget.os;
    final principalNome = (os.tipoServicoNome ?? '').trim().isEmpty
        ? 'Serviço principal'
        : os.tipoServicoNome!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: ClxSpace.x4),
        ],
        if (os.refazer) ...[
          Text(
            'OS de Refazer: R\$ 0,00 é permitido (garantia/cortesia).',
            style: tt.bodySmall?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x3),
        ] else ...[
          Text(
            'Informe o valor cobrado em cada serviço. A comissão usa o '
            'total registrado (pode negociar abaixo da tabela).',
            style: tt.bodySmall?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x3),
        ],

        // Linhas editáveis
        _linhaEditavel(
          context,
          label: principalNome,
          tabela: os.valorServico ?? 0,
          controller: _principalCtrl,
        ),
        for (var i = 0; i < _extrasCobraveis.length; i++) ...[
          const SizedBox(height: ClxSpace.x2),
          _linhaEditavel(
            context,
            label: _extrasCobraveis[i].nome.isEmpty
                ? 'Serviço extra'
                : _extrasCobraveis[i].nome,
            tabela: _extrasCobraveis[i].valor * _extrasCobraveis[i].quantidade,
            controller: _extraCtrls[i],
          ),
        ],

        if (os.descontos > 0) ...[
          const SizedBox(height: ClxSpace.x2),
          Text(
            'Descontos de orçamento: ${formatCurrency(os.descontos)} '
            '(já negociados nas linhas acima se aplicável).',
            style: tt.bodySmall?.copyWith(color: clx.ink3),
          ),
        ],

        const SizedBox(height: ClxSpace.x3),
        Container(
          padding: const EdgeInsets.all(ClxSpace.x3),
          decoration: BoxDecoration(
            color: clx.bg2,
            borderRadius: ClxRadii.rMd,
            border: Border.all(color: clx.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total a registrar',
                  style: tt.labelLarge?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatCurrency(_totalLinhas),
                style: tt.labelLarge?.copyWith(
                  color: clx.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _loading ? null : _usarTabela,
            child: const Text('Usar preços de tabela'),
          ),
        ),

        const SizedBox(height: ClxSpace.x2),
        Text(
          'Forma de pagamento',
          style: tt.labelMedium?.copyWith(color: clx.ink2),
        ),
        const SizedBox(height: ClxSpace.x1),
        DropdownButtonFormField<FormaPagamento>(
          initialValue: _forma,
          isExpanded: true,
          decoration: const InputDecoration(),
          hint: const Text('Selecione…'),
          items: [
            for (final f in {
              ...FormaPagamento.selecionaveis,
              if (_forma != null) _forma!,
            })
              DropdownMenuItem(value: f, child: Text(f.label)),
          ],
          onChanged: _loading
              ? null
              : (v) => setState(() => _forma = v),
        ),
        if (_forma == FormaPagamento.outros) ...[
          const SizedBox(height: ClxSpace.x3),
          TextField(
            controller: _outroCtrl,
            enabled: !_loading,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'Qual? Ex.: transferência, cortesia…',
              counterText: '',
            ),
          ),
        ],
        const SizedBox(height: ClxSpace.x5),
        Row(
          children: [
            Expanded(
              child: ClxButton(
                label: 'Cancelar',
                variant: ClxButtonVariant.ghost,
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: ClxSpace.x3),
            Expanded(
              flex: 2,
              child: ClxButton(
                label: 'Salvar pagamento',
                icon: Icons.check_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _linhaEditavel(
    BuildContext context, {
    required String label,
    required double tabela,
    required TextEditingController controller,
  }) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tt.labelMedium?.copyWith(color: clx.ink2),
              ),
            ),
            if (tabela > 0)
              Text(
                'Tabela: ${formatCurrency(tabela)}',
                style: tt.bodySmall?.copyWith(color: clx.ink3),
              ),
          ],
        ),
        const SizedBox(height: ClxSpace.x1),
        TextField(
          controller: controller,
          enabled: !_loading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(hintText: '0,00'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
