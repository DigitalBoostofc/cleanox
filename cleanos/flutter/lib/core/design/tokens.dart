/// tokens.dart — Design tokens do CleanOS em Dart.
///
/// Design tokens Cleanox: navy `#0B1D34` + cyan `#0EA5E7` (board oficial),
/// raios, espaçamentos, sombras e tipografia Sora (Poppins = P1).
/// Nenhuma feature usa cor hardcoded — tudo vem daqui ou do `CleanoxColors`.
library;

import 'package:flutter/material.dart';

/// Família tipográfica de marca. Os .ttf são registrados no pubspec quando os
/// binários entrarem no repo; até lá, cai no fallback do sistema.
const String kFontFamily = 'Sora';

/// Raios de borda (--clx-r-*).
class ClxRadii {
  const ClxRadii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 100;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

/// Escala de espaçamento (múltiplos de 4; toque mínimo 48 no mobile).
class ClxSpace {
  const ClxSpace._();
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
}

/// Layout (--clx-*-w/-h).
class ClxLayout {
  const ClxLayout._();
  static const double sidebarW = 240;
  static const double topbarH = 64;
  static const double bottomNavH = 64;
  static const double contentMaxW = 1200;

  /// Toque mínimo (Material / Android). iOS 44.
  static const double minTouchTarget = 48;

  /// Limite inferior da janela "medium" MD3 (compact < 600dp ≤ medium).
  /// Valor canônico do projeto — não duplicar em outros arquivos.
  static const double narrowBreakpoint = 600;
}

/// Nome de exibição do produto na UI (login, sidebar, título do app).
/// Package/API/IDs técnicos continuam `cleanos` — só a marca visível muda.
const String kAppDisplayName = 'Cleanox';

/// Tagline oficial da marca (login / hero).
const String kAppTagline = 'Higienização de estofados';

/// Cores de marca Cleanox — paleta oficial (board / kit de marca).
///
/// ```
/// #0B1D34  navy        — texto, sidebar, accent
/// #0EA5E7  cyan        — CTA, foco, OX
/// #22D3EE  cyan claro  — gradientes, destaques
/// #F5F7FA  off-white   — canvas / fundos
/// #7B8794  cinza       — texto secundário
/// ```
class ClxBrand {
  const ClxBrand._();

  /// Navy profundo — wordmark CLEAN, headers, rail.
  static const Color navy = Color(0xFF0B1D34);

  /// Teal/cyan principal — CTA, item de menu selecionado, OX.
  /// Board: #0EA5B7 (não o sky #0EA5E7).
  static const Color cyan = Color(0xFF0EA5B7);

  /// Cyan claro — brilhos, gradientes, acentos secundários.
  static const Color cyanLight = Color(0xFF22D3EE);

  /// Off-white — canvas do modo claro.
  static const Color canvas = Color(0xFFF5F7FA);

  /// Cinza — texto muted / ícones neutros.
  static const Color muted = Color(0xFF7B8794);

  // Aliases usados no tema (compat).
  static const Color primary = cyan;
  static const Color primary2 = Color(0xFF0B8A98); // hover do teal
  static const Color primaryLight = cyanLight;
  static const Color accent = navy;
  static const Color accent2 = Color(0xFF152A45); // hover do navy

  /// Texto/ícone sobre [primary] (branco sobre teal #0EA5B7).
  static const Color onPrimary = Color(0xFFFFFFFF);
}

/// Sombras (--clx-shadow-*), variante clara (base navy Cleanox).
class ClxShadows {
  const ClxShadows._();
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x140B1D34),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A0B1D34),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x0A0B1D34),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x290B1D34),
      blurRadius: 60,
      offset: Offset(0, 24),
    ),
  ];

  /// Card de página / painel flutuando no canvas.
  static const List<BoxShadow> float = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0A0EA5E7),
      blurRadius: 40,
      offset: Offset(0, 4),
    ),
  ];
}

/// Curvas de animação (--clx-ease-*).
class ClxEase {
  const ClxEase._();
  static const Cubic out = Cubic(0.22, 1, 0.36, 1);
  static const Cubic soft = Cubic(0.65, 0, 0.35, 1);
}

/// Motion tokens MD3 (easing + duração por tipo de transição).
///
/// Espelha a spec m3.material.io/styles/motion: `emphasized*` para transições
/// que definem o caráter da UI (painéis, accordions, trocas de tela) e
/// `standard*` para utilitárias (hover, fades pequenos). As curvas vêm do
/// próprio Flutter ([Easing]) — já são os cubic-beziers oficiais do MD3.
class ClxMotion {
  const ClxMotion._();

  // Enter/exit "emphasized" — elementos que entram/saem de cena.
  static const Curve emphasized = Easing.emphasizedDecelerate;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;
  static const Duration emphasizedDuration = Durations.medium4; // 400ms
  static const Duration emphasizedExitDuration = Durations.short4; // 200ms

  // Utilitárias "standard" — mudanças pequenas dentro da tela.
  static const Curve standard = Easing.standard;
  static const Curve standardDecelerate = Easing.standardDecelerate;
  static const Curve standardAccelerate = Easing.standardAccelerate;
  static const Duration standardDuration = Durations.medium2; // 300ms
  static const Duration shortDuration = Durations.short3; // 150ms
}

/// Cor do **placeholder** (hint) dos campos de formulário.
///
/// O hint é só um EXEMPLO ("Rua das Flores, 123"), não um dado digitado. Antes
/// ele usava `ink3` e ficava em ~5.5:1 de contraste — mais forte que muito texto
/// de corpo, então o dono confundia campo vazio com campo preenchido.
///
/// Aqui ele é deliberadamente fraco, pra criar uma diferença ÓBVIA contra o
/// texto digitado (que fica em ~17:1):
///   claro  #9AA7B0 sobre branco   → ~2.5:1
///   escuro #626262 sobre #191919  → ~2.9:1
///
/// ⚠️ Isso fica ABAIXO do mínimo WCAG de 4.5:1 — de propósito, e é seguro aqui
/// porque o hint não carrega informação: todo campo tem um rótulo real acima
/// ("Nome", "Telefone", "CEP"). Quem lê o rótulo não perde nada. NÃO use esta
/// cor para texto que precise ser lido.
Color clxHintColor(bool isDark) =>
    isDark ? const Color(0xFF626262) : const Color(0xFF9AA7B0);
