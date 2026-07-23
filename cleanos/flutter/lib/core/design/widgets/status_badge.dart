import 'package:flutter/material.dart';

import '../../models/collections.dart' show OSStatus;
import '../cleanox_colors.dart';
import '../tokens.dart';
import 'clx_chip.dart';

/// Badge de status da OS — cor/label derivados do `CleanoxColors` + enum.
///
/// Com [refazer], mostra chip extra "Refazer" (OS reaberta após conclusão).
/// Com [vitrine], mostra chip "Vitrine" (agendada em agendar.cleanox.com.br).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.dense = false,
    this.refazer = false,
    this.vitrine = false,
  });

  final OSStatus status;
  final bool dense;
  final bool refazer;
  final bool vitrine;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final chips = <Widget>[
      ClxChip(
        label: status.label,
        color: clx.statusColor(status),
        background: clx.statusBg(status),
        dense: dense,
      ),
    ];
    if (vitrine) {
      chips.add(const SizedBox(width: ClxSpace.x1));
      chips.add(
        ClxChip(
          label: 'Vitrine',
          color: clx.info,
          background: clx.infoBg,
          dense: dense,
        ),
      );
    }
    if (refazer) {
      chips.add(const SizedBox(width: ClxSpace.x1));
      chips.add(
        ClxChip(
          label: 'Refazer',
          color: clx.warning,
          background: clx.warning.withValues(alpha: 0.14),
          dense: dense,
        ),
      );
    }
    if (chips.length == 1) return chips.first;
    return Row(mainAxisSize: MainAxisSize.min, children: chips);
  }
}
