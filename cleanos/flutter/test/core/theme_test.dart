/// Testes do tema claro/escuro + CleanoxColors (status/grupos).
library;

import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tema claro carrega CleanoxColors claro', () {
    final t = buildLightTheme();
    expect(t.brightness, Brightness.light);
    final clx = t.extension<CleanoxColors>();
    expect(clx, isNotNull);
    expect(clx!.bg, const Color(0xFFFFFFFF));
  });

  test('tema escuro carrega CleanoxColors escuro', () {
    final t = buildDarkTheme();
    expect(t.brightness, Brightness.dark);
    final clx = t.extension<CleanoxColors>()!;
    expect(clx.bg, const Color(0xFF0C0C0C));
  });

  test('claro e escuro têm superfícies distintas', () {
    expect(
      buildLightTheme().extension<CleanoxColors>()!.bg,
      isNot(buildDarkTheme().extension<CleanoxColors>()!.bg),
    );
  });

  test('statusColor mapeia OSStatus (tons WCAG ≥ 4.5:1 do upgrade MD3)', () {
    final clx = CleanoxColors.light;
    expect(clx.statusColor(OSStatus.concluida), const Color(0xFF15803D));
    expect(clx.statusColor(OSStatus.emAndamento), const Color(0xFFB45309));
    expect(clx.statusColor(OSStatus.cancelada), const Color(0xFFDC2626));
  });

  test('groupColor mapeia Grupo', () {
    final clx = CleanoxColors.light;
    expect(clx.groupColor(Grupo.avulsos), const Color(0xFFC2410C));
    expect(clx.groupColor(Grupo.sofa), clx.groupColor(Grupo.colchao));
  });

  test('lerp interpola sem quebrar (t=0 e t=1)', () {
    final a = CleanoxColors.light;
    final b = CleanoxColors.dark;
    expect(a.lerp(b, 0).bg, a.bg);
    expect(a.lerp(b, 1).bg, b.bg);
  });
}
