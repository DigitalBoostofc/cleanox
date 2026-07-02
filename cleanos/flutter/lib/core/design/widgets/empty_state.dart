import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';

/// Estado vazio: ícone + título + mensagem + ação opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClxSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: clx.ink3),
            const SizedBox(height: ClxSpace.x4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: clx.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: ClxSpace.x2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: clx.ink3, fontSize: 14),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: ClxSpace.x5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
