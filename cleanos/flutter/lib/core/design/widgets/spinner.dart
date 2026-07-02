import 'package:flutter/material.dart';

import '../cleanox_colors.dart';

/// Spinner de carregamento com a cor de marca.
class Spinner extends StatelessWidget {
  const Spinner({
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2.5,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? context.clx.primary),
      ),
    );
  }
}
