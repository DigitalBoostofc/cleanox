/// Componentes de UI da vitrine — alinhados aos mockups mobile Cleanox.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
// logo via Image.asset (assets/brand/logo_cleanox_color.png)

/// Canvas e superfícies do mockup.
abstract final class VitrineUi {
  static const bg = ClxBrand.canvas;
  static const card = Colors.white;
  static const line = Color(0xFFE2E8F0);
  static const ink2 = Color(0xFF3D4F63);
  static const rMd = 14.0;
  static const rLg = 20.0;
  static const rPill = 999.0;

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: VitrineUi.logoH,
      width: VitrineUi.logoW,
      child: Image.asset(
        VitrineUi.logoAsset,
        height: VitrineUi.logoH,
        width: VitrineUi.logoW,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Align(
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
        ),
      ),
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
    this.maxWidth = 760,
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

/// Saudação estável em web/Android, sem depender de fonte de emoji do sistema.
class VitrineGreeting extends StatelessWidget {
  const VitrineGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Olá',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(width: 7),
        Icon(Icons.waving_hand_rounded, size: 25, color: Color(0xFFF59E0B)),
      ],
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

/// Bottom nav: Início · **Agendar (FAB redondo suspenso)** · Como funciona.
/// Barra baixa + círculo sobreposto (como o FAB do casco Easypay do painel).
class VitrineBottomNav extends StatelessWidget {
  const VitrineBottomNav({
    super.key,
    required this.index,
    required this.onTap,
  });

  /// 0 início · 1 agendar · 2 como funciona
  final int index;
  final ValueChanged<int> onTap;

  static const double _fabSize = 58;
  /// Quanto o FAB sobe por cima da barra (flutuação forte).
  static const double _fabLift = 36;
  /// Altura da faixa branca (sem safe-area).
  static const double _barH = 54;
  static const double _centerSlot = 84;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Espaço extra no topo do widget para o FAB não cortar (Stack overflow).
    return Padding(
      padding: const EdgeInsets.only(top: _fabLift),
      child: Material(
        elevation: 12,
        shadowColor: const Color(0x1A0B1D34),
        color: Colors.transparent,
        child: Container(
          height: _barH + bottom,
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
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Itens laterais na barra baixa; vão centralizados verticalmente.
                Row(
                  children: [
                    _sideItem(0, Icons.home_rounded, 'Início'),
                    const SizedBox(width: _centerSlot),
                    _sideItem(2, Icons.info_outline_rounded, 'Como funciona'),
                  ],
                ),
                // FAB suspenso: metade acima da barra, sobreposto.
                Positioned(
                  top: -_fabLift,
                  child: _agendarFab(),
                ),
              ],
            ),
          ),
        ),
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

  /// Círculo elevado + label pequena "Agendar" (fica na zona da barra).
  Widget _agendarFab() {
    final on = index == 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(1),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _centerSlot,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    // Sombra profunda = “descolado” da barra.
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
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Agendar',
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

/// CTA sticky do mockup (total + botão pill).
class VitrineStickyBar extends StatelessWidget {
  const VitrineStickyBar({
    super.key,
    this.totalLabel,
    this.totalValue,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
  });

  final String? totalLabel;
  final String? totalValue;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
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
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          if (totalLabel != null && totalValue != null) ...[
            Row(
              children: [
                Text(
                  totalLabel!,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 13,
                    color: ClxBrand.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  totalValue!,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ClxBrand.navy,
                  ),
                ),
              ],
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
                disabledBackgroundColor: ClxBrand.cyan.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VitrineUi.rPill),
                ),
                textStyle: const TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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
                  : Text(buttonLabel),
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
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onCta;
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
                FilledButton(
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

/// Grid de categorias (mockup 4 colunas).
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
