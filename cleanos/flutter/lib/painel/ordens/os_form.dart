/// os_form.dart — Formulário de criar/editar Ordem de Serviço (Painel).
///
/// Espelha `OrdensServico.tsx` + `OSFormSection.tsx`: seleção de cliente (busca NO
/// SERVIDOR — sem `getFullList`), serviço (prefila nome+valor), profissional
/// (define status atribuída/agendada), data + slot de horário (HH:MM), valor e
/// observações. Cria/atribui via `OrdensRepository.create`/`update`.
///
/// Mostrado via [showOSForm] — Dialog centrado (Painel desktop-first). Resolve
/// `true` quando salvou (o caller recarrega a lista).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'ordens_controller.dart';

Future<bool?> showOSForm(BuildContext context, {OrdemServico? editing}) {
  return showDialog<bool>(
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

const List<String> _kMinutes = ['00', '15', '30', '45'];

/// Estágio da busca de disponibilidade do profissional selecionado.
enum _DispState { idle, loading, loaded, error }

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

  String _clienteId = '';
  String _clienteLabel = '';
  String _servicoId = '';
  String _profissionalId = '';
  String _dataDate = ''; // yyyy-MM-dd (BRT)
  String _horaH = '08';
  String _horaM = '00';

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  // Disponibilidade real do profissional selecionado (seletor de slot).
  Disponibilidade? _disp;
  _DispState _dispState = _DispState.idle;
  List<String> _ocupados = const [];
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
      _clienteLabel = os.nomeCurto;
      _servicoId = os.servico ?? '';
      _tipoServico.text = os.tipoServicoNome ?? '';
      _valor.text = os.valorServico == null ? '' : _numText(os.valorServico!);
      _profissionalId = os.profissional ?? '';
      _observacoes.text = os.observacoes ?? '';
      final local = pbDateToLocalInput(os.dataHora); // yyyy-MM-ddTHH:mm
      if (local.isNotEmpty) {
        final parts = local.split('T');
        _dataDate = parts[0];
        final hm = parts[1].split(':');
        _horaH = hm[0].padLeft(2, '0');
        _horaM = _snapMinute(hm.length > 1 ? hm[1] : '00');
      }
      // Já editando com profissional atribuído → carrega disponibilidade + ocupação.
      if (_profissionalId.isNotEmpty) {
        _fetchDisp();
        _fetchOcupados();
      }
    }
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

  static String _snapMinute(String raw) {
    final m = int.tryParse(raw) ?? 0;
    final snapped = (m / 15).round() * 15;
    return (snapped == 60 ? 0 : snapped).toString().padLeft(2, '0');
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

  /// Busca a disponibilidade semanal do profissional selecionado.
  Future<void> _fetchDisp() async {
    final prof = _profissionalId;
    if (prof.isEmpty) {
      setState(() {
        _disp = null;
        _dispState = _DispState.idle;
        _ocupados = const [];
      });
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
      _autoSelectSlot();
    } catch (_) {
      if (!mounted || seq != _dispSeq) return;
      setState(() {
        _disp = null;
        _dispState = _DispState.error;
      });
    }
  }

  /// Busca as OS que ocupam a agenda do profissional no dia selecionado.
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
      final times = <String>[
        for (final o in res.items)
          if (o.id != editingId) formatTime(o.dataHora),
      ]..removeWhere((t) => t == '—');
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

  /// Estado do seletor de horário derivado (espelha OSFormSection.tsx).
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

  /// Ao (re)calcular slots, se o horário atual não é mais válido, seleciona o
  /// primeiro slot livre (espelha o auto-select do React).
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

  Map<String, String> _validate() {
    final errs = <String, String>{};
    if (_clienteId.isEmpty) errs['cliente'] = 'Selecione um cliente';
    if (_dataDate.isEmpty) {
      errs['data'] = 'Data é obrigatória';
    } else if (_dataDate.compareTo(todayLocalDate()) < 0) {
      errs['data'] = 'A data não pode ser no passado';
    }
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
    setState(() {
      _saving = true;
      _saveError = null;
      _errs.clear();
    });

    final hasProf = _profissionalId.isNotEmpty;
    final valor = double.parse(_valor.text.trim().replaceAll(',', '.'));
    final payload = <String, dynamic>{
      'cliente': _clienteId,
      'servico': _servicoId.isEmpty ? null : _servicoId,
      'tipo_servico_nome': _tipoServico.text.trim(),
      'data_hora': localInputToPBDate('${_dataDate}T$_horaH:$_horaM'),
      'valor_servico': valor,
      'profissional': hasProf ? _profissionalId : null,
      'observacoes': _observacoes.text.trim(),
    };

    // Transições de status (paridade com o React).
    final editing = widget.editing;
    if (!_isEdit) {
      payload['status'] = hasProf
          ? OSStatus.atribuida.wire
          : OSStatus.agendada.wire;
    } else if (editing != null) {
      if (hasProf && editing.status == OSStatus.agendada) {
        payload['status'] = OSStatus.atribuida.wire;
      } else if (!hasProf && editing.status == OSStatus.atribuida) {
        payload['status'] = OSStatus.agendada.wire;
      }
    }

    try {
      final repo = ref.read(ordensRepositoryProvider);
      if (_isEdit) {
        await repo.update(editing!.id, payload);
      } else {
        await repo.create(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
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
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 18,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClxButton(
                label: 'Cancelar',
                variant: ClxButtonVariant.ghost,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: ClxSpace.x3),
              ClxButton(
                label: 'Salvar',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _form(CleanoxColors clx, OrdensLookups lk) {
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

          // Serviço.
          _label('Serviço'),
          DropdownButtonFormField<String>(
            key: const ValueKey('os-servico'),
            initialValue: _servicoId.isEmpty ? null : _servicoId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text('— Selecionar —'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Selecionar —')),
              for (final s in lk.servicos)
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
              style: TextStyle(color: clx.ink3, fontSize: 11.5),
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
          style: TextStyle(
            color: clx.ink2,
            fontSize: 13,
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
              style: TextStyle(
                color: _dataDate.isEmpty ? clx.ink3 : clx.ink,
                fontSize: 14,
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
            key: const ValueKey('os-hora-loading'),
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
            child: Row(
              children: [
                const Spinner(size: 14),
                const SizedBox(width: ClxSpace.x2),
                Text(
                  'Carregando horários…',
                  style: TextStyle(color: clx.ink3, fontSize: 13),
                ),
              ],
            ),
          )
        else if (s.slotMode && !s.diaAtende)
          Padding(
            key: const ValueKey('os-hora-dia-inativo'),
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
            child: Text(
              'Profissional não atende neste dia',
              style: TextStyle(
                color: clx.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (s.slotMode && s.slots.isEmpty)
          Padding(
            key: const ValueKey('os-hora-sem-slots'),
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
            child: Text(
              'Sem horários disponíveis nesta data',
              style: TextStyle(color: clx.ink3, fontSize: 13),
            ),
          )
        else if (s.slotMode)
          _slotDropdowns(s.slots)
        else
          _freeDropdowns(),
      ],
    );
  }

  /// Modo slot: dois dropdowns restritos aos horários LIVRES.
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
      key: const ValueKey('os-hora-slots'),
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const ValueKey('os-hora-h'),
            initialValue: selectedHour,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final h in validHours)
                DropdownMenuItem(value: h, child: Text('${h}h')),
            ],
            onChanged: _saving
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
            key: const ValueKey('os-hora-m'),
            initialValue: selectedMin,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final m in validMins)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() => _horaM = v ?? _horaM),
          ),
        ),
      ],
    );
  }

  /// Modo livre (fallback): horas 0–23 + minutos fixos. Mantido quando não há
  /// profissional, a disponibilidade falhou, ou o profissional não tem
  /// disponibilidade cadastrada — paridade com o React (override manual).
  Widget _freeDropdowns() {
    return Row(
      key: const ValueKey('os-hora-livre'),
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
            onChanged: _saving
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
            onChanged: _saving
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
                    style: TextStyle(
                      color: clx.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: opt.sub.isEmpty
                      ? null
                      : Text(
                          opt.sub,
                          style: TextStyle(color: clx.ink3, fontSize: 12),
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
              style: TextStyle(color: clx.ink3, fontSize: 13),
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
