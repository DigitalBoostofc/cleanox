/// Formulário de tarefa/compromisso da Agenda.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agenda/agenda_layout.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/agenda_compromisso.dart';
import '../data/painel_providers.dart';
import 'agenda_controller.dart';

Future<bool> showCompromissoForm(
  BuildContext context, {
  AgendaCompromisso? editing,
  DateTime? dia,
  String? profissionalId,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _CompromissoDialog(
      editing: editing,
      dia: dia,
      profissionalId: profissionalId,
    ),
  );
  return saved == true;
}

String _hhmmMais(String hhmm, int min) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first) ?? 9;
  final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
  var t = h * 60 + m + min;
  if (t < 15) t = 15;
  if (t >= 24 * 60) t = 24 * 60 - 15;
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

class _CompromissoDialog extends ConsumerStatefulWidget {
  const _CompromissoDialog({
    this.editing,
    this.dia,
    this.profissionalId,
  });

  final AgendaCompromisso? editing;
  final DateTime? dia;
  final String? profissionalId;

  @override
  ConsumerState<_CompromissoDialog> createState() => _CompromissoDialogState();
}

class _CompromissoDialogState extends ConsumerState<_CompromissoDialog> {
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _hora = TextEditingController(text: '09:00');
  final _horaFim = TextEditingController(text: '10:00');
  DateTime? _dia;
  final _profIds = <String>{};
  RecorrenciaCompromisso _recorrencia = RecorrenciaCompromisso.nenhuma;
  bool _saving = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titulo.text = e.titulo;
      _descricao.text = e.descricao;
      _profIds.addAll(e.profissionais);
      _recorrencia = RecorrenciaCompromisso.nenhuma;
      final utc = parsePbUtc(e.dataHora);
      if (utc != null) {
        final brt = utc.subtract(kBrtOffset);
        _dia = DateTime(brt.year, brt.month, brt.day);
        _hora.text =
            '${brt.hour.toString().padLeft(2, '0')}:${brt.minute.toString().padLeft(2, '0')}';
        _horaFim.text = _hhmmMais(_hora.text, e.duracaoMin);
      }
    } else {
      final d = widget.dia ?? DateTime.now();
      _dia = DateTime(d.year, d.month, d.day);
      final seed = (widget.profissionalId ?? '').trim();
      if (seed.isNotEmpty) _profIds.add(seed);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _hora.dispose();
    _horaFim.dispose();
    super.dispose();
  }

  DateTime? _inicioUtc() {
    final d = _dia;
    if (d == null) return null;
    final parts = _hora.text.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    String p(int n) => n.toString().padLeft(2, '0');
    final local =
        '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)}T${p(h)}:${p(m)}';
    return parsePbUtc(localInputToPBDate(local));
  }

  Future<void> _salvar() async {
    if (_saving) return;
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) {
      setState(() => _erro = 'Informe o título.');
      return;
    }
    if (_profIds.isEmpty) {
      setState(() => _erro = 'Selecione ao menos um profissional.');
      return;
    }
    final dur = duracaoEntreHorarios(_hora.text, _horaFim.text);
    if (dur < 15) {
      setState(() => _erro = 'O fim precisa ser depois do início.');
      return;
    }
    final inicio = _inicioUtc();
    if (inicio == null) {
      setState(() => _erro = 'Data ou horário inválido.');
      return;
    }
    setState(() {
      _saving = true;
      _erro = null;
    });
    final profs = _profIds.toList();
    try {
      final repo = ref.read(agendaCompromissosRepositoryProvider);
      final editing = widget.editing;
      if (editing != null) {
        await repo.update(editing.id, {
          ...editing
              .copyWith(
                titulo: titulo,
                descricao: _descricao.text.trim(),
                profissionais: profs,
                dataHora: localInputToPBDate(
                  inicio.subtract(kBrtOffset).toIso8601String().substring(0, 16),
                ),
                duracaoMin: dur,
              )
              .toBody(),
        });
      } else {
        final datas = ocorrenciasCompromisso(
          inicioUtc: inicio,
          recorrencia: _recorrencia,
        );
        final serie = _recorrencia == RecorrenciaCompromisso.nenhuma
            ? ''
            : DateTime.now().millisecondsSinceEpoch.toString();
        for (final dt in datas) {
          final brt = dt.subtract(kBrtOffset);
          String p(int n) => n.toString().padLeft(2, '0');
          final local =
              '${brt.year.toString().padLeft(4, '0')}-${p(brt.month)}-${p(brt.day)}T${p(brt.hour)}:${p(brt.minute)}';
          await repo.create({
            'titulo': titulo,
            'descricao': _descricao.text.trim(),
            'profissional': profs,
            'data_hora': localInputToPBDate(local),
            'duracao_min': dur,
            'recorrencia': _recorrencia.wire,
            'serie_id': serie,
            'status': StatusCompromisso.pendente.wire,
          });
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _erro = 'Não foi possível salvar a tarefa.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final profs = ref.watch(agendaControllerProvider).profissionais;
    return AlertDialog(
      title: Text(widget.editing == null ? 'Nova tarefa' : 'Editar tarefa'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_erro != null) ...[
                Text(_erro!, style: TextStyle(color: clx.error)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _titulo,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              Text(
                'Profissionais',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in profs)
                    FilterChip(
                      avatar: UserAvatar(user: p, radius: 10),
                      label: Text(p.displayName),
                      selected: _profIds.contains(p.id),
                      onSelected: _saving
                          ? null
                          : (on) => setState(() {
                              if (on) {
                                _profIds.add(p.id);
                              } else {
                                _profIds.remove(p.id);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dia == null
                      ? 'Data'
                      : '${_dia!.day.toString().padLeft(2, '0')}/${_dia!.month.toString().padLeft(2, '0')}/${_dia!.year}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dia ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2032),
                        );
                        if (picked != null) setState(() => _dia = picked);
                      },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hora,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Início (HH:MM)',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _horaFim,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Fim (HH:MM)',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.editing == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<RecorrenciaCompromisso>(
                  initialValue: _recorrencia,
                  decoration: const InputDecoration(labelText: 'Repetir'),
                  items: [
                    for (final r in RecorrenciaCompromisso.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(
                          () => _recorrencia =
                              v ?? RecorrenciaCompromisso.nenhuma,
                        ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _descricao,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _salvar,
          child: Text(_saving ? 'Salvando…' : 'Salvar'),
        ),
      ],
    );
  }
}
