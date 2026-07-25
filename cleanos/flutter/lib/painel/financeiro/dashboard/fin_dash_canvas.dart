/// fin_dash_canvas.dart — Canvas freeform do Dashboard (desktop).
///
/// Renderiza cards em grade 12 colunas. Em [editing]: arraste para mover,
/// handle no canto SE para redimensionar, botão ocultar. Snap na grade.
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import 'fin_dash_layout.dart';

typedef FinDashCardBuilder = Widget Function(BuildContext context, String id);

class FinDashCanvas extends StatefulWidget {
  const FinDashCanvas({
    super.key,
    required this.layout,
    required this.editing,
    required this.cardBuilder,
    required this.onLayoutChanged,
    this.rowPx = kFinDashRowPx,
  });

  final FinDashLayout layout;
  final bool editing;
  final FinDashCardBuilder cardBuilder;
  final ValueChanged<FinDashLayout> onLayoutChanged;
  final double rowPx;

  @override
  State<FinDashCanvas> createState() => _FinDashCanvasState();
}

class _FinDashCanvasState extends State<FinDashCanvas> {
  String? _dragId;
  String? _resizeId;
  Offset _dragOrigin = Offset.zero;
  FinDashPlacement? _originPlacement;

  void _emit(FinDashLayout next) => widget.onLayoutChanged(next);

  void _beginDrag(String id, Offset global) {
    final p = widget.layout.byId(id);
    if (p == null || !p.visible) return;
    setState(() {
      _dragId = id;
      _resizeId = null;
      _dragOrigin = global;
      _originPlacement = p;
    });
  }

  void _beginResize(String id, Offset global) {
    final p = widget.layout.byId(id);
    if (p == null || !p.visible) return;
    setState(() {
      _resizeId = id;
      _dragId = null;
      _dragOrigin = global;
      _originPlacement = p;
    });
  }

  void _onPointerMove(Offset global, double cellW) {
    final origin = _originPlacement;
    if (origin == null) return;
    final dx = global.dx - _dragOrigin.dx;
    final dy = global.dy - _dragOrigin.dy;
    final dCol = (dx / cellW).round();
    final dRow = (dy / widget.rowPx).round();

    // Posição/tamanho do card ativo a partir do gesto; os demais reflow.
    // Usa o layout **atual** (já com pushes) mas ancora o ativo no origin do
    // gesto para o cursor não “pular”.
    if (_dragId != null) {
      final active = FinDashLayout.clampPlacement(
        origin.copyWith(x: origin.x + dCol, y: origin.y + dRow),
      );
      _emit(widget.layout.placeWithReflow(active));
    } else if (_resizeId != null) {
      final min = FinDashCardId.minSize(origin.id);
      final active = FinDashLayout.clampPlacement(
        origin.copyWith(
          w: (origin.w + dCol).clamp(min.$1, kFinDashCols - origin.x),
          h: (origin.h + dRow).clamp(min.$2, 40),
        ),
      );
      _emit(widget.layout.placeWithReflow(active));
    }
  }

  void _endGesture() {
    setState(() {
      _dragId = null;
      _resizeId = null;
      _originPlacement = null;
    });
  }

  void _hide(String id) {
    final p = widget.layout.byId(id);
    if (p == null) return;
    _emit(widget.layout.upsert(p.copyWith(visible: false)));
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final cellW = width / kFinDashCols;
        final height = widget.layout.contentHeightPx(rowPx: widget.rowPx);
        final visible = widget.layout.items.where((p) => p.visible).toList()
          ..sort((a, b) {
            // Card em drag/resize fica no topo (z-order).
            final aTop = a.id == _dragId || a.id == _resizeId;
            final bTop = b.id == _dragId || b.id == _resizeId;
            if (aTop && !bTop) return 1;
            if (!aTop && bTop) return -1;
            return a.y.compareTo(b.y);
          });

        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.editing)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      cols: kFinDashCols,
                      rowPx: widget.rowPx,
                      color: clx.line.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              for (final p in visible)
                Positioned(
                  left: p.x * cellW + kFinDashGap / 2,
                  top: p.y * widget.rowPx + kFinDashGap / 2,
                  width: p.w * cellW - kFinDashGap,
                  height: p.h * widget.rowPx - kFinDashGap,
                  child: _DashTileChrome(
                    editing: widget.editing,
                    title: FinDashCardId.label(p.id),
                    active: p.id == _dragId || p.id == _resizeId,
                    onHide: () => _hide(p.id),
                    onDragStart: (g) => _beginDrag(p.id, g),
                    onResizeStart: (g) => _beginResize(p.id, g),
                    onPointerMove: (g) => _onPointerMove(g, cellW),
                    onPointerEnd: _endGesture,
                    child: widget.cardBuilder(context, p.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashTileChrome extends StatelessWidget {
  const _DashTileChrome({
    required this.editing,
    required this.title,
    required this.active,
    required this.child,
    required this.onHide,
    required this.onDragStart,
    required this.onResizeStart,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final bool editing;
  final String title;
  final bool active;
  final Widget child;
  final VoidCallback onHide;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onResizeStart;
  final ValueChanged<Offset> onPointerMove;
  final VoidCallback onPointerEnd;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final body = Material(
      color: Colors.transparent,
      child: child,
    );

    if (!editing) {
      return ClipRRect(
        borderRadius: ClxRadii.rLg,
        child: body,
      );
    }

    return Listener(
      onPointerMove: (e) => onPointerMove(e.position),
      onPointerUp: (_) => onPointerEnd(),
      onPointerCancel: (_) => onPointerEnd(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: clx.bg,
          borderRadius: ClxRadii.rLg,
          border: Border.all(
            color: active ? clx.primary : clx.primary.withValues(alpha: 0.45),
            width: active ? 2 : 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: clx.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: ClxRadii.rLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => onDragStart(d.globalPosition),
                onPanUpdate: (d) => onPointerMove(d.globalPosition),
                onPanEnd: (_) => onPointerEnd(),
                child: Container(
                  height: 32,
                  color: clx.primary.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator_rounded,
                          size: 18, color: clx.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: clx.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ocultar card',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onHide,
                        icon: Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: clx.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                        child: body,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => onResizeStart(d.globalPosition),
                        onPanUpdate: (d) => onPointerMove(d.globalPosition),
                        onPanEnd: (_) => onPointerEnd(),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.south_east_rounded,
                              size: 16,
                              color: clx.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.cols,
    required this.rowPx,
    required this.color,
  });

  final int cols;
  final double rowPx;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cellW = size.width / cols;
    for (var i = 0; i <= cols; i++) {
      final x = i * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final rows = (size.height / rowPx).ceil();
    for (var j = 0; j <= rows; j++) {
      final y = j * rowPx;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols || old.rowPx != rowPx || old.color != color;
}

/// Chip / menu para reexibir cards ocultos.
class FinDashHiddenTray extends StatelessWidget {
  const FinDashHiddenTray({
    super.key,
    required this.layout,
    required this.onShow,
  });

  final FinDashLayout layout;
  final ValueChanged<String> onShow;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final hidden =
        layout.items.where((p) => !p.visible).map((p) => p.id).toList();
    if (hidden.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Ocultos:',
            style: TextStyle(
              color: clx.ink2,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          for (final id in hidden)
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16, color: clx.primary),
              label: Text(FinDashCardId.label(id)),
              onPressed: () => onShow(id),
              side: BorderSide(color: clx.line),
              backgroundColor: clx.bg2,
            ),
        ],
      ),
    );
  }
}
