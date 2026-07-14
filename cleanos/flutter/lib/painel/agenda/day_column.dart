/// day_column.dart — A COLUNA DE UM DIA da agenda (grade time-grid, desktop).
///
/// Um único widget usado 1× na visão **dia** e 7× na visão **semana** — a régua
/// de horas ([AgendaHourGutter]) fica ao lado, fora da coluna. Os blocos são
/// posicionados por MINUTO (`top = (início − dayStart) × escala`,
/// `height = duração × escala`), com colunas lado a lado para OS sobrepostas —
/// tudo vindo do núcleo puro `core/agenda/agenda_layout.dart`.
///
/// A escala px/min mora num token único ([kAgendaAlturaHoraPx]); zoom é futuro.
///
/// [editable] é a costura para a Fase 2 (arrastar/redimensionar): a camada de
/// gestos entra por cima do bloco, sem mexer no cálculo do layout. Na Fase 1 ela
/// não existe e `editable` é sempre `false`.
///
/// Mobile/APK/web estreita NÃO usam esta grade — lá é lista de cards (R4).
library;

import 'package:flutter/material.dart';

import '../../core/agenda/agenda_layout.dart';
import '../../core/design/design.dart';
import '../../core/models/collections.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/ordem_servico.dart';

/// Altura de UMA hora na grade. Token ÚNICO de escala (px/min = /60).
const double kAgendaAlturaHoraPx = 56;

/// Escala px por minuto — derivada do token acima.
const double kAgendaPxPorMin = kAgendaAlturaHoraPx / 60;

/// Altura VISUAL mínima de um bloco (só render — não mexe no dado).
const double kAgendaAlturaMinBlocoPx = 24;

/// Largura da régua de horas (à esquerda da grade).
const double kAgendaReguaW = 56;

/// Só `agendada` e `atribuida` serão arrastáveis (D6) — as demais renderizam sem
/// alça mesmo quando a grade estiver editável (Fase 2).
bool osArrastavel(OrdemServico os) =>
    os.status == OSStatus.agendada || os.status == OSStatus.atribuida;

/// Régua de horas (rótulos "13h") alinhada à mesma janela das colunas.
class AgendaHourGutter extends StatelessWidget {
  const AgendaHourGutter({
    super.key,
    required this.dayStart,
    required this.dayEnd,
  });

  final int dayStart;
  final int dayEnd;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final horaInicial = dayStart ~/ 60;
    final horaFinal = (dayEnd + 59) ~/ 60;
    return Container(
      width: kAgendaReguaW,
      height: (dayEnd - dayStart) * kAgendaPxPorMin,
      decoration: BoxDecoration(
        color: clx.bg2,
        border: Border(right: BorderSide(color: clx.line)),
      ),
      child: Stack(
        children: [
          for (var h = horaInicial; h < horaFinal; h++)
            Positioned(
              top: (h * 60 - dayStart) * kAgendaPxPorMin,
              right: ClxSpace.x2,
              child: Text(
                '${h}h',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: clx.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

class DayColumn extends StatelessWidget {
  const DayColumn({
    super.key,
    required this.day,
    required this.events,
    required this.onTap,
    required this.dayStart,
    required this.dayEnd,
    this.dispByProf = const {},
    this.editable = false,
    this.maxColunas = kMaxColunasDesktop,
    this.showLeftBorder = true,
  });

  /// Dia (date-only, BRT) desta coluna.
  final DateTime day;

  /// OS que COMEÇAM neste dia (o recorte da fração pós-meia-noite é do layout).
  final List<OrdemServico> events;

  final ValueChanged<OrdemServico> onTap;

  /// Janela desenhada, COMPARTILHADA entre as colunas (senão as linhas de hora
  /// da semana não alinham). Ver [janelaCompartilhada].
  final int dayStart;
  final int dayEnd;

  /// Disponibilidade por profissional — alimenta o fallback de duração (D9).
  final Map<String, Disponibilidade> dispByProf;

  /// Fase 2: liga a camada de gestos (arrastar/redimensionar). Hoje sempre false.
  final bool editable;

  final int maxColunas;
  final bool showLeftBorder;

  Disponibilidade? _dispDe(OrdemServico os) =>
      dispByProf[os.profissional ?? ''];

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final porId = {for (final os in events) os.id: os};
    final layout = layoutDayEvents(
      [for (final os in events) intervaloDaOs(os, _dispDe(os))],
      dayStart: dayStart,
      dayEnd: dayEnd,
      maxColunas: maxColunas,
    );
    final alturaTotal = (dayEnd - dayStart) * kAgendaPxPorMin;
    final horaInicial = (dayStart + 59) ~/ 60;
    final horaFinal = (dayEnd + 59) ~/ 60;

    return LayoutBuilder(
      builder: (context, c) {
        final largura = c.maxWidth;
        return SizedBox(
          height: alturaTotal,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Fundo: linhas de hora.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: showLeftBorder
                        ? Border(left: BorderSide(color: clx.line))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      for (var h = horaInicial; h < horaFinal; h++)
                        Positioned(
                          top: (h * 60 - dayStart) * kAgendaPxPorMin,
                          left: 0,
                          right: 0,
                          child: Container(height: 1, color: clx.line),
                        ),
                    ],
                  ),
                ),
              ),

              // Blocos posicionados por minuto.
              for (final p in layout.eventos)
                if (porId[p.id] != null)
                  _blocoPosicionado(p, porId[p.id]!, largura),

              // Excedente do aglomerado ("+N") — R4: abre a LISTA, não espreme
              // mais colunas ilegíveis.
              for (final ex in layout.excedentes)
                Positioned(
                  top: (ex.startMin - dayStart) * kAgendaPxPorMin + 2,
                  right: 2,
                  child: _ChipExcedente(
                    excedente: ex,
                    porId: porId,
                    onTap: onTap,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _blocoPosicionado(
    EventoPosicionado p,
    OrdemServico os,
    double larguraTotal,
  ) {
    final larguraCol = larguraTotal / p.columnCount;
    final altura = (p.duracaoMin * kAgendaPxPorMin).clamp(
      kAgendaAlturaMinBlocoPx,
      double.infinity,
    );
    return Positioned(
      top: (p.startMin - dayStart) * kAgendaPxPorMin,
      left: p.column * larguraCol,
      width: larguraCol,
      height: altura,
      child: _BlocoOS(
        os: os,
        posicao: p,
        duracaoMin: duracaoEfetivaMin(os, _dispDe(os)),
        onTap: onTap,
        editable: editable && osArrastavel(os),
      ),
    );
  }
}

/// O bloco de uma OS na grade: cor do status, faixa "08:00–10:00" e nome curto.
class _BlocoOS extends StatelessWidget {
  const _BlocoOS({
    required this.os,
    required this.posicao,
    required this.duracaoMin,
    required this.onTap,
    required this.editable,
  });

  final OrdemServico os;
  final EventoPosicionado posicao;
  final int duracaoMin;
  final ValueChanged<OrdemServico> onTap;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final faixa =
        '${hhmmDeMinutos(posicao.startMin)}–${hhmmDeMinutos(posicao.endMin)}';
    final curto = posicao.duracaoMin < 45;

    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 1),
      child: Material(
        color: clx.statusBg(os.status),
        borderRadius: ClxRadii.rSm,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(os),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: clx.statusColor(os.status), width: 3),
                top: posicao.truncTop
                    ? BorderSide(color: clx.statusColor(os.status))
                    : BorderSide.none,
                bottom: posicao.truncBottom
                    ? BorderSide(color: clx.statusColor(os.status))
                    : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  curto
                      ? '$faixa ${os.nomeCurto.isEmpty ? '—' : os.nomeCurto}'
                      : faixa,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!curto)
                  Flexible(
                    child: Text(
                      os.nomeCurto.isEmpty ? '—' : os.nomeCurto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(color: clx.ink2),
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

/// Chip "+N" do excedente de um aglomerado: abre a lista das OS que não couberam.
class _ChipExcedente extends StatelessWidget {
  const _ChipExcedente({
    required this.excedente,
    required this.porId,
    required this.onTap,
  });

  final ExcedenteAglomerado excedente;
  final Map<String, OrdemServico> porId;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return PopupMenuButton<OrdemServico>(
      tooltip: 'Mais ${excedente.count} nesta faixa',
      padding: EdgeInsets.zero,
      onSelected: onTap,
      itemBuilder: (_) => [
        for (final iv in excedente.eventos)
          if (porId[iv.id] != null)
            PopupMenuItem<OrdemServico>(
              value: porId[iv.id],
              child: Text(
                '${hhmmDeMinutos(iv.startMin)} '
                '${iv.label.isEmpty ? '—' : iv.label}',
              ),
            ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: clx.bg3,
          borderRadius: ClxRadii.rSm,
          border: Border.all(color: clx.line2),
        ),
        child: Text(
          '+${excedente.count}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: clx.ink2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
