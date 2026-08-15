/// Calendário compacto da lista de OS: 1 dia ou intervalo (estilo card).
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';

class PeriodoSelecao {
  const PeriodoSelecao({this.inicio, this.fim});

  final DateTime? inicio;
  final DateTime? fim;

  bool get vazio => inicio == null;

  DateTime get start => inicio!;
  DateTime get end => fim ?? inicio!;

  static DateTime dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 1º toque = início. 2º = fim (pode ser o mesmo dia). Depois recomeça.
  PeriodoSelecao toque(DateTime raw) {
    final d = dia(raw);
    if (inicio == null || fim != null) {
      return PeriodoSelecao(inicio: d);
    }
    if (d.isBefore(inicio!)) {
      return PeriodoSelecao(inicio: d, fim: inicio);
    }
    return PeriodoSelecao(inicio: inicio, fim: d);
  }

  bool contem(DateTime raw) {
    if (inicio == null) return false;
    final d = dia(raw);
    final a = inicio!;
    final b = fim ?? inicio!;
    return !d.isBefore(a) && !d.isAfter(b);
  }
}

const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

Future<DateTimeRange?> showOrdensPeriodoCalendario(
  BuildContext context, {
  required DateTime inicio,
  required DateTime fim,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _CalendarioCard(inicio: inicio, fim: fim),
  );
}

class _CalendarioCard extends StatefulWidget {
  const _CalendarioCard({required this.inicio, required this.fim});

  final DateTime inicio;
  final DateTime fim;

  @override
  State<_CalendarioCard> createState() => _CalendarioCardState();
}

class _CalendarioCardState extends State<_CalendarioCard> {
  late PeriodoSelecao _sel;
  late DateTime _mes;

  @override
  void initState() {
    super.initState();
    final a = PeriodoSelecao.dia(widget.inicio);
    final b = PeriodoSelecao.dia(widget.fim);
    _sel = PeriodoSelecao(inicio: a, fim: b.isAtSameMomentAs(a) ? a : b);
    _mes = DateTime(a.year, a.month);
  }

  void _mesDelta(int d) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + d));
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final rotulo = _sel.vazio
        ? 'Toque um dia ou um período'
        : _sel.start == _sel.end
        ? _fmt(_sel.start)
        : '${_fmt(_sel.start)} – ${_fmt(_sel.end)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(
          color: clx.bg,
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Data selecionada',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: clx.ink3),
                ),
                const SizedBox(height: 2),
                Text(
                  rotulo,
                  key: const ValueKey('ordens-cal-rotulo'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('ordens-cal-prev'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _mesDelta(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${_meses[_mes.month - 1]} ${_mes.year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('ordens-cal-next'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _mesDelta(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final d in _diasSemana)
                      Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: clx.ink3,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _grade(clx),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: KeyedSubtree(
                        key: const ValueKey('ordens-cal-pronto'),
                        child: ClxButton(
                          label: 'Pronto',
                          onPressed: _sel.vazio
                              ? null
                              : () => Navigator.of(context).pop(
                                  DateTimeRange(
                                    start: _sel.start,
                                    end: _sel.end,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      key: const ValueKey('ordens-cal-cancelar'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: clx.ink2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grade(CleanoxColors clx) {
    final first = DateTime(_mes.year, _mes.month, 1);
    final startOffset = (first.weekday + 6) % 7; // segunda = 0
    final daysInMonth = DateTime(_mes.year, _mes.month + 1, 0).day;
    final cells = startOffset + daysInMonth;
    final rows = ((cells + 6) ~/ 7);

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _celula(clx, r * 7 + c, startOffset, daysInMonth)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _celula(CleanoxColors clx, int i, int offset, int daysInMonth) {
    final n = i - offset + 1;
    if (n < 1 || n > daysInMonth) return const SizedBox(height: 36);
    final d = DateTime(_mes.year, _mes.month, n);
    final on = _sel.contem(d);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: on ? clx.primary : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: ValueKey(
            'ordens-cal-dia-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          ),
          customBorder: const CircleBorder(),
          onTap: () => setState(() => _sel = _sel.toque(d)),
          child: SizedBox(
            height: 36,
            child: Center(
              child: Text(
                '$n',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: on ? clx.onPrimary : clx.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
