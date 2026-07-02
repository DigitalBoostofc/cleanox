/// agenda_screen.dart — Agenda do Painel: grade densa de slots por profissional/dia.
///
/// Espelha o conceito de `Agenda.tsx` (grade por profissional/horário), derivando os
/// slots da DISPONIBILIDADE semanal e cruzando com as ORDENS do dia (ver
/// `agenda_controller.dart`). É a tela mais pesada do Painel Web — por isso a grade é
/// VIRTUALIZADA e com header/coluna de horário FIXOS:
///   • eixo vertical (horários) por `ListView.builder` com `itemExtent` (não renderiza
///     a grade inteira);
///   • header (nomes) e coluna de horário são pinados e SINCRONIZADOS por bridges de
///     `ScrollController` (sem pacote externo);
///   • responsivo: grade 2D no desktop, lista por profissional em telas menores.
///
/// MD3: superfícies tonais + `outline-variant` (clx.line) nas divisórias, raios/tokens
/// do design system, toque ≥ 48dp, mantendo a marca petrol+cyan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import 'agenda_controller.dart';

const double _kGridBreakpoint = 760;
const double _kRowH = 52;
const double _kColW = 168;
const double _kTimeW = 68;
const double _kHeaderH = 56;

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agendaControllerProvider);
    return Column(
      children: [
        _Toolbar(state: state),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(AgendaState state) {
    if (state.loading) return const Center(child: Spinner(size: 26));
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () => ref.read(agendaControllerProvider.notifier).load(),
            ),
          ),
        ),
      );
    }
    final grid = state.grid;
    if (grid.profissionais.isEmpty) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Nenhum profissional',
        message: 'Cadastre profissionais em Usuários para montar a agenda.',
      );
    }
    if (grid.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Sem disponibilidade ou OS neste dia',
        message:
            'Configure a disponibilidade dos profissionais (em Usuários) '
            'ou agende OS para ver a grade preenchida.',
        action: ClxButton(
          label: 'Hoje',
          variant: ClxButtonVariant.ghost,
          icon: Icons.today_rounded,
          onPressed: () =>
              ref.read(agendaControllerProvider.notifier).goToday(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final canGrid =
            c.maxWidth >= _kGridBreakpoint && grid.profissionais.length > 1;
        return canGrid
            ? _AgendaGridView(grid: grid, onTapOS: _openOS)
            : _AgendaListView(grid: grid, onTapOS: _openOS);
      },
    );
  }

  void _openOS(OrdemServico os) {
    showDialog<void>(
      context: context,
      builder: (_) => _OSDetailDialog(os: os),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.state});
  final AgendaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final notifier = ref.read(agendaControllerProvider.notifier);
    final grid = state.grid;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x4,
        ClxSpace.x6,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Wrap(
        spacing: ClxSpace.x3,
        runSpacing: ClxSpace.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Navegação de dia.
          Container(
            decoration: BoxDecoration(
              color: clx.bg2,
              borderRadius: ClxRadii.rMd,
              border: Border.all(color: clx.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Dia anterior',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => notifier.shiftDays(-1),
                ),
                InkWell(
                  onTap: () => _pickDate(context, ref),
                  borderRadius: ClxRadii.rSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClxSpace.x2,
                      vertical: ClxSpace.x2,
                    ),
                    child: Text(
                      _labelDate(state.date),
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo dia',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => notifier.shiftDays(1),
                ),
              ],
            ),
          ),
          ClxButton(
            label: 'Hoje',
            variant: ClxButtonVariant.ghost,
            icon: Icons.today_rounded,
            onPressed: notifier.goToday,
          ),
          // Filtro de profissional.
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              initialValue: state.filterProfId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: clx.bg2,
                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                border: const OutlineInputBorder(
                  borderRadius: ClxRadii.rMd,
                  borderSide: BorderSide.none,
                ),
              ),
              hint: const Text('Todos os profissionais'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos os profissionais'),
                ),
                for (final p in state.profissionais)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: notifier.setFilterProf,
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: notifier.load,
          ),
          if (!grid.isEmpty)
            _SummaryChip(
              livres: _countLivres(grid),
              ocupados: grid.totalOcupados,
            ),
        ],
      ),
    );
  }

  int _countLivres(AgendaGrid grid) {
    var n = 0;
    for (final byTime in grid.cells.values) {
      for (final c in byTime.values) {
        if (c.kind == AgendaCellKind.livre) n++;
      }
    }
    return n;
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final current = DateTime.tryParse(state.date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 1),
      lastDate: DateTime(current.year + 2),
    );
    if (picked != null) {
      ref
          .read(agendaControllerProvider.notifier)
          .setDate(
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}',
          );
    }
  }

  static const List<String> _dow = [
    'Domingo',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
  ];

  String _labelDate(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final dow = _dow[d.weekday % 7];
    return '$dow, ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.livres, required this.ocupados});
  final int livres;
  final int ocupados;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClxChip(
          label: '$ocupados agendado${ocupados == 1 ? '' : 's'}',
          color: clx.accent,
          icon: Icons.event_available_rounded,
          dense: true,
        ),
        const SizedBox(width: ClxSpace.x2),
        ClxChip(
          label: '$livres livre${livres == 1 ? '' : 's'}',
          color: clx.success,
          icon: Icons.schedule_rounded,
          dense: true,
        ),
      ],
    );
  }
}

/* ─────────────────────────── GRADE 2D (desktop) ─────────────────────────── */

/// Grade densa virtualizada: header (nomes) + coluna de horário FIXOS; corpo com
/// `ListView.builder` (`itemExtent`) e scroll 2D sincronizado por bridges.
class _AgendaGridView extends StatefulWidget {
  const _AgendaGridView({required this.grid, required this.onTapOS});
  final AgendaGrid grid;
  final ValueChanged<OrdemServico> onTapOS;

  @override
  State<_AgendaGridView> createState() => _AgendaGridViewState();
}

class _AgendaGridViewState extends State<_AgendaGridView> {
  final ScrollController _bodyV = ScrollController();
  final ScrollController _timeV = ScrollController();
  final ScrollController _bodyH = ScrollController();
  final ScrollController _headerH = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyV.addListener(() => _sync(_bodyV, _timeV));
    _bodyH.addListener(() => _sync(_bodyH, _headerH));
  }

  /// Espelha o offset de [src] em [dst] (guarda reentrância e clients).
  void _sync(ScrollController src, ScrollController dst) {
    if (!dst.hasClients || !src.hasClients) return;
    if ((dst.offset - src.offset).abs() < 0.5) return;
    dst.jumpTo(
      src.offset.clamp(
        dst.position.minScrollExtent,
        dst.position.maxScrollExtent,
      ),
    );
  }

  @override
  void dispose() {
    _bodyV.dispose();
    _timeV.dispose();
    _bodyH.dispose();
    _headerH.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final grid = widget.grid;
    final profs = grid.profissionais;
    final times = grid.times;
    final bodyWidth = profs.length * _kColW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header fixo: canto + nomes dos profissionais (scroll H sincronizado).
        SizedBox(
          height: _kHeaderH,
          child: Row(
            children: [
              _CornerCell(clx: clx),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerH,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: bodyWidth,
                    child: Row(
                      children: [
                        for (final p in profs) _ProfHeaderCell(prof: p),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        // ── Corpo: coluna de horário fixa + grade 2D virtualizada.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coluna de horários pinada (scroll V sincronizado, sem gesto próprio).
              SizedBox(
                width: _kTimeW,
                child: ListView.builder(
                  controller: _timeV,
                  physics: const NeverScrollableScrollPhysics(),
                  itemExtent: _kRowH,
                  itemCount: times.length,
                  itemBuilder: (context, i) =>
                      _TimeCell(time: times[i], clx: clx),
                ),
              ),
              VerticalDivider(width: 1, color: clx.line),
              // Grade: H drive + V drive (virtualizado por linha).
              Expanded(
                child: SingleChildScrollView(
                  controller: _bodyH,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: bodyWidth,
                    child: ListView.builder(
                      controller: _bodyV,
                      itemExtent: _kRowH,
                      itemCount: times.length,
                      itemBuilder: (context, i) {
                        final time = times[i];
                        return Row(
                          children: [
                            for (final p in profs)
                              _GridCell(
                                cell: grid.cell(p.id, time),
                                onTap: widget.onTapOS,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CornerCell extends StatelessWidget {
  const _CornerCell({required this.clx});
  final CleanoxColors clx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTimeW,
      height: _kHeaderH,
      alignment: Alignment.center,
      color: clx.bg3,
      child: Text(
        'Hora',
        style: TextStyle(
          color: clx.ink3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ProfHeaderCell extends StatelessWidget {
  const _ProfHeaderCell({required this.prof});
  final User prof;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: _kColW,
      height: _kHeaderH,
      padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x2),
      decoration: BoxDecoration(
        color: clx.bg3,
        border: Border(left: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: clx.accent,
            child: Text(
              prof.displayName.isNotEmpty
                  ? prof.displayName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: Text(
              prof.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: clx.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.time, required this.clx});
  final String time;
  final CleanoxColors clx;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kRowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: clx.bg2,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: clx.ink2,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.cell, required this.onTap});
  final AgendaCell cell;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final base = Container(
      width: _kColW,
      height: _kRowH,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: clx.line),
          bottom: BorderSide(color: clx.line),
        ),
      ),
      child: _content(clx),
    );
    if (cell.kind == AgendaCellKind.ocupado && cell.os != null) {
      return InkWell(onTap: () => onTap(cell.os!), child: base);
    }
    return base;
  }

  Widget _content(CleanoxColors clx) {
    switch (cell.kind) {
      case AgendaCellKind.vazio:
        return const SizedBox.shrink();
      case AgendaCellKind.livre:
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ClxSpace.x2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: clx.successBg,
              borderRadius: ClxRadii.rSm,
            ),
            child: Text(
              'Livre',
              style: TextStyle(
                color: clx.success,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case AgendaCellKind.ocupado:
        final os = cell.os!;
        return Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x2,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: clx.statusBg(os.status),
            borderRadius: ClxRadii.rSm,
            border: Border(
              left: BorderSide(color: clx.statusColor(os.status), width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                os.nomeCurto.isEmpty ? '—' : os.nomeCurto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                os.tipoServicoNome ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink3, fontSize: 10.5),
              ),
            ],
          ),
        );
    }
  }
}

/* ─────────────────────────── LISTA (mobile) ─────────────────────────── */

/// Lista por profissional (telas menores): cada profissional vira um bloco com os
/// horários do dia (livre/ocupado). Virtualizada por `ListView.builder`.
class _AgendaListView extends StatelessWidget {
  const _AgendaListView({required this.grid, required this.onTapOS});
  final AgendaGrid grid;
  final ValueChanged<OrdemServico> onTapOS;

  @override
  Widget build(BuildContext context) {
    final profs = grid.profissionais;
    return ListView.builder(
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: profs.length,
      itemBuilder: (context, i) {
        final prof = profs[i];
        final byTime = grid.cells[prof.id] ?? const {};
        final entries = grid.times
            .where((t) => byTime.containsKey(t))
            .map((t) => MapEntry(t, byTime[t]!))
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: _ProfDayCard(prof: prof, entries: entries, onTapOS: onTapOS),
        );
      },
    );
  }
}

class _ProfDayCard extends StatelessWidget {
  const _ProfDayCard({
    required this.prof,
    required this.entries,
    required this.onTapOS,
  });

  final User prof;
  final List<MapEntry<String, AgendaCell>> entries;
  final ValueChanged<OrdemServico> onTapOS;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: clx.accent,
                child: Text(
                  prof.displayName.isNotEmpty
                      ? prof.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  prof.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          if (entries.isEmpty)
            Text(
              'Sem disponibilidade ou OS neste dia.',
              style: TextStyle(color: clx.ink3, fontSize: 13),
            )
          else
            for (final e in entries) ...[
              _SlotTile(time: e.key, cell: e.value, onTapOS: onTapOS),
              const SizedBox(height: ClxSpace.x2),
            ],
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.time,
    required this.cell,
    required this.onTapOS,
  });

  final String time;
  final AgendaCell cell;
  final ValueChanged<OrdemServico> onTapOS;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ocupado = cell.kind == AgendaCellKind.ocupado && cell.os != null;
    final os = cell.os;
    final tile = Container(
      constraints: const BoxConstraints(minHeight: ClxLayout.minTouchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x3,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        color: ocupado ? clx.statusBg(os!.status) : clx.successBg,
        borderRadius: ClxRadii.rMd,
        border: Border(
          left: BorderSide(
            color: ocupado ? clx.statusColor(os!.status) : clx.success,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              time,
              style: TextStyle(
                color: clx.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: ocupado
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        os!.nomeCurto.isEmpty ? '—' : os.nomeCurto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: clx.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        os.tipoServicoNome ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: clx.ink3, fontSize: 11.5),
                      ),
                    ],
                  )
                : Text(
                    'Horário livre',
                    style: TextStyle(
                      color: clx.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          if (ocupado) StatusBadge(status: os!.status, dense: true),
        ],
      ),
    );
    if (ocupado) {
      return InkWell(
        borderRadius: ClxRadii.rMd,
        onTap: () => onTapOS(os!),
        child: tile,
      );
    }
    return tile;
  }
}

/* ─────────────────────────── Detalhe da OS ─────────────────────────── */

class _OSDetailDialog extends StatelessWidget {
  const _OSDetailDialog({required this.os});
  final OrdemServico os;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final prof = os.expand?.profissional;
    return AlertDialog(
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: Row(
        children: [
          Expanded(
            child: Text(
              os.nomeCurto.isEmpty ? 'Ordem de serviço' : os.nomeCurto,
              style: TextStyle(
                color: clx.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          StatusBadge(status: os.status, dense: true),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(clx, 'Serviço', os.tipoServicoNome ?? '—'),
          _row(clx, 'Bairro', os.bairro),
          _row(clx, 'Data / Hora', formatDateTime(os.dataHora)),
          _row(clx, 'Profissional', prof?.displayName ?? '—'),
          _row(clx, 'Valor', formatCurrency(os.valorServico ?? 0)),
        ],
      ),
      actions: [
        ClxButton(
          label: 'Fechar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _row(CleanoxColors clx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(color: clx.ink3, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: clx.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
