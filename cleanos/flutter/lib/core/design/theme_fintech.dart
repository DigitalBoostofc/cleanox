/// theme_fintech.dart — ThemeData claro/escuro do redesign "Fintech Clean"
/// (Opção B, doc 12) para o APK Android (`AppSurface.android`/`.profissional`).
///
/// Arquivo IRMÃO de `theme.dart`, deliberadamente duplicado (não uma ramificação
/// condicional dentro dele): a Web (`main_painel.dart`) nunca importa este
/// arquivo, então uma flag invertida não tem como vazar o visual novo pra lá.
/// Reaproveita `ClxRadii.{md,lg,xl,pill}` e `ClxSpace` — nenhum token novo de
/// raio/espaçamento (a Opção B bate 1:1 com a escala já existente; `ClxRadii.sm`
/// simplesmente não é usado nas telas fintech).
library;

import 'package:flutter/material.dart';

import 'cleanox_colors.dart';
import 'tokens.dart';

/// ColorScheme MD3 derivado dos tokens Fintech Clean. `tertiary` (violeta de
/// status "Atribuída") vem de `statusAtribuida`/`statusAtribuidaBg` — não uma
/// terceira fonte de roxo hardcoded, como o `theme.dart` clássico tinha.
ColorScheme _schemeFintech(Brightness brightness, CleanoxColors clx) {
  final isDark = brightness == Brightness.dark;
  return ColorScheme(
    brightness: brightness,
    primary: clx.primary,
    onPrimary: clx.onPrimary,
    primaryContainer: clx.primary2,
    onPrimaryContainer: clx.onPrimary,
    secondary: clx.accent,
    onSecondary: isDark ? const Color(0xFF06222B) : Colors.white,
    secondaryContainer: clx.accent2,
    onSecondaryContainer: isDark ? const Color(0xFF06222B) : Colors.white,
    tertiary: clx.statusAtribuida,
    onTertiary: isDark ? const Color(0xFF2E1065) : Colors.white,
    tertiaryContainer: clx.statusAtribuidaBg,
    onTertiaryContainer: clx.statusAtribuida,
    error: clx.error,
    onError: isDark ? const Color(0xFF450A0A) : Colors.white,
    errorContainer: clx.errorBg,
    onErrorContainer: clx.error,
    surface: clx.bg,
    onSurface: clx.ink,
    onSurfaceVariant: clx.ink2,
    surfaceDim: isDark ? const Color(0xFF0A0B0C) : const Color(0xFFE9EBEE),
    surfaceBright: isDark ? const Color(0xFF232629) : const Color(0xFFFFFFFF),
    surfaceContainerLowest: isDark
        ? const Color(0xFF0A0B0C)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: clx.bg2,
    surfaceContainer: isDark
        ? const Color(0xFF1B1D1F)
        : const Color(0xFFF4F6F8),
    surfaceContainerHigh: isDark
        ? const Color(0xFF1F2224)
        : const Color(0xFFF0F2F5),
    surfaceContainerHighest: clx.bg3,
    inverseSurface: isDark ? const Color(0xFFF3F5F6) : clx.ink,
    onInverseSurface: isDark ? const Color(0xFF0B1220) : clx.bg2,
    inversePrimary: isDark ? const Color(0xFF00A87F) : clx.primary,
    outline: clx.line2,
    outlineVariant: clx.line,
    shadow: const Color(0xFF0B1220),
    surfaceTint: clx.primary,
  );
}

/// Escala tipográfica da Opção B (7 degraus, Sora) — pesos diferentes dos
/// mesmos papéis MD3 de `theme.dart`, por isso um `_textThemeFintech()` próprio
/// em vez de um `if` dentro de `_textTheme()`.
TextTheme _textThemeFintech() {
  const f = kFontFamily;
  return const TextTheme(
    // display (34/40, 800): saldo geral, valores hero.
    displayLarge: TextStyle(
      fontFamily: f,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 40 / 34,
    ),
    displayMedium: TextStyle(
      fontFamily: f,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontFamily: f,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    headlineLarge: TextStyle(
      fontFamily: f,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: f,
      fontSize: 25,
      fontWeight: FontWeight.w800,
      height: 1.25,
    ),
    // title1 (24/30, 800): título de tela.
    headlineSmall: TextStyle(
      fontFamily: f,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 30 / 24,
    ),
    // title2 (18/24, 700): título de card.
    titleLarge: TextStyle(
      fontFamily: f,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 24 / 18,
    ),
    // bodyLg (16/22, 500): nome do item, valor de linha.
    titleMedium: TextStyle(
      fontFamily: f,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 22 / 16,
    ),
    // body (15/21, 400): texto corrido.
    titleSmall: TextStyle(
      fontFamily: f,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 21 / 15,
    ),
    bodyLarge: TextStyle(
      fontFamily: f,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 21 / 15,
    ),
    // label (13/18, 600): chip, botão, rótulo.
    bodyMedium: TextStyle(
      fontFamily: f,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 18 / 13,
    ),
    // caption (12/16, 500): metadados, timestamps.
    bodySmall: TextStyle(
      fontFamily: f,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 16 / 12,
    ),
    labelLarge: TextStyle(
      fontFamily: f,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 18 / 13,
    ),
    labelMedium: TextStyle(
      fontFamily: f,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 16 / 12,
    ),
    labelSmall: TextStyle(
      fontFamily: f,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
  );
}

ThemeData _buildFintech(Brightness brightness, CleanoxColors clx) {
  final scheme = _schemeFintech(brightness, clx);
  final textTheme = _textThemeFintech();

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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: clx.bg2,
      foregroundColor: clx.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall?.copyWith(color: clx.ink),
    ),
    // Cards planos hairline (sem elevação, borda fina) — o "cartão" da Opção B.
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
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      titleTextStyle: textTheme.headlineSmall?.copyWith(color: clx.ink),
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: clx.ink2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: clx.bg,
      dragHandleColor: clx.line2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ClxRadii.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: clx.primary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rMd),
    ),
    // Chips pill (label/caption), fundo -bg do feedback quando selecionado.
    chipTheme: ChipThemeData(
      labelStyle: textTheme.bodyMedium?.copyWith(color: clx.ink2),
      side: BorderSide(color: clx.line),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rPill),
      backgroundColor: clx.bg2,
      selectedColor: clx.successBg,
    ),
    // Bottom nav de 5 itens (admin) / 3 (profissional) — indicador = primary.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: clx.bg,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? clx.primary : clx.ink3,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: ClxSpace.x3),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: clx.line2, width: 1.5),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: clx.line2, width: 1.5),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: clx.primary, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: clx.error, width: 1.5),
      ),
    ),
    // Botões pill full-width (padrão Opção B): `ClxButton` já lê `clx.onPrimary`.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: clx.primary,
        foregroundColor: clx.onPrimary,
        minimumSize: const Size(0, ClxLayout.minTouchTarget + 6),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: clx.primary,
        backgroundColor: clx.successBg,
        side: BorderSide.none,
        minimumSize: const Size(0, ClxLayout.minTouchTarget),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: clx.ink2,
        minimumSize: const Size(0, ClxLayout.minTouchTarget),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    dividerTheme: DividerThemeData(color: clx.line, thickness: 1, space: 1),
    scrollbarTheme: const ScrollbarThemeData(interactive: true),
  );
}

/// Tema claro "Fintech Clean" (Opção B) — só para `AppSurface.android`.
ThemeData buildFintechLightTheme() =>
    _buildFintech(Brightness.light, CleanoxColors.fintechLight);

/// Tema escuro "Fintech Clean".
ThemeData buildFintechDarkTheme() =>
    _buildFintech(Brightness.dark, CleanoxColors.fintechDark);
