/// map_pin_widget.dart — Pin de mapa (gota/teardrop) com número e bounce.
///
/// Usado no mapa do dia e na rota in-app. A ponta do pin fica no ponto
/// geográfico (Marker com alignment bottomCenter).
library;

import 'package:flutter/material.dart';

/// Pin clássico de localização com número (e animação de pulo no mapa).
class MapNumberPin extends StatefulWidget {
  const MapNumberPin({
    super.key,
    required this.n,
    required this.color,
    this.emAndamento = false,
    this.size = 44,
    this.bounce = true,
  });

  final int n;
  final Color color;
  final bool emAndamento;
  final double size;

  /// Animação de "pulo" (só no mapa; desligar na lista).
  final bool bounce;

  @override
  State<MapNumberPin> createState() => _MapNumberPinState();
}

class _MapNumberPinState extends State<MapNumberPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bounce = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.bounce) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MapNumberPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounce && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.bounce && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = widget.size * 1.25; // pin é mais alto que largo
    final border = widget.emAndamento
        ? const Color(0xFFFBBF24)
        : Colors.white;

    Widget pin = SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _PinPainter(
          color: widget.color,
          borderColor: border,
          borderWidth: widget.emAndamento ? 2.5 : 2,
        ),
        child: Align(
          // Número fica no círculo superior do pin (não na ponta).
          alignment: const Alignment(0, -0.35),
          child: Text(
            '${widget.n}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: w * 0.36,
              height: 1,
              shadows: const [
                Shadow(
                  color: Color(0x44000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!widget.bounce) return pin;

    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: child,
        );
      },
      child: pin,
    );
  }
}

/// Pin de destino (sem número) — rota in-app.
class MapDestPin extends StatefulWidget {
  const MapDestPin({
    super.key,
    required this.color,
    this.size = 48,
    this.bounce = true,
  });

  final Color color;
  final double size;
  final bool bounce;

  @override
  State<MapDestPin> createState() => _MapDestPinState();
}

class _MapDestPinState extends State<MapDestPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bounce = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.bounce) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = widget.size * 1.25;
    Widget pin = SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _PinPainter(
          color: widget.color,
          borderColor: Colors.white,
          borderWidth: 2.5,
          showHole: true,
        ),
      ),
    );
    if (!widget.bounce) return pin;
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: child,
        );
      },
      child: pin,
    );
  }
}

/// Desenha o pin estilo "location marker" (gota).
class _PinPainter extends CustomPainter {
  _PinPainter({
    required this.color,
    required this.borderColor,
    this.borderWidth = 2,
    this.showHole = false,
  });

  final Color color;
  final Color borderColor;
  final double borderWidth;
  final bool showHole;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Centro do círculo superior e ponta embaixo.
    final cx = w / 2;
    final r = w * 0.42;
    final cy = r + 2; // um pouco de margem no topo

    final path = Path();
    // Arco superior (quase círculo completo) + ponta em V.
    path.moveTo(cx, h - 1);
    path.quadraticBezierTo(cx - r * 0.15, h * 0.62, cx - r, cy);
    path.arcToPoint(
      Offset(cx + r, cy),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.quadraticBezierTo(cx + r * 0.15, h * 0.62, cx, h - 1);
    path.close();

    // Sombra suave sob o pin.
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 1.5);
    canvas.drawPath(path, shadow);
    canvas.restore();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    // Brilho sutil no topo.
    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45));
    canvas.drawPath(path, gloss);

    if (showHole) {
      final holeR = r * 0.38;
      canvas.drawCircle(
        Offset(cx, cy),
        holeR,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.showHole != showHole;
}
