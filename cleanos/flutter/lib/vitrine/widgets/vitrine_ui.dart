/// Componentes de UI da vitrine — alinhados aos mockups mobile Cleanox.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/cleanox_logo.dart';

/// Canvas e superfícies do mockup.
abstract final class VitrineUi {
  static const bg = ClxBrand.canvas;
  static const card = Colors.white;
  static const line = Color(0xFFE2E8F0);
  static const ink2 = Color(0xFF3D4F63);
  static const rMd = 14.0;
  static const rLg = 20.0;
  static const rPill = 999.0;

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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            const CleanoxLogo(
              height: 36,
              variant: CleanoxLogoVariant.primary,
            ),
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
      ),
    );
  }
}

/// Header navy arredondado + pill de passo (telas 1–4 do mockup).
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
          const CleanoxLogo(
            height: 32,
            variant: CleanoxLogoVariant.fullDark,
          ),
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

/// Bottom nav mockup: Início · Orçar · Como funciona (sem Conta).
class VitrineBottomNav extends StatelessWidget {
  const VitrineBottomNav({
    super.key,
    required this.index,
    required this.onTap,
  });

  /// 0 início · 1 orçar · 2 como funciona
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0B1D34),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Row(
        children: [
          _item(0, Icons.home_rounded, 'Início'),
          _item(1, Icons.checklist_rounded, 'Orçar'),
          _item(2, Icons.info_outline_rounded, 'Como funciona'),
        ],
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) {
    final on = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: on
                      ? ClxBrand.cyan.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: on ? ClxBrand.cyan : ClxBrand.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
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
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 168),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
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
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: [
        for (final it in items)
          Material(
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
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: VitrineUi.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
