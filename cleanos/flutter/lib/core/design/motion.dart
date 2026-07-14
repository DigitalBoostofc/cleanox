/// motion.dart — Helpers de animação Easypay / dashboard (fade-slide, scale,
/// press, hover, stagger, page swap, count-up).
///
/// Durações/curvas canônicas: [ClxMotion] em `tokens.dart`.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Fade + slide de entrada (listas, cards, seções).
class ClxFadeSlide extends StatelessWidget {
  const ClxFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = ClxMotion.standardDuration,
    this.offset = const Offset(0, 0.08),
    this.curve = ClxMotion.emphasized,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final totalMs = (duration + delay).inMilliseconds;
    final start = totalMs == 0 ? 0.0 : delay.inMilliseconds / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(start.clamp(0.0, 0.99), 1, curve: curve),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(offset.dx * 24 * (1 - t), offset.dy * 28 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Fade + scale elástico (shell flutuante, modais, KPIs).
class ClxScaleFade extends StatelessWidget {
  const ClxScaleFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = ClxMotion.emphasizedDuration,
    this.beginScale = 0.92,
    this.curve = ClxMotion.emphasized,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double beginScale;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final totalMs = (duration + delay).inMilliseconds;
    final start = totalMs == 0 ? 0.0 : delay.inMilliseconds / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(start.clamp(0.0, 0.99), 1, curve: curve),
      builder: (context, t, child) {
        final s = beginScale + (1 - beginScale) * t;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: s, child: child),
        );
      },
      child: child,
    );
  }
}

/// Troca de página com fade + slide lateral (conteúdo do shell).
class ClxPageSwap extends StatelessWidget {
  const ClxPageSwap({
    super.key,
    required this.child,
    required this.switchKey,
    this.duration = ClxMotion.emphasizedDuration,
  });

  final Widget child;
  final Object switchKey;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: ClxMotion.emphasized,
      switchOutCurve: ClxMotion.emphasizedAccelerate,
      transitionBuilder: (child, anim) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: ClxMotion.emphasized,
          reverseCurve: ClxMotion.emphasizedAccelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(switchKey), child: child),
    );
  }
}

/// Elevação no hover (web) + leve scale.
class ClxHoverLift extends StatefulWidget {
  const ClxHoverLift({
    super.key,
    required this.child,
    this.lift = 6,
    this.scale = 1.015,
  });

  final Widget child;
  final double lift;
  final double scale;

  @override
  State<ClxHoverLift> createState() => _ClxHoverLiftState();
}

class _ClxHoverLiftState extends State<ClxHoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: ClxMotion.shortDuration,
        curve: ClxMotion.emphasized,
        transform: Matrix4.identity()
          ..translateByDouble(0, _hover ? -widget.lift : 0, 0, 1)
          ..scaleByDouble(
            _hover ? widget.scale : 1,
            _hover ? widget.scale : 1,
            1,
            1,
          ),
        transformAlignment: Alignment.center,
        child: AnimatedOpacity(
          duration: ClxMotion.shortDuration,
          opacity: 1,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Escala elástica no toque (botões/atalhos circulares).
class ClxPressScale extends StatefulWidget {
  const ClxPressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.92,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<ClxPressScale> createState() => _ClxPressScaleState();
}

class _ClxPressScaleState extends State<ClxPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: ClxMotion.shortDuration,
    reverseDuration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: widget.scale,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _c.forward(),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _c.reverse();
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null ? null : _c.reverse,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Contador animado de valor inteiro (KPIs).
class ClxCountUp extends StatelessWidget {
  const ClxCountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = ClxMotion.emphasizedDuration,
  });

  final int value;
  final Widget Function(BuildContext context, int value) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: ClxMotion.emphasized,
      builder: (context, v, _) => builder(context, v.round()),
    );
  }
}

/// Pulso suave (logo, FAB, badge ativo).
class ClxPulse extends StatefulWidget {
  const ClxPulse({
    super.key,
    required this.child,
    this.minScale = 0.96,
    this.maxScale = 1.04,
    this.period = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration period;

  @override
  State<ClxPulse> createState() => _ClxPulseState();
}

class _ClxPulseState extends State<ClxPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: widget.minScale,
        end: widget.maxScale,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
