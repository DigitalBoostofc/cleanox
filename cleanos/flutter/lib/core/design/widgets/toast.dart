import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';

enum ToastType { info, success, warning, error }

/// Toast transiente (espelha os toasts de `MeusServicos`). Usa o
/// ScaffoldMessenger — chame de dentro de uma tela com Scaffold.
void showClxToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
  Duration duration = const Duration(milliseconds: 3800),
}) {
  final clx = context.clx;
  // O toast de warning muda de tom por tema (claro #B45309 escuro / escuro
  // #FBBF24 âmbar-claro). Fixar branco quebrava o WCAG no escuro (~1,6:1), então
  // a cor do texto/ícone segue o BRILHO do fundo real: fundo escuro → branco,
  // fundo claro → preto — legível (AA) nos dois temas sem tocar no fundo.
  final warningFg =
      ThemeData.estimateBrightnessForColor(clx.warning) == Brightness.dark
      ? Colors.white
      : Colors.black87;
  final (bg, fg, icon) = switch (type) {
    ToastType.success => (
      clx.success,
      Colors.white,
      Icons.check_circle_rounded,
    ),
    ToastType.warning => (clx.warning, warningFg, Icons.warning_amber_rounded),
    ToastType.error => (clx.error, Colors.white, Icons.error_rounded),
    ToastType.info => (clx.accent, Colors.white, Icons.info_rounded),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rMd),
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: ClxSpace.x3),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
}
