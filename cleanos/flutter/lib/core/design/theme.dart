/// theme.dart — ThemeData claro/escuro + controller de ThemeMode persistido.
///
/// Deriva o `ColorScheme` da marca (cyan primário, petrol secundário) e anexa o
/// `CleanoxColors` (ThemeExtension). O ThemeMode é persistido na chave
/// `cleanos-theme` (mesma do `ThemeContext.tsx`), em secure storage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cleanox_colors.dart';
import 'tokens.dart';

/// Chave de persistência do tema (paridade com o web).
const String kThemeStorageKey = 'cleanos-theme';

ThemeData _build(Brightness brightness, CleanoxColors clx) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: clx.primary,
    onPrimary: const Color(0xFF04201E),
    primaryContainer: clx.primary2,
    onPrimaryContainer: Colors.white,
    secondary: clx.accent,
    onSecondary: Colors.white,
    secondaryContainer: clx.accent2,
    onSecondaryContainer: Colors.white,
    surface: clx.bg,
    onSurface: clx.ink,
    surfaceContainerHighest: clx.bg3,
    onSurfaceVariant: clx.ink2,
    error: clx.error,
    onError: Colors.white,
    outline: clx.line2,
    outlineVariant: clx.line,
    shadow: const Color(0xFF0F4C5C),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    scaffoldBackgroundColor: clx.bg2,
    canvasColor: clx.bg,
    dividerColor: clx.line,
    extensions: <ThemeExtension<dynamic>>[clx],
    appBarTheme: AppBarTheme(
      backgroundColor: clx.bg,
      foregroundColor: clx.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: clx.bg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: ClxRadii.rLg,
        side: BorderSide(color: clx.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? clx.bg2 : clx.bg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      border: OutlineInputBorder(
        borderRadius: ClxRadii.rMd,
        borderSide: BorderSide(color: clx.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: ClxRadii.rMd,
        borderSide: BorderSide(color: clx.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: ClxRadii.rMd,
        borderSide: BorderSide(color: clx.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: ClxRadii.rMd,
        borderSide: BorderSide(color: clx.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: clx.primary,
        foregroundColor: const Color(0xFF04201E),
        minimumSize: const Size(0, ClxLayout.minTouchTarget),
        shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    dividerTheme: DividerThemeData(color: clx.line, thickness: 1, space: 1),
    scrollbarTheme: const ScrollbarThemeData(interactive: true),
  );
}

/// Tema claro (padrão, paridade com o web).
ThemeData buildLightTheme() => _build(Brightness.light, CleanoxColors.light);

/// Tema escuro.
ThemeData buildDarkTheme() => _build(Brightness.dark, CleanoxColors.dark);

/* ─────────────────── controller de ThemeMode ─────────────────── */

/// Storage injetável (override em teste).
final themeStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Controla e persiste o ThemeMode (light/dark/system). Default: light (web).
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(themeStorageProvider)
          .read(key: kThemeStorageKey);
      final mode = switch (raw) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (mode != null) state = mode;
    } catch (_) {
      /* mantém default */
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    try {
      await ref
          .read(themeStorageProvider)
          .write(key: kThemeStorageKey, value: raw);
    } catch (_) {
      /* best-effort */
    }
  }

  void set(ThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  /// Alterna claro↔escuro (espelha `toggle` do ThemeContext).
  void toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
