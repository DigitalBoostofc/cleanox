import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_surface_provider.dart';
import '../cleanox_colors.dart';
import '../tokens.dart';

/// Estado vazio: ícone + título + mensagem + ação opcional.
///
/// No surface Fintech Clean (APK), o ícone ganha um círculo `bg3` atrás
/// (fiel ao mock — `.empty-state-icon`). Lido via `Consumer` local (não via
/// `ConsumerWidget`) pra não obrigar as ~14 telas da Web que já usam este
/// widget a mudar de tipo; o default de `isFintechCleanProvider` é `false`
/// sem override, então a Web nunca vê o círculo.
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
            Consumer(
              builder: (context, ref, _) {
                final iconWidget = Icon(icon, size: 48, color: clx.ink3);
                if (!ref.watch(isFintechCleanProvider)) return iconWidget;
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: clx.bg3,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: iconWidget,
                );
              },
            ),
            const SizedBox(height: ClxSpace.x4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: clx.ink),
            ),
            if (message != null) ...[
              const SizedBox(height: ClxSpace.x2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: clx.ink3),
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
