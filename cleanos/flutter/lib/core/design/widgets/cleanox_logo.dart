/// cleanox_logo.dart — Logo oficial Cleanox (wordmark / mark).
///
/// Assets em `assets/brand/`. Preferir [CleanoxLogoVariant.primary]
/// (wordmark com fundo transparente) no login e na sidebar.
library;

import 'package:flutter/material.dart';

/// Qual arquivo de marca carregar.
enum CleanoxLogoVariant {
  /// Wordmark oficial com fundo transparente (sidebar / genérico).
  primary,

  /// Login tema claro — LOGO_SEM_FUNDO_BRANCO (wordmark em fundo claro).
  loginLight,

  /// Alias do primary (legado).
  fullLight,

  /// Wordmark claro em fundo navy (hero escuro / fintech).
  fullDark,

  /// Wordmark semi-transparente (sobre fundo colorido).
  fullOnColor,

  /// Só o monograma C (sidebar colapsada).
  mark,
}

/// Logo Cleanox reutilizável (login, shell, splash).
///
/// Para preencher a coluna da sidebar: coloque em um [SizedBox] com
/// `width: double.infinity` e altura desejada, e use
/// `width/height: double.infinity` + [BoxFit.contain].
class CleanoxLogo extends StatelessWidget {
  const CleanoxLogo({
    super.key,
    this.height = 40,
    this.width,
    this.variant = CleanoxLogoVariant.primary,
    this.fit = BoxFit.contain,
  });

  /// Altura do box. `double.infinity` preenche o pai (SizedBox/Expanded).
  final double height;

  /// Largura opcional. `double.infinity` = largura da coluna.
  final double? width;
  final CleanoxLogoVariant variant;
  final BoxFit fit;

  static const String _primary = 'assets/brand/logo_primary.png';
  static const String _fullLight = 'assets/brand/logo_full_light.png';
  static const String _fullDark = 'assets/brand/logo_full_dark.png';
  static const String _fullOnColor = 'assets/brand/logo_full_on_color.png';
  static const String _mark = 'assets/brand/logo_mark.png';

  String get _asset => switch (variant) {
    CleanoxLogoVariant.primary => _primary,
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
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        final iconSize = height.isFinite ? height * 0.7 : 32.0;
        return Icon(
          Icons.cleaning_services_rounded,
          size: iconSize,
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}
