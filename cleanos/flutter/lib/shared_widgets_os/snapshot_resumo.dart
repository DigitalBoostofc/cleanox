/// snapshot_resumo.dart — Exibe o serviço principal da OS (snapshot).
///
/// Widget GENÉRICO: nome, categoria, valor, tempo e orientações. A imutabilidade
/// do snapshot continua garantida no servidor — sem faixa de aviso na UI.
library;

import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../core/formatters/formatters.dart';
import '../core/models/servico.dart';
import 'labels.dart';

class SnapshotResumo extends StatelessWidget {
  const SnapshotResumo({super.key, required this.snapshot});

  final ServiceSnapshot snapshot;

  String get _valor {
    if (snapshot.tipoValor == TipoValor.faixa &&
        snapshot.valorBaseMax != null) {
      return '${formatCurrency(snapshot.valorBase)} a '
          '${formatCurrency(snapshot.valorBaseMax!)}';
    }
    return formatCurrency(snapshot.valorBase);
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final semObs =
        (snapshot.observacaoTecnica ?? '').isEmpty &&
        (snapshot.orientacoesPreServico ?? '').isEmpty &&
        (snapshot.orientacoesPosServico ?? '').isEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: clx.line, width: 1.5),
        borderRadius: ClxRadii.rLg,
        color: clx.bg2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(ClxSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.nome,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
            Wrap(
              spacing: ClxSpace.x2,
              runSpacing: ClxSpace.x1,
              children: [
                ClxChip(
                  label: categoriaLabel(snapshot.categoria),
                  color: clx.primary,
                ),
                if (snapshot.grupo != null)
                  ClxChip(
                    label: grupoLabel(snapshot.grupo),
                    color: clx.groupColor(snapshot.grupo!),
                  ),
                ClxChip(
                  label: tipoValorLabel(snapshot.tipoValor),
                  color: clx.ink3,
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Campo(label: 'Valor base', value: _valor),
                ),
                Expanded(
                  child: _Campo(
                    label: 'Tempo médio',
                    value: formatTempoMedio(
                      snapshot.tempoMedioMin,
                      snapshot.tempoMedioLabel,
                    ),
                  ),
                ),
              ],
            ),
            if (!semObs) ...[
              Divider(height: ClxSpace.x6, color: clx.line),
              if ((snapshot.observacaoTecnica ?? '').isNotEmpty)
                _Campo(
                  label: 'Observação técnica',
                  value: snapshot.observacaoTecnica!,
                ),
              if ((snapshot.orientacoesPreServico ?? '').isNotEmpty) ...[
                const SizedBox(height: ClxSpace.x3),
                _Campo(
                  label: 'Orientações pré-serviço',
                  value: snapshot.orientacoesPreServico!,
                ),
              ],
              if ((snapshot.orientacoesPosServico ?? '').isNotEmpty) ...[
                const SizedBox(height: ClxSpace.x3),
                _Campo(
                  label: 'Orientações pós-serviço',
                  value: snapshot.orientacoesPosServico!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: clx.ink3,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: clx.ink),
        ),
      ],
    );
  }
}
