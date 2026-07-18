/// cancelar_os_dialog.dart — Dialog de cancelamento de OS com motivo.
///
/// Usado no app do profissional e no painel (admin/gerente). Devolve o texto
/// do motivo ou null se cancelar o dialog.
library;

import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../core/models/ordem_servico.dart';

/// Abre o dialog; retorna o motivo trimado ou null.
Future<String?> showCancelarOsDialog(
  BuildContext context, {
  required OrdemServico os,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CancelarOsDialog(os: os),
  );
}

class _CancelarOsDialog extends StatefulWidget {
  const _CancelarOsDialog({required this.os});
  final OrdemServico os;

  @override
  State<_CancelarOsDialog> createState() => _CancelarOsDialogState();
}

class _CancelarOsDialogState extends State<_CancelarOsDialog> {
  final _ctrl = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final m = _ctrl.text.trim();
    if (m.isEmpty) {
      setState(() => _erro = 'Informe o motivo do cancelamento.');
      return;
    }
    if (m.length < 3) {
      setState(() => _erro = 'Motivo muito curto (mín. 3 caracteres).');
      return;
    }
    Navigator.of(context).pop(m);
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final nome = widget.os.nomeCurto.isNotEmpty
        ? widget.os.nomeCurto
        : 'esta OS';

    return AlertDialog(
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: const Text('Cancelar OS'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cancelar o serviço de $nome?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
              ),
            ),
            const SizedBox(height: ClxSpace.x3),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              maxLength: 1000,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Motivo do cancelamento *',
                hintText: 'Ex.: cliente pediu reagendamento, endereço errado…',
                border: const OutlineInputBorder(),
                errorText: _erro,
                alignLabelWithHint: true,
              ),
              onChanged: (_) {
                if (_erro != null) setState(() => _erro = null);
              },
            ),
            Text(
              'Será registrado quem cancelou e o motivo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: clx.ink3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ClxButton(
          label: 'Voltar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ClxButton(
          label: 'Cancelar OS',
          variant: ClxButtonVariant.danger,
          icon: Icons.cancel_outlined,
          onPressed: _confirmar,
        ),
      ],
    );
  }
}
