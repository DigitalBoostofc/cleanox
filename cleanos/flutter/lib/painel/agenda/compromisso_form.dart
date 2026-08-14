/// Formulário de tarefa/compromisso da Agenda.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/agenda_compromisso.dart';
import '../data/painel_providers.dart';
import '../ordens/os_form.dart' show kDuracaoOpcoes;
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
  DateTime? _dia;
  String? _profId;
  int _duracao = 60;
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
      _profId = e.profissional;
      _duracao = e.duracaoMin;
      _recorrencia = RecorrenciaCompromisso.nenhuma;
      final utc = parsePbUtc(e.dataHora);
      if (utc != null) {
        final brt = utc.subtract(kBrtOffset);
        _dia = DateTime(brt.year, brt.month, brt.day);
        _hora.text =
            '${brt.hour.toString().padLeft(2, '0')}:${brt.minute.toString().padLeft(2, '0')}';
      }
    } else {
      final d = widget.dia ?? DateTime.now();
      _dia = DateTime(d.year, d.month, d.day);
      _profId = widget.profissionalId;
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _hora.dispose();
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
    if ((_profId ?? '').isEmpty) {
      setState(() => _erro = 'Selecione o profissional.');
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
    try {
      final repo = ref.read(agendaCompromissosRepositoryProvider);
      final editing = widget.editing;
      if (editing != null) {
        await repo.update(editing.id, {
          ...editing
              .copyWith(
                titulo: titulo,
                descricao: _descricao.text.trim(),
                profissional: _profId!,
                dataHora: localInputToPBDate(
                  inicio.subtract(kBrtOffset).toIso8601String().substring(0, 16),
                ),
                duracaoMin: _duracao,
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
            'profissional': _profId,
            'data_hora': localInputToPBDate(local),
            'duracao_min': _duracao,
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
              DropdownButtonFormField<String>(
                initialValue: _profId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Profissional'),
                items: [
                  for (final p in profs)
                    DropdownMenuItem(value: p.id, child: Text(p.displayName)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _profId = v),
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
              TextField(
                controller: _hora,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Horário (HH:MM)'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _duracao,
                decoration: const InputDecoration(labelText: 'Duração'),
                items: [
                  for (final m in kDuracaoOpcoes)
                    DropdownMenuItem(
                      value: m,
                      child: Text(m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 == 0 ? '' : m % 60}'),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _duracao = v ?? 60),
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
