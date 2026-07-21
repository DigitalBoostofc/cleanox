/// clx_responsive.dart — Escala de layout/tipografia por tamanho de tela.
///
/// Referência de design: **390×844** (telefone médio atual).
/// Em celulares menores (ex.: 320–360) a UI **encolhe** de forma controlada;
/// em telas maiores (ex.: 430) **cresce** levemente — sem estourar em tablet.
///
/// Uso:
/// ```dart
/// final r = ClxResponsive.of(context);
/// Text('…', style: TextStyle(fontSize: r.sp(16)));
/// padding: EdgeInsets.all(r.s(16));
/// // ou envolve a árvore:
/// ClxResponsiveScope(child: …) // ajusta TextScaler + Theme
/// ```
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Largura/altura de referência (dp) — “1.0” da escala.
const double kClxRefWidth = 390;
const double kClxRefHeight = 844;

/// Escala mínima/máxima de layout (evita UI ilegível ou monstruosa).
const double kClxScaleMin = 0.86;
const double kClxScaleMax = 1.16;

/// Escala final de texto (layout × preferência do SO), com teto de acessibilidade.
const double kClxTextScaleMin = 0.82;
const double kClxTextScaleMax = 1.38;

/// Snapshot de responsividade para o [BuildContext] atual.
@immutable
class ClxResponsive {
  const ClxResponsive._({
    required this.size,
    required this.layoutScale,
    required this.textScale,
  });

  final Size size;

  /// Fator só de tela (sem acessibilidade do usuário).
  final double layoutScale;

  /// Fator aplicado à tipografia (tela × preferência do sistema, clampado).
  final double textScale;

  /// Largura lógica atual.
  double get width => size.width;

  /// Altura lógica atual.
  double get height => size.height;

  /// Telefone estreito (&lt; 360dp).
  bool get isCompactPhone => width < 360;

  /// Telefone “grande” / phablet (≥ 414dp e &lt; 600).
  bool get isLargePhone => width >= 414 && width < ClxLayout.narrowBreakpoint;

  factory ClxResponsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = computeLayoutScale(size);
    // Preferência do SO (não o MediaQuery já reescrito por ClxResponsiveScope),
    // para `sp()` não aplicar o fator em dobro.
    final platform =
        WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    final text =
        (layout * platform).clamp(kClxTextScaleMin, kClxTextScaleMax);
    return ClxResponsive._(
      size: size,
      layoutScale: layout,
      textScale: text.toDouble(),
    );
  }

  /// Escala de layout a partir do [Size] (pura, testável).
  ///
  /// Mistura largura (70%) e altura (30%) para celulares muito baixos
  /// (notch + barras) não ficarem “esticados” só por width.
  static double computeLayoutScale(Size size) {
    if (size.width <= 0 || size.height <= 0) return 1;
    final w = size.width / kClxRefWidth;
    final h = size.height / kClxRefHeight;
    final mixed = w * 0.72 + h * 0.28;
    return mixed.clamp(kClxScaleMin, kClxScaleMax);
  }

  /// Tipografia a partir do tamanho de design (dp no mock 390).
  double sp(double designPx) => designPx * textScale;

  /// Espaçamento / ícone / raio a partir do tamanho de design.
  double s(double designPx) => designPx * layoutScale;

  /// Alias semântico de [s] para raios.
  double r(double designPx) => s(designPx);

  /// Padding simétrico horizontal padrão da Carteira mobile.
  double get pagePadH => s(16);

  /// Padding inferior para conteúdo acima do bottom nav Easypay.
  double get bottomNavClearance => s(100).clamp(88.0, 120.0);

  /// Altura mínima de toque (nunca abaixo de 44).
  double get touch => s(ClxLayout.minTouchTarget).clamp(44.0, 56.0);
}

/// Extensão: `context.clxR.sp(14)`.
extension ClxResponsiveX on BuildContext {
  ClxResponsive get clxR => ClxResponsive.of(this);
}

/// Aplica [TextScaler] + reescala leve do [TextTheme] para a subárvore.
///
/// Coloque no casco fintech (APK / web estreita) para que **todo** o app
/// mobile herde a escala — não só o Financeiro.
class ClxResponsiveScope extends StatelessWidget {
  const ClxResponsiveScope({
    super.key,
    required this.child,
    this.enable = true,
  });

  final Widget child;

  /// Se false, passa o filho sem alterar (ex.: desktop web).
  final bool enable;

  @override
  Widget build(BuildContext context) {
    if (!enable) return child;

    final r = ClxResponsive.of(context);
    final mq = MediaQuery.of(context);

    // Um único fator no TextScaler: (preferência do SO × tela), clampado.
    // Text/Theme usam fontSize de design; o scaler faz o resto — sem double-dip.
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(r.textScale),
      ),
      child: child,
    );
  }
}
