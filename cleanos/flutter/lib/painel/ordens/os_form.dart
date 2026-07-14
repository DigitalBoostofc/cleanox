/// os_form.dart — Formulário de criar/editar Ordem de Serviço (Painel).
///
/// Seleção de cliente (busca NO SERVIDOR — sem `getFullList`), serviço (prefila
/// nome+valor), profissional (define status atribuída/agendada), data, **hora
/// livre HH:MM**, **duração** e valor. Cria/atribui via
/// `OrdensRepository.create`/`update`.
///
/// ⭐ Agenda estilo Google (spec §8): **sobrepor é permitido**. O horário deixou
/// de ser um dropdown de slots "livres" (que escondia encaixes legítimos) e virou
/// entrada livre com snap de 15 min; a colisão vira um **aviso amarelo que não
/// bloqueia o salvar** (D2/D10/D11), calculado pela MESMA função `sobreposicoes`
/// que a grade usa para desenhar — aviso e desenho nunca se contradizem.
///
/// A Duração vem **prefilada visível** com a duração do profissional (D9): o
/// usuário vê de onde veio e pode mudar. Nada de herança invisível no servidor.
///
/// Mostrado via [showOSForm] — Dialog centrado (Painel desktop-first). Resolve a
/// OS GRAVADA (ou `null` se o usuário desistiu): o caller recarrega a lista e,
/// como o salvar pode MUDAR o status na surdina (agendada + profissional →
/// atribuída), precisa do status resultante para levar a lista até a aba certa
/// em vez de deixar a OS sumir da tela (F-232).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agenda/agenda_layout.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/servico.dart';
import '../agenda/agenda_controller.dart' show weekdayIndexOf;
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';
import '../servicos/servicos_labels.dart';
import 'ordens_controller.dart';
import 'os_rebaixar_confirm.dart';
import 'os_status_rules.dart';

/// A OS gravada volta com o profissional/cliente expandidos: ela substitui o
/// registro na lista e alimenta o detalhe, que sem o expand mostraria "—" no
/// lugar do nome do profissional recém-atribuído.
const String _kFormExpand = 'profissional,cliente';

Future<OrdemServico?> showOSForm(BuildContext context, {OrdemServico? editing}) {
  return showDialog<OrdemServico>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: OSForm(editing: editing),
      ),
    ),
  );
}

/// Opções do seletor de Duração (min). A duração do profissional entra na lista
/// se não estiver aqui (a prefilagem tem que ser SEMPRE visível — D9).
const List<int> kDuracaoOpcoes = [15, 30, 45, 60, 90, 120, 150, 180, 240];

/// Abaixo desta largura de viewport os campos Data + Hora deixam de dividir a
/// linha e passam a empilhar (cada um ocupa a largura toda). Espelha o
/// `@media (max-width: 640px) { .form-grid-2 { grid-template-columns: 1fr } }`
/// do React — o `.form-grid-2` que envolve o `OSFormSection` vem de
/// `Clientes.tsx` (linha ~665, `form-grid form-grid-2`); note que
/// `OrdensServico.tsx` renderiza o mesmo form em `.form-grid` (1-col sempre),
/// então a referência do side-by-side @640 é o `Clientes.tsx`. Sem isso, em
/// telas estreitas a Hora ficava com ~metade da linha e
/// os dois dropdowns (hora + minuto) não cabiam — o "10" era cortado p/ "1"
/// pela seta + padding do dropdown. (F-602)
const double _kStackFieldsBelow = 640;

/// Resultado PURO do cruzamento disponibilidade × ocupação para um dia.
/// Espelha o cálculo de `OSFormSection.tsx`: se o profissional atende no dia,
/// [slots] são os horários 'HH:MM' LIVRES; senão [diaAtende] é `false`.
class OSDaySlots {
  const OSDaySlots({required this.diaAtende, required this.slots});

  final bool diaAtende;
  final List<String> slots;

  static const OSDaySlots naoAtende = OSDaySlots(diaAtende: false, slots: []);
}

/// Gera os slots LIVRES de um profissional num [date] (yyyy-MM-dd, BRT), cruzando
/// a [disp] semanal (dia da semana via [weekdayIndexOf], reuso da Agenda) com os
/// [ocupados] ('HH:MM' BRT). Função PURA (testável sem rede). Reusa
/// `gerarSlotsDisponiveis` do core (mesma lógica de slot da Agenda).
OSDaySlots computeOSDaySlots({
  required Disponibilidade disp,
  required String date,
  required List<String> ocupados,
}) {
  if (date.isEmpty) return const OSDaySlots(diaAtende: true, slots: []);
  final weekday = weekdayIndexOf(date);
  if (weekday >= disp.dias.length) {
    return const OSDaySlots(diaAtende: true, slots: []);
  }
  final dia = disp.dias[weekday];
  if (!dia.ativo) return OSDaySlots.naoAtende;
  final slots = gerarSlotsDisponiveis(
    DisponibilidadeDia(ativo: true, inicio: dia.inicio, fim: dia.fim),
    disp.duracaoMin,
    ocupados,
  );
  return OSDaySlots(diaAtende: true, slots: slots);
}

class OSForm extends ConsumerStatefulWidget {
  const OSForm({super.key, this.editing});

  final OrdemServico? editing;

  @override
  ConsumerState<OSForm> createState() => _OSFormState();
}

class _OSFormState extends ConsumerState<OSForm> {
  final TextEditingController _tipoServico = TextEditingController();
  final TextEditingController _valor = TextEditingController();
  final TextEditingController _observacoes = TextEditingController();

  /// Hora de início — entrada LIVRE 'HH:MM' (snap de 15 min ao sair do campo).
  final TextEditingController _hora = TextEditingController(text: '08:00');
  final FocusNode _horaFocus = FocusNode();

  String _clienteId = '';
  String _clienteLabel = '';
  String _servicoId = '';
  String _profissionalId = '';
  String _dataDate = ''; // yyyy-MM-dd (BRT)

  /// Duração da OS (min). `null` = ainda não decidida → prefilada, VISÍVEL, com a
  /// duração do profissional quando ele é escolhido (D9).
  int? _duracaoMin;

  /// O usuário mexeu na duração à mão → a prefilagem não sobrescreve mais.
  bool _duracaoTocada = false;

  // Filtro cascata Categoria → Grupo → Serviço (espelha OSFormSection.tsx): os
  // serviços do catálogo são filtrados pela categoria/grupo configurados neles.
  Categoria? _catFiltro;
  Grupo? _grupoFiltro;
  bool _cascadeInit = false;

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  // Disponibilidade real do profissional selecionado (prefila a Duração).
  Disponibilidade? _disp;

  /// Agenda OCUPADA do profissional no dia — base do aviso de sobreposição. Só o
  /// que de fato ocupa: `agendada`/`atribuida`/`em_andamento` (D11 — `cancelada` e
  /// `concluida` ficam de fora, senão reagendar no mesmo dia vira ruído).
  ///
  /// Guarda as OS (não os intervalos): a duração efetiva de cada uma depende da
  /// disponibilidade do profissional, que pode chegar DEPOIS desta lista.
  List<OrdemServico> _ocupados = const [];
  bool _ocupadosLoading = false;
  // Tokens monotônicos p/ descartar respostas obsoletas (troca rápida de prof/data).
  int _dispSeq = 0;
  int _ocupSeq = 0;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final os = widget.editing;
    if (os != null) {
      _clienteId = os.cliente;
      _clienteLabel = os.clienteNomeExibicao;
      _servicoId = os.servico ?? '';
      _tipoServico.text = os.tipoServicoNome ?? '';
      _valor.text = os.valorServico == null ? '' : _numText(os.valorServico!);
      _profissionalId = os.profissional ?? '';
      _observacoes.text = os.observacoes ?? '';
      // OS já tem duração própria → é ela que manda (e não é sobrescrita).
      if (os.duracaoMin != null) {
        _duracaoMin = os.duracaoMin;
        _duracaoTocada = true;
      }
      final local = pbDateToLocalInput(os.dataHora); // yyyy-MM-ddTHH:mm
      if (local.isNotEmpty) {
        final parts = local.split('T');
        _dataDate = parts[0];
        _hora.text = parts[1];
      }
      // Já editando com profissional atribuído → carrega disponibilidade + ocupação.
      if (_profissionalId.isNotEmpty) {
        _fetchDisp();
        _fetchOcupados();
      }
    }
    // Snap de 15 min ao SAIR do campo de hora (digitar 08:07 → 08:00).
    _horaFocus.addListener(() {
      if (!_horaFocus.hasFocus) _normalizarHora();
    });
  }

  @override
  void dispose() {
    _tipoServico.dispose();
    _valor.dispose();
    _observacoes.dispose();
    _hora.dispose();
    _horaFocus.dispose();
    super.dispose();
  }

  static String _numText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Minutos-BRT do texto de hora, ou `null` se ainda não é um 'HH:MM' válido.
  int? get _horaMin => parseHoraLivre(_hora.text);

  /// Duração efetiva escolhida: OS > profissional > 60 (mesma regra do render).
  int get _duracaoEfetiva {
    if ((_duracaoMin ?? 0) > 0) return _duracaoMin!;
    final doProf = _disp?.duracaoMin ?? 0;
    return doProf > 0 ? doProf : kDuracaoPadraoMin;
  }

  /// Normaliza o campo de hora: completa, valida e faz o snap de 15 min.
  void _normalizarHora() {
    final min = parseHoraLivre(_hora.text);
    if (min == null) {
      setState(() => _errs['hora'] = 'Horário inválido (HH:MM)');
      return;
    }
    final snapped = snap15(min);
    setState(() {
      _errs.remove('hora');
      _hora.text = hhmmDeMinutos(snapped);
    });
  }

  /// Prefila a Duração com a do profissional — VISÍVEL no campo (D9). Só age
  /// enquanto o usuário não escolheu uma duração à mão.
  void _prefillDuracao() {
    if (_duracaoTocada) return;
    final doProf = _disp?.duracaoMin ?? 0;
    final nova = doProf > 0 ? doProf : null;
    if (nova == _duracaoMin) return;
    setState(() => _duracaoMin = nova);
  }

  void _onServico(String? id, List<ServicoPB> servicos) {
    setState(() {
      _servicoId = id ?? '';
      _errs.remove('servico');
      if (id != null && id.isNotEmpty) {
        for (final svc in servicos) {
          if (svc.id == id) {
            _tipoServico.text = svc.nome;
            _valor.text = _numText(svc.valorBase);
            _errs.remove('valor');
            break;
          }
        }
      }
    });
  }

  ServicoPB? _servicoAtual(List<ServicoPB> servicos) {
    for (final s in servicos) {
      if (s.id == _servicoId) return s;
    }
    return null;
  }

  /// Categoria do filtro mudou: reseta o grupo e limpa o serviço se ele já não
  /// pertencer à nova categoria (espelha `handleCategoriaChange`).
  void _onCategoria(Categoria? c, List<ServicoPB> servicos) {
    setState(() {
      _catFiltro = c;
      _grupoFiltro = null;
      if (c != null && _servicoId.isNotEmpty) {
        final cur = _servicoAtual(servicos);
        if (cur?.categoria != null && cur!.categoria != c) _servicoId = '';
      }
    });
  }

  /// Grupo do filtro mudou: limpa o serviço se ele já não pertencer ao novo
  /// grupo (espelha `handleGrupoChange`).
  void _onGrupo(Grupo? g, List<ServicoPB> servicos) {
    setState(() {
      _grupoFiltro = g;
      if (g != null && _servicoId.isNotEmpty) {
        final cur = _servicoAtual(servicos);
        if (cur?.grupo != null && cur!.grupo != g) _servicoId = '';
      }
    });
  }

  /// Modo edição: inicializa o filtro a partir do serviço já selecionado (uma
  /// única vez, quando o catálogo carrega). Espelha o useEffect de init do React.
  void _maybeInitCascade(List<ServicoPB> servicos) {
    if (_cascadeInit || _servicoId.isEmpty || servicos.isEmpty) return;
    _cascadeInit = true;
    final cur = _servicoAtual(servicos);
    if (cur == null || (cur.categoria == null && cur.grupo == null)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _catFiltro = cur.categoria;
        _grupoFiltro = cur.grupo;
      });
    });
  }

  /// Profissional mudou: reseta e recarrega disponibilidade + ocupação.
  void _onProfissional(String v) {
    setState(() => _profissionalId = v);
    _fetchDisp();
    _fetchOcupados();
  }

  /// Limites [start, end) do dia [date] em string UTC do PB (BRT centralizado,
  /// mesmo cálculo da Agenda).
  static ({String start, String end}) _dayBounds(String date) {
    final start = localInputToPBDate('${date}T00:00');
    final d = DateTime.tryParse(date) ?? DateTime.now();
    final next = DateTime(d.year, d.month, d.day + 1);
    final nextDate =
        '${next.year.toString().padLeft(4, '0')}-'
        '${next.month.toString().padLeft(2, '0')}-'
        '${next.day.toString().padLeft(2, '0')}';
    return (start: start, end: localInputToPBDate('${nextDate}T00:00'));
  }

  /// Busca a disponibilidade semanal do profissional selecionado — hoje ela serve
  /// para PREFILAR a Duração (D9) e para estimar a duração das OS já ocupadas.
  Future<void> _fetchDisp() async {
    final prof = _profissionalId;
    if (prof.isEmpty) {
      setState(() {
        _disp = null;
        _ocupados = const [];
      });
      _prefillDuracao();
      return;
    }
    final seq = ++_dispSeq;
    try {
      final res = await ref
          .read(disponibilidadeRepositoryProvider)
          .list(
            page: 1,
            perPage: 1,
            filter: disponibilidadeDoProfissionalFilter(prof),
          );
      if (!mounted || seq != _dispSeq) return;
      setState(() => _disp = res.items.isEmpty ? null : res.items.first);
      _prefillDuracao();
    } catch (_) {
      // Sem disponibilidade (rede/registro ausente) a Duração cai no padrão de 60.
      if (!mounted || seq != _dispSeq) return;
      setState(() => _disp = null);
      _prefillDuracao();
    }
  }

  /// Busca as OS que OCUPAM a agenda do profissional no dia selecionado — base do
  /// aviso de sobreposição (não bloqueia nada: encaixar é permitido).
  Future<void> _fetchOcupados() async {
    final prof = _profissionalId;
    final date = _dataDate;
    if (prof.isEmpty || date.isEmpty) {
      setState(() {
        _ocupados = const [];
        _ocupadosLoading = false;
      });
      return;
    }
    final seq = ++_ocupSeq;
    setState(() => _ocupadosLoading = true);
    final bounds = _dayBounds(date);
    try {
      final res = await ref
          .read(ordensRepositoryProvider)
          .list(
            page: 1,
            perPage: 200,
            filter: ordensOcupamAgendaFilter(
              profissionalId: prof,
              dataInicio: bounds.start,
              dataFim: bounds.end,
            ),
            sort: 'data_hora',
          );
      if (!mounted || seq != _ocupSeq) return;
      final editingId = widget.editing?.id;
      final ocupados = <OrdemServico>[
        for (final o in res.items)
          // D11: só o que de fato ocupa a agenda. `concluida`/`cancelada` ficam
          // de fora (reagendar no mesmo dia não deve gerar aviso fantasma), e a
          // própria OS em edição também.
          if (o.id != editingId &&
              o.status != OSStatus.concluida &&
              o.status != OSStatus.cancelada)
            o,
      ];
      setState(() {
        _ocupados = ocupados;
        _ocupadosLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _ocupSeq) return;
      setState(() {
        _ocupados = const [];
        _ocupadosLoading = false;
      });
    }
  }

  /// OS do dia que a escolha atual SOBREPÕE (mesma função que a grade usa para
  /// desenhar as colunas — aviso e desenho nunca divergem).
  List<Intervalo> get _colisoes {
    final inicio = _horaMin;
    if (inicio == null || _ocupados.isEmpty) return const [];
    return sobreposicoes(
      [for (final o in _ocupados) intervaloDaOs(o, _disp)],
      inicio,
      _duracaoEfetiva,
    );
  }

  Map<String, String> _validate() {
    final errs = <String, String>{};
    if (_clienteId.isEmpty) errs['cliente'] = 'Selecione um cliente';
    if (_dataDate.isEmpty) {
      errs['data'] = 'Data é obrigatória';
    } else if (_dataDate.compareTo(todayLocalDate()) < 0) {
      errs['data'] = 'A data não pode ser no passado';
    }
    if (_horaMin == null) errs['hora'] = 'Horário inválido (HH:MM)';
    final valor = double.tryParse(_valor.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) errs['valor'] = 'Informe o valor';
    return errs;
  }

  Future<void> _save() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() {
        _errs
          ..clear()
          ..addAll(errs);
      });
      return;
    }

    final hasProf = _profissionalId.isNotEmpty;
    final editing = widget.editing;

    // Tirar o profissional de uma OS EM ANDAMENTO rebaixa o status — e o hook
    // do servidor, ao ver o status sair de `em_andamento`, apaga o endereço
    // liberado e as coordenadas (são efêmeros por design). Perder isso é uma
    // consequência legítima, mas não pode acontecer sem o admin saber (F-228).
    if (_isEdit &&
        !hasProf &&
        editing != null &&
        editing.status == OSStatus.emAndamento) {
      final ok = await confirmarRebaixarEmAndamento(
        context,
        removendo: true,
      );
      if (ok != true) return;
    }

    if (!mounted) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _errs.clear();
    });

    final valor = double.parse(_valor.text.trim().replaceAll(',', '.'));
    final hora = hhmmDeMinutos(snap15(_horaMin!));
    final payload = <String, dynamic>{
      'cliente': _clienteId,
      'servico': _servicoId.isEmpty ? null : _servicoId,
      'tipo_servico_nome': _tipoServico.text.trim(),
      'data_hora': localInputToPBDate('${_dataDate}T$hora'),
      // Duração PRÓPRIA da OS: grava o que está VISÍVEL no campo (prefilado com a
      // do profissional). Nada de herança invisível no servidor (D9).
      'duracao_min': _duracaoEfetiva,
      'valor_servico': valor,
      'profissional': hasProf ? _profissionalId : null,
      'observacoes': _observacoes.text.trim(),
    };

    // Status: DERIVADO do profissional que está sendo submetido, nunca deduzido
    // de uma transição a partir do registro em mãos — que pode estar velho.
    // Sem `statusAposEdicao`, um registro velho dizendo "agendada/sem prof" fazia
    // os dois ramos de transição falharem, o `status` não entrava no payload e o
    // `atribuida` do banco sobrevivia ao lado de `profissional=""` (F-234).
    if (!_isEdit) {
      payload['status'] = hasProf
          ? OSStatus.atribuida.wire
          : OSStatus.agendada.wire;
    } else if (editing != null) {
      final novo = statusAposEdicao(
        atual: editing.status,
        temProfissional: hasProf,
      );
      if (novo != null) payload['status'] = novo.wire;
    }

    try {
      final repo = ref.read(ordensRepositoryProvider);
      final salva = _isEdit
          ? await repo.update(editing!.id, payload, expand: _kFormExpand)
          : await repo.create(payload, expand: _kFormExpand);
      if (mounted) Navigator.of(context).pop(salva);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Não foi possível salvar a ordem de serviço.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final lookups = ref.watch(ordensLookupsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x5,
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? 'Editar OS' : 'Nova Ordem de Serviço',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Flexible(
          child: lookups.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(ClxSpace.x10),
              child: Center(child: Spinner(size: 24)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(ClxSpace.x5),
              child: ErrorBanner(
                message: 'Não foi possível carregar serviços/profissionais.',
                onRetry: () => ref.invalidate(ordensLookupsProvider),
              ),
            ),
            data: (lk) => _form(clx, lk),
          ),
        ),
        Divider(height: 1, color: clx.line),
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          // Rodapé de ações: em largura comum os botões ficam lado a lado à
          // direita numa `Row` (comportamento original, aparência preservada).
          // Em telas muito estreitas (≤ ~366px úteis — aparelhos pequenos ou
          // split-screen) o par não cabia na `Row` e estourava ~5,5px
          // (RenderFlex overflow); abaixo do breakpoint troca-se por um `Wrap`
          // alinhado à direita que deixa o "Salvar" descer para a 2ª linha —
          // rótulos preservados, sem corte nem overflow. O gate por
          // `LayoutBuilder` garante que em largura normal o layout (e a altura)
          // continua idêntico ao original. (F-603)
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cancelar = ClxButton(
                label: 'Cancelar',
                variant: ClxButtonVariant.ghost,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              );
              final salvar = ClxButton(
                label: 'Salvar',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              );
              if (constraints.maxWidth < 366) {
                return Wrap(
                  alignment: WrapAlignment.end,
                  spacing: ClxSpace.x3,
                  runSpacing: ClxSpace.x2,
                  children: [cancelar, salvar],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  cancelar,
                  const SizedBox(width: ClxSpace.x3),
                  salvar,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _form(CleanoxColors clx, OrdensLookups lk) {
    _maybeInitCascade(lk.servicos);
    // Cascata Categoria → Grupo → Serviço (mesmo cálculo do OSFormSection.tsx).
    final categorias = <Categoria>[
      for (final c in <Categoria>{
        for (final s in lk.servicos)
          if (s.categoria != null) s.categoria!,
      })
        c,
    ];
    final grupos = <Grupo>[
      for (final g in <Grupo>{
        for (final s in lk.servicos)
          if (s.grupo != null &&
              (_catFiltro == null || s.categoria == _catFiltro))
            s.grupo!,
      })
        g,
    ];
    final servicosFiltrados = [
      for (final s in lk.servicos)
        if ((_catFiltro == null || s.categoria == _catFiltro) &&
            (_grupoFiltro == null || s.grupo == _grupoFiltro))
          s,
    ];
    // Valor seguro para o dropdown (evita value fora dos items quando o filtro
    // exclui o serviço atual — mantém o serviço só quando visível na lista).
    final servicoValue = servicosFiltrados.any((s) => s.id == _servicoId)
        ? _servicoId
        : '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ClxSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saveError != null) ...[
            ErrorBanner(message: _saveError!),
            const SizedBox(height: ClxSpace.x4),
          ],

          // Cliente (busca no servidor).
          _label('Cliente', required: true),
          _ClientePicker(
            initialLabel: _clienteLabel,
            error: _errs['cliente'],
            enabled: !_saving,
            onSelected: (id, label) => setState(() {
              _clienteId = id;
              _clienteLabel = label;
              _errs.remove('cliente');
            }),
          ),
          const SizedBox(height: ClxSpace.x4),

          // Categoria (filtro cascata) — só aparece se o catálogo tem categorias.
          if (categorias.isNotEmpty) ...[
            _label('Categoria'),
            DropdownButtonFormField<String>(
              key: ValueKey('os-cat-${_catFiltro?.wire ?? ''}'),
              initialValue: _catFiltro?.wire,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('— Todas —'),
              items: [
                const DropdownMenuItem(value: '', child: Text('— Todas —')),
                for (final c in categorias)
                  DropdownMenuItem(value: c.wire, child: Text(categoriaLabel(c))),
              ],
              onChanged: _saving
                  ? null
                  : (v) => _onCategoria(
                      (v == null || v.isEmpty)
                          ? null
                          : Categoria.values.byName(v),
                      lk.servicos,
                    ),
            ),
            const SizedBox(height: ClxSpace.x4),
          ],

          // Grupo (filtro cascata) — só aparece se há grupos elegíveis.
          if (grupos.isNotEmpty) ...[
            _label('Grupo'),
            DropdownButtonFormField<String>(
              key: ValueKey('os-grupo-${_grupoFiltro?.wire ?? ''}'),
              initialValue: _grupoFiltro?.wire,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('— Todos —'),
              items: [
                const DropdownMenuItem(value: '', child: Text('— Todos —')),
                for (final g in grupos)
                  DropdownMenuItem(value: g.wire, child: Text(grupoLabel(g))),
              ],
              onChanged: _saving
                  ? null
                  : (v) => _onGrupo(
                      (v == null || v.isEmpty) ? null : Grupo.values.byName(v),
                      lk.servicos,
                    ),
            ),
            const SizedBox(height: ClxSpace.x4),
          ],

          // Serviço (filtrado pela categoria/grupo acima).
          _label('Serviço'),
          DropdownButtonFormField<String>(
            key: ValueKey('os-servico-$servicoValue'),
            initialValue: servicoValue.isEmpty ? null : servicoValue,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text('— Selecionar —'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Selecionar —')),
              for (final s in servicosFiltrados)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(s.nome, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving ? null : (v) => _onServico(v, lk.servicos),
          ),
          const SizedBox(height: ClxSpace.x4),

          // Nome do serviço (snapshot editável).
          _textField(
            label: 'Nome do serviço (snapshot)',
            controller: _tipoServico,
            hint: 'Ex: Sofá 3 lugares',
          ),

          // Profissional.
          _label('Profissional'),
          DropdownButtonFormField<String>(
            key: const ValueKey('os-profissional'),
            initialValue: _profissionalId.isEmpty ? null : _profissionalId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text('— Não atribuído (Agendada) —'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('— Não atribuído (Agendada) —'),
              ),
              for (final p in lk.profissionais)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving ? null : (v) => _onProfissional(v ?? ''),
          ),
          Padding(
            padding: const EdgeInsets.only(top: ClxSpace.x1),
            child: Text(
              'Ao atribuir um profissional, o status passa para "Atribuída".',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: clx.ink3),
            ),
          ),
          const SizedBox(height: ClxSpace.x4),

          // Data + hora + duração: lado a lado em telas largas; empilhados no
          // mobile (espelha o colapso do `.form-grid-2` do React em ≤640px).
          // Sem o empilhamento os campos ficam espremidos e o texto é cortado
          // (regressão F-602).
          if (MediaQuery.sizeOf(context).width < _kStackFieldsBelow) ...[
            _dateField(clx),
            const SizedBox(height: ClxSpace.x4),
            _horaField(clx),
            const SizedBox(height: ClxSpace.x4),
            _duracaoField(clx),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _dateField(clx)),
                const SizedBox(width: ClxSpace.x3),
                Expanded(child: _horaField(clx)),
                const SizedBox(width: ClxSpace.x3),
                Expanded(flex: 2, child: _duracaoField(clx)),
              ],
            ),
          _avisoSobreposicao(clx),
          const SizedBox(height: ClxSpace.x4),

          // Valor.
          _textField(
            label: 'Valor do serviço (R\$)',
            required: true,
            controller: _valor,
            errorKey: 'valor',
            hint: '0,00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),

          // Observações.
          _textField(
            label: 'Observações',
            controller: _observacoes,
            hint: 'Detalhes adicionais para o serviço…',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x1),
      child: Text.rich(
        TextSpan(
          text: text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: clx.ink2,
            fontWeight: FontWeight.w600,
          ),
          children: [
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: clx.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    String? errorKey,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final err = errorKey == null ? null : _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            enabled: !_saving,
            onChanged: (_) {
              if (err != null) setState(() => _errs.remove(errorKey));
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              errorText: err,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(CleanoxColors clx) {
    final err = _errs['data'];
    final display = _dataDate.isEmpty ? 'Selecionar…' : _brDate(_dataDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Data', required: true),
        InkWell(
          onTap: _saving ? null : _pickDate,
          borderRadius: ClxRadii.rMd,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              errorText: err,
              suffixIcon: const Icon(Icons.calendar_month_outlined, size: 18),
            ),
            child: Text(
              display,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _dataDate.isEmpty ? clx.ink3 : clx.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Hora: entrada LIVRE 'HH:MM' (D10). Sem dropdown de slots — com sobreposição
  /// permitida, esconder horários "ocupados" só impediria encaixes legítimos.
  /// Snap de 15 min ao sair do campo.
  Widget _horaField(CleanoxColors clx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Hora', required: true),
        TextField(
          key: const ValueKey('os-hora-input'),
          controller: _hora,
          focusNode: _horaFocus,
          enabled: !_saving,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: (_) => setState(() => _errs.remove('hora')),
          onSubmitted: (_) => _normalizarHora(),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'HH:MM',
            errorText: _errs['hora'],
          ),
        ),
      ],
    );
  }

  /// Duração da OS — PREFILADA (visível) com a duração do profissional (D9).
  Widget _duracaoField(CleanoxColors clx) {
    final efetiva = _duracaoEfetiva;
    final opcoes = <int>[
      ...{...kDuracaoOpcoes, efetiva},
    ]..sort();
    final doProf = _disp?.duracaoMin ?? 0;
    final prefilado = !_duracaoTocada && doProf > 0 && efetiva == doProf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Duração'),
        DropdownButtonFormField<int>(
          key: const ValueKey('os-duracao'),
          initialValue: efetiva,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final min in opcoes)
              DropdownMenuItem(value: min, child: Text(labelDuracao(min))),
          ],
          onChanged: _saving
              ? null
              : (v) {
                  if (v == null) return;
                  setState(() {
                    _duracaoMin = v;
                    _duracaoTocada = true;
                  });
                },
        ),
        if (prefilado)
          Padding(
            padding: const EdgeInsets.only(top: ClxSpace.x1),
            child: Text(
              'Duração padrão do profissional.',
              key: const ValueKey('os-duracao-prefill'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: clx.ink3),
            ),
          ),
      ],
    );
  }

  /// Aviso AMARELO de sobreposição (D2): informa, NÃO bloqueia o salvar.
  Widget _avisoSobreposicao(CleanoxColors clx) {
    final colisoes = _colisoes;
    if (colisoes.isEmpty || _ocupadosLoading) return const SizedBox.shrink();
    final texto = colisoes
        .map(
          (c) =>
              '${c.label.isEmpty ? 'OS' : 'OS de ${c.label}'} '
              '(${hhmmDeMinutos(c.startMin)}–${hhmmDeMinutos(c.endMin)})',
        )
        .join(', ');
    return Padding(
      key: const ValueKey('os-aviso-sobreposicao'),
      padding: const EdgeInsets.only(top: ClxSpace.x2),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: clx.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime initial;
    if (_dataDate.isNotEmpty) {
      initial = DateTime.tryParse(_dataDate) ?? now;
    } else {
      initial = now;
    }
    final first = DateTime(now.year, now.month, now.day);
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _dataDate =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
        _errs.remove('data');
      });
      _fetchOcupados(); // dia mudou → recarrega ocupação p/ recalcular slots
    }
  }

  static String _brDate(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }
}

/// Seletor de cliente com busca NO SERVIDOR (getList paginado, sem getFullList).
class _ClientePicker extends ConsumerStatefulWidget {
  const _ClientePicker({
    required this.initialLabel,
    required this.onSelected,
    this.error,
    this.enabled = true,
  });

  final String initialLabel;
  final void Function(String id, String label) onSelected;
  final String? error;
  final bool enabled;

  @override
  ConsumerState<_ClientePicker> createState() => _ClientePickerState();
}

class _ClientePickerState extends ConsumerState<_ClientePicker> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  List<_ClienteOption> _results = const [];
  bool _searching = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onSelected('', value); // limpa seleção enquanto digita
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _open = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _open = true;
    });
    try {
      final res = await ref
          .read(clientesRepositoryProvider)
          .list(
            page: 1,
            perPage: 8,
            filter: clienteSearchFilter(query),
            sort: 'nome,sobrenome',
          );
      if (!mounted) return;
      setState(() {
        _results = [
          for (final c in res.items)
            _ClienteOption(
              id: c.id,
              label: [
                c.nome,
                c.sobrenome,
              ].where((s) => (s ?? '').isNotEmpty).join(' '),
              sub: [
                c.enderecoBairro,
                if (c.telefone.isNotEmpty) c.telefone,
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
        ];
        _searching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searching = false;
        });
      }
    }
  }

  void _select(_ClienteOption opt) {
    _ctrl.text = opt.label;
    widget.onSelected(opt.id, opt.label);
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          enabled: widget.enabled,
          onChanged: _onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Digite para buscar cliente…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            errorText: widget.error,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(ClxSpace.x3),
                    child: Spinner(size: 16),
                  )
                : null,
          ),
        ),
        if (_open && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: ClxSpace.x1),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: clx.bg,
              borderRadius: ClxRadii.rMd,
              border: Border.all(color: clx.line2),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final opt = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    opt.label,
                    style: tt.titleSmall?.copyWith(color: clx.ink),
                  ),
                  subtitle: opt.sub.isEmpty
                      ? null
                      : Text(
                          opt.sub,
                          style: tt.bodySmall?.copyWith(color: clx.ink3),
                        ),
                  onTap: () => _select(opt),
                );
              },
            ),
          ),
        if (_open && !_searching && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: ClxSpace.x2),
            child: Text(
              'Nenhum cliente encontrado.',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            ),
          ),
      ],
    );
  }
}

class _ClienteOption {
  const _ClienteOption({
    required this.id,
    required this.label,
    required this.sub,
  });
  final String id;
  final String label;
  final String sub;
}
