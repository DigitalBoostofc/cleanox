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
  final (bg, fg, icon) = switch (type) {
    ToastType.success => (
      clx.success,
      Colors.white,
      Icons.check_circle_rounded,
    ),
    ToastType.warning => (
      clx.warning,
      Colors.black87,
      Icons.warning_amber_rounded,
    ),
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
              child: Text(message, style: TextStyle(color: fg, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
}
