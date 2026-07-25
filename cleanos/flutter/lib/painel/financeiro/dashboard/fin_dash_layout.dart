/// fin_dash_layout.dart — Modelo puro do layout freeform do Dashboard financeiro.
///
/// Grade de [kFinDashCols] colunas × unidades de linha. Cada card é um retângulo
/// (x, y, w, h) em células. Serializa em JSON para preferência por usuário.
///
/// v2 (2026-07): 24 colunas + linha 28px (antes v1: 12 × 56px) — mais precisão
/// no editor. Layouts v1 são migrados com escala ×2.
library;

/// Colunas da grade (desktop). v2 = 24 (v1 era 12).
const int kFinDashCols = 24;

/// Altura de 1 unidade de linha (px). v2 = 28 (v1 era 56).
const double kFinDashRowPx = 28;

/// Gap entre cards (px).
const double kFinDashGap = 8;

/// Altura máxima de um card em unidades de linha.
const int kFinDashMaxH = 80;

/// Versão atual do JSON persistido.
/// v3: `pinned` + `align` (esquerda/centro/direita).
const int kFinDashLayoutVersion = 3;

/// Alinhamento horizontal do **conteúdo** dentro do card.
enum FinDashAlign {
  left,
  center,
  right;

  static FinDashAlign parse(Object? raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    return switch (s) {
      'center' || 'centro' || 'c' => FinDashAlign.center,
      'right' || 'direita' || 'r' => FinDashAlign.right,
      _ => FinDashAlign.left,
    };
  }

  String get wire => name;
}

/// IDs canônicos dos cards do Dashboard (desktop freeform).
abstract final class FinDashCardId {
  static const kpis = 'kpis';
  static const receitasCat = 'receitas_cat';
  static const despesasCat = 'despesas_cat';
  static const freq = 'freq';
  static const objetivos = 'objetivos';
  static const balanco = 'balanco';
  static const economia = 'economia';
  static const pendencias = 'pendencias';
  static const contas = 'contas';
  static const favoritas = 'favoritas';
  static const planejamento = 'planejamento';
  static const calendario = 'calendario';

  static const all = <String>[
    kpis,
    receitasCat,
    despesasCat,
    freq,
    objetivos,
    balanco,
    economia,
    pendencias,
    contas,
    favoritas,
    planejamento,
    calendario,
  ];

  static String label(String id) => switch (id) {
        kpis => 'Indicadores (KPIs)',
        receitasCat => 'Receitas por categoria',
        despesasCat => 'Despesas por categoria',
        freq => 'Frequência de gastos',
        objetivos => 'Objetivos',
        balanco => 'Balanço mensal',
        economia => 'Economia mensal',
        pendencias => 'Pendências e alertas',
        contas => 'Minhas contas',
        favoritas => 'Transações favoritas',
        planejamento => 'Planejamento mensal',
        calendario => 'Calendário do mês',
        _ => id,
      };

  /// Mínimos de grade por card (v2 — mais livres para personalizar).
  static (int w, int h) minSize(String id) => switch (id) {
        kpis => (6, 2),
        receitasCat || despesasCat || freq => (3, 3),
        calendario => (6, 4),
        _ => (2, 2),
      };

  /// Tamanho padrão (layout inicial) na grade v2 (24×).
  static (int w, int h) defaultSize(String id) => switch (id) {
        kpis => (24, 4),
        receitasCat || despesasCat => (12, 10),
        freq => (12, 10),
        objetivos => (12, 8),
        balanco => (12, 8),
        economia => (12, 6),
        pendencias => (12, 6),
        contas => (12, 8),
        favoritas => (12, 6),
        planejamento => (12, 8),
        calendario => (24, 12),
        _ => (12, 6),
      };
}

/// Posição e tamanho de um card na grade.
class FinDashPlacement {
  const FinDashPlacement({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.visible = true,
    this.pinned = false,
    this.align = FinDashAlign.left,
  });

  final String id;
  final int x;
  final int y;
  final int w;
  final int h;
  final bool visible;

  /// Fixo no reflow: não é empurrado por outros cards.
  final bool pinned;

  /// Alinhamento do conteúdo (esquerda / centro / direita).
  final FinDashAlign align;

  FinDashPlacement copyWith({
    int? x,
    int? y,
    int? w,
    int? h,
    bool? visible,
    bool? pinned,
    FinDashAlign? align,
  }) =>
      FinDashPlacement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        visible: visible ?? this.visible,
        pinned: pinned ?? this.pinned,
        align: align ?? this.align,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'visible': visible,
        'pinned': pinned,
        'align': align.wire,
      };

  factory FinDashPlacement.fromJson(
    Map<String, dynamic> j, {
    int scale = 1,
  }) {
    final id = (j['id'] as String? ?? '').trim();
    final min = FinDashCardId.minSize(id);
    var w = ((j['w'] as num?)?.toInt() ?? min.$1) * scale;
    var h = ((j['h'] as num?)?.toInt() ?? min.$2) * scale;
    var x = ((j['x'] as num?)?.toInt() ?? 0) * scale;
    var y = ((j['y'] as num?)?.toInt() ?? 0) * scale;
    w = w.clamp(min.$1, kFinDashCols);
    h = h.clamp(min.$2, kFinDashMaxH);
    x = x.clamp(0, kFinDashCols - 1);
    if (x + w > kFinDashCols) x = (kFinDashCols - w).clamp(0, kFinDashCols - 1);
    y = y < 0 ? 0 : y;
    return FinDashPlacement(
      id: id,
      x: x,
      y: y,
      w: w,
      h: h,
      visible: j['visible'] as bool? ?? true,
      pinned: j['pinned'] as bool? ?? false,
      align: FinDashAlign.parse(j['align']),
    );
  }
}

/// Layout completo do dashboard (lista de placements).
class FinDashLayout {
  const FinDashLayout(this.items);

  final List<FinDashPlacement> items;

  FinDashLayout copyWithItems(List<FinDashPlacement> items) =>
      FinDashLayout(items);

  FinDashPlacement? byId(String id) {
    for (final p in items) {
      if (p.id == id) return p;
    }
    return null;
  }

  FinDashLayout upsert(FinDashPlacement p) {
    final next = <FinDashPlacement>[];
    var found = false;
    for (final it in items) {
      if (it.id == p.id) {
        next.add(p);
        found = true;
      } else {
        next.add(it);
      }
    }
    if (!found) next.add(p);
    return FinDashLayout(next);
  }

  /// Altura total em linhas (maior y+h entre visíveis).
  int get contentRows {
    var max = 16;
    for (final p in items) {
      if (!p.visible) continue;
      final bottom = p.y + p.h;
      if (bottom > max) max = bottom;
    }
    return max + 4; // folga p/ drop e grade densa
  }

  double contentHeightPx({double rowPx = kFinDashRowPx}) =>
      contentRows * rowPx;

  Map<String, dynamic> toJson() => {
        'v': kFinDashLayoutVersion,
        'items': [for (final p in items) p.toJson()],
      };

  factory FinDashLayout.fromJson(Map<String, dynamic>? j) {
    if (j == null) return FinDashLayout.defaultLayout();
    final raw = j['items'];
    if (raw is! List || raw.isEmpty) return FinDashLayout.defaultLayout();

    // v1 = 12 cols / linha 56px → v2 = 24 cols / 28px: escala ×2.
    final ver = (j['v'] as num?)?.toInt() ?? 1;
    final scale = ver < kFinDashLayoutVersion ? 2 : 1;

    final parsed = <FinDashPlacement>[];
    final seen = <String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final p = FinDashPlacement.fromJson(
        Map<String, dynamic>.from(e),
        scale: scale,
      );
      if (p.id.isEmpty || !FinDashCardId.all.contains(p.id)) continue;
      if (seen.contains(p.id)) continue;
      seen.add(p.id);
      parsed.add(p);
    }
    // Garante que cards novos (após update do app) entram no layout.
    for (final id in FinDashCardId.all) {
      if (seen.contains(id)) continue;
      final def = FinDashLayout.defaultLayout().byId(id)!;
      parsed.add(def.copyWith(visible: false));
    }
    if (parsed.isEmpty) return FinDashLayout.defaultLayout();
    return FinDashLayout(parsed);
  }

  /// Layout inicial espelhando o dashboard clássico (2 colunas) na grade v2.
  factory FinDashLayout.defaultLayout() {
    return const FinDashLayout([
      FinDashPlacement(id: FinDashCardId.kpis, x: 0, y: 0, w: 24, h: 4),
      FinDashPlacement(
        id: FinDashCardId.receitasCat,
        x: 0,
        y: 4,
        w: 12,
        h: 10,
      ),
      FinDashPlacement(
        id: FinDashCardId.despesasCat,
        x: 12,
        y: 4,
        w: 12,
        h: 10,
      ),
      FinDashPlacement(id: FinDashCardId.freq, x: 0, y: 14, w: 12, h: 10),
      FinDashPlacement(id: FinDashCardId.objetivos, x: 12, y: 14, w: 12, h: 8),
      FinDashPlacement(id: FinDashCardId.balanco, x: 0, y: 24, w: 12, h: 8),
      FinDashPlacement(id: FinDashCardId.economia, x: 12, y: 22, w: 12, h: 6),
      FinDashPlacement(id: FinDashCardId.pendencias, x: 0, y: 32, w: 12, h: 6),
      FinDashPlacement(id: FinDashCardId.contas, x: 12, y: 28, w: 12, h: 8),
      FinDashPlacement(
        id: FinDashCardId.planejamento,
        x: 0,
        y: 38,
        w: 12,
        h: 8,
      ),
      FinDashPlacement(id: FinDashCardId.favoritas, x: 12, y: 36, w: 12, h: 6),
      FinDashPlacement(
        id: FinDashCardId.calendario,
        x: 0,
        y: 46,
        w: 24,
        h: 12,
      ),
    ]);
  }

  /// Move com clamp na grade.
  static FinDashPlacement clampPlacement(FinDashPlacement p) {
    final min = FinDashCardId.minSize(p.id);
    var w = p.w.clamp(min.$1, kFinDashCols);
    var h = p.h.clamp(min.$2, kFinDashMaxH);
    var x = p.x.clamp(0, kFinDashCols - w);
    var y = p.y < 0 ? 0 : p.y;
    return p.copyWith(x: x, y: y, w: w, h: h);
  }

  /// Retângulos se sobrepõem (grade half-open em células).
  static bool overlaps(FinDashPlacement a, FinDashPlacement b) {
    if (a.id == b.id) return false;
    return a.x < b.x + b.w &&
        a.x + a.w > b.x &&
        a.y < b.y + b.h &&
        a.y + a.h > b.y;
  }

  /// Aplica [active] (já na posição/tamanho desejados) e **empurra** os outros
  /// cards visíveis para baixo até não haver colisão.
  ///
  /// - Card **ativo** do gesto tende a ficar onde o usuário colocou.
  /// - Cards **pinned** nunca se movem no reflow (o outro cede).
  /// - `pinned` / `align` vêm do item já salvo (gesto só mexe x/y/w/h).
  FinDashLayout placeWithReflow(FinDashPlacement active) {
    final map = <String, FinDashPlacement>{
      for (final p in items) p.id: p,
    };
    final existing = map[active.id];
    active = clampPlacement(
      FinDashPlacement(
        id: active.id,
        x: active.x,
        y: active.y,
        w: active.w,
        h: active.h,
        visible: existing?.visible ?? active.visible,
        pinned: existing?.pinned ?? active.pinned,
        align: existing?.align ?? active.align,
      ),
    );
    map[active.id] = active;

    var changed = true;
    var guard = 0;
    while (changed && guard < 1200) {
      guard++;
      changed = false;
      final visible = map.values.where((p) => p.visible).toList();

      for (var i = 0; i < visible.length; i++) {
        for (var j = i + 1; j < visible.length; j++) {
          final a = map[visible[i].id]!;
          final b = map[visible[j].id]!;
          if (!overlaps(a, b)) continue;

          final resolved = _whoMoves(a, b, activeId: active.id);
          if (resolved == null) continue;
          final stay = resolved.$1;
          final moving = resolved.$2;

          final newY = stay.y + stay.h;
          if (moving.y < newY) {
            map[moving.id] = moving.copyWith(y: newY);
            changed = true;
          } else {
            map[moving.id] = moving.copyWith(y: moving.y + 1);
            changed = true;
          }
        }
      }
    }

    _compactUp(map, gestureId: active.id);

    return FinDashLayout([
      for (final p in items) map[p.id] ?? p,
    ]);
  }

  /// Decide (stay, moving). Null = não resolve (dois pinned).
  static (FinDashPlacement, FinDashPlacement)? _whoMoves(
    FinDashPlacement a,
    FinDashPlacement b, {
    required String activeId,
  }) {
    final aActive = a.id == activeId;
    final bActive = b.id == activeId;

    // Preferir não mover pinned; se o outro for pinned e o ativo colide, move o ativo.
    if (aActive && !b.pinned) return (a, b);
    if (bActive && !a.pinned) return (b, a);
    if (aActive && b.pinned) return (b, a);
    if (bActive && a.pinned) return (a, b);
    if (a.pinned && !b.pinned) return (a, b);
    if (b.pinned && !a.pinned) return (b, a);
    if (a.pinned && b.pinned) return null;

    // Nenhum pinned/ativo especial: empurra o de baixo.
    if (a.y + a.h <= b.y + b.h) return (a, b);
    return (b, a);
  }

  /// Sobe cada card livre o máximo sem colidir — "gravidade".
  /// Não move [gestureId] nem cards `pinned`.
  static void _compactUp(
    Map<String, FinDashPlacement> byId, {
    required String gestureId,
  }) {
    final order = byId.values.where((p) => p.visible).toList()
      ..sort((a, b) {
        final cy = a.y.compareTo(b.y);
        if (cy != 0) return cy;
        return a.x.compareTo(b.x);
      });

    for (final raw in order) {
      if (raw.id == gestureId || raw.pinned) continue;
      var p = byId[raw.id]!;
      var y = p.y;
      while (y > 0) {
        final trial = p.copyWith(y: y - 1);
        final hit = byId.values.any(
          (o) => o.visible && o.id != p.id && overlaps(trial, o),
        );
        if (hit) break;
        y--;
      }
      if (y != p.y) {
        byId[p.id] = p.copyWith(y: y);
      }
    }
  }
}
