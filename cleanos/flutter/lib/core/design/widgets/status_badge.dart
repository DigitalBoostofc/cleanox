import 'package:flutter/material.dart';

import '../../models/collections.dart' show OSStatus;
import '../cleanox_colors.dart';
import 'clx_chip.dart';

/// Badge de status da OS — cor/label derivados do `CleanoxColors` + enum.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false});

  final OSStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxChip(
      label: status.label,
      color: clx.statusColor(status),
      background: clx.statusBg(status),
      dense: dense,
    );
  }
}
