/// tokens.dart — Design tokens do CleanOS em Dart.
///
/// Espelho 1:1 de `web/src/styles/tokens.css` (variáveis `--clx-*`): paleta
/// petrol `#0F4C5C` + cyan/teal `#00C2B8`, raios, espaçamentos, sombras e a
/// tipografia Sora. Nenhuma feature usa cor hardcoded — tudo vem daqui ou do
/// `CleanoxColors` (ThemeExtension).
library;

import 'package:flutter/material.dart';

/// Família tipográfica de marca. Os .ttf são registrados no pubspec quando os
/// binários entrarem no repo; até lá, cai no fallback do sistema.
const String kFontFamily = 'Sora';

/// Raios de borda (--clx-r-*).
class ClxRadii {
  const ClxRadii._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 100;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

/// Escala de espaçamento (múltiplos de 4; toque mínimo 48 no mobile).
class ClxSpace {
  const ClxSpace._();
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
}

/// Layout (--clx-*-w/-h).
class ClxLayout {
  const ClxLayout._();
  static const double sidebarW = 240;
  static const double topbarH = 64;
  static const double bottomNavH = 64;
  static const double contentMaxW = 1200;

  /// Toque mínimo (Material / Android). iOS 44.
  static const double minTouchTarget = 48;
}

/// Cores de marca fixas (independem de tema).
class ClxBrand {
  const ClxBrand._();
  static const Color primary = Color(0xFF00C2B8); // teal/cyan — CTA
  static const Color primary2 = Color(0xFF00A39B); // teal hover
  static const Color accent = Color(0xFF0F4C5C); // petrol blue
  static const Color accent2 = Color(0xFF1B6B7A); // petrol hover
}

/// Sombras (--clx-shadow-*), variante clara.
class ClxShadows {
  const ClxShadows._();
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x140F4C5C), // rgba(15,76,92,0.08)
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1F0F4C5C), // rgba(15,76,92,0.12)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x290F4C5C), // rgba(15,76,92,0.16)
      blurRadius: 60,
      offset: Offset(0, 24),
    ),
  ];
}

/// Curvas de animação (--clx-ease-*).
class ClxEase {
  const ClxEase._();
  static const Cubic out = Cubic(0.22, 1, 0.36, 1);
  static const Cubic soft = Cubic(0.65, 0, 0.35, 1);
}
