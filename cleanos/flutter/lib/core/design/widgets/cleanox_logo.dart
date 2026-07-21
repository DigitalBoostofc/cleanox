/// cleanox_logo.dart — Logo oficial Cleanox (wordmark / mark).
///
/// Assets em `assets/brand/`. Variantes para fundo claro, escuro e só o ícone.
library;

import 'package:flutter/material.dart';

/// Qual arquivo de marca carregar.
enum CleanoxLogoVariant {
  /// Wordmark + ícone (fundo claro / transparente).
  fullLight,

  /// Wordmark claro em fundo navy (hero / splash).
  fullDark,

  /// Wordmark semi-transparente (sobre fundo colorido).
  fullOnColor,

  /// Só o monograma C (sidebar colapsada, favicon-like).
  mark,
}

/// Logo Cleanox reutilizável (login, shell, splash).
class CleanoxLogo extends StatelessWidget {
  const CleanoxLogo({
    super.key,
    this.height = 40,
    this.variant = CleanoxLogoVariant.fullLight,
    this.fit = BoxFit.contain,
  });

  final double height;
  final CleanoxLogoVariant variant;
  final BoxFit fit;

  static const String _fullLight = 'assets/brand/logo_full_light.png';
  static const String _fullDark = 'assets/brand/logo_full_dark.png';
  static const String _fullOnColor = 'assets/brand/logo_full_on_color.png';
  static const String _mark = 'assets/brand/logo_mark.png';

  String get _asset => switch (variant) {
    CleanoxLogoVariant.fullLight => _fullLight,
    CleanoxLogoVariant.fullDark => _fullDark,
    CleanoxLogoVariant.fullOnColor => _fullOnColor,
    CleanoxLogoVariant.mark => _mark,
  };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.cleaning_services_rounded,
        size: height * 0.7,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
