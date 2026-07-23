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

/// Cor estável por texto de tag (hash → pool de cores vivas).
Color finTagAccentColor(String tag) {
  final t = tag.trim().toLowerCase();
  if (t.isEmpty) {
    return finParseHex(kFinCategoriaCoresPool.first) ?? const Color(0xFF3B82F6);
  }
  var h = 0;
  for (final u in t.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  final hex = kFinCategoriaCoresPool[h % kFinCategoriaCoresPool.length];
  return finParseHex(hex) ?? const Color(0xFF3B82F6);
}

/// Cor do **desenho** do ícone sobre fundo na cor da categoria.
/// Cores claras → ink escuro; cores saturadas/escuras → branco (máximo contraste).
Color finOnCategoriaColor(Color cor) {
  return cor.computeLuminance() > 0.55
      ? const Color(0xFF0B1D34)
      : const Color(0xFFFFFFFF);
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
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: clx.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── CategoriaAvatar ─────────────────────── */

/// Círculo **sólido** na cor da categoria + ícone em contraste (branco/ink).
/// O desenho do ícone fica legível em qualquer tom da paleta.
class FinCategoriaAvatar extends StatelessWidget {
  const FinCategoriaAvatar({super.key, this.categoria, this.size = 34});

  final FinCategoria? categoria;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = finParseHex(categoria?.cor) ?? clx.primary;
    final onCor = finOnCategoriaColor(cor);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cor.withValues(alpha: 0.35),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        finCategoriaIcon(categoria?.icone),
        size: size * 0.52,
        color: onCor,
      ),
    );
  }
}

/// Etiqueta (tag de lançamento) com cor estável e alto contraste.
class FinTagChip extends StatelessWidget {
  const FinTagChip({
    super.key,
    required this.label,
    this.count,
    this.dense = true,
    this.onTap,
  });

  final String label;
  final int? count;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = finTagAccentColor(label);
    final chip = ClxChip(
      label: count != null ? '$label · $count' : label,
      color: cor,
      icon: Icons.sell_outlined,
      dense: dense,
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rPill,
        child: chip,
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
