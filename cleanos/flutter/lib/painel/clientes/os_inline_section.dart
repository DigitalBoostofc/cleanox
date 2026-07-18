/// os_inline_section.dart — Seção de OS embutida na criação de Cliente ("Gerar OS").
///
/// Espelha `OSFormSection.tsx` reaproveitado pelo `Clientes.tsx` quando o toggle
/// "Gerar OS" está ligado: serviço (prefila nome+valor), profissional (define
/// atribuída/agendada no save), data + slot de horário (mesma lógica de
/// disponibilidade da Nova OS), **duração** (paridade com Nova OS — D9) e
/// valor/observações. NÃO tem seletor de cliente — a OS é gerada para o cliente
/// recém-criado.
///
/// Reusa a função PURA [computeOSDaySlots] do formulário de OS (mesma lógica de
/// slot da Agenda/Nova OS) e os providers/filtros já congelados. O estado dos
/// campos vive AQUI; o formulário-pai lê os valores + [OsInlineSectionState.validate]
/// via `GlobalKey` no save (espelha `validateOSInlineForm` do React).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agenda/agenda_layout.dart' show kDuracaoPadraoMin, labelDuracao;
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/servico.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';
import '../servicos/servicos_labels.dart';
import '../ordens/ordens_controller.dart' show ordensLookupsProvider;
import '../ordens/os_form.dart' show computeOSDaySlots, kDuracaoOpcoes;
import '../../core/auth/auth_providers.dart' show ordensRepositoryProvider;

const List<String> _kMinutes = ['00', '15', '30', '45'];

/// Estágio da busca de disponibilidade do profissional selecionado.
enum _DispState { idle, loading, loaded, error }

class OsInlineSection extends ConsumerStatefulWidget {
  const OsInlineSection({super.key, required this.enabled});

  /// Desabilita os campos enquanto o cliente está salvando.
  final bool enabled;

  @override
  ConsumerState<OsInlineSection> createState() => OsInlineSectionState();
}

class OsInlineSectionState extends ConsumerState<OsInlineSection> {
  final TextEditingController _tipoServico = TextEditingController();
  final TextEditingController _valor = TextEditingController();
  final TextEditingController _observacoes = TextEditingController();

  String _servicoId = '';
  String _profissionalId = '';
  String _dataDate = ''; // yyyy-MM-dd (BRT)
  String _horaH = '08';
  String _horaM = '00';

  /// Duração da OS (min). `null` → prefilada com a do profissional (D9).
  int? _duracaoMin;
  bool _duracaoTocada = false;

  // Filtro cascata Categoria → Grupo → Serviço (espelha OSFormSection.tsx).
  Categoria? _catFiltro;
  Grupo? _grupoFiltro;

  final Map<String, String> _errs = {};

  // Disponibilidade real do profissional selecionado (seletor de slot).
  Disponibilidade? _disp;
  _DispState _dispState = _DispState.idle;
  List<String> _ocupados = const [];
  bool _ocupadosLoading = false;
  int _dispSeq = 0;
  int _ocupSeq = 0;

  /* ─── API pública consumida pelo formulário-pai (via GlobalKey) ─── */

  String get servicoId => _servicoId;
  String get tipoServicoNome => _tipoServico.text.trim();
  String get dataDate => _dataDate;
  String get horaH => _horaH;
  String get horaM => _horaM;
  String get valorServico => _valor.text.trim();
  String get profissionalId => _profissionalId;
  String get observacoes => _observacoes.text.trim();

  /// Duração efetiva gravada na OS (OS > prof > 60), paridade com [OSForm].
  int get duracaoMin {
    if ((_duracaoMin ?? 0) > 0) return _duracaoMin!;
    final doProf = _disp?.duracaoMin ?? 0;
    return doProf > 0 ? doProf : kDuracaoPadraoMin;
  }

  /// Valida os campos da OS (espelha `validateOSInlineForm`: serviço + data + valor).
  /// Atualiza os erros exibidos e retorna `true` se está tudo válido.
  bool validate() {
    final errs = <String, String>{};
    if (_servicoId.isEmpty) errs['servico'] = 'Selecione um serviço';
    // Datas no passado são permitidas (registrar OS históricas / backfill).
    if (_dataDate.isEmpty) {
      errs['data'] = 'Data é obrigatória';
    }
    final valor = double.tryParse(_valor.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) errs['valor'] = 'Informe o valor';
    setState(() {
      _errs
        ..clear()
        ..addAll(errs);
    });
    return errs.isEmpty;
  }

  @override
  void dispose() {
    _tipoServico.dispose();
    _valor.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  static String _numText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

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

  /// Grupo do filtro mudou: limpa o serviço se ele já não pertencer ao novo grupo.
  void _onGrupo(Grupo? g, List<ServicoPB> servicos) {
    setState(() {
      _grupoFiltro = g;
      if (g != null && _servicoId.isNotEmpty) {
        final cur = _servicoAtual(servicos);
        if (cur?.grupo != null && cur!.grupo != g) _servicoId = '';
      }
    });
  }

  /// Serviço mudou: sempre prefila nome + valor (espelha `onOSServicoChange`).
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

  void _onProfissional(String v) {
    setState(() => _profissionalId = v);
    _fetchDisp();
    _fetchOcupados();
  }

  /// Prefilla duração com a do profissional enquanto o usuário não mexeu (D9).
  void _prefillDuracao() {
    if (_duracaoTocada) return;
    final doProf = _disp?.duracaoMin ?? 0;
    final nova = doProf > 0 ? doProf : kDuracaoPadraoMin;
    if (nova == _duracaoMin) return;
    setState(() => _duracaoMin = nova);
  }

  /// Limites [start, end) do dia [date] em string UTC do PB (BRT centralizado).
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

  Future<void> _fetchDisp() async {
    final prof = _profissionalId;
    if (prof.isEmpty) {
      setState(() {
        _disp = null;
        _dispState = _DispState.idle;
        _ocupados = const [];
      });
      _prefillDuracao();
      return;
    }
    final seq = ++_dispSeq;
    setState(() => _dispState = _DispState.loading);
    try {
      final res = await ref
          .read(disponibilidadeRepositoryProvider)
          .list(
            page: 1,
            perPage: 1,
            filter: disponibilidadeDoProfissionalFilter(prof),
          );
      if (!mounted || seq != _dispSeq) return;
      setState(() {
        _disp = res.items.isEmpty ? null : res.items.first;
        _dispState = _DispState.loaded;
      });
      _prefillDuracao();
      _autoSelectSlot();
    } catch (_) {
      if (!mounted || seq != _dispSeq) return;
      setState(() {
        _disp = null;
        _dispState = _DispState.error;
      });
    }
  }

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
      final times = <String>[for (final o in res.items) formatTime(o.dataHora)]
        ..removeWhere((t) => t == '—');
      setState(() {
        _ocupados = times;
        _ocupadosLoading = false;
      });
      _autoSelectSlot();
    } catch (_) {
      if (!mounted || seq != _ocupSeq) return;
      setState(() {
        _ocupados = const [];
        _ocupadosLoading = false;
      });
    }
  }

  ({bool loading, bool slotMode, bool diaAtende, List<String> slots})
  _slotState() {
    final attempt = _profissionalId.isNotEmpty;
    final loading =
        attempt &&
        (_dispState == _DispState.loading ||
            (_dispState == _DispState.loaded &&
                _disp != null &&
                _ocupadosLoading));
    final slotMode =
        attempt && _dispState == _DispState.loaded && _disp != null;
    if (!slotMode) {
      return (
        loading: loading,
        slotMode: false,
        diaAtende: true,
        slots: const [],
      );
    }
    final day = computeOSDaySlots(
      disp: _disp!,
      date: _dataDate,
      ocupados: _ocupados,
    );
    return (
      loading: loading,
      slotMode: true,
      diaAtende: day.diaAtende,
      slots: day.slots,
    );
  }

  void _autoSelectSlot() {
    final s = _slotState();
    if (!s.slotMode || s.loading || s.slots.isEmpty) return;
    final current = '$_horaH:$_horaM';
    if (s.slots.contains(current)) return;
    final first = s.slots.first.split(':');
    setState(() {
      _horaH = first[0];
      _horaM = first[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final lookups = ref.watch(ordensLookupsProvider);
    return lookups.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: ClxSpace.x5),
        child: Center(child: Spinner(size: 20)),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: ClxSpace.x2),
        child: ErrorBanner(
          message: 'Não foi possível carregar serviços/profissionais.',
          onRetry: () => ref.invalidate(ordensLookupsProvider),
        ),
      ),
      data: (lk) => _dataForm(clx, lk),
    );
  }

  Widget _dataForm(CleanoxColors clx, dynamic lk) {
    // Cascata Categoria → Grupo → Serviço (mesmo cálculo do OSFormSection.tsx).
    final servicos = lk.servicos as List<ServicoPB>;
    final categorias = <Categoria>[
      for (final c in <Categoria>{
        for (final s in servicos)
          if (s.categoria != null) s.categoria!,
      })
        c,
    ];
    final grupos = <Grupo>[
      for (final g in <Grupo>{
        for (final s in servicos)
          if (s.grupo != null &&
              (_catFiltro == null || s.categoria == _catFiltro))
            s.grupo!,
      })
        g,
    ];
    final servicosFiltrados = [
      for (final s in servicos)
        if ((_catFiltro == null || s.categoria == _catFiltro) &&
            (_grupoFiltro == null || s.grupo == _grupoFiltro))
          s,
    ];
    final servicoValue = servicosFiltrados.any((s) => s.id == _servicoId)
        ? _servicoId
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Categoria (filtro cascata).
        if (categorias.isNotEmpty) ...[
          _label('Categoria'),
          DropdownButtonFormField<String>(
            key: ValueKey('os-inline-cat-${_catFiltro?.wire ?? ''}'),
            initialValue: _catFiltro?.wire,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text('— Todas —'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Todas —')),
              for (final c in categorias)
                DropdownMenuItem(value: c.wire, child: Text(categoriaLabel(c))),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) => _onCategoria(
                    (v == null || v.isEmpty) ? null : Categoria.values.byName(v),
                    servicos,
                  ),
          ),
          const SizedBox(height: ClxSpace.x4),
        ],

        // Grupo (filtro cascata).
        if (grupos.isNotEmpty) ...[
          _label('Grupo'),
          DropdownButtonFormField<String>(
            key: ValueKey('os-inline-grupo-${_grupoFiltro?.wire ?? ''}'),
            initialValue: _grupoFiltro?.wire,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text('— Todos —'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Todos —')),
              for (final g in grupos)
                DropdownMenuItem(value: g.wire, child: Text(grupoLabel(g))),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) => _onGrupo(
                    (v == null || v.isEmpty) ? null : Grupo.values.byName(v),
                    servicos,
                  ),
          ),
          const SizedBox(height: ClxSpace.x4),
        ],

        // Serviço (filtrado pela categoria/grupo acima).
        _label('Serviço', required: true),
        DropdownButtonFormField<String>(
          key: ValueKey('os-inline-servico-$servicoValue'),
          initialValue: servicoValue.isEmpty ? null : servicoValue,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            errorText: _errs['servico'],
          ),
          hint: const Text('— Selecionar —'),
          items: [
            const DropdownMenuItem(value: '', child: Text('— Selecionar —')),
            for (final s in servicosFiltrados)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.nome, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: !widget.enabled ? null : (v) => _onServico(v, servicos),
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
            key: const ValueKey('os-inline-profissional'),
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
            onChanged: !widget.enabled
                ? null
                : (v) => _onProfissional(v ?? ''),
          ),
          Padding(
            padding: const EdgeInsets.only(top: ClxSpace.x1),
            child: Text(
              'Ao atribuir um profissional, o status passa para "Atribuída".',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.ink3),
            ),
          ),
          const SizedBox(height: ClxSpace.x4),

          // Data + horário.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _dateField(clx)),
              const SizedBox(width: ClxSpace.x3),
              Expanded(child: _horaField(clx)),
            ],
          ),
          const SizedBox(height: ClxSpace.x4),

          // Duração (paridade com Nova OS — pedida pelo dono quando "Gerar OS").
          _duracaoField(clx),
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
              TextSpan(text: ' *', style: TextStyle(color: clx.error)),
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
            enabled: widget.enabled,
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

  /// Duração da OS — prefilada (visível) com a do profissional (D9).
  Widget _duracaoField(CleanoxColors clx) {
    final efetiva = duracaoMin;
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
          key: ValueKey('os-inline-duracao-$efetiva'),
          initialValue: efetiva,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final min in opcoes)
              DropdownMenuItem(value: min, child: Text(labelDuracao(min))),
          ],
          onChanged: !widget.enabled
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
              key: const ValueKey('os-inline-duracao-prefill'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: clx.ink3),
            ),
          ),
      ],
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
          onTap: widget.enabled ? _pickDate : null,
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

  Widget _horaField(CleanoxColors clx) {
    final s = _slotState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Hora', required: true),
        if (s.loading)
          Padding(
            key: const ValueKey('os-inline-hora-loading'),
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
            child: Row(
              children: [
                const Spinner(size: 14),
                const SizedBox(width: ClxSpace.x2),
                Text(
                  'Carregando horários…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          )
        else if (s.slotMode && !s.diaAtende)
          Padding(
            key: const ValueKey('os-inline-hora-dia-inativo'),
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
            child: Text(
              'Profissional não atende neste dia',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (s.slotMode && s.slots.isEmpty)
          Padding(
            key: const ValueKey('os-inline-hora-sem-slots'),
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
            child: Text(
              'Sem horários disponíveis nesta data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
            ),
          )
        else if (s.slotMode)
          _slotDropdowns(s.slots)
        else
          _freeDropdowns(),
      ],
    );
  }

  Widget _slotDropdowns(List<String> slots) {
    final validHours = <String>[
      for (final h in {for (final t in slots) t.split(':')[0]}) h,
    ];
    final selectedHour = validHours.contains(_horaH)
        ? _horaH
        : (validHours.isEmpty ? _horaH : validHours.first);
    final validMins = [
      for (final t in slots)
        if (t.split(':')[0] == selectedHour) t.split(':')[1],
    ];
    final selectedMin = validMins.contains(_horaM)
        ? _horaM
        : (validMins.isEmpty ? _horaM : validMins.first);
    return Row(
      key: const ValueKey('os-inline-hora-slots'),
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const ValueKey('os-inline-hora-h'),
            initialValue: selectedHour,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final h in validHours)
                DropdownMenuItem(value: h, child: Text('${h}h')),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _horaH = v;
                      final firstForHour = slots.firstWhere(
                        (t) => t.startsWith('$v:'),
                        orElse: () => '$v:$_horaM',
                      );
                      _horaM = firstForHour.split(':')[1];
                    });
                  },
          ),
        ),
        const SizedBox(width: ClxSpace.x2),
        SizedBox(
          width: 80,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('os-inline-hora-m'),
            initialValue: selectedMin,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final m in validMins)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) => setState(() => _horaM = v ?? _horaM),
          ),
        ),
      ],
    );
  }

  Widget _freeDropdowns() {
    return Row(
      key: const ValueKey('os-inline-hora-livre'),
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _horaH,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(
                  value: h.toString().padLeft(2, '0'),
                  child: Text('${h.toString().padLeft(2, '0')}h'),
                ),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) => setState(() => _horaH = v ?? '08'),
          ),
        ),
        const SizedBox(width: ClxSpace.x2),
        SizedBox(
          width: 80,
          child: DropdownButtonFormField<String>(
            initialValue: _kMinutes.contains(_horaM) ? _horaM : '00',
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final m in _kMinutes)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) => setState(() => _horaM = v ?? '00'),
          ),
        ),
      ],
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
    // Piso amplo: permite lançar OS de atendimentos passados (backfill operacional).
    final first = DateTime(2020);
    if (initial.isBefore(first)) initial = first;
    final last = DateTime(now.year + 2);
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _dataDate =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
        _errs.remove('data');
      });
      _fetchOcupados();
    }
  }

  static String _brDate(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }
}
