/// fin_form_kit.dart — Campos de formulário reutilizáveis do Financeiro.
///
/// Um só lugar para: parse/format de dinheiro BR (vírgula decimal), campo de
/// texto rotulado com erro, dropdown rotulado, campo de data ('YYYY-MM-DD' de
/// parede — sem fuso, gate BRT) e o campo de dinheiro. Usados pelos 4 modais
/// (conta, categoria, lançamento, limite) — evita reescrever labels/validação.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';

/* ─────────────────────── dinheiro BR ─────────────────────── */

/// "1.234,56" ou "1234,56" ou "1234.56" → 1234.56. Vazio/ inválido → null.
double? parseMoedaBr(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[^\d,.\-]'), '');
  // Se tem vírgula, ela é o separador decimal (BR): remove pontos de milhar.
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// Valor → string editável com vírgula decimal ("1234.5" → "1234,50").
String formatMoedaInput(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/* ─────────────────────── campo rotulado ─────────────────────── */

/// Rótulo (com `*` se obrigatório) + input, com erro inline. Mesma estética dos
/// formulários do Painel.
class FinField extends StatelessWidget {
  const FinField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.error,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.inputFormatters,
    this.prefix,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
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
            enabled: enabled,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              counterText: '',
              errorText: error,
              prefixText: prefix,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown rotulado genérico.
class FinDropdown<T> extends StatelessWidget {
  const FinDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.required = false,
    this.error,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String? error;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
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
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              errorText: error,
              hintText: hint,
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
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── data de parede ─────────────────────── */

/// Campo de data 'YYYY-MM-DD' (parede/BRT — sem hora nem fuso). Abre um
/// `DatePicker` e escreve a data escolhida no [controller] como string ISO.
class FinDateField extends StatelessWidget {
  const FinDateField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.error,
    this.enabled = true,
  });

  final String label;

  /// Guarda a data como 'YYYY-MM-DD' (ou vazio).
  final TextEditingController controller;
  final bool required;
  final String? error;
  final bool enabled;

  static String _fmtBr(String ymd) {
    if (ymd.length != 10) return '';
    return '${ymd.substring(8, 10)}/${ymd.substring(5, 7)}/${ymd.substring(0, 4)}';
  }

  Future<void> _pick(BuildContext context) async {
    final current = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      String p(int n) => n.toString().padLeft(2, '0');
      controller.text = '${picked.year}-${p(picked.month)}-${p(picked.day)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
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
          InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: ClxRadii.rMd,
            child: InputDecorator(
              decoration: InputDecoration(
                isDense: true,
                errorText: error,
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final txt = _fmtBr(value.text);
                  return Text(
                    txt.isEmpty ? 'Selecionar…' : txt,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: txt.isEmpty ? clx.ink3 : clx.ink,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coluna dupla responsiva (empilha < 480px). Usada nos modais.
class FinTwoCol extends StatelessWidget {
  const FinTwoCol(this.a, this.b, {super.key});
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 480) return Column(children: [a, b]);
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
}

/// Casca padrão dos modais do Financeiro (cabeçalho + corpo rolável + rodapé de
/// ações), montada dentro de um `Dialog` por [showFinModal].
class FinModalScaffold extends StatelessWidget {
  const FinModalScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onSave,
    required this.saving,
    this.saveLabel = 'Salvar',
    this.error,
    this.extraActions = const [],
  });

  final String title;
  final Widget body;
  final VoidCallback onSave;
  final bool saving;
  final String saveLabel;
  final String? error;
  final List<Widget> extraActions;

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
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: clx.ink),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  ErrorBanner(message: error!),
                  const SizedBox(height: ClxSpace.x4),
                ],
                body,
              ],
            ),
          ),
        ),
        Divider(height: 1, color: clx.line),
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Row(
            children: [
              ...extraActions,
              const Spacer(),
              ClxButton(
                label: 'Cancelar',
                variant: ClxButtonVariant.ghost,
                onPressed: saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: ClxSpace.x3),
              ClxButton(
                label: saveLabel,
                icon: Icons.check_rounded,
                loading: saving,
                onPressed: saving ? null : onSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Abre um modal do Financeiro (Dialog centrado, largura limitada).
Future<T?> showFinModal<T>(BuildContext context, Widget child) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: child,
      ),
    ),
  );
}
