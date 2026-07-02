/// snapshot_resumo.dart — Exibe o SNAPSHOT IMUTÁVEL do serviço principal na OS.
///
/// Widget GENÉRICO (dono: Time B, reusável pelo Painel): recebe só um
/// [ServiceSnapshot] e o renderiza. Porte de `components/os/SnapshotResumo.tsx`.
/// Deixa explícito o contrato de imutabilidade (cópia congelada na seleção).
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Faixa de imutabilidade.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ClxSpace.x4,
              vertical: ClxSpace.x2,
            ),
            color: clx.warningBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: clx.warning),
                const SizedBox(width: ClxSpace.x2),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              'Cópia do serviço no momento da seleção — alterações '
                              'futuras no cadastro não afetam esta OS.',
                          style: TextStyle(
                            color: clx.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (snapshot.capturedAt.isNotEmpty)
                          TextSpan(
                            text:
                                ' Capturado em '
                                '${formatDateTime(snapshot.capturedAt)}.',
                            style: TextStyle(color: clx.ink3, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x4,
              ClxSpace.x4,
              ClxSpace.x4,
              ClxSpace.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.nome,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 17,
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
                ] else ...[
                  const SizedBox(height: ClxSpace.x3),
                  Text(
                    'Sem observações técnicas ou orientações cadastradas.',
                    style: TextStyle(color: clx.ink3, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
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
          style: TextStyle(
            color: clx.ink3,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: clx.ink, fontSize: 14, height: 1.45),
        ),
      ],
    );
  }
}
