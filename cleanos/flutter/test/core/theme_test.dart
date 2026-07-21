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

  test('tema escuro carrega CleanoxColors escuro (carvão, sem preto puro)', () {
    final t = buildDarkTheme();
    expect(t.brightness, Brightness.dark);
    final clx = t.extension<CleanoxColors>()!;
    expect(clx.bg, const Color(0xFF1E1E1E)); // surface/cards
    expect(clx.bg2, const Color(0xFF121212)); // canvas
    expect(clx.bg3, const Color(0xFF242424)); // elevação
    expect(clx.ink, const Color(0xFFFFFFFF));
    expect(clx.ink2, const Color(0xFFB0B0B0));
    expect(clx.primary, const Color(0xFF5EC8D4));
    // ColorScheme espelha tokens (sem surface #070707 / #000).
    expect(t.colorScheme.surface, clx.bg);
    expect(t.scaffoldBackgroundColor, clx.bg2);
    expect(t.colorScheme.surfaceContainerLowest, clx.bg2);
    expect(t.colorScheme.onSurface, clx.ink);
    expect(t.colorScheme.onSurfaceVariant, clx.ink2);
  });

  test('claro e escuro têm superfícies distintas', () {
    expect(
      buildLightTheme().extension<CleanoxColors>()!.bg,
      isNot(buildDarkTheme().extension<CleanoxColors>()!.bg),
    );
  });

  test('statusColor mapeia OSStatus (paleta clara de marca)', () {
    final clx = CleanoxColors.light;
    expect(clx.statusColor(OSStatus.concluida), const Color(0xFF15803D));
    expect(clx.statusColor(OSStatus.emAndamento), const Color(0xFF0B8A98));
    expect(clx.statusColor(OSStatus.cancelada), const Color(0xFFDC2626));
  });

  test('groupColor mapeia Grupo', () {
    final clx = CleanoxColors.light;
    expect(clx.groupColor(Grupo.avulsos), const Color(0xFF7B8794));
    expect(clx.groupColor(Grupo.sofa), const Color(0xFF0EA5B7));
    expect(clx.groupColor(Grupo.colchao), const Color(0xFF0B8A98));
  });

  test('lerp interpola sem quebrar (t=0 e t=1)', () {
    final a = CleanoxColors.light;
    final b = CleanoxColors.dark;
    expect(a.lerp(b, 0).bg, a.bg);
    expect(a.lerp(b, 1).bg, b.bg);
  });
}
