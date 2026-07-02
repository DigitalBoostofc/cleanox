/// fin_chips.dart — Chips/badges/avatares compartilhados do Financeiro.
///
/// Porte do KIT `web/src/pages/painel/financeiro/components/` (OrigemChip,
/// TipoChip, ContaBadge, CategoriaIcon, ProgressBar). Tudo MD3 + tokens do design
/// system (`context.clx`, `ClxRadii`, `ClxSpace`) — nada hardcoded, claro/escuro.
/// Reaproveita `finCategoriaIcon`/`recorrenciaLabel`/`origemLabel` de fin_labels.
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/models/financeiro.dart';
import 'fin_labels.dart';

/// Converte um hex ('#RRGGBB' ou 'RRGGBB', com/sem alpha) em [Color]. `null` se
/// vazio/ inválido. Centraliza o parse antes espalhado pelas telas.
Color? finParseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.isEmpty) return null;
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/* ─────────────────────── OrigemChip ─────────────────────── */

/// Chip da origem do lançamento: `via_os` → tom info (com ícone de link);
/// `manual` → neutro. Espelha `components/OrigemChip.tsx`.
class OrigemChip extends StatelessWidget {
  const OrigemChip({super.key, required this.origem, this.dense = true});

  final OrigemLancamento origem;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final isOs = origem == OrigemLancamento.viaOs;
    return ClxChip(
      label: origemLabel(origem),
      color: isOs ? clx.info : clx.ink3,
      background: isOs ? clx.infoBg : null,
      icon: isOs ? Icons.link_rounded : null,
      dense: dense,
    );
  }
}

/* ─────────────────────── RecorrenciaChip (TipoChip) ─────────────────────── */

/// Chip neutro do tipo de recorrência (Única/Fixa/Recorrente/Parcelada).
/// Espelha `components/TipoChip.tsx`.
class RecorrenciaChip extends StatelessWidget {
  const RecorrenciaChip({
    super.key,
    required this.recorrencia,
    this.dense = true,
  });

  final RecorrenciaTipo recorrencia;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxChip(
      label: recorrenciaLabel(recorrencia),
      color: clx.ink3,
      dense: dense,
    );
  }
}

/* ─────────────────────── ContaBadge ─────────────────────── */

/// Ícone (ponto colorido) + nome da conta/carteira. Espelha
/// `components/ContaBadge.tsx` (que usa a cor da conta ou um cinza neutro).
class ContaBadge extends StatelessWidget {
  const ContaBadge({super.key, required this.conta});

  final FinConta conta;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = finParseHex(conta.cor) ?? clx.ink3;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: clx.bg2,
        borderRadius: ClxRadii.rPill,
        border: Border.all(color: clx.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: ClxSpace.x1),
          Flexible(
            child: Text(
              conta.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: clx.ink2,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── CategoriaAvatar ─────────────────────── */

/// Círculo colorido com o ícone da categoria (fundo = cor translúcida, ícone na
/// cor sólida). Espelha `components/CategoriaIcon.tsx`. Usa o mesmo mapeamento de
/// ícone (`finCategoriaIcon`) das telas de Categorias/Limites — consistência.
class FinCategoriaAvatar extends StatelessWidget {
  const FinCategoriaAvatar({super.key, this.categoria, this.size = 34});

  final FinCategoria? categoria;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = finParseHex(categoria?.cor) ?? clx.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        finCategoriaIcon(categoria?.icone),
        size: size * 0.52,
        color: cor,
      ),
    );
  }
}

/* ─────────────────────── ProgressBar ─────────────────────── */

/// Barra de progresso fina para limites de gasto. [value] é a fração 0..1 (como
/// `ProgressoLimite.pct`); o preenchimento é clampado, mas o TOM deriva do valor
/// real: <0.8 success, 0.8–1 warning, >1 error. Espelha `components/ProgressBar.tsx`.
class FinProgressBar extends StatelessWidget {
  const FinProgressBar({super.key, required this.value, this.tone});

  final double value;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final safe = value.isFinite ? value : 0.0;
    final resolved =
        tone ??
        (safe > 1
            ? StatusTone.error
            : safe >= 0.8
            ? StatusTone.warning
            : StatusTone.success);
    return ClipRRect(
      borderRadius: ClxRadii.rPill,
      child: LinearProgressIndicator(
        value: safe.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: clx.bg3,
        valueColor: AlwaysStoppedAnimation<Color>(toneColor(clx, resolved)),
      ),
    );
  }
}
