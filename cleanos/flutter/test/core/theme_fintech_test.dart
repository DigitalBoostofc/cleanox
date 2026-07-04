/// theme_fintech_test.dart — ThemeData "Fintech Clean" (Opção B, doc 12).
///
/// Garante que `buildFintechLightTheme`/`buildFintechDarkTheme` carregam os
/// tokens novos (`CleanoxColors.fintechLight/.fintechDark`) e a tipografia da
/// Opção B — e que são DISTINTOS do tema clássico (`theme.dart`), provando
/// que a bifurcação por arquivo (não por `if`) realmente troca os valores.
library;

import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
