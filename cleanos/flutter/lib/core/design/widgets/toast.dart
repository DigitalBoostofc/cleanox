import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';

enum ToastType { info, success, warning, error }

/// Onde o toast aparece na tela. `bottom` (padrão) usa o `ScaffoldMessenger`
/// normal; `top` (feedback do dono, painel de filtros de Contas a
/// pagar/receber) sobe um `OverlayEntry` fixo no topo — o `SnackBar` do
/// Material não tem posição configurável nativamente.
enum ToastPosition { bottom, top }

(Color bg, Color fg, IconData icon) _toastLook(
  CleanoxColors clx,
  ToastType type,
) {
  // O toast de warning muda de tom por tema (claro #B45309 escuro / escuro
  // #FBBF24 âmbar-claro). Fixar branco quebrava o WCAG no escuro (~1,6:1), então
  // a cor do texto/ícone segue o BRILHO do fundo real: fundo escuro → branco,
  // fundo claro → preto — legível (AA) nos dois temas sem tocar no fundo.
  final warningFg =
      ThemeData.estimateBrightnessForColor(clx.warning) == Brightness.dark
      ? Colors.white
      : Colors.black87;
  return switch (type) {
    ToastType.success => (
      clx.success,
      Colors.white,
      Icons.check_circle_rounded,
    ),
    ToastType.warning => (clx.warning, warningFg, Icons.warning_amber_rounded),
    ToastType.error => (clx.error, Colors.white, Icons.error_rounded),
    ToastType.info => (clx.accent, Colors.white, Icons.info_rounded),
  };
}

/// Toast transiente (espelha os toasts de `MeusServicos`). Usa o
/// ScaffoldMessenger — chame de dentro de uma tela com Scaffold.
void showClxToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
  Duration duration = const Duration(milliseconds: 3800),
  ToastPosition position = ToastPosition.bottom,
}) {
  final clx = context.clx;
  final (bg, fg, icon) = _toastLook(clx, type);

  if (position == ToastPosition.top) {
    _showTopToast(
      context,
      message,
      bg: bg,
      fg: fg,
      icon: icon,
      duration: duration,
    );
    return;
  }

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

/// Sobe um banner fixo no topo da tela (abaixo da safe area), some sozinho
/// após [duration]. Não depende do `Scaffold`/`ScaffoldMessenger` (usa o
/// `Overlay` da rota), então funciona em qualquer tela.
void _showTopToast(
  BuildContext context,
  String message, {
  required Color bg,
  required Color fg,
  required IconData icon,
  required Duration duration,
}) {
  final overlay = Overlay.of(context);
  final topPadding = MediaQuery.paddingOf(context).top;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: topPadding + ClxSpace.x3,
      left: ClxSpace.x4,
      right: ClxSpace.x4,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x4,
            vertical: ClxSpace.x3,
          ),
          decoration: BoxDecoration(color: bg, borderRadius: ClxRadii.rMd),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: ClxSpace.x3),
              Flexible(
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
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}
