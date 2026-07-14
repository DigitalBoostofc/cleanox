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

/// Cor de texto/ícone sobre o cyan da marca (primary e primaryContainer).
const Color _onBrandCyan = ClxBrand.onPrimary;

/// ColorScheme MD3 COMPLETO derivado da marca (todos os roles preenchidos —
/// tertiary, tiers de surface-container, inverse*, containers de feedback).
/// Pares X/onX verificados a ≥ 4.5:1 (WCAG AA texto normal).
ColorScheme _scheme(Brightness brightness, CleanoxColors clx) {
  final isDark = brightness == Brightness.dark;
  return ColorScheme(
    brightness: brightness,
    primary: clx.primary,
    onPrimary: _onBrandCyan,
    primaryContainer: clx.primary2,
    onPrimaryContainer: _onBrandCyan,
    secondary: clx.accent,
    onSecondary: isDark ? const Color(0xFF06222B) : Colors.white,
    secondaryContainer: clx.accent2,
    onSecondaryContainer: isDark ? const Color(0xFF06222B) : Colors.white,
    tertiary: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
    onTertiary: isDark ? const Color(0xFF2E1065) : Colors.white,
    tertiaryContainer: isDark
        ? const Color(0xFF5B21B6)
        : const Color(0xFFEDE9FE),
    onTertiaryContainer: isDark
        ? const Color(0xFFEDE9FE)
        : const Color(0xFF4C1D95),
    error: clx.error,
    onError: isDark ? const Color(0xFF450A0A) : Colors.white,
    errorContainer: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
    onErrorContainer: isDark
        ? const Color(0xFFFECACA)
        : const Color(0xFF7F1D1D),
    surface: clx.bg,
    onSurface: clx.ink,
    onSurfaceVariant: clx.ink2,
    surfaceDim: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFE6ECF1),
    surfaceBright: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFFFFFFF),
    surfaceContainerLowest: isDark
        ? const Color(0xFF070707)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: clx.bg2,
    surfaceContainer: isDark
        ? const Color(0xFF1B1B1B)
        : const Color(0xFFF4F7FA),
    surfaceContainerHigh: isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF1F5F8),
    surfaceContainerHighest: clx.bg3,
    inverseSurface: isDark ? const Color(0xFFF7F9FB) : clx.ink,
    onInverseSurface: isDark ? const Color(0xFF0B1F2A) : clx.bg2,
    inversePrimary: isDark ? const Color(0xFF007A74) : clx.primary,
    outline: clx.line2,
    outlineVariant: clx.line,
    shadow: const Color(0xFF0F4C5C),
    surfaceTint: clx.primary,
  );
}

/// Escala tipográfica MD3 com os tamanhos da marca (Sora). Cores herdam de
/// `onSurface` — texto muted usa `copyWith(color: clx.ink2/ink3)` no ponto de
/// uso. Papéis seguem a semântica MD3: Display (números-herói/KPI), Headline
/// (seções), Title (títulos de página/card), Body (corpo), Label (botões,
/// chips, captions).
TextTheme _textTheme() {
  const f = kFontFamily;
  return const TextTheme(
    displayLarge: TextStyle(
      fontFamily: f,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: f,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontFamily: f,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineLarge: TextStyle(
      fontFamily: f,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: f,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    headlineSmall: TextStyle(
      fontFamily: f,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    titleLarge: TextStyle(
      fontFamily: f,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontFamily: f,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleSmall: TextStyle(
      fontFamily: f,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    bodyLarge: TextStyle(
      fontFamily: f,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontFamily: f,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: f,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: f,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelMedium: TextStyle(
      fontFamily: f,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelSmall: TextStyle(
      fontFamily: f,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
  );
}

ThemeData _build(Brightness brightness, CleanoxColors clx) {
  final isDark = brightness == Brightness.dark;
  final scheme = _scheme(brightness, clx);
  final textTheme = _textTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: clx.bg2,
    canvasColor: clx.bg,
    dividerColor: clx.line,
    extensions: <ThemeExtension<dynamic>>[clx],
    // Transições de rota MD3 (fade-forwards) + iOS nativo.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: clx.bg,
      foregroundColor: clx.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: clx.ink),
    ),
    // Card "outlined" (variante MD3): elevação 0 + borda outline-variant.
    cardTheme: CardThemeData(
      color: clx.bg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: ClxRadii.rLg,
        side: BorderSide(color: clx.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      titleTextStyle: textTheme.headlineSmall?.copyWith(color: clx.ink),
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: clx.ink2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ClxRadii.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rSm),
    ),
    chipTheme: ChipThemeData(
      labelStyle: textTheme.labelMedium?.copyWith(color: clx.ink2),
      side: BorderSide(color: clx.line),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rSm),
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: clx.bgSidebar,
      indicatorColor: scheme.secondaryContainer,
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: clx.ink),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: clx.ink2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? clx.bg2 : clx.bg,
      // Hint em cinza "muted" (ink3): deixa claro que é só um exemplo, não o
      // dado digitado (que usa `ink`). Sem isso o placeholder confunde.
      hintStyle: textTheme.bodyLarge?.copyWith(color: clx.ink3),
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
    // Botões com shape "full" (StadiumBorder), padrão MD3; texto = labelLarge.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: clx.primary,
        foregroundColor: _onBrandCyan,
        minimumSize: const Size(0, ClxLayout.minTouchTarget),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: clx.ink2,
        side: BorderSide(color: clx.line2),
        minimumSize: const Size(0, ClxLayout.minTouchTarget),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? clx.primary : scheme.secondary,
        minimumSize: const Size(0, ClxLayout.minTouchTarget),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
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
