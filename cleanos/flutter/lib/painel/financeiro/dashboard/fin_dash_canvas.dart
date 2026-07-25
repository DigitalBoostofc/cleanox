/// fin_dash_canvas.dart — Canvas freeform do Dashboard (desktop).
///
/// Grade densa. Em [editing]: arraste, resize (E/S/SE), fixar, alinhar L/C/R,
/// ocultar. A **borda** do card ocupa o retângulo completo do slot (w×h).
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import 'fin_dash_layout.dart';

typedef FinDashCardBuilder = Widget Function(BuildContext context, String id);

enum _ResizeEdge { se, e, s }

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
  _ResizeEdge _resizeEdge = _ResizeEdge.se;
  Offset _dragOrigin = Offset.zero;
  FinDashPlacement? _originPlacement;

  void _emit(FinDashLayout next) => widget.onLayoutChanged(next);

  void _beginDrag(String id, Offset global) {
    final p = widget.layout.byId(id);
    if (p == null || !p.visible || p.pinned) return;
    setState(() {
      _dragId = id;
      _resizeId = null;
      _dragOrigin = global;
      _originPlacement = p;
    });
  }

  void _beginResize(String id, Offset global, _ResizeEdge edge) {
    final p = widget.layout.byId(id);
    if (p == null || !p.visible) return;
    setState(() {
      _resizeId = id;
      _resizeEdge = edge;
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

    if (_dragId != null) {
      final active = FinDashLayout.clampPlacement(
        origin.copyWith(x: origin.x + dCol, y: origin.y + dRow),
      );
      _emit(widget.layout.placeWithReflow(active));
      return;
    }

    if (_resizeId == null) return;
    final min = FinDashCardId.minSize(origin.id);
    var w = origin.w;
    var h = origin.h;
    switch (_resizeEdge) {
      case _ResizeEdge.se:
        w = (origin.w + dCol).clamp(min.$1, kFinDashCols - origin.x);
        h = (origin.h + dRow).clamp(min.$2, kFinDashMaxH);
      case _ResizeEdge.e:
        w = (origin.w + dCol).clamp(min.$1, kFinDashCols - origin.x);
      case _ResizeEdge.s:
        h = (origin.h + dRow).clamp(min.$2, kFinDashMaxH);
    }
    final active = FinDashLayout.clampPlacement(origin.copyWith(w: w, h: h));
    _emit(widget.layout.placeWithReflow(active));
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

  void _togglePin(String id) {
    final p = widget.layout.byId(id);
    if (p == null) return;
    _emit(widget.layout.upsert(p.copyWith(pinned: !p.pinned)));
  }

  void _setAlign(String id, FinDashAlign align) {
    final p = widget.layout.byId(id);
    if (p == null) return;
    _emit(widget.layout.upsert(p.copyWith(align: align)));
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
                      minor: clx.line.withValues(alpha: 0.35),
                      major: clx.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              for (final p in visible)
                // Slot = exatamente w×h células; gap só como margem interna
                // para a borda visual acompanhar o redimensionamento.
                Positioned(
                  left: p.x * cellW,
                  top: p.y * widget.rowPx,
                  width: p.w * cellW,
                  height: p.h * widget.rowPx,
                  child: Padding(
                    padding: const EdgeInsets.all(kFinDashGap / 2),
                    child: _DashTileChrome(
                      editing: widget.editing,
                      title: FinDashCardId.label(p.id),
                      sizeLabel: '${p.w}×${p.h}',
                      pinned: p.pinned,
                      align: p.align,
                      active: p.id == _dragId || p.id == _resizeId,
                      onHide: () => _hide(p.id),
                      onTogglePin: () => _togglePin(p.id),
                      onAlign: (a) => _setAlign(p.id, a),
                      onDragStart: (g) => _beginDrag(p.id, g),
                      onResizeStart: (g, edge) =>
                          _beginResize(p.id, g, edge),
                      onPointerMove: (g) => _onPointerMove(g, cellW),
                      onPointerEnd: _endGesture,
                      child: widget.cardBuilder(context, p.id),
                    ),
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
    required this.sizeLabel,
    required this.pinned,
    required this.align,
    required this.active,
    required this.child,
    required this.onHide,
    required this.onTogglePin,
    required this.onAlign,
    required this.onDragStart,
    required this.onResizeStart,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final bool editing;
  final String title;
  final String sizeLabel;
  final bool pinned;
  final FinDashAlign align;
  final bool active;
  final Widget child;
  final VoidCallback onHide;
  final VoidCallback onTogglePin;
  final ValueChanged<FinDashAlign> onAlign;
  final ValueChanged<Offset> onDragStart;
  final void Function(Offset global, _ResizeEdge edge) onResizeStart;
  final ValueChanged<Offset> onPointerMove;
  final VoidCallback onPointerEnd;

  Alignment get _contentAlign => switch (align) {
        FinDashAlign.left => Alignment.topLeft,
        FinDashAlign.center => Alignment.topCenter,
        FinDashAlign.right => Alignment.topRight,
      };

  Widget _alignedBody() {
    // Conteúdo alinhado L/C/R dentro da borda do card.
    return SizedBox.expand(
      child: Align(
        alignment: _contentAlign,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;

    // Borda sempre no retângulo do slot (view + edição).
    final frame = DecoratedBox(
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: ClxRadii.rLg,
        border: Border.all(
          color: editing
              ? (active
                  ? clx.primary
                  : (pinned
                      ? clx.warning.withValues(alpha: 0.7)
                      : clx.primary.withValues(alpha: 0.45)))
              : clx.line,
          width: editing && active ? 2 : 1,
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
        child: editing
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Toolbar do card
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: pinned
                        ? null
                        : (d) => onDragStart(d.globalPosition),
                    onPanUpdate: pinned
                        ? null
                        : (d) => onPointerMove(d.globalPosition),
                    onPanEnd: pinned ? null : (_) => onPointerEnd(),
                    child: Container(
                      height: 34,
                      color: (pinned ? clx.warning : clx.primary)
                          .withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            pinned
                                ? Icons.push_pin_rounded
                                : Icons.drag_indicator_rounded,
                            size: 16,
                            color: pinned ? clx.warning : clx.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pinned ? clx.warning : clx.primary,
                              ),
                            ),
                          ),
                          Text(
                            sizeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: clx.ink3,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          // Alinhar
                          _TinyIconBtn(
                            tooltip: 'Alinhar à esquerda',
                            selected: align == FinDashAlign.left,
                            icon: Icons.format_align_left_rounded,
                            onTap: () => onAlign(FinDashAlign.left),
                          ),
                          _TinyIconBtn(
                            tooltip: 'Centralizar',
                            selected: align == FinDashAlign.center,
                            icon: Icons.format_align_center_rounded,
                            onTap: () => onAlign(FinDashAlign.center),
                          ),
                          _TinyIconBtn(
                            tooltip: 'Alinhar à direita',
                            selected: align == FinDashAlign.right,
                            icon: Icons.format_align_right_rounded,
                            onTap: () => onAlign(FinDashAlign.right),
                          ),
                          _TinyIconBtn(
                            tooltip: pinned
                                ? 'Desafixar card'
                                : 'Fixar card (não move no reflow)',
                            selected: pinned,
                            icon: pinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            onTap: onTogglePin,
                          ),
                          _TinyIconBtn(
                            tooltip: 'Ocultar card',
                            icon: Icons.visibility_off_outlined,
                            onTap: onHide,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
                            child: _alignedBody(),
                          ),
                        ),
                        // Resize E
                        Positioned(
                          right: 0,
                          top: 4,
                          bottom: 24,
                          width: 12,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => onResizeStart(
                                d.globalPosition,
                                _ResizeEdge.e,
                              ),
                              onPanUpdate: (d) =>
                                  onPointerMove(d.globalPosition),
                              onPanEnd: (_) => onPointerEnd(),
                              child: Center(
                                child: Container(
                                  width: 3,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: clx.primary.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Resize S
                        Positioned(
                          left: 8,
                          right: 24,
                          bottom: 0,
                          height: 12,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => onResizeStart(
                                d.globalPosition,
                                _ResizeEdge.s,
                              ),
                              onPanUpdate: (d) =>
                                  onPointerMove(d.globalPosition),
                              onPanEnd: (_) => onPointerEnd(),
                              child: Center(
                                child: Container(
                                  height: 3,
                                  width: 24,
                                  decoration: BoxDecoration(
                                    color: clx.primary.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Resize SE
                        Positioned(
                          right: 0,
                          bottom: 0,
                          width: 24,
                          height: 24,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeDownRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => onResizeStart(
                                d.globalPosition,
                                _ResizeEdge.se,
                              ),
                              onPanUpdate: (d) =>
                                  onPointerMove(d.globalPosition),
                              onPanEnd: (_) => onPointerEnd(),
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(
                                  Icons.south_east_rounded,
                                  size: 14,
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
              )
            : Padding(
                padding: const EdgeInsets.all(8),
                child: _alignedBody(),
              ),
      ),
    );

    if (!editing) return frame;

    return Listener(
      onPointerMove: (e) => onPointerMove(e.position),
      onPointerUp: (_) => onPointerEnd(),
      onPointerCancel: (_) => onPointerEnd(),
      child: frame,
    );
  }
}

class _TinyIconBtn extends StatelessWidget {
  const _TinyIconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: clx.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Icon(
          icon,
          size: 15,
          color: selected ? clx.primary : clx.ink2,
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.cols,
    required this.rowPx,
    required this.minor,
    required this.major,
  });

  final int cols;
  final double rowPx;
  final Color minor;
  final Color major;

  static const int majorEvery = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final rows = (size.height / rowPx).ceil();

    final minorPaint = Paint()
      ..color = minor
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = major
      ..strokeWidth = 1.25;

    for (var i = 0; i <= cols; i++) {
      final x = i * cellW;
      final paint = i % majorEvery == 0 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var j = 0; j <= rows; j++) {
      final y = j * rowPx;
      final paint = j % majorEvery == 0 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols ||
      old.rowPx != rowPx ||
      old.minor != minor ||
      old.major != major;
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
