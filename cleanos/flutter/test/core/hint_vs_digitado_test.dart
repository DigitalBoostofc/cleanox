/// O placeholder tem que ser MUITO mais fraco que o texto digitado.
///
/// Feedback do dono (14/07): "o contraste do exemplo pra o que eu digitei é
/// quase o mesmo... os exemplos precisam vir bem fracos e o que digita bem
/// forte, pra ficar nítido que não está digitado nada, senão confunde."
///
/// Antes o hint usava `ink3` e ficava em ~5.5:1 — mais forte que muito texto de
/// corpo. Este teste trava a DISTÂNCIA entre os dois: se alguém "consertar" o
/// hint pra passar no WCAG, o campo vazio volta a parecer preenchido e o teste
/// quebra explicando por quê.
library;

import 'dart:math' as math;

import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _canal(int c) {
  final v = c / 255;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
}

double _luminancia(Color c) =>
    0.2126 * _canal((c.r * 255).round()) +
    0.7152 * _canal((c.g * 255).round()) +
    0.0722 * _canal((c.b * 255).round());

/// Razão de contraste WCAG entre duas cores OPACAS.
double _contraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  void checar(String nome, ThemeData tema, {required bool isDark}) {
    final clx = tema.extension<CleanoxColors>()!;
    // Fundo do campo: o `fillColor` de cada tema.
    final fundo = isDark ? clx.bg2 : clx.bg;

    final hint = tema.inputDecorationTheme.hintStyle!.color!;
    final digitado = tema.textTheme.bodyLarge!.color!;

    final crHint = _contraste(hint, fundo);
    final crDigitado = _contraste(digitado, fundo);

    test('$nome — hint é fraco (exemplo), não parece dado digitado', () {
      expect(
        crHint,
        lessThan(3.5),
        reason:
            'Hint a ${crHint.toStringAsFixed(1)}:1 — forte demais. Campo vazio '
            'volta a parecer preenchido (foi exatamente a queixa do dono).',
      );
    });

    test('$nome — texto digitado é forte', () {
      expect(
        crDigitado,
        greaterThan(10),
        reason: 'Digitado a ${crDigitado.toStringAsFixed(1)}:1 — fraco demais.',
      );
    });

    test('$nome — o digitado é MUITO mais forte que o hint (≥ 4x)', () {
      expect(
        crDigitado / crHint,
        greaterThanOrEqualTo(4),
        reason:
            'Distância de apenas ${(crDigitado / crHint).toStringAsFixed(1)}x '
            '(hint ${crHint.toStringAsFixed(1)}:1 vs digitado '
            '${crDigitado.toStringAsFixed(1)}:1). É esta distância que faz o '
            'olho distinguir "vazio" de "preenchido" sem precisar ler.',
      );
    });

    test('$nome — hint usa o token clxHintColor (não ink3)', () {
      expect(hint, clxHintColor(isDark));
      expect(
        hint,
        isNot(clx.ink3),
        reason: 'ink3 é texto muted legível (~5.5:1) — forte demais pra hint.',
      );
    });
  }

  group('Tema clássico (web painel)', () {
    checar('claro', buildLightTheme(), isDark: false);
    checar('escuro', buildDarkTheme(), isDark: true);
  });

  group('Tema Fintech (APK / web estreita)', () {
    checar('claro', buildFintechLightTheme(), isDark: false);
    checar('escuro', buildFintechDarkTheme(), isDark: true);
  });
}
