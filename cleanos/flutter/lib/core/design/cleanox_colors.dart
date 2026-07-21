/// cleanox_colors.dart — ThemeExtension com os tokens que não cabem no ColorScheme.
///
/// Espelha `tokens.css`: superfícies, ink, linhas, feedback, STATUS de OS, cores
/// de GRUPO de serviço e a paleta FINANCEIRA — nas variantes clara e escura.
/// Acesso: `Theme.of(context).extension<CleanoxColors>()!` (ou `context.clx`).
library;

import 'package:flutter/material.dart';

import '../models/collections.dart' show OSStatus;
import '../models/servico.dart' show Grupo;

@immutable
class CleanoxColors extends ThemeExtension<CleanoxColors> {
  const CleanoxColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.bgSidebar,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.primary,
    required this.primary2,
    required this.onPrimary,
    required this.accent,
    required this.accent2,
    required this.line,
    required this.line2,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.errorBg,
    required this.successBg,
    required this.warningBg,
    required this.infoBg,
    required this.statusAgendada,
    required this.statusAtribuida,
    required this.statusEmAndamento,
    required this.statusConcluida,
    required this.statusCancelada,
    required this.statusAgendadaBg,
    required this.statusAtribuidaBg,
    required this.statusEmAndamentoBg,
    required this.statusConcluidaBg,
    required this.statusCanceladaBg,
    required this.groupPlano,
    required this.groupPromocao,
    required this.groupAdicional,
    required this.groupAvulsos,
    required this.groupSofa,
    required this.groupColchao,
    required this.groupOutros,
    required this.finIncome,
    required this.finExpense,
    required this.finInfo,
    required this.finMuted,
    required this.finSeries,
  });

  final Color bg, bg2, bg3, bgSidebar;
  final Color ink, ink2, ink3;
  final Color primary, primary2, onPrimary, accent, accent2;
  final Color line, line2;
  final Color error, success, warning, info;
  final Color errorBg, successBg, warningBg, infoBg;
  final Color statusAgendada,
      statusAtribuida,
      statusEmAndamento,
      statusConcluida,
      statusCancelada;
  final Color statusAgendadaBg,
      statusAtribuidaBg,
      statusEmAndamentoBg,
      statusConcluidaBg,
      statusCanceladaBg;
  final Color groupPlano,
      groupPromocao,
      groupAdicional,
      groupAvulsos,
      groupSofa,
      groupColchao,
      groupOutros;
  final Color finIncome, finExpense, finInfo, finMuted;

  /// Série de cores para donut/barras (--clx-fin-c1..c8).
  final List<Color> finSeries;

  /// Cor do texto/borda de um status de OS.
  Color statusColor(OSStatus s) => switch (s) {
    OSStatus.agendada => statusAgendada,
    OSStatus.atribuida => statusAtribuida,
    OSStatus.emAndamento => statusEmAndamento,
    OSStatus.concluida => statusConcluida,
    OSStatus.cancelada => statusCancelada,
  };

  /// Fundo (badge/chip) de um status de OS.
  Color statusBg(OSStatus s) => switch (s) {
    OSStatus.agendada => statusAgendadaBg,
    OSStatus.atribuida => statusAtribuidaBg,
    OSStatus.emAndamento => statusEmAndamentoBg,
    OSStatus.concluida => statusConcluidaBg,
    OSStatus.cancelada => statusCanceladaBg,
  };

  /// Cor do chip de um grupo de serviço.
  Color groupColor(Grupo g) => switch (g) {
    Grupo.plano => groupPlano,
    Grupo.promocao => groupPromocao,
    Grupo.adicional => groupAdicional,
    Grupo.avulsos => groupAvulsos,
    Grupo.sofa => groupSofa,
    Grupo.colchao => groupColchao,
    Grupo.outros => groupOutros,
  };

  /// Modo claro — paleta oficial Cleanox em toda a ferramenta.
  /// #0B1D34 · #0EA5B7 · #22D3EE · #F5F7FA · #7B8794
  static const CleanoxColors light = CleanoxColors(
    bg: Color(0xFFFFFFFF), // cards
    bg2: Color(0xFFF5F7FA), // canvas off-white
    bg3: Color(0xFFE8EEF3), // superfície elevada sutil
    bgSidebar: Color(0xFFF5F7FA),
    ink: Color(0xFF0B1D34), // navy
    ink2: Color(0xFF3D4F5F), // navy suavizado
    ink3: Color(0xFF7B8794), // cinza board
    primary: Color(0xFF0EA5B7), // teal menu/CTA (board)
    primary2: Color(0xFF0B8A98), // teal hover
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF0B1D34), // navy
    accent2: Color(0xFF152A45),
    line: Color(0x140B1D34),
    line2: Color(0x240B1D34),
    // Feedback: semântica clara, info alinhado à marca.
    error: Color(0xFFDC2626),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    info: Color(0xFF0EA5B7),
    errorBg: Color(0x1ADC2626),
    successBg: Color(0x1A15803D),
    warningBg: Color(0x1AB45309),
    infoBg: Color(0x1A0EA5B7),
    // Status de OS — família da marca + semântica.
    statusAgendada: Color(0xFF0EA5B7), // teal
    statusAtribuida: Color(0xFF0B1D34), // navy
    statusEmAndamento: Color(0xFF0B8A98),
    statusConcluida: Color(0xFF15803D),
    statusCancelada: Color(0xFFDC2626),
    statusAgendadaBg: Color(0x1A0EA5B7),
    statusAtribuidaBg: Color(0x140B1D34),
    statusEmAndamentoBg: Color(0x1A22D3EE),
    statusConcluidaBg: Color(0x1A15803D),
    statusCanceladaBg: Color(0x1ADC2626),
    groupPlano: Color(0xFF0B1D34),
    groupPromocao: Color(0xFF0EA5B7),
    groupAdicional: Color(0xFF22D3EE),
    groupAvulsos: Color(0xFF7B8794),
    groupSofa: Color(0xFF0EA5B7),
    groupColchao: Color(0xFF0B8A98),
    groupOutros: Color(0xFF7B8794),
    finIncome: Color(0xFF15803D),
    finExpense: Color(0xFFDC2626),
    finInfo: Color(0xFF0EA5B7),
    finMuted: Color(0xFF7B8794),
    finSeries: [
      Color(0xFF0EA5B7),
      Color(0xFF0B1D34),
      Color(0xFF22D3EE),
      Color(0xFF7B8794),
      Color(0xFF0B8A98),
      Color(0xFF152A45),
      Color(0xFF67E8F9),
      Color(0xFF94A3B8),
    ],
  );

  static const CleanoxColors dark = CleanoxColors(
    bg: Color(0xFF0C0C0C),
    bg2: Color(0xFF191919),
    bg3: Color(0xFF212121),
    bgSidebar: Color(0xFF191919),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xD1FFFFFF), // rgba(255,255,255,0.82)
    ink3: Color(0xFF9A9A9A), // ≥ 4.5:1 sobre bg/bg2/bg3 escuros
    primary: Color(0xFF38BDF8), // cyan mais claro no dark
    primary2: Color(0xFF0EA5E7),
    onPrimary: Color(0xFF0B1D34),
    accent: Color(0xFF38BDF8),
    accent2: Color(0xFF7DD3FC),
    line: Color(0x14FFFFFF),
    line2: Color(0x29FFFFFF),
    error: Color(0xFFF87171),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF38BDF8),
    errorBg: Color(0x26F87171),
    successBg: Color(0x264ADE80),
    warningBg: Color(0x26FBBF24),
    infoBg: Color(0x2638BDF8),
    statusAgendada: Color(0xFF38BDF8),
    statusAtribuida: Color(0xFFA78BFA),
    statusEmAndamento: Color(0xFFFBBF24),
    statusConcluida: Color(0xFF4ADE80),
    statusCancelada: Color(0xFFF87171),
    statusAgendadaBg: Color(0x2938BDF8),
    statusAtribuidaBg: Color(0x29A78BFA),
    statusEmAndamentoBg: Color(0x2EFBBF24),
    statusConcluidaBg: Color(0x294ADE80),
    statusCanceladaBg: Color(0x29F87171),
    groupPlano: Color(0xFF94A3B8),
    groupPromocao: Color(0xFFFBBF24),
    groupAdicional: Color(0xFF38BDF8),
    groupAvulsos: Color(0xFFFFB27A),
    groupSofa: Color(0xFFD8B4FE),
    groupColchao: Color(0xFFD8B4FE),
    groupOutros: Color(0xFF94A3B8),
    finIncome: Color(0xFF4ADE80),
    finExpense: Color(0xFFF87171),
    finInfo: Color(0xFF38BDF8),
    finMuted: Color(0xFF9A9A9A),
    finSeries: [
      Color(0xFF0EA5E7),
      Color(0xFF4ADE80),
      Color(0xFF38BDF8),
      Color(0xFFFBBF24),
      Color(0xFFA78BFA),
      Color(0xFFF472B6),
      Color(0xFF94A3B8),
      Color(0xFF4B5563),
    ],
  );

  /// Fintech claro = mesma paleta oficial (APK / web estreita).
  static const CleanoxColors fintechLight = CleanoxColors(
    bg: Color(0xFFFFFFFF),
    bg2: Color(0xFFF5F7FA),
    bg3: Color(0xFFE8EEF3),
    bgSidebar: Color(0xFFFFFFFF),
    ink: Color(0xFF0B1D34),
    ink2: Color(0xFF3D4F5F),
    ink3: Color(0xFF7B8794),
    primary: Color(0xFF0EA5B7),
    primary2: Color(0xFF0B8A98),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF0B1D34),
    accent2: Color(0xFF152A45),
    line: Color(0x140B1D34),
    line2: Color(0x240B1D34),
    error: Color(0xFFDC2626),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    info: Color(0xFF0EA5B7),
    errorBg: Color(0x1ADC2626),
    successBg: Color(0x1A15803D),
    warningBg: Color(0x1AB45309),
    infoBg: Color(0x1A0EA5B7),
    statusAgendada: Color(0xFF0EA5B7),
    statusAtribuida: Color(0xFF0B1D34),
    statusEmAndamento: Color(0xFF0B8A98),
    statusConcluida: Color(0xFF15803D),
    statusCancelada: Color(0xFFDC2626),
    statusAgendadaBg: Color(0x1A0EA5B7),
    statusAtribuidaBg: Color(0x140B1D34),
    statusEmAndamentoBg: Color(0x1A22D3EE),
    statusConcluidaBg: Color(0x1A15803D),
    statusCanceladaBg: Color(0x1ADC2626),
    groupPlano: Color(0xFF0B1D34),
    groupPromocao: Color(0xFF0EA5B7),
    groupAdicional: Color(0xFF22D3EE),
    groupAvulsos: Color(0xFF7B8794),
    groupSofa: Color(0xFF0EA5B7),
    groupColchao: Color(0xFF0B8A98),
    groupOutros: Color(0xFF7B8794),
    finIncome: Color(0xFF15803D),
    finExpense: Color(0xFFDC2626),
    finInfo: Color(0xFF0EA5B7),
    finMuted: Color(0xFF7B8794),
    finSeries: [
      Color(0xFF0EA5B7),
      Color(0xFF0B1D34),
      Color(0xFF22D3EE),
      Color(0xFF7B8794),
      Color(0xFF0B8A98),
      Color(0xFF152A45),
      Color(0xFF67E8F9),
      Color(0xFF94A3B8),
    ],
  );

  /// Fintech Clean dark — cyan Cleanox sobre navy.
  static const CleanoxColors fintechDark = CleanoxColors(
    bg: Color(0xFF0B1D34),
    bg2: Color(0xFF081526),
    bg3: Color(0xFF152A45),
    bgSidebar: Color(0xFF0B1D34),
    ink: Color(0xFFF3F5F6),
    ink2: Color(0xFFB7BEC4),
    ink3: Color(0xFF9CA6AE),
    primary: Color(0xFF38BDF8),
    primary2: Color(0xFF0EA5E7),
    onPrimary: Color(0xFF0B1D34),
    accent: Color(0xFF22D3EE),
    accent2: Color(0xFF7DD3FC),
    line: Color(0x14FFFFFF),
    line2: Color(0x29FFFFFF),
    error: Color(0xFFFF6B6E),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFFC24B),
    info: Color(0xFF38BDF8),
    errorBg: Color(0x24FF6B6E),
    successBg: Color(0x244ADE80),
    warningBg: Color(0x29FFC24B),
    infoBg: Color(0x2438BDF8),
    statusAgendada: Color(0xFF38BDF8),
    statusAtribuida: Color(0xFFA78BFA),
    statusEmAndamento: Color(0xFFFFC24B),
    statusConcluida: Color(0xFF4ADE80),
    statusCancelada: Color(0xFFFF6B6E),
    statusAgendadaBg: Color(0x2438BDF8),
    statusAtribuidaBg: Color(0x29A78BFA),
    statusEmAndamentoBg: Color(0x29FFC24B),
    statusConcluidaBg: Color(0x244ADE80),
    statusCanceladaBg: Color(0x24FF6B6E),
    groupPlano: Color(0xFF94A3B8),
    groupPromocao: Color(0xFFFBBF24),
    groupAdicional: Color(0xFF38BDF8),
    groupAvulsos: Color(0xFFFFB27A),
    groupSofa: Color(0xFFD8B4FE),
    groupColchao: Color(0xFFD8B4FE),
    groupOutros: Color(0xFF94A3B8),
    finIncome: Color(0xFF4ADE80),
    finExpense: Color(0xFFFF6B6E),
    finInfo: Color(0xFF38BDF8),
    finMuted: Color(0xFF9CA6AE),
    finSeries: [
      Color(0xFF38BDF8),
      Color(0xFFFF6B6E),
      Color(0xFFFFC24B),
      Color(0xFF0EA5E7),
      Color(0xFFA78BFA),
      Color(0xFF9CA6AE),
      Color(0xFFB7BEC4),
      Color(0xFF4B5563),
    ],
  );

  @override
  CleanoxColors copyWith({
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? bgSidebar,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? primary,
    Color? primary2,
    Color? onPrimary,
    Color? accent,
    Color? accent2,
    Color? line,
    Color? line2,
    Color? error,
    Color? success,
    Color? warning,
    Color? info,
    Color? errorBg,
    Color? successBg,
    Color? warningBg,
    Color? infoBg,
    Color? statusAgendada,
    Color? statusAtribuida,
    Color? statusEmAndamento,
    Color? statusConcluida,
    Color? statusCancelada,
    Color? statusAgendadaBg,
    Color? statusAtribuidaBg,
    Color? statusEmAndamentoBg,
    Color? statusConcluidaBg,
    Color? statusCanceladaBg,
    Color? groupPlano,
    Color? groupPromocao,
    Color? groupAdicional,
    Color? groupAvulsos,
    Color? groupSofa,
    Color? groupColchao,
    Color? groupOutros,
    Color? finIncome,
    Color? finExpense,
    Color? finInfo,
    Color? finMuted,
    List<Color>? finSeries,
  }) {
    return CleanoxColors(
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      primary: primary ?? this.primary,
      primary2: primary2 ?? this.primary2,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      errorBg: errorBg ?? this.errorBg,
      successBg: successBg ?? this.successBg,
      warningBg: warningBg ?? this.warningBg,
      infoBg: infoBg ?? this.infoBg,
      statusAgendada: statusAgendada ?? this.statusAgendada,
      statusAtribuida: statusAtribuida ?? this.statusAtribuida,
      statusEmAndamento: statusEmAndamento ?? this.statusEmAndamento,
      statusConcluida: statusConcluida ?? this.statusConcluida,
      statusCancelada: statusCancelada ?? this.statusCancelada,
      statusAgendadaBg: statusAgendadaBg ?? this.statusAgendadaBg,
      statusAtribuidaBg: statusAtribuidaBg ?? this.statusAtribuidaBg,
      statusEmAndamentoBg: statusEmAndamentoBg ?? this.statusEmAndamentoBg,
      statusConcluidaBg: statusConcluidaBg ?? this.statusConcluidaBg,
      statusCanceladaBg: statusCanceladaBg ?? this.statusCanceladaBg,
      groupPlano: groupPlano ?? this.groupPlano,
      groupPromocao: groupPromocao ?? this.groupPromocao,
      groupAdicional: groupAdicional ?? this.groupAdicional,
      groupAvulsos: groupAvulsos ?? this.groupAvulsos,
      groupSofa: groupSofa ?? this.groupSofa,
      groupColchao: groupColchao ?? this.groupColchao,
      groupOutros: groupOutros ?? this.groupOutros,
      finIncome: finIncome ?? this.finIncome,
      finExpense: finExpense ?? this.finExpense,
      finInfo: finInfo ?? this.finInfo,
      finMuted: finMuted ?? this.finMuted,
      finSeries: finSeries ?? this.finSeries,
    );
  }

  @override
  CleanoxColors lerp(covariant CleanoxColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    List<Color> cs(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], i < b.length ? b[i] : a[i]),
    ];
    return CleanoxColors(
      bg: c(bg, other.bg),
      bg2: c(bg2, other.bg2),
      bg3: c(bg3, other.bg3),
      bgSidebar: c(bgSidebar, other.bgSidebar),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      primary: c(primary, other.primary),
      primary2: c(primary2, other.primary2),
      onPrimary: c(onPrimary, other.onPrimary),
      accent: c(accent, other.accent),
      accent2: c(accent2, other.accent2),
      line: c(line, other.line),
      line2: c(line2, other.line2),
      error: c(error, other.error),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      info: c(info, other.info),
      errorBg: c(errorBg, other.errorBg),
      successBg: c(successBg, other.successBg),
      warningBg: c(warningBg, other.warningBg),
      infoBg: c(infoBg, other.infoBg),
      statusAgendada: c(statusAgendada, other.statusAgendada),
      statusAtribuida: c(statusAtribuida, other.statusAtribuida),
      statusEmAndamento: c(statusEmAndamento, other.statusEmAndamento),
      statusConcluida: c(statusConcluida, other.statusConcluida),
      statusCancelada: c(statusCancelada, other.statusCancelada),
      statusAgendadaBg: c(statusAgendadaBg, other.statusAgendadaBg),
      statusAtribuidaBg: c(statusAtribuidaBg, other.statusAtribuidaBg),
      statusEmAndamentoBg: c(statusEmAndamentoBg, other.statusEmAndamentoBg),
      statusConcluidaBg: c(statusConcluidaBg, other.statusConcluidaBg),
      statusCanceladaBg: c(statusCanceladaBg, other.statusCanceladaBg),
      groupPlano: c(groupPlano, other.groupPlano),
      groupPromocao: c(groupPromocao, other.groupPromocao),
      groupAdicional: c(groupAdicional, other.groupAdicional),
      groupAvulsos: c(groupAvulsos, other.groupAvulsos),
      groupSofa: c(groupSofa, other.groupSofa),
      groupColchao: c(groupColchao, other.groupColchao),
      groupOutros: c(groupOutros, other.groupOutros),
      finIncome: c(finIncome, other.finIncome),
      finExpense: c(finExpense, other.finExpense),
      finInfo: c(finInfo, other.finInfo),
      finMuted: c(finMuted, other.finMuted),
      finSeries: cs(finSeries, other.finSeries),
    );
  }
}

/// Açúcar: `context.clx.primary`.
extension CleanoxColorsX on BuildContext {
  CleanoxColors get clx =>
      Theme.of(this).extension<CleanoxColors>() ?? CleanoxColors.light;
}
