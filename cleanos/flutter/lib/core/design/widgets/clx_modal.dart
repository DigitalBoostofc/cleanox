import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';

/// Conteúdo padrão de modal do CleanOS (título + corpo + ações). Use com
/// [showClxModal] (dialog no desktop/web) ou [showClxSheet] (bottom sheet mobile).
class ClxModal extends StatelessWidget {
  const ClxModal({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.onClose,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onClose;

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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x5),
            child: child,
          ),
        ),
        if (actions.isNotEmpty) ...[
          Divider(height: 1, color: clx.line),
          Padding(
            padding: const EdgeInsets.all(ClxSpace.x4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final a in actions) ...[
                  a,
                  if (a != actions.last) const SizedBox(width: ClxSpace.x3),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Abre um [ClxModal] como dialog centrado (desktop/web).
Future<T?> showClxModal<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x5),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: ClxModal(title: title, actions: actions, child: child),
      ),
    ),
  );
}

/// Abre um [ClxModal] como bottom sheet (mobile, thumb-friendly).
Future<T?> showClxSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  List<Widget> actions = const [],
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ClxRadii.xl)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ClxModal(title: title, actions: actions, child: child),
    ),
  );
}
