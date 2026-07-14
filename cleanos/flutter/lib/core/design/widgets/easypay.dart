/// easypay.dart — Componentes visuais do redesign Easypay (APK / web estreita).
library;

import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../motion.dart';
import '../tokens.dart';

/// Faixa de dias com **scroll contínuo horizontal**.
///
/// Arraste esquerda/direita: os números entram de lado, um a um.
/// A viewport mostra 7 dias. O primeiro dia visível é o início da
/// “semana” rolante (ex.: qua → ter — 7 dias; pode começar em qualquer
/// dia da semana).
///
/// [onWindowStart] dispara quando o primeiro dia da janela muda e
/// atualiza o rótulo “de X a Y” em cima.
///
/// Toque em um dia **só seleciona** — não realinha a janela.
class EasypayWeekStrip extends StatefulWidget {
  const EasypayWeekStrip({
    super.key,
    required this.selected,
    required this.today,
    required this.windowStart,
    required this.onSelect,
    required this.onWindowStart,
    this.dowLabels = const ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'],
  });

  final DateTime selected;
  final DateTime today;

  /// Primeiro dia da janela de 7 dias (setas / Hoje do pai).
  final DateTime windowStart;

  final ValueChanged<DateTime> onSelect;

  /// Primeiro dia visível mudou (arraste).
  final ValueChanged<DateTime> onWindowStart;

  /// 0=Dom … 6=Sáb (`DateTime.weekday % 7`).
  final List<String> dowLabels;

  @override
  State<EasypayWeekStrip> createState() => _EasypayWeekStripState();
}

class _EasypayWeekStripState extends State<EasypayWeekStrip> {
  static final DateTime _base = DateTime(2020, 1, 1);
  static const int _maxDays = 20000;

  final ScrollController _ctrl = ScrollController();
  double _itemW = 0;
  bool _initialized = false;
  bool _snapping = false;
  int _lastNotifiedIndex = -999999;

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _indexOf(DateTime d) =>
      _dateOnly(d).difference(_base).inDays.clamp(0, _maxDays);

  static DateTime _dateAt(int i) => _base.add(Duration(days: i));

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_initialized || !_ctrl.hasClients || _itemW <= 0 || _snapping) return;
    _notifyFirstVisible();
  }

  int _firstVisibleIndex() {
    // floor: o dia que está saindo/entrando pela esquerda atualiza o período.
    return (_ctrl.offset / _itemW).floor().clamp(0, _maxDays);
  }

  void _notifyFirstVisible({bool force = false}) {
    final i = _firstVisibleIndex();
    if (!force && i == _lastNotifiedIndex) return;
    _lastNotifiedIndex = i;
    widget.onWindowStart(_dateAt(i));
  }

  void _jumpToWindow(DateTime start) {
    if (!_ctrl.hasClients || _itemW <= 0) return;
    final i = _indexOf(start);
    final target = (i * _itemW).clamp(0.0, _ctrl.position.maxScrollExtent);
    if ((_ctrl.offset - target).abs() > 0.5) {
      _ctrl.jumpTo(target);
    }
    _lastNotifiedIndex = i;
  }

  Future<void> _snapToDay() async {
    if (!_ctrl.hasClients || _itemW <= 0 || _snapping) return;
    final i = (_ctrl.offset / _itemW).round().clamp(0, _maxDays);
    final target = (i * _itemW).clamp(0.0, _ctrl.position.maxScrollExtent);
    if ((_ctrl.offset - target).abs() < 0.5) {
      _lastNotifiedIndex = i;
      widget.onWindowStart(_dateAt(i));
      return;
    }
    _snapping = true;
    try {
      await _ctrl.animateTo(
        target,
        duration: ClxMotion.standardDuration,
        curve: ClxMotion.emphasized,
      );
      _lastNotifiedIndex = i;
      widget.onWindowStart(_dateAt(i));
    } finally {
      _snapping = false;
    }
  }

  @override
  void didUpdateWidget(covariant EasypayWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza só quando o pai muda o período (setas / Hoje) e não
    // estamos no meio de um scroll do usuário.
    if (!_same(oldWidget.windowStart, widget.windowStart) &&
        _initialized &&
        _ctrl.hasClients &&
        !_ctrl.position.isScrollingNotifier.value &&
        !_snapping) {
      final expected = _indexOf(widget.windowStart) * _itemW;
      if ((_ctrl.offset - expected).abs() > _itemW * 0.4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _jumpToWindow(widget.windowStart);
        });
      }
    }
  }

  void _ensureLaidOut(double itemW) {
    if (itemW <= 0) return;
    final widthChanged = (_itemW - itemW).abs() > 0.5;
    if (!_initialized) {
      _itemW = itemW;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ctrl.hasClients) return;
        _jumpToWindow(widget.windowStart);
        _initialized = true;
        _notifyFirstVisible(force: true);
      });
      return;
    }
    if (widthChanged && _ctrl.hasClients) {
      // Mantém o mesmo dia no início ao rotacionar/resize.
      final dayIndex = _firstVisibleIndex();
      _itemW = itemW;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ctrl.hasClients) return;
        _ctrl.jumpTo(
          (dayIndex * _itemW).clamp(0.0, _ctrl.position.maxScrollExtent),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return LayoutBuilder(
      builder: (context, c) {
        final itemW = (c.maxWidth - 8) / 7;
        _ensureLaidOut(itemW);
        // Usa o itemW do layout atual (mesmo se ainda não inicializou).
        final extent = itemW > 0 ? itemW : 48.0;
        if (_itemW <= 0) _itemW = extent;

        return Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                clx.accent,
                Color.lerp(clx.accent, clx.primary, 0.55)!,
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: clx.accent.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _snapToDay();
              return false;
            },
            child: SizedBox(
              height: 72,
              child: ListView.builder(
                controller: _ctrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                // Cada célula = 1/7 da largura → 7 dias na tela;
                // scroll contínuo (não PageView).
                itemExtent: extent,
                itemCount: _maxDays,
                itemBuilder: (context, i) {
                  final day = _dateAt(i);
                  final selected = _same(day, widget.selected);
                  final isToday = _same(day, widget.today);
                  final dow = widget.dowLabels[day.weekday % 7];
                  return _DayCell(
                    day: day,
                    dow: dow,
                    selected: selected,
                    isToday: isToday,
                    onTap: () => widget.onSelect(day),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.dow,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final String dow;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1.0,
        duration: ClxMotion.shortDuration,
        curve: ClxMotion.emphasized,
        child: AnimatedContainer(
          duration: ClxMotion.shortDuration,
          curve: ClxMotion.emphasized,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dow,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? clx.accent
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: ClxMotion.shortDuration,
                style: TextStyle(
                  fontSize: selected ? 17 : 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? clx.accent : Colors.white,
                ),
                child: Text('${day.day}'.padLeft(2, '0')),
              ),
              if (isToday && !selected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de lista estilo extrato (OS / lançamento / evento).
class EasypayListCard extends StatelessWidget {
  const EasypayListCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.stripeColor,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? stripeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: clx.bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: clx.line),
            boxShadow: [
              BoxShadow(
                color: clx.ink.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                if (stripeColor != null)
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: stripeColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: clx.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(color: clx.ink3),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
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

/// Pill de período (Dia / Semana / Mês / Ano).
class EasypayPeriodPills extends StatelessWidget {
  const EasypayPeriodPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.onDark = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClxPressScale(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: ClxMotion.shortDuration,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selectedIndex == i
                      ? (onDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : clx.primary.withValues(alpha: 0.14))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selectedIndex == i
                        ? (onDark ? Colors.white : clx.primary)
                        : (onDark
                              ? Colors.white.withValues(alpha: 0.65)
                              : clx.ink3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
