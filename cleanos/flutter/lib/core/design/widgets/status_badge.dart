import 'package:flutter/material.dart';

import '../../models/collections.dart' show OSStatus;
import '../cleanox_colors.dart';
import '../tokens.dart';
import 'clx_chip.dart';

/// Badge de status da OS — cor/label derivados do `CleanoxColors` + enum.
///
/// Com [refazer], mostra chip extra "Refazer" (OS reaberta após conclusão).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.dense = false,
    this.refazer = false,
  });

  final OSStatus status;
  final bool dense;
  final bool refazer;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final statusChip = ClxChip(
      label: status.label,
      color: clx.statusColor(status),
      background: clx.statusBg(status),
      dense: dense,
    );
    if (!refazer) return statusChip;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        statusChip,
        const SizedBox(width: ClxSpace.x1),
        ClxChip(
          label: 'Refazer',
          color: clx.warning,
          background: clx.warning.withValues(alpha: 0.14),
          dense: dense,
        ),
      ],
    );
  }
}
