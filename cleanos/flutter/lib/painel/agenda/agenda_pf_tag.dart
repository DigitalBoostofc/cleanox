/// Tag redonda **PF** no card da Agenda quando a OS é em ponto físico.
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/models/ordem_servico.dart';

/// Iniciais do ponto físico. Só pinta se [OrdemServico.isLocalPontoFisico].
class AgendaPfTag extends StatelessWidget {
  const AgendaPfTag({super.key, required this.os, this.size = 18});

  final OrdemServico os;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!os.isLocalPontoFisico) return const SizedBox.shrink();
    final clx = context.clx;
    return Tooltip(
      message: 'Ponto físico',
      child: Container(
        key: ValueKey('agenda-pf-${os.id}'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: clx.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          'PF',
          style: TextStyle(
            color: clx.onPrimary,
            fontSize: (size * 0.42).clamp(7, 10),
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
