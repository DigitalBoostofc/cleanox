/// pagamento_modal.dart — Modal de "registrar pagamento" (bottom sheet mobile).
///
/// Porte do modal de pagamento de `MeusServicos.tsx`: valor pago + forma de
/// pagamento, com validação. `onSubmit` faz o PATCH (via controller) e pode
/// lançar — o erro é mostrado dentro do sheet; em sucesso, fecha.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';

/// Abre o sheet de pagamento. [onSubmit] persiste (pode lançar).
Future<void> showPagamentoModal(
  BuildContext context, {
  required OrdemServico os,
  required Future<void> Function(double valor, FormaPagamento forma) onSubmit,
}) {
  return showClxSheet<void>(
    context,
    title: 'Registrar pagamento',
    child: _PagamentoForm(os: os, onSubmit: onSubmit),
  );
}

class _PagamentoForm extends StatefulWidget {
  const _PagamentoForm({required this.os, required this.onSubmit});

  final OrdemServico os;
  final Future<void> Function(double valor, FormaPagamento forma) onSubmit;

  @override
  State<_PagamentoForm> createState() => _PagamentoFormState();
}

class _PagamentoFormState extends State<_PagamentoForm> {
  late final TextEditingController _valorCtrl;
  FormaPagamento? _forma;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final valor = widget.os.valorServico ?? 0;
    _valorCtrl = TextEditingController(
      text: valor > 0 ? valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _forma = widget.os.formaPagamento;
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final raw = _valorCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(raw) ?? 0;
    if (valor <= 0) {
      setState(() => _error = 'Informe o valor pago.');
      return;
    }
    if (_forma == null) {
      setState(() => _error = 'Selecione a forma de pagamento.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(valor, _forma!);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: ClxSpace.x4),
        ],
        Text(
          'Valor pago (R\$)',
          style: tt.labelMedium?.copyWith(color: clx.ink2),
        ),
        const SizedBox(height: ClxSpace.x1),
        TextField(
          controller: _valorCtrl,
          enabled: !_loading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(hintText: '0,00'),
        ),
        const SizedBox(height: ClxSpace.x4),
        Text(
          'Forma de pagamento',
          style: tt.labelMedium?.copyWith(color: clx.ink2),
        ),
        const SizedBox(height: ClxSpace.x1),
        DropdownButtonFormField<FormaPagamento>(
          initialValue: _forma,
          decoration: const InputDecoration(),
          hint: const Text('Selecione…'),
          items: [
            for (final f in FormaPagamento.values)
              DropdownMenuItem(value: f, child: Text(f.label)),
          ],
          onChanged: _loading ? null : (v) => setState(() => _forma = v),
        ),
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
