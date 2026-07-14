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
/// ── FASE 2: camada de gestos (desktop web) ───────────────────────────────────
/// [editable] liga o arraste POR CIMA do bloco, sem tocar no cálculo do layout:
/// - arrastar o CORPO **move** a OS (`data_hora`), inclusive para outra coluna
///   na visão semana (cross-day — D8, via [permiteCrossDay]);
/// - arrastar a BORDA INFERIOR **redimensiona** (`duracao_min`);
/// - só `agendada`/`atribuida` têm alça (D6); nunca cai num dia anterior (D7);
/// - snap de 15 min e duração mínima de 15 min — aritmética toda em
///   `core/agenda/agenda_drag.dart` (minutos-BRT inteiros, gate G-8).
///
/// ⚠️ O PREVIEW vive em ESTADO LOCAL do widget (spec R-B3): um [ValueNotifier] +
/// um fantasma no [Overlay]. Nada de `setState`/StateNotifier por frame de
/// ponteiro — `layoutDayEvents` (aglomerados/colunas) roda uma vez por build, não
/// 60×/s. O estado global só é tocado no DROP.
///
/// Mobile/APK/web estreita NÃO usam esta grade — lista de cards (R4).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/agenda/agenda_drag.dart';
import '../../core/agenda/agenda_layout.dart';
import '../../core/design/design.dart';
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

/// Altura da alça de redimensionar (borda inferior do bloco).
const double kAgendaAlcaPx = 8;

/// Pan do bloco, com dois desvios do padrão — ambos necessários:
///
/// 1. **aceita com o slop de TOQUE** (menor), não com o de PAN: sem isso o
///    `SingleChildScrollView` que embrulha a grade vence a arena (o
///    `VerticalDragGestureRecognizer` dele dispara primeiro) e arrastar o bloco
///    viraria rolar a página;
/// 2. **`DragStartBehavior.down`**: o padrão (`start`) DESCARTA o deslocamento
///    gasto até a aceitação — o bloco cairia ~18px acima do ponteiro (≈20 min de
///    erro, o suficiente pra pular um slot de 15).
class _AgendaPanRecognizer extends PanGestureRecognizer {
  _AgendaPanRecognizer({required Object super.debugOwner}) {
    dragStartBehavior = DragStartBehavior.down;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings);
}

/// O que o fantasma do arraste desenha AGORA (estado local, R-B3).
///
/// A posição do fantasma sai da PRÓPRIA proposta (não do pixel cru do mouse):
/// ele anda GRUDADO no snap de 15 min e na coluna de destino — o usuário vê
/// exatamente onde a OS vai cair, e preview e drop nunca divergem.
class _Preview {
  const _Preview({
    required this.osId,
    required this.proposta,
    required this.origem,
    required this.larguraBloco,
    required this.larguraColunaDia,
    required this.resize,
  });

  final String osId;
  final DragProposta proposta;

  /// Canto superior-esquerdo do bloco (coordenadas do [Overlay]) no início do
  /// arraste.
  final Offset origem;

  /// Largura do BLOCO (pode ser 1/N da coluna, se há sobreposição) e largura da
  /// COLUNA DE DIA (o passo do cross-day).
  final double larguraBloco;
  final double larguraColunaDia;

  final bool resize;

  double get left =>
      origem.dx + (resize ? 0 : proposta.deltaDias * larguraColunaDia);

  double get top =>
      origem.dy +
      (resize
          ? 0
          : (proposta.startMin - proposta.origemStartMin) * kAgendaPxPorMin);

  double get altura => (proposta.duracaoMin * kAgendaPxPorMin).clamp(
    kAgendaAlturaMinBlocoPx,
    double.infinity,
  );
}

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

class DayColumn extends StatefulWidget {
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
    this.hoje,
    this.pendentes = const {},
    this.permiteCrossDay = false,
    this.onMover,
    this.onRedimensionar,
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

  /// Liga a camada de gestos (arrastar/redimensionar) — desktop web.
  final bool editable;

  final int maxColunas;
  final bool showLeftBorder;

  /// Hoje (date-only, BRT) — piso do arraste (D7). Sem ele, não há arraste.
  final DateTime? hoje;

  /// OS com drop em voo: não arrastam de novo (R-A3).
  final Set<String> pendentes;

  /// Semana: o arraste horizontal troca de dia (D8). Visão dia: nunca.
  final bool permiteCrossDay;

  /// Drop de mover: novo dia (date-only) + novo início (minutos-BRT).
  final void Function(OrdemServico os, DateTime dia, int startMin)? onMover;

  /// Drop de redimensionar: nova duração em minutos.
  final void Function(OrdemServico os, int duracaoMin)? onRedimensionar;

  @override
  State<DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<DayColumn> {
  /// Preview do arraste em curso — LOCAL (R-B3). Só os blocos escutam.
  final ValueNotifier<_Preview?> _preview = ValueNotifier<_Preview?>(null);
  OverlayEntry? _fantasma;

  @override
  void dispose() {
    _removerFantasma();
    _preview.dispose();
    super.dispose();
  }

  Disponibilidade? _dispDe(OrdemServico os) =>
      widget.dispByProf[os.profissional ?? ''];

  bool _arrastavel(OrdemServico os) =>
      widget.editable &&
      widget.hoje != null &&
      // Só `agendada`/`atribuida` (D6) — a MESMA regra do sheet do APK.
      osAjustavel(os) &&
      !widget.pendentes.contains(os.id);

  void _mostrarFantasma() {
    if (_fantasma != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return; // sem Overlay (teste isolado): sem fantasma.
    _fantasma = OverlayEntry(
      builder: (_) => ValueListenableBuilder<_Preview?>(
        valueListenable: _preview,
        builder: (context, p, _) {
          if (p == null) return const SizedBox.shrink();
          return Positioned(
            left: p.left,
            top: p.top,
            width: p.larguraBloco,
            height: p.altura,
            child: IgnorePointer(child: _FantasmaDrag(preview: p)),
          );
        },
      ),
    );
    overlay.insert(_fantasma!);
  }

  void _removerFantasma() {
    _fantasma?.remove();
    _fantasma = null;
  }

  /// Início de um arraste: guarda a origem do bloco em coordenadas do Overlay.
  void _dragStart({
    required BuildContext blocoContext,
    required OrdemServico os,
    required DragProposta inicial,
    required bool resize,
    required double larguraColunaDia,
  }) {
    final box = blocoContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlayBox =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final global = box.localToGlobal(Offset.zero);
    _preview.value = _Preview(
      osId: os.id,
      proposta: inicial,
      origem: overlayBox?.globalToLocal(global) ?? global,
      larguraBloco: box.size.width,
      larguraColunaDia: larguraColunaDia,
      resize: resize,
    );
    _mostrarFantasma();
  }

  /// Cada frame do ponteiro: SÓ a proposta muda — o fantasma escuta o notifier e
  /// se redesenha sozinho; a grade (aglomerados/colunas) não é recalculada.
  void _dragUpdate(DragProposta p) {
    final atual = _preview.value;
    if (atual == null) return;
    _preview.value = _Preview(
      osId: atual.osId,
      proposta: p,
      origem: atual.origem,
      larguraBloco: atual.larguraBloco,
      larguraColunaDia: atual.larguraColunaDia,
      resize: atual.resize,
    );
  }

  void _dragEnd() {
    _preview.value = null;
    _removerFantasma();
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final porId = {for (final os in widget.events) os.id: os};
    final layout = layoutDayEvents(
      [for (final os in widget.events) intervaloDaOs(os, _dispDe(os))],
      dayStart: widget.dayStart,
      dayEnd: widget.dayEnd,
      maxColunas: widget.maxColunas,
    );
    final alturaTotal = (widget.dayEnd - widget.dayStart) * kAgendaPxPorMin;
    final horaInicial = (widget.dayStart + 59) ~/ 60;
    final horaFinal = (widget.dayEnd + 59) ~/ 60;

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
                    border: widget.showLeftBorder
                        ? Border(left: BorderSide(color: clx.line))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      for (var h = horaInicial; h < horaFinal; h++)
                        Positioned(
                          top: (h * 60 - widget.dayStart) * kAgendaPxPorMin,
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
                  top:
                      (ex.startMin - widget.dayStart) * kAgendaPxPorMin + 2,
                  right: 2,
                  child: _ChipExcedente(
                    excedente: ex,
                    porId: porId,
                    onTap: widget.onTap,
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
    final duracao = duracaoEfetivaMin(os, _dispDe(os));
    final altura = (p.duracaoMin * kAgendaPxPorMin).clamp(
      kAgendaAlturaMinBlocoPx,
      double.infinity,
    );
    return Positioned(
      top: (p.startMin - widget.dayStart) * kAgendaPxPorMin,
      left: p.column * larguraCol,
      width: larguraCol,
      height: altura,
      child: _BlocoOS(
        os: os,
        posicao: p,
        duracaoMin: duracao,
        onTap: widget.onTap,
        arrastavel: _arrastavel(os),
        pendente: widget.pendentes.contains(os.id),
        preview: _preview,
        larguraColuna: larguraTotal,
        hoje: widget.hoje,
        dia: widget.day,
        permiteCrossDay: widget.permiteCrossDay,
        onDragStart: (ctx, inicial, resize) => _dragStart(
          blocoContext: ctx,
          os: os,
          inicial: inicial,
          resize: resize,
          larguraColunaDia: larguraTotal,
        ),
        onDragUpdate: _dragUpdate,
        onDragEnd: _dragEnd,
        onMover: widget.onMover,
        onRedimensionar: widget.onRedimensionar,
      ),
    );
  }
}

/// O fantasma que segue o arraste (no [Overlay], acima de todas as colunas — é o
/// que permite ver o bloco atravessando para o dia vizinho na semana).
class _FantasmaDrag extends StatelessWidget {
  const _FantasmaDrag({required this.preview});
  final _Preview preview;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final p = preview.proposta;
    final faixa = faixaHoraria(p.startMin, p.duracaoMin);
    final dia = p.deltaDias == 0
        ? ''
        : '${kDowShortDrag[p.dia.weekday % 7]} ${p.dia.day} · ';
    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 1),
      child: Material(
        color: clx.primary.withValues(alpha: 0.22),
        borderRadius: ClxRadii.rSm,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: clx.primary, width: 1.5),
            borderRadius: ClxRadii.rSm,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          alignment: Alignment.topLeft,
          child: Text(
            '$dia$faixa',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dias da semana curtos (0=Dom) — rótulo do fantasma no cross-day.
const List<String> kDowShortDrag = [
  'Dom',
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sáb',
];

/// O bloco de uma OS na grade: cor do status, faixa "08:00–10:00" e nome curto.
/// Quando [arrastavel], ganha a camada de gestos (corpo = mover, borda = resize).
class _BlocoOS extends StatefulWidget {
  const _BlocoOS({
    required this.os,
    required this.posicao,
    required this.duracaoMin,
    required this.onTap,
    required this.arrastavel,
    required this.pendente,
    required this.preview,
    required this.larguraColuna,
    required this.dia,
    required this.hoje,
    required this.permiteCrossDay,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onMover,
    required this.onRedimensionar,
  });

  final OrdemServico os;
  final EventoPosicionado posicao;
  final int duracaoMin;
  final ValueChanged<OrdemServico> onTap;
  final bool arrastavel;
  final bool pendente;
  final ValueNotifier<_Preview?> preview;

  /// Largura de UMA coluna de DIA (não a do bloco) — divisor do cross-day.
  final double larguraColuna;

  final DateTime dia;
  final DateTime? hoje;
  final bool permiteCrossDay;

  final void Function(BuildContext ctx, DragProposta inicial, bool resize)
  onDragStart;
  final ValueChanged<DragProposta> onDragUpdate;
  final VoidCallback onDragEnd;

  final void Function(OrdemServico os, DateTime dia, int startMin)? onMover;
  final void Function(OrdemServico os, int duracaoMin)? onRedimensionar;

  @override
  State<_BlocoOS> createState() => _BlocoOSState();
}

class _BlocoOSState extends State<_BlocoOS> {
  bool _hover = false;
  Offset _acumulado = Offset.zero;
  DragProposta? _atual;

  int get _startMin => widget.posicao.startMin;

  DragProposta _propor({required bool resize}) => resize
      ? propostaDeRedimensionar(
          diaOriginal: widget.dia,
          startMin: _startMin,
          duracaoMin: widget.duracaoMin,
          dyPx: _acumulado.dy,
          pxPorMin: kAgendaPxPorMin,
        )
      : propostaDeMover(
          diaOriginal: widget.dia,
          hoje: widget.hoje ?? widget.dia,
          startMin: _startMin,
          duracaoMin: widget.duracaoMin,
          dxPx: _acumulado.dx,
          dyPx: _acumulado.dy,
          pxPorMin: kAgendaPxPorMin,
          larguraColunaPx: widget.larguraColuna,
          permiteCrossDay: widget.permiteCrossDay,
        );

  void _start(BuildContext ctx, bool resize) {
    _acumulado = Offset.zero;
    _atual = _propor(resize: resize);
    widget.onDragStart(ctx, _atual!, resize);
  }

  void _update(DragUpdateDetails d, bool resize) {
    _acumulado += d.delta;
    final p = _propor(resize: resize);
    _atual = p;
    widget.onDragUpdate(p);
  }

  void _end(bool resize) {
    final p = _atual;
    _atual = null;
    _acumulado = Offset.zero;
    widget.onDragEnd();
    if (p == null || p.inerte) return;
    if (resize) {
      widget.onRedimensionar?.call(widget.os, p.duracaoMin);
    } else {
      widget.onMover?.call(widget.os, p.dia, p.startMin);
    }
  }

  void _cancel() {
    _atual = null;
    _acumulado = Offset.zero;
    widget.onDragEnd();
  }

  /// Pan que vence o scroll da grade (ver [_AgendaPanRecognizer]).
  Widget _pan({required Widget child, required bool resize}) =>
      RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _AgendaPanRecognizer:
              GestureRecognizerFactoryWithHandlers<_AgendaPanRecognizer>(
                () => _AgendaPanRecognizer(debugOwner: this),
                (r) {
                  r.onStart = (_) => _start(context, resize);
                  r.onUpdate = (d) => _update(d, resize);
                  r.onEnd = (_) => _end(resize);
                  r.onCancel = _cancel;
                },
              ),
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final p = widget.posicao;
    final os = widget.os;
    final faixa = faixaHoraria(p.startMin, p.duracaoMin);
    final curto = p.duracaoMin < 45;

    final conteudo = Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: clx.statusColor(os.status), width: 3),
          top: p.truncTop
              ? BorderSide(color: clx.statusColor(os.status))
              : BorderSide.none,
          bottom: p.truncBottom
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
                ? '$faixa ${os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao}'
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
                os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: clx.ink2),
              ),
            ),
        ],
      ),
    );

    // Bloco NÃO arrastável (Fase 1 / status travado / drop em voo): sem alça.
    if (!widget.arrastavel) {
      return Padding(
        padding: const EdgeInsets.only(right: 2, bottom: 1),
        child: Opacity(
          opacity: widget.pendente ? 0.55 : 1,
          child: Material(
            color: clx.statusBg(os.status),
            borderRadius: ClxRadii.rSm,
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: () => widget.onTap(os), child: conteudo),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.move,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ValueListenableBuilder<_Preview?>(
        valueListenable: widget.preview,
        builder: (context, prev, child) {
          // O bloco de ORIGEM some pro fundo enquanto o fantasma está no ar.
          final arrastando = prev?.osId == os.id;
          return Opacity(opacity: arrastando ? 0.3 : 1, child: child);
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 1),
          child: Material(
            color: clx.statusBg(os.status),
            borderRadius: ClxRadii.rSm,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Corpo: clique abre a OS; arraste MOVE (e cruza dias na semana).
                Positioned.fill(
                  child: _pan(
                    resize: false,
                    child: InkWell(
                      onTap: () => widget.onTap(os),
                      child: conteudo,
                    ),
                  ),
                ),
                // Borda inferior: arraste REDIMENSIONA (aparece no hover).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: kAgendaAlcaPx,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: _pan(
                      resize: true,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: ClxMotion.shortDuration,
                          opacity: _hover ? 1 : 0,
                          child: Container(
                            key: ValueKey('agenda-alca-${os.id}'),
                            width: 22,
                            height: 3,
                            decoration: BoxDecoration(
                              color: clx.statusColor(os.status),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
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
