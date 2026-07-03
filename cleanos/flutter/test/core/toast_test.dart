/// Testes do toast (showClxToast): a cor do texto/ícone do warning deve seguir
/// o brilho do fundo p/ manter contraste WCAG AA nos dois temas (F-740).
library;

import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contraste WCAG relativo entre duas cores OPACAS (fórmula 2.0).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Compõe `fg` (possivelmente translúcido) sobre `bg` opaco → cor opaca
/// resultante, p/ medir o contraste real percebido.
Color _composite(Color fg, Color bg) {
  final af = fg.a;
  int mix(double f, double b) => ((f * af) + (b * (1 - af))).round();
  return Color.fromARGB(
    255,
    mix(fg.r * 255, bg.r * 255),
    mix(fg.g * 255, bg.g * 255),
    mix(fg.b * 255, bg.b * 255),
  );
}

Future<Color> _pumpWarningAndReadTextColor(
  WidgetTester tester,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showClxToast(context, 'Atenção', type: ToastType.warning),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump(); // dispara o SnackBar
  await tester.pump(const Duration(milliseconds: 400)); // anima entrada
  final textWidget = tester.widget<Text>(find.text('Atenção'));
  return textWidget.style!.color!;
}

void main() {
  testWidgets('toast warning no tema CLARO usa texto branco (fundo escuro)', (
    tester,
  ) async {
    final color = await _pumpWarningAndReadTextColor(tester, buildLightTheme());
    expect(color, Colors.white);
  });

  testWidgets('toast warning no tema ESCURO usa texto escuro (fundo claro)', (
    tester,
  ) async {
    final color = await _pumpWarningAndReadTextColor(tester, buildDarkTheme());
    expect(color, Colors.black87);
  });

  test('seleção por brilho do fundo bate com o esperado nos dois temas', () {
    // claro: warning #B45309 (escuro) → texto branco
    expect(
      ThemeData.estimateBrightnessForColor(CleanoxColors.light.warning),
      Brightness.dark,
    );
    // escuro: warning #FBBF24 (âmbar claro) → texto escuro
    expect(
      ThemeData.estimateBrightnessForColor(CleanoxColors.dark.warning),
      Brightness.light,
    );
  });

  test('contraste do warning ≥ 4.5:1 (WCAG AA) nos dois temas', () {
    // Tema CLARO: #B45309 + branco.
    final lightBg = CleanoxColors.light.warning;
    expect(_contrast(Colors.white, lightBg), greaterThanOrEqualTo(4.5));

    // Tema ESCURO: #FBBF24 + black87 (composto sobre o fundo âmbar).
    final darkBg = CleanoxColors.dark.warning;
    final darkText = _composite(Colors.black87, darkBg);
    expect(_contrast(darkText, darkBg), greaterThanOrEqualTo(4.5));
  });
}
