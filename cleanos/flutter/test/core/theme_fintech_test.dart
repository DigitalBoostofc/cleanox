/// theme_fintech_test.dart — ThemeData "Fintech Clean" (Opção B, doc 12).
///
/// Garante que `buildFintechLightTheme`/`buildFintechDarkTheme` carregam os
/// tokens novos (`CleanoxColors.fintechLight/.fintechDark`) e a tipografia da
/// Opção B — e que são DISTINTOS do tema clássico (`theme.dart`), provando
/// que a bifurcação por arquivo (não por `if`) realmente troca os valores.
library;

import 'dart:math' as math;

import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Razão de contraste WCAG 2.x entre duas cores (luminância relativa).
double _contrastRatio(Color a, Color b) {
  double linearize(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) {
    final r = linearize(c.r);
    final g = linearize(c.g);
    final b = linearize(c.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  final la = luminance(a);
  final lb = luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('tema claro fintech carrega CleanoxColors.fintechLight', () {
    final t = buildFintechLightTheme();
    expect(t.brightness, Brightness.light);
    final clx = t.extension<CleanoxColors>();
    expect(clx, isNotNull);
    expect(clx!.primary, CleanoxColors.fintechLight.primary);
    expect(clx.onPrimary, const Color(0xFF04231C));
  });

  test('tema escuro fintech carrega CleanoxColors.fintechDark', () {
    final t = buildFintechDarkTheme();
    expect(t.brightness, Brightness.dark);
    final clx = t.extension<CleanoxColors>()!;
    expect(clx.primary, CleanoxColors.fintechDark.primary);
    expect(clx.bg, const Color(0xFF17191B));
  });

  test('cores fintech são distintas do tema clássico (não vaza pra Web)', () {
    expect(
      buildFintechLightTheme().extension<CleanoxColors>()!.primary,
      isNot(buildLightTheme().extension<CleanoxColors>()!.primary),
    );
    expect(
      buildFintechDarkTheme().extension<CleanoxColors>()!.primary,
      isNot(buildDarkTheme().extension<CleanoxColors>()!.primary),
    );
  });

  test('escala tipográfica da Opção B: display 34/800, title1 24/800', () {
    final t = buildFintechLightTheme();
    expect(t.textTheme.displayLarge?.fontSize, 34);
    expect(t.textTheme.displayLarge?.fontWeight, FontWeight.w800);
    expect(t.textTheme.headlineSmall?.fontSize, 24);
    expect(t.textTheme.headlineSmall?.fontWeight, FontWeight.w800);
  });

  test('ColorScheme.primary/onPrimary vêm de CleanoxColors.onPrimary novo', () {
    final scheme = buildFintechLightTheme().colorScheme;
    expect(scheme.primary, CleanoxColors.fintechLight.primary);
    expect(scheme.onPrimary, CleanoxColors.fintechLight.onPrimary);
  });

  test('tertiary do ColorScheme fintech vem de statusAtribuida (sem 3ª fonte de roxo)', () {
    final scheme = buildFintechLightTheme().colorScheme;
    expect(scheme.tertiary, CleanoxColors.fintechLight.statusAtribuida);
  });

  test(
    'onPrimary do tema Web (CleanoxColors.light) trava em ClxBrand.onPrimary '
    '— não pode mudar de cor por acidente (ex.: vazamento de um reskin)',
    () {
      expect(CleanoxColors.light.onPrimary, ClxBrand.onPrimary);
    },
  );

  test(
    'warning do fintechLight atinge AA (>=4.5:1) sobre bg2 (#F7F8FA)',
    () {
      final ratio = _contrastRatio(
        CleanoxColors.fintechLight.warning,
        CleanoxColors.fintechLight.bg2,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'warning=${CleanoxColors.fintechLight.warning} sobre '
            'bg2=${CleanoxColors.fintechLight.bg2} deu ${ratio.toStringAsFixed(2)}:1',
      );
    },
  );

  test(
    'warning do fintechDark continua AA (>=4.5:1) sobre bg (#17191B)',
    () {
      final ratio = _contrastRatio(
        CleanoxColors.fintechDark.warning,
        CleanoxColors.fintechDark.bg,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    },
  );
}
