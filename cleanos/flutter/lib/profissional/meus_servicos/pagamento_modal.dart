/// pagamento_modal.dart — Registrar pagamento (sheet).
///
/// Um campo editável: **Valor pago**. Orçamento total (soma dos serviços da OS)
/// é só informação. Comissão e caixa usam `valor_pago`.
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

  /// Orçamento do principal — o modal não renegocia linhas.
  final double valorServico;

  /// Adicionais originais — o modal não renegocia linhas.
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

String _fmtValor(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

double? _parseValor(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
}

class _PagamentoForm extends StatefulWidget {
  const _PagamentoForm({required this.os, required this.onSubmit});

  final OrdemServico os;
  final Future<void> Function(PagamentoResult result) onSubmit;

  @override
  State<_PagamentoForm> createState() => _PagamentoFormState();
}

class _PagamentoFormState extends State<_PagamentoForm> {
  late final TextEditingController _pagoCtrl;
  late final TextEditingController _outroCtrl;
  FormaPagamento? _forma;
  bool _loading = false;
  String? _error;

  double get _orcamento => widget.os.valorTotal;

  @override
  void initState() {
    super.initState();
    final pago = widget.os.valorPago ?? 0;
    _pagoCtrl = TextEditingController(
      text: _fmtValor(pago > 0 ? pago : _orcamento),
    );
    _outroCtrl = TextEditingController(text: widget.os.formaPagamentoOutro ?? '');
    _forma = widget.os.formaPagamento;
  }

  @override
  void dispose() {
    _pagoCtrl.dispose();
    _outroCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final parsed = _parseValor(_pagoCtrl.text);
    final empty = _pagoCtrl.text.trim().isEmpty;
    final total = empty && widget.os.refazer ? 0.0 : (parsed ?? -1);
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

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        PagamentoResult(
          valorPago: (total * 100).roundToDouble() / 100,
          forma: forma,
          outro: outro,
          valorServico: widget.os.valorServico ?? 0,
          adicionais: widget.os.adicionais,
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
          const SizedBox(height: ClxSpace.x4),
        ],
        Text(
          'Orçamento total = ${formatCurrency(_orcamento)}',
          key: const ValueKey('pag-orcamento-total'),
          style: tt.titleSmall?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Soma total dos serviços adicionados nessa OS.',
          style: tt.bodySmall?.copyWith(color: clx.ink3),
        ),
        const SizedBox(height: ClxSpace.x4),
        Text(
          'Valor pago',
          style: tt.labelMedium?.copyWith(color: clx.ink2),
        ),
        const SizedBox(height: ClxSpace.x1),
        TextField(
          key: const ValueKey('pag-valor-pago'),
          controller: _pagoCtrl,
          enabled: !_loading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(hintText: '0,00'),
        ),
        const SizedBox(height: ClxSpace.x3),
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
          onChanged: _loading ? null : (v) => setState(() => _forma = v),
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
}
