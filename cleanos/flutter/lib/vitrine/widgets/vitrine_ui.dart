/// Componentes de UI da vitrine — alinhados aos mockups mobile Cleanox.
library;

import 'dart:math' show cos, sin;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
// logo: assets/brand/logo_cleanox_color.png

/// Canvas e superfícies do mockup.
abstract final class VitrineUi {
  static const bg = ClxBrand.canvas;
  static const card = Colors.white;
  static const line = Color(0xFFE2E8F0);
  static const ink2 = Color(0xFF3D4F63);
  static const rMd = 14.0;
  static const rLg = 20.0;
  static const rPill = 999.0;

  /// Largura máxima do conteúdo público (home + todas as etapas do funil).
  static const double contentMaxWidth = 1180;

  /// Proporções canônicas do cabeçalho (home, funil, brand bar).
  static const double headerPadH = 16;
  static const double headerPadV = 10;
  /// Altura da faixa de conteúdo do header (alinha logo + ações).
  static const double headerRowH = 44;
  static const double logoH = 36;
  static const double logoW = 140;
  static const String logoAsset = 'assets/brand/logo_cleanox_color.png';

  static BoxDecoration cardDeco({
    Color? border,
    double radius = rMd,
    bool selected = false,
  }) =>
      BoxDecoration(
        color: selected ? ClxBrand.cyan.withValues(alpha: 0.04) : card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? ClxBrand.cyan
              : (border ?? line),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: ClxBrand.cyan.withValues(alpha: 0.12),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0A0B1D34),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      );
}

/// Logo oficial Cleanox — mesmo tamanho em todas as barras da Vitrine.
class VitrineBrandLogo extends StatelessWidget {
  const VitrineBrandLogo({
    super.key,
    this.onDark = false,
  });

  /// Se true, fallback de texto fica branco (header legado navy).
  final bool onDark;

  Widget _fallback() => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'CLEANOX',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: onDark ? Colors.white : ClxBrand.navy,
            letterSpacing: 0.6,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Na web, Image.asset às vezes falha silenciosamente com SW/cache;
    // tenta network no mesmo origin e cai no asset/texto.
    final Widget img;
    if (kIsWeb) {
      final url =
          '${Uri.base.origin}/assets/assets/brand/logo_cleanox_color.png';
      img = Image.network(
        url,
        height: VitrineUi.logoH,
        width: VitrineUi.logoW,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Image.asset(
          VitrineUi.logoAsset,
          height: VitrineUi.logoH,
          width: VitrineUi.logoW,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    } else {
      img = Image.asset(
        VitrineUi.logoAsset,
        height: VitrineUi.logoH,
        width: VitrineUi.logoW,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return SizedBox(
      height: VitrineUi.logoH,
      width: VitrineUi.logoW,
      child: img,
    );
  }
}

/// Casco comum do cabeçalho claro (mesma altura/padding em todas as telas).
class VitrineHeaderShell extends StatelessWidget {
  const VitrineHeaderShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VitrineUi.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            VitrineUi.headerPadH,
            VitrineUi.headerPadV,
            VitrineUi.headerPadH,
            VitrineUi.headerPadV,
          ),
          child: SizedBox(
            height: VitrineUi.headerRowH,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Centraliza a experiência pública sem deixar o conteúdo esticar em telas
/// largas. No mobile ocupa toda a largura disponível.
class VitrineContentFrame extends StatelessWidget {
  const VitrineContentFrame({
    super.key,
    required this.child,
    this.maxWidth = VitrineUi.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

/// Topbar claro: logo + chip WhatsApp (home pública — sem conta).
class VitrineLightTopBar extends StatelessWidget {
  const VitrineLightTopBar({super.key, this.whatsapp});

  final String? whatsapp;

  Future<void> _openWa() async {
    final raw = (whatsapp ?? '').replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return;
    final uri = Uri.parse('https://wa.me/55$raw');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return VitrineHeaderShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const VitrineBrandLogo(),
          const Spacer(),
          if ((whatsapp ?? '').trim().isNotEmpty)
            Material(
              color: const Color(0x1A059669),
              borderRadius: BorderRadius.circular(VitrineUi.rPill),
              child: InkWell(
                onTap: _openWa,
                borderRadius: BorderRadius.circular(VitrineUi.rPill),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat, size: 16, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Header claro do funil (passos 1–4): volta + logo + chip de etapa.
/// Mesmas proporções/logo da home ([VitrineHeaderShell] + [VitrineBrandLogo]).
class VitrineLightStepHeader extends StatelessWidget {
  const VitrineLightStepHeader({
    super.key,
    required this.stepLabel,
    this.onBack,
  });

  final String stepLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return VitrineHeaderShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null)
            SizedBox(
              width: 40,
              height: VitrineUi.headerRowH,
              child: IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: VitrineUi.headerRowH,
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: ClxBrand.navy,
              ),
            )
          else
            const SizedBox(width: 0),
          const VitrineBrandLogo(),
          const Spacer(),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(VitrineUi.rPill),
                  border: Border.all(color: VitrineUi.line),
                ),
                child: Text(
                  stepLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    color: ClxBrand.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header navy arredondado + pill de passo (legado / opcional).
class VitrineNavyHeader extends StatelessWidget {
  const VitrineNavyHeader({
    super.key,
    required this.stepLabel,
    this.onBack,
  });

  final String stepLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        left: 16,
        right: 16,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [ClxBrand.navy, ClxBrand.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ],
          const VitrineBrandLogo(onDark: true),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VitrineUi.rPill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              stepLabel,
              style: const TextStyle(
                fontFamily: kFontFamily,
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom nav: Início · **Carrinho (FAB redondo suspenso)** · Como funciona.
/// Barra baixa + círculo sobreposto (como o FAB do casco Easypay do painel).
///
/// Hit-test: o FAB NÃO usa `Positioned(top: -lift)` dentro de uma barra baixa —
/// isso deixa a metade de cima do círculo fora do retângulo de toque (só a
/// parte de baixo clicava). A estrutura é Stack com altura total
/// `lift + barra + safe`, FAB no topo (y=0) e barra ancorada embaixo.
class VitrineBottomNav extends StatelessWidget {
  const VitrineBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    this.cartCount = 0,
  });

  /// 0 início · 1 carrinho · 2 como funciona
  final int index;
  final ValueChanged<int> onTap;

  /// Itens no carrinho (badge vermelho no FAB).
  final int cartCount;

  static const double _fabSize = 58;
  /// Quanto o FAB sobe por cima da barra (flutuação forte).
  static const double _fabLift = 36;
  /// Altura da faixa branca (sem safe-area).
  static const double _barH = 54;
  static const double _centerSlot = 84;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Altura total = lift (só o FAB) + barra + safe-area. Tudo dentro do
    // retângulo recebe hit-test; o círculo não "vaza" para cima do Stack.
    return SizedBox(
      height: _fabLift + _barH + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Barra branca (só a faixa inferior).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barH + bottom,
            child: Material(
              elevation: 12,
              shadowColor: const Color(0x1A0B1D34),
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140B1D34),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: Row(
                    children: [
                      _sideItem(0, Icons.home_rounded, 'Início'),
                      const SizedBox(width: _centerSlot),
                      _sideItem(2, Icons.info_outline_rounded, 'Como funciona'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // FAB central: topo do Stack = topo do círculo (clicável inteiro).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _carrinhoFab()),
          ),
        ],
      ),
    );
  }

  Widget _sideItem(int i, IconData icon, String label) {
    final on = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              icon,
              size: 22,
              color: on ? ClxBrand.cyan : ClxBrand.muted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: on ? ClxBrand.cyan : ClxBrand.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Círculo elevado + ícone de carrinho + badge de quantidade.
  Widget _carrinhoFab() {
    final on = index == 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('vitrine-nav-agendar'),
        onTap: () => onTap(1),
        borderRadius: BorderRadius.circular(_centerSlot / 2),
        child: SizedBox(
          width: _centerSlot,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hit-box explícita do círculo (centro do toque).
              SizedBox(
                width: _fabSize + 8,
                height: _fabSize + 8,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: _fabSize,
                        height: _fabSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: on
                                ? const [
                                    Color(0xFF0B1D34),
                                    Color(0xFF0B8A98),
                                    Color(0xFF0EA5B7),
                                  ]
                                : const [
                                    Color(0xFF0EA5B7),
                                    Color(0xFF0B8A98),
                                  ],
                          ),
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            // Sombra profunda = "descolado" da barra.
                            BoxShadow(
                              color: const Color(0xFF0B1D34).withValues(alpha: 0.22),
                              blurRadius: 22,
                              spreadRadius: 0,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: ClxBrand.cyan.withValues(alpha: 0.55),
                              blurRadius: 28,
                              spreadRadius: 1,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: ClxBrand.cyan.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        // Carrinho em stroke branco (não depende de MaterialIcons no web).
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CustomPaint(
                              painter: _VitrineFabCartPainter(),
                            ),
                          ),
                        ),
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            key: const Key('vitrine-nav-cart-badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            child: Text(
                              cartCount > 99 ? '99+' : '$cartCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Carrinho',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: on ? ClxBrand.cyan : ClxBrand.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carrinho de compras em stroke branco — independente de MaterialIcons (web).
class _VitrineFabCartPainter extends CustomPainter {
  const _VitrineFabCartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * 0.095).clamp(1.8, 2.6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Corpo do carrinho (trapézio arredondado).
    final basket = Path()
      ..moveTo(w * 0.18, h * 0.32)
      ..lineTo(w * 0.88, h * 0.32)
      ..lineTo(w * 0.78, h * 0.72)
      ..lineTo(w * 0.28, h * 0.72)
      ..close();
    canvas.drawPath(basket, stroke);

    // Alça / abertura superior.
    final handle = Path()
      ..moveTo(w * 0.22, h * 0.32)
      ..lineTo(w * 0.30, h * 0.14)
      ..lineTo(w * 0.52, h * 0.14);
    canvas.drawPath(handle, stroke);

    // Rodinhas.
    final r = w * 0.075;
    canvas.drawCircle(Offset(w * 0.36, h * 0.86), r, stroke);
    canvas.drawCircle(Offset(w * 0.68, h * 0.86), r, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CTA sticky do mockup (total + botão pill).
///
/// Em telas estreitas o total **não** estoura: label com ellipsis e valor com
/// [FittedBox] (fonte encolhe se precisar).
class VitrineStickyBar extends StatelessWidget {
  const VitrineStickyBar({
    super.key,
    this.totalLabel,
    this.totalValue,
    this.totalCaption,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
  });

  final String? totalLabel;
  final String? totalValue;

  /// Texto auxiliar acima do valor (ex.: "Valor estimado").
  final String? totalCaption;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final labelSize = scaler.scale(13).clamp(11.0, 16.0);
    final valueSize = scaler.scale(20).clamp(15.0, 24.0);
    final captionSize = scaler.scale(11).clamp(10.0, 13.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140B1D34),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: VitrineUi.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalLabel != null && totalValue != null) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 380;
                    final label = Text(
                      totalLabel!,
                      maxLines: narrow ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: labelSize,
                        color: ClxBrand.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                    final valueBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((totalCaption ?? '').trim().isNotEmpty)
                          Text(
                            totalCaption!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: captionSize,
                              color: ClxBrand.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            totalValue!,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: valueSize,
                              fontWeight: FontWeight.w800,
                              color: ClxBrand.navy,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          label,
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: valueBlock,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: label),
                        const SizedBox(width: 12),
                        Flexible(child: valueBlock),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: loading ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: ClxBrand.cyan,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        ClxBrand.cyan.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VitrineUi.rPill),
                    ),
                    textStyle: TextStyle(
                      fontFamily: kFontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: scaler.scale(15).clamp(13.0, 18.0),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero gradiente do mockup (+ foto opcional da CMS).
class VitrineHeroCard extends StatelessWidget {
  const VitrineHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onCta,
    this.showCta = true,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onCta;
  final bool showCta;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: wide ? 220 : 168),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VitrineUi.rLg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B1D34),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImg
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _HeroGradient(),
                  )
                : const _HeroGradient(),
          ),
          if (hasImg)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ClxBrand.navy.withValues(alpha: 0.82),
                      ClxBrand.cyan.withValues(alpha: 0.45),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            )
          else
            const Positioned.fill(child: _HeroGradient()),
          if (!hasImg && wide)
            Positioned(
              key: const Key('vitrine-hero-art'),
              right: 72,
              top: 20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  size: 78,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(wide ? 32 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 560 : 280),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.white,
                      fontSize: wide ? 30 : 18,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 520 : 280),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: wide ? 15 : 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (showCta)
                  FilledButton(
                    key: const Key('vitrine-hero-cta'),
                    onPressed: onCta,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ClxBrand.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VitrineUi.rPill),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: kFontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    child: Text(cta),
                  ),
              ],
            ),
          ),
          ],
        ),
        );
      },
    );
  }
}

class _HeroGradient extends StatelessWidget {
  const _HeroGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1D34), Color(0xFF0B8A98), ClxBrand.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// Item de categoria (ícone e/ou imagem CMS).
class VitrineCatItem {
  const VitrineCatItem({
    required this.icon,
    required this.label,
    this.filter,
    this.imageUrl,
  });
  final IconData icon;
  final String label;
  final String? filter;
  final String? imageUrl;
}

/// Glifos desenhados (CustomPaint) — Material Icons some no Flutter web.
enum VitrineChoiceGlyph {
  car,
  clean,
  sofa,
  bed,
  chair,
  seat,
  layers,
  star,
  offer,
  add,
  sparkle,
  more,
  roof,
  texture,
  grid,
  home,
  category,
  brush,
  garage,
  moto,
}

/// Mapa CMS de macros → glifo.
VitrineChoiceGlyph vitrineMacroGlyph(String key) {
  switch (key.trim().toLowerCase()) {
    case 'cleaning':
    case 'limpeza':
      return VitrineChoiceGlyph.clean;
    case 'sofa':
    case 'sofá':
    case 'weekend':
      return VitrineChoiceGlyph.sofa;
    case 'home':
    case 'casa':
      return VitrineChoiceGlyph.home;
    case 'car':
    case 'auto':
    case 'carro':
      return VitrineChoiceGlyph.car;
    case 'garage':
    case 'garagem':
      return VitrineChoiceGlyph.garage;
    case 'spray':
      return VitrineChoiceGlyph.brush;
    default:
      return VitrineChoiceGlyph.category;
  }
}

/// Mapa de grupo/slug da taxonomia → glifo representativo.
VitrineChoiceGlyph vitrineGrupoGlyph(String slug) {
  switch (slug.trim().toLowerCase()) {
    case 'sofa':
    case 'sofá':
    case 'sofaa':
      return VitrineChoiceGlyph.sofa;
    case 'colchao':
    case 'colchão':
    case 'colchoes':
    case 'colchões':
      return VitrineChoiceGlyph.bed;
    case 'plano':
    case 'planos':
      return VitrineChoiceGlyph.star;
    case 'promocao':
    case 'promoção':
    case 'promo':
      return VitrineChoiceGlyph.offer;
    case 'adicional':
    case 'adicionais':
      return VitrineChoiceGlyph.add;
    case 'avulsos':
    case 'avulso':
      return VitrineChoiceGlyph.sparkle;
    case 'higienizacao_interna':
    case 'higienizacao':
      return VitrineChoiceGlyph.clean;
    case 'lavagens_essenciais':
    case 'lavagem':
    case 'lavagens':
      return VitrineChoiceGlyph.car;
    case 'lavagens_moto':
    case 'moto':
    case 'motos':
      return VitrineChoiceGlyph.moto;
    case 'outros':
    case 'outro':
      return VitrineChoiceGlyph.more;
    case 'cadeira':
    case 'cadeiras':
    case 'poltrona':
    case 'poltronas':
      return VitrineChoiceGlyph.chair;
    case 'tapete':
    case 'tapetes':
      return VitrineChoiceGlyph.layers;
    case 'banco':
    case 'bancos':
      return VitrineChoiceGlyph.seat;
    case 'teto':
      return VitrineChoiceGlyph.roof;
    case 'carpete':
    case 'carpetes':
      return VitrineChoiceGlyph.texture;
    default:
      return VitrineChoiceGlyph.grid;
  }
}

/// Nome do grupo na vitrine (acento e copy do lead).
String vitrineLabelGrupo(String slug) {
  switch (slug.trim().toLowerCase()) {
    case 'lavagens_essenciais':
      return 'Lavagens de carro';
    case 'lavagens_moto':
      return 'Lavagens de moto';
    case 'higienizacao_interna':
    case 'higienizacao':
      return 'Higienização interna';
    case 'promocao':
    case 'promoção':
      return 'Promoções';
    case 'adicional':
    case 'adicionais':
      return 'Adicionais';
    case 'avulsos':
    case 'avulso':
      return 'Avulsos';
    case 'sofa':
      return 'Sofá';
    case 'colchao':
      return 'Colchão e box';
    case 'poltrona_puff':
      return 'Poltrona e puff';
    case 'cadeiras':
      return 'Cadeiras';
    case 'tapetes':
      return 'Tapetes';
    case 'plano':
      return 'Planos';
    case 'outros':
      return 'Outros';
    default:
      final s = slug.trim();
      if (s.isEmpty) return 'Outros';
      return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}

const _ordemVeicular = [
  'lavagens_essenciais',
  'lavagens_moto',
  'higienizacao_interna',
  'promocao',
  'avulsos',
  'adicional',
];

const _ordemResidencial = [
  'sofa',
  'colchao',
  'poltrona_puff',
  'cadeiras',
  'tapetes',
  'outros',
];

/// Ordem dos cards de grupo: lavagens no topo, extras no fim.
List<String> ordenarGruposVitrine(String macro, Iterable<String> slugs) {
  final rankOf = macro == 'veicular'
      ? _ordemVeicular
      : macro == 'residencial'
      ? _ordemResidencial
      : const <String>[];
  int rank(String s) {
    final i = rankOf.indexOf(s);
    return i < 0 ? 100 : i;
  }

  final out = slugs.toList();
  out.sort((a, b) {
    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : a.compareTo(b);
  });
  return out;
}

/// Compat: ainda expõe IconData para telas legadas — preferir [VitrineChoiceIcon].
IconData vitrineMacroIcon(String key) {
  switch (vitrineMacroGlyph(key)) {
    case VitrineChoiceGlyph.clean:
      return Icons.cleaning_services;
    case VitrineChoiceGlyph.sofa:
      return Icons.weekend;
    case VitrineChoiceGlyph.home:
      return Icons.home;
    case VitrineChoiceGlyph.car:
      return Icons.directions_car;
    case VitrineChoiceGlyph.garage:
      return Icons.garage;
    case VitrineChoiceGlyph.brush:
      return Icons.brush;
    default:
      return Icons.category;
  }
}

/// Ícone de escolha na paleta Cleanox (navy/cyan) — não depende da fonte Material.
class VitrineChoiceIcon extends StatelessWidget {
  const VitrineChoiceIcon({
    super.key,
    required this.glyph,
    this.color = ClxBrand.cyan,
    this.size = 28,
  });

  final VitrineChoiceGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VitrineChoiceGlyphPainter(glyph: glyph, color: color),
      ),
    );
  }
}

class _VitrineChoiceGlyphPainter extends CustomPainter {
  _VitrineChoiceGlyphPainter({required this.glyph, required this.color});

  final VitrineChoiceGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final s = size.shortestSide;
    final o = Offset(size.width / 2, size.height / 2);

    switch (glyph) {
      case VitrineChoiceGlyph.car:
        _car(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.clean:
        _clean(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.sofa:
        _sofa(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.bed:
        _bed(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.chair:
        _chair(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.seat:
        _seat(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.layers:
        _layers(canvas, o, s, p);
      case VitrineChoiceGlyph.star:
        _star(canvas, o, s, fill);
      case VitrineChoiceGlyph.offer:
        _offer(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.add:
        _add(canvas, o, s, p);
      case VitrineChoiceGlyph.sparkle:
        _sparkle(canvas, o, s, p);
      case VitrineChoiceGlyph.more:
        _more(canvas, o, s, fill);
      case VitrineChoiceGlyph.roof:
        _roof(canvas, o, s, p);
      case VitrineChoiceGlyph.texture:
        _texture(canvas, o, s, p);
      case VitrineChoiceGlyph.grid:
        _grid(canvas, o, s, p);
      case VitrineChoiceGlyph.home:
        _home(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.category:
        _category(canvas, o, s, p);
      case VitrineChoiceGlyph.brush:
        _brush(canvas, o, s, p, fill);
      case VitrineChoiceGlyph.garage:
        _garage(canvas, o, s, p);
      case VitrineChoiceGlyph.moto:
        _moto(canvas, o, s, p, fill);
    }
  }

  void _car(Canvas c, Offset o, double s, Paint p, Paint fill) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o.translate(0, s * 0.02), width: s * 0.72, height: s * 0.34),
      Radius.circular(s * 0.08),
    );
    c.drawRRect(body, p);
    final cabin = Path()
      ..moveTo(o.dx - s * 0.18, o.dy - s * 0.05)
      ..lineTo(o.dx - s * 0.08, o.dy - s * 0.28)
      ..lineTo(o.dx + s * 0.12, o.dy - s * 0.28)
      ..lineTo(o.dx + s * 0.22, o.dy - s * 0.05)
      ..close();
    c.drawPath(cabin, p);
    c.drawCircle(Offset(o.dx - s * 0.22, o.dy + s * 0.22), s * 0.09, fill);
    c.drawCircle(Offset(o.dx + s * 0.22, o.dy + s * 0.22), s * 0.09, fill);
  }

  void _clean(Canvas c, Offset o, double s, Paint p, Paint fill) {
    // sparkles / limpeza
    c.drawCircle(o, s * 0.08, fill);
    for (final a in [0.0, 1.0, 2.0, 3.0]) {
      final rad = a * 3.14159 / 2;
      final d = Offset(cos(rad), sin(rad));
      c.drawLine(o + d * s * 0.16, o + d * s * 0.34, p);
    }
    c.drawLine(
      Offset(o.dx - s * 0.28, o.dy + s * 0.28),
      Offset(o.dx + s * 0.28, o.dy + s * 0.28),
      p,
    );
  }

  void _sofa(Canvas c, Offset o, double s, Paint p, Paint fill) {
    final seat = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o.translate(0, s * 0.06), width: s * 0.7, height: s * 0.28),
      Radius.circular(s * 0.08),
    );
    c.drawRRect(seat, p);
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx - s * 0.35, o.dy - s * 0.28, s * 0.7, s * 0.22),
      Radius.circular(s * 0.08),
    );
    c.drawRRect(back, p);
    c.drawLine(
      Offset(o.dx - s * 0.28, o.dy + s * 0.2),
      Offset(o.dx - s * 0.28, o.dy + s * 0.32),
      p,
    );
    c.drawLine(
      Offset(o.dx + s * 0.28, o.dy + s * 0.2),
      Offset(o.dx + s * 0.28, o.dy + s * 0.32),
      p,
    );
  }

  void _bed(Canvas c, Offset o, double s, Paint p, Paint fill) {
    // headboard
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx - s * 0.34, o.dy - s * 0.3, s * 0.14, s * 0.46),
        Radius.circular(s * 0.04),
      ),
      p,
    );
    // mattress
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx - s * 0.2, o.dy - s * 0.06, s * 0.54, s * 0.22),
        Radius.circular(s * 0.06),
      ),
      p,
    );
    // legs
    c.drawLine(Offset(o.dx - s * 0.12, o.dy + s * 0.16), Offset(o.dx - s * 0.12, o.dy + s * 0.3), p);
    c.drawLine(Offset(o.dx + s * 0.28, o.dy + s * 0.16), Offset(o.dx + s * 0.28, o.dy + s * 0.3), p);
  }

  void _chair(Canvas c, Offset o, double s, Paint p, Paint fill) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o.translate(0, s * 0.04), width: s * 0.42, height: s * 0.2),
        Radius.circular(s * 0.05),
      ),
      p,
    );
    c.drawLine(Offset(o.dx - s * 0.18, o.dy - s * 0.28), Offset(o.dx - s * 0.18, o.dy + s * 0.05), p);
    c.drawLine(Offset(o.dx - s * 0.18, o.dy - s * 0.28), Offset(o.dx + s * 0.16, o.dy - s * 0.28), p);
    c.drawLine(Offset(o.dx - s * 0.14, o.dy + s * 0.14), Offset(o.dx - s * 0.14, o.dy + s * 0.3), p);
    c.drawLine(Offset(o.dx + s * 0.14, o.dy + s * 0.14), Offset(o.dx + s * 0.14, o.dy + s * 0.3), p);
  }

  void _seat(Canvas c, Offset o, double s, Paint p, Paint fill) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o, width: s * 0.55, height: s * 0.28),
        Radius.circular(s * 0.08),
      ),
      p,
    );
    c.drawLine(Offset(o.dx - s * 0.22, o.dy - s * 0.02), Offset(o.dx - s * 0.22, o.dy - s * 0.28), p);
  }

  void _layers(Canvas c, Offset o, double s, Paint p) {
    for (var i = 0; i < 3; i++) {
      final dy = (i - 1) * s * 0.14;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: o.translate(0, dy), width: s * 0.62 - i * s * 0.06, height: s * 0.12),
          Radius.circular(s * 0.04),
        ),
        p,
      );
    }
  }

  void _star(Canvas c, Offset o, double s, Paint fill) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -3.14159 / 2 + i * 2 * 3.14159 / 5;
      final a2 = a + 3.14159 / 5;
      final outer = Offset(o.dx + cos(a) * s * 0.34, o.dy + sin(a) * s * 0.34);
      final inner = Offset(o.dx + cos(a2) * s * 0.14, o.dy + sin(a2) * s * 0.14);
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    c.drawPath(path, fill);
  }

  void _offer(Canvas c, Offset o, double s, Paint p, Paint fill) {
    final path = Path()
      ..moveTo(o.dx - s * 0.08, o.dy - s * 0.32)
      ..lineTo(o.dx + s * 0.28, o.dy - s * 0.08)
      ..lineTo(o.dx + s * 0.08, o.dy + s * 0.32)
      ..lineTo(o.dx - s * 0.28, o.dy + s * 0.08)
      ..close();
    c.drawPath(path, p);
    c.drawCircle(Offset(o.dx - s * 0.06, o.dy - s * 0.08), s * 0.05, fill);
  }

  void _add(Canvas c, Offset o, double s, Paint p) {
    c.drawCircle(o, s * 0.32, p);
    c.drawLine(Offset(o.dx - s * 0.16, o.dy), Offset(o.dx + s * 0.16, o.dy), p);
    c.drawLine(Offset(o.dx, o.dy - s * 0.16), Offset(o.dx, o.dy + s * 0.16), p);
  }

  void _sparkle(Canvas c, Offset o, double s, Paint p) {
    c.drawLine(Offset(o.dx, o.dy - s * 0.32), Offset(o.dx, o.dy + s * 0.32), p);
    c.drawLine(Offset(o.dx - s * 0.32, o.dy), Offset(o.dx + s * 0.32, o.dy), p);
    c.drawLine(Offset(o.dx - s * 0.2, o.dy - s * 0.2), Offset(o.dx + s * 0.2, o.dy + s * 0.2), p);
    c.drawLine(Offset(o.dx + s * 0.2, o.dy - s * 0.2), Offset(o.dx - s * 0.2, o.dy + s * 0.2), p);
  }

  void _more(Canvas c, Offset o, double s, Paint fill) {
    c.drawCircle(Offset(o.dx - s * 0.22, o.dy), s * 0.07, fill);
    c.drawCircle(o, s * 0.07, fill);
    c.drawCircle(Offset(o.dx + s * 0.22, o.dy), s * 0.07, fill);
  }

  void _roof(Canvas c, Offset o, double s, Paint p) {
    final path = Path()
      ..moveTo(o.dx - s * 0.34, o.dy + s * 0.05)
      ..lineTo(o.dx, o.dy - s * 0.28)
      ..lineTo(o.dx + s * 0.34, o.dy + s * 0.05)
      ..close();
    c.drawPath(path, p);
    c.drawLine(Offset(o.dx - s * 0.22, o.dy + s * 0.05), Offset(o.dx - s * 0.22, o.dy + s * 0.28), p);
    c.drawLine(Offset(o.dx + s * 0.22, o.dy + s * 0.05), Offset(o.dx + s * 0.22, o.dy + s * 0.28), p);
  }

  void _texture(Canvas c, Offset o, double s, Paint p) {
    for (var i = -2; i <= 2; i++) {
      c.drawLine(
        Offset(o.dx - s * 0.28, o.dy + i * s * 0.1),
        Offset(o.dx + s * 0.28, o.dy + i * s * 0.1),
        p,
      );
    }
  }

  void _grid(Canvas c, Offset o, double s, Paint p) {
    final gap = s * 0.08;
    final cell = s * 0.22;
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 2; x++) {
        final cx = o.dx - cell - gap / 2 + x * (cell + gap) + cell / 2;
        final cy = o.dy - cell - gap / 2 + y * (cell + gap) + cell / 2;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: cell, height: cell),
            Radius.circular(s * 0.04),
          ),
          p,
        );
      }
    }
  }

  void _home(Canvas c, Offset o, double s, Paint p, Paint fill) {
    final path = Path()
      ..moveTo(o.dx - s * 0.3, o.dy)
      ..lineTo(o.dx, o.dy - s * 0.3)
      ..lineTo(o.dx + s * 0.3, o.dy)
      ..lineTo(o.dx + s * 0.3, o.dy + s * 0.28)
      ..lineTo(o.dx - s * 0.3, o.dy + s * 0.28)
      ..close();
    c.drawPath(path, p);
    c.drawRect(Rect.fromCenter(center: o.translate(0, s * 0.14), width: s * 0.14, height: s * 0.2), p);
  }

  void _category(Canvas c, Offset o, double s, Paint p) {
    c.drawCircle(Offset(o.dx - s * 0.14, o.dy - s * 0.14), s * 0.12, p);
    c.drawCircle(Offset(o.dx + s * 0.14, o.dy - s * 0.14), s * 0.12, p);
    c.drawCircle(Offset(o.dx - s * 0.14, o.dy + s * 0.14), s * 0.12, p);
    c.drawCircle(Offset(o.dx + s * 0.14, o.dy + s * 0.14), s * 0.12, p);
  }

  void _brush(Canvas c, Offset o, double s, Paint p, Paint fill) {
    c.drawLine(Offset(o.dx - s * 0.1, o.dy + s * 0.28), Offset(o.dx + s * 0.22, o.dy - s * 0.2), p);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o.translate(s * 0.18, -s * 0.22), width: s * 0.22, height: s * 0.16),
        Radius.circular(s * 0.04),
      ),
      fill,
    );
  }

  void _garage(Canvas c, Offset o, double s, Paint p) {
    c.drawRect(Rect.fromCenter(center: o.translate(0, s * 0.04), width: s * 0.62, height: s * 0.48), p);
    c.drawLine(Offset(o.dx - s * 0.31, o.dy - s * 0.2), Offset(o.dx + s * 0.31, o.dy - s * 0.2), p);
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(o.dx - s * 0.2, o.dy + i * s * 0.1),
        Offset(o.dx + s * 0.2, o.dy + i * s * 0.1),
        p,
      );
    }
  }

  void _moto(Canvas c, Offset o, double s, Paint p, Paint fill) {
    c.drawCircle(Offset(o.dx - s * 0.22, o.dy + s * 0.16), s * 0.12, p);
    c.drawCircle(Offset(o.dx + s * 0.24, o.dy + s * 0.16), s * 0.12, p);
    final body = Path()
      ..moveTo(o.dx - s * 0.18, o.dy + s * 0.04)
      ..lineTo(o.dx + s * 0.02, o.dy - s * 0.04)
      ..lineTo(o.dx + s * 0.18, o.dy - s * 0.02)
      ..lineTo(o.dx + s * 0.22, o.dy + s * 0.06);
    c.drawPath(body, p);
    c.drawLine(
      Offset(o.dx + s * 0.08, o.dy - s * 0.04),
      Offset(o.dx + s * 0.18, o.dy - s * 0.22),
      p,
    );
    c.drawLine(
      Offset(o.dx + s * 0.06, o.dy - s * 0.2),
      Offset(o.dx + s * 0.26, o.dy - s * 0.16),
      p,
    );
    c.drawCircle(o.translate(-s * 0.04, -s * 0.02), s * 0.05, fill);
  }

  @override
  bool shouldRepaint(covariant _VitrineChoiceGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// Dois cards grandes: Residencial × Automotiva (“O que você procura?”).
/// Ordem, textos e ícones vêm do CMS (`VitrineConfig.macro*`).
class VitrineMacroChoice extends StatelessWidget {
  const VitrineMacroChoice({
    super.key,
    required this.onResidencial,
    required this.onAutomotiva,
    this.residencialImageUrl,
    this.automotivaImageUrl,
    this.autoPrimeiro = true,
    this.residencialTitulo = 'Higienização residencial',
    this.residencialSubtitulo = 'Sofá, colchão, poltrona, tapete e mais',
    this.residencialIcone = 'cleaning',
    this.automotivaTitulo = 'Estética automotiva',
    this.automotivaSubtitulo = 'Bancos, teto, carpete e pacotes Cleanox',
    this.automotivaIcone = 'car',
  });

  final VoidCallback onResidencial;
  final VoidCallback onAutomotiva;
  final String? residencialImageUrl;
  final String? automotivaImageUrl;
  final bool autoPrimeiro;
  final String residencialTitulo;
  final String residencialSubtitulo;
  final String residencialIcone;
  final String automotivaTitulo;
  final String automotivaSubtitulo;
  final String automotivaIcone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final residencial = _MacroCard(
          key: const Key('vitrine-macro-residencial'),
          title: residencialTitulo,
          subtitle: residencialSubtitulo,
          glyph: vitrineMacroGlyph(residencialIcone),
          imageUrl: residencialImageUrl,
          onTap: onResidencial,
        );
        final automotiva = _MacroCard(
          key: const Key('vitrine-macro-automotiva'),
          title: automotivaTitulo,
          subtitle: automotivaSubtitulo,
          glyph: vitrineMacroGlyph(automotivaIcone),
          imageUrl: automotivaImageUrl,
          onTap: onAutomotiva,
        );
        final first = autoPrimeiro ? automotiva : residencial;
        final second = autoPrimeiro ? residencial : automotiva;
        if (stacked) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.onTap,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final VitrineChoiceGlyph glyph;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(VitrineUi.rLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VitrineUi.rLg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          decoration: VitrineUi.cardDeco().copyWith(
            borderRadius: BorderRadius.circular(VitrineUi.rLg),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ClxBrand.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => VitrineChoiceIcon(
                          glyph: glyph,
                          size: 30,
                          color: ClxBrand.cyan,
                        ),
                      )
                    : VitrineChoiceIcon(
                        glyph: glyph,
                        size: 30,
                        color: ClxBrand.cyan,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ClxBrand.navy,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 12,
                        color: ClxBrand.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ClxBrand.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid de categorias (legado / uso secundário).
class VitrineCategoryGrid extends StatelessWidget {
  const VitrineCategoryGrid({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<VitrineCatItem> items;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 8 : 4;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 94,
          ),
          itemBuilder: (context, index) {
            final it = items[index];
            return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(VitrineUi.rMd),
            child: InkWell(
              onTap: () => onTap(it.filter),
              borderRadius: BorderRadius.circular(VitrineUi.rMd),
              child: Container(
                decoration: VitrineUi.cardDeco(),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ClxBrand.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: it.imageUrl != null && it.imageUrl!.isNotEmpty
                          ? Image.network(
                              it.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                it.icon,
                                size: 20,
                                color: ClxBrand.cyan,
                              ),
                            )
                          : Icon(it.icon, size: 20, color: ClxBrand.cyan),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      it.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: VitrineUi.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }
}

/// Linha de serviço multi-select (mockup C2).
class VitrineServiceRow extends StatelessWidget {
  const VitrineServiceRow({
    super.key,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.selected,
    required this.onTap,
  });

  final String nome;
  final String descricao;
  final String preco;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VitrineUi.rMd),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: VitrineUi.cardDeco(selected: selected),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? ClxBrand.cyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: selected ? ClxBrand.cyan : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontFamily: kFontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: ClxBrand.navy,
                        ),
                      ),
                      if (descricao.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 12,
                            color: ClxBrand.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  preco,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ClxBrand.cyan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de formulário estilo mockup.
class VitrineField extends StatelessWidget {
  const VitrineField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboard,
    this.formatters,
    this.maxLines = 1,
    this.hint,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final int maxLines;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VitrineUi.ink2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            inputFormatters: formatters,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 14,
              color: ClxBrand.navy,
            ),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rMd),
                borderSide: const BorderSide(color: VitrineUi.line, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rMd),
                borderSide: const BorderSide(color: VitrineUi.line, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rMd),
                borderSide: const BorderSide(color: ClxBrand.cyan, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
