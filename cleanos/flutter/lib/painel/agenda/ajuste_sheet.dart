/// ajuste_sheet.dart — AJUSTE de uma OS no APK / web estreita (Fase 3, D3).
///
/// No celular NÃO existe grade nem arraste (R4: card por item, nunca tabela) —
/// o long-press no card abre ESTE bottom sheet, com steppers de ±15 min para
/// **início** e **duração**. Só isso: quem precisa mudar cliente, serviço ou dia
/// abre o formulário da OS.
///
/// As regras são as MESMAS do arraste do desktop, vindas do núcleo puro:
/// - snap de 15 e piso de 00:00 — adiantar não rola pro dia anterior (D7);
/// - duração mínima de 15 min, teto na meia-noite (`duracaoComPasso`);
/// - só `agendada`/`atribuida` chegam aqui (D6 — `osAjustavel`), e o servidor
///   (`os_logic.js`) ainda barra `data_hora`/`duracao_min` em `concluida` e
///   `cancelada`;
/// - **aviso** de sobreposição pela mesma `sobreposicoes` do formulário (D11):
///   informa, **nunca bloqueia** — encaixar OS é permitido por design.
///
/// A gravação sai por `AgendaController.ajustarOs` (um PATCH, otimista, com
/// rollback cirúrgico) — o sheet não fala com o repositório.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/agenda/agenda_ajuste.dart';
import '../../core/agenda/agenda_drag.dart';
import '../../core/agenda/agenda_layout.dart';
import '../../core/design/design.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/ordem_servico.dart';

/// Abre o sheet de ajuste de [os]. [onSalvar] recebe o dia (date-only, já
/// recortado por D7), o início (minutos-BRT) e a duração (min).
Future<void> showAjusteOsSheet(
  BuildContext context, {
  required OrdemServico os,
  required DateTime dia,
  required DateTime hoje,
  required void Function(DateTime dia, int startMin, int duracaoMin) onSalvar,
  Disponibilidade? disp,
  List<Intervalo> ocupados = const [],
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.clx.bg,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => AjusteOsSheet(
    os: os,
    dia: dia,
    hoje: hoje,
    disp: disp,
    ocupados: ocupados,
    onSalvar: onSalvar,
  ),
);

/// Conteúdo do sheet (público para o teste de widget montá-lo isolado).
class AjusteOsSheet extends StatefulWidget {
  const AjusteOsSheet({
    super.key,
    required this.os,
    required this.dia,
    required this.hoje,
    required this.onSalvar,
    this.disp,
    this.ocupados = const [],
  });

  final OrdemServico os;

  /// Dia (date-only, BRT) em que a OS está — o sheet não muda de dia.
  final DateTime dia;

  /// Hoje (date-only, BRT) — piso do D7.
  final DateTime hoje;

  /// Disponibilidade do profissional — 2º degrau do fallback de duração (D9).
  final Disponibilidade? disp;

  /// Agenda OCUPADA do mesmo profissional naquele dia (D11: sem `concluida` /
  /// `cancelada`, sem a própria OS) — base do aviso de sobreposição.
  final List<Intervalo> ocupados;

  final void Function(DateTime dia, int startMin, int duracaoMin) onSalvar;

  @override
  State<AjusteOsSheet> createState() => _AjusteOsSheetState();
}

class _AjusteOsSheetState extends State<AjusteOsSheet> {
  late int _startMin = intervaloBrtMin(widget.os, widget.disp).startMin;
  late int _duracaoMin = duracaoEfetivaMin(widget.os, widget.disp);

  bool get _podeAdiantar => _startMin > 0;
  bool get _podeAtrasar => _startMin < kMinutosNoDia - kDuracaoMinimaMin;
  bool get _podeEncurtar => _duracaoMin > kDuracaoMinimaMin;
  bool get _podeAlongar => _startMin + _duracaoMin < kMinutosNoDia;

  /// OS do dia que a escolha atual sobrepõe — MESMA função da grade e do form.
  List<Intervalo> get _colisoes =>
      sobreposicoes(widget.ocupados, _startMin, _duracaoMin);

  void _passoInicio(int passos) => setState(() {
    _startMin = inicioComPasso(_startMin, passos);
    // Empurrar o início pra frente pode espremer o fim contra a meia-noite.
    _duracaoMin = duracaoComPasso(_duracaoMin, 0, startMin: _startMin);
  });

  void _passoDuracao(int passos) => setState(
    () => _duracaoMin = duracaoComPasso(_duracaoMin, passos, startMin: _startMin),
  );

  void _salvar() {
    // D7: o sheet não troca de dia, mas o piso é o mesmo do arraste — nenhum
    // caminho da agenda pode jogar uma OS num dia anterior.
    final dia = clampDiaDestino(
      widget.dia,
      diaOriginal: widget.dia,
      hoje: widget.hoje,
    );
    widget.onSalvar(dia, _startMin, _duracaoMin);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final os = widget.os;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ClxSpace.x4,
          ClxSpace.x2,
          ClxSpace.x4,
          ClxSpace.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: clx.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: ClxSpace.x4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ajustar horário',
                    style: tt.titleMedium?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusBadge(status: os.status, dense: true),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              os.nomeCurto.isEmpty ? 'Ordem de serviço' : os.nomeCurto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            ),
            const SizedBox(height: ClxSpace.x4),

            // Faixa resultante, ao vivo: "14:00–14:45 · 45 min".
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ClxSpace.x4,
                vertical: ClxSpace.x3,
              ),
              decoration: BoxDecoration(
                color: clx.bg2,
                borderRadius: ClxRadii.rLg,
                border: Border.all(color: clx.line),
              ),
              child: Text(
                '${faixaHoraria(_startMin, _duracaoMin)} · '
                '${labelDuracao(_duracaoMin)}',
                key: const ValueKey('ajuste-faixa'),
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: ClxSpace.x3),

            _StepperLinha(
              label: 'Início',
              valor: hhmmDeMinutos(_startMin),
              keyMenos: 'ajuste-inicio-menos',
              keyMais: 'ajuste-inicio-mais',
              onMenos: _podeAdiantar ? () => _passoInicio(-1) : null,
              onMais: _podeAtrasar ? () => _passoInicio(1) : null,
            ),
            const SizedBox(height: ClxSpace.x2),
            _StepperLinha(
              label: 'Duração',
              valor: labelDuracao(_duracaoMin),
              keyMenos: 'ajuste-duracao-menos',
              keyMais: 'ajuste-duracao-mais',
              onMenos: _podeEncurtar ? () => _passoDuracao(-1) : null,
              onMais: _podeAlongar ? () => _passoDuracao(1) : null,
            ),

            _aviso(clx, tt),
            const SizedBox(height: ClxSpace.x4),

            Row(
              children: [
                Expanded(
                  child: ClxButton(
                    label: 'Cancelar',
                    variant: ClxButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(width: ClxSpace.x3),
                Expanded(
                  child: ClxButton(
                    key: const ValueKey('ajuste-salvar'),
                    label: 'Salvar',
                    icon: Icons.check_rounded,
                    // Sobrepor é PERMITIDO: o aviso informa, nunca desabilita.
                    onPressed: _salvar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Aviso AMARELO de sobreposição (D2/D11) — o mesmo do formulário.
  Widget _aviso(CleanoxColors clx, TextTheme tt) {
    final colisoes = _colisoes;
    if (colisoes.isEmpty) return const SizedBox(height: ClxSpace.x2);
    final texto = colisoes
        .map(
          (c) =>
              '${c.label.isEmpty ? 'OS' : 'OS de ${c.label}'} '
              '(${faixaHoraria(c.startMin, c.duracaoMin)})',
        )
        .join(', ');
    return Padding(
      key: const ValueKey('ajuste-aviso-sobreposicao'),
      padding: const EdgeInsets.only(top: ClxSpace.x3),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        decoration: BoxDecoration(
          color: clx.warningBg,
          borderRadius: ClxRadii.rMd,
          border: Border.all(color: clx.warning),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: clx.warning),
            const SizedBox(width: ClxSpace.x2),
            Expanded(
              child: Text(
                'Sobrepõe $texto. Pode salvar assim mesmo.',
                style: tt.bodySmall?.copyWith(color: clx.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma linha de stepper: rótulo, valor grande e os botões −/+ (alvo ≥ 48dp).
/// Botão nulo = limite atingido (sem afordância de fazer o que não pode).
class _StepperLinha extends StatelessWidget {
  const _StepperLinha({
    required this.label,
    required this.valor,
    required this.keyMenos,
    required this.keyMais,
    required this.onMenos,
    required this.onMais,
  });

  final String label;
  final String valor;
  final String keyMenos;
  final String keyMais;
  final VoidCallback? onMenos;
  final VoidCallback? onMais;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.bodySmall?.copyWith(color: clx.ink3),
              ),
              Text(
                valor,
                style: tt.titleMedium?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _BotaoPasso(
          chave: keyMenos,
          icon: Icons.remove_rounded,
          tooltip: '−15 min',
          onPressed: onMenos,
        ),
        const SizedBox(width: ClxSpace.x2),
        _BotaoPasso(
          chave: keyMais,
          icon: Icons.add_rounded,
          tooltip: '+15 min',
          onPressed: onMais,
        ),
      ],
    );
  }
}

class _BotaoPasso extends StatelessWidget {
  const _BotaoPasso({
    required this.chave,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String chave;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ativo = onPressed != null;
    return SizedBox(
      width: ClxLayout.minTouchTarget,
      height: ClxLayout.minTouchTarget,
      child: IconButton(
        key: ValueKey(chave),
        tooltip: tooltip,
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        style: IconButton.styleFrom(
          backgroundColor: ativo ? clx.bg2 : clx.bg3,
          shape: RoundedRectangleBorder(
            borderRadius: ClxRadii.rMd,
            side: BorderSide(color: clx.line),
          ),
        ),
        icon: Icon(icon, size: 20, color: ativo ? clx.ink : clx.ink3),
      ),
    );
  }
}
