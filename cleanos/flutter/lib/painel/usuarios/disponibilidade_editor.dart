/// disponibilidade_editor.dart — Editor da disponibilidade semanal de um profissional.
///
/// Espelha o `DisponibilidadeModal` de `Agenda.tsx`: duração do slot (min) + 7 dias
/// (Dom…Sáb) com toggle ativo e janela início/fim. Faz UPSERT via
/// `DisponibilidadeRepository` (interface congelada): procura o registro do
/// profissional com `list(filter, perPage: 1)` e cria/atualiza. Todos os estados.
///
/// A disponibilidade alimenta a Agenda (grade de slots) — os horários são 'HH:MM' em
/// BRT (relógio de parede), sem conta de fuso solta.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/user.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';

const List<String> _kDiasSemana = [
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

/// Abre o editor de disponibilidade do [profissional]. Resolve `true` se salvou.
Future<bool?> showDisponibilidadeEditor(
  BuildContext context, {
  required User profissional,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: DisponibilidadeEditor(profissional: profissional),
      ),
    ),
  );
}

class DisponibilidadeEditor extends ConsumerStatefulWidget {
  const DisponibilidadeEditor({super.key, required this.profissional});

  final User profissional;

  @override
  ConsumerState<DisponibilidadeEditor> createState() =>
      _DisponibilidadeEditorState();
}

class _DisponibilidadeEditorState extends ConsumerState<DisponibilidadeEditor> {
  List<DisponibilidadeDiaPB> _dias = List.generate(
    7,
    (_) =>
        const DisponibilidadeDiaPB(ativo: false, inicio: '08:00', fim: '18:00'),
  );
  int _duracaoMin = 60;
  // Campo de duração em texto livre (espelha o `<input type=number>` do React —
  // qualquer valor ≥ 15, não uma lista fechada de opções).
  final TextEditingController _duracaoCtrl = TextEditingController(text: '60');
  String? _existingId;

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;
  bool _saveOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _duracaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _saveOk = false;
    });
    try {
      final res = await ref
          .read(disponibilidadeRepositoryProvider)
          .list(
            page: 1,
            perPage: 1,
            filter: disponibilidadeDoProfissionalFilter(widget.profissional.id),
          );
      if (!mounted) return;
      final existing = res.items.isEmpty ? null : res.items.first;
      setState(() {
        if (existing != null) {
          _existingId = existing.id;
          _duracaoMin = existing.duracaoMin <= 0 ? 60 : existing.duracaoMin;
          _dias = _normalizeDias(existing.dias);
        } else {
          _existingId = null;
          _duracaoMin = 60;
        }
        _duracaoCtrl.text = '$_duracaoMin';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Não foi possível carregar a disponibilidade.';
        });
      }
    }
  }

  /// Garante exatamente 7 dias (preenche faltantes com o default).
  static List<DisponibilidadeDiaPB> _normalizeDias(
    List<DisponibilidadeDiaPB> src,
  ) {
    return List.generate(7, (i) {
      if (i < src.length) {
        final d = src[i];
        return DisponibilidadeDiaPB(
          ativo: d.ativo,
          inicio: d.inicio.isEmpty ? '08:00' : d.inicio,
          fim: d.fim.isEmpty ? '18:00' : d.fim,
        );
      }
      return const DisponibilidadeDiaPB(
        ativo: false,
        inicio: '08:00',
        fim: '18:00',
      );
    });
  }

  void _updateDia(int idx, DisponibilidadeDiaPB dia) {
    setState(() {
      _dias = [
        for (var i = 0; i < _dias.length; i++)
          if (i == idx) dia else _dias[i],
      ];
      _saveOk = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
      _saveOk = false;
    });
    final payload = <String, dynamic>{
      'profissional': widget.profissional.id,
      'duracao_min': _duracaoMin,
      'dias': [
        for (final d in _dias)
          {'ativo': d.ativo, 'inicio': d.inicio, 'fim': d.fim},
      ],
    };
    try {
      final repo = ref.read(disponibilidadeRepositoryProvider);
      if (_existingId != null) {
        await repo.update(_existingId!, payload);
      } else {
        final created = await repo.create(payload);
        _existingId = created.id;
      }
      if (mounted) setState(() => _saveOk = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = 'Não foi possível salvar a disponibilidade.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Disponibilidade',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.profissional.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(_saveOk),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Flexible(child: _body(context, clx)),
        Divider(height: 1, color: clx.line),
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClxButton(
                label: 'Fechar',
                variant: ClxButtonVariant.ghost,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(_saveOk),
              ),
              const SizedBox(width: ClxSpace.x3),
              ClxButton(
                label: 'Salvar',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: (_saving || _loading || _loadError != null)
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, CleanoxColors clx) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(ClxSpace.x10),
        child: Center(child: Spinner(size: 24)),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(ClxSpace.x5),
        child: ErrorBanner(message: _loadError!, onRetry: _load),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ClxSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saveError != null) ...[
            ErrorBanner(message: _saveError!),
            const SizedBox(height: ClxSpace.x4),
          ],
          if (_saveOk) ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: clx.success),
                const SizedBox(width: ClxSpace.x2),
                Text(
                  'Disponibilidade salva.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: clx.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x4),
          ],
          // Duração PADRÃO do serviço deste profissional.
          //
          // O rótulo antigo era "Duração do serviço (slot)" — herança da agenda
          // velha, em que este número GERAVA os horários fixos de um dropdown.
          // Esses slots não existem mais (a hora agora é digitada livremente),
          // então "slot" descrevia uma mecânica morta e confundia o dono.
          //
          // O campo continua valendo, por dois motivos (ver `duracaoEfetivaMin`):
          //   1. prefila a Duração de toda OS nova deste profissional (D9);
          //   2. é o FALLBACK da agenda para OS sem duração própria — ou seja,
          //      toda OS anterior à migration 27. Zerar isso encolheria essas
          //      OS pra 60 min na grade.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duração padrão do serviço',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: clx.ink2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x1),
                    Text(
                      'Preenche a duração das novas OS deste profissional. '
                      'Dá pra alterar em cada OS.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _duracaoCtrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 'min',
                  ),
                  onChanged: (v) => setState(() {
                    final parsed = int.tryParse(v);
                    // Mínimo 15 (espelha `min=15` do React); vazio mantém default.
                    _duracaoMin = parsed == null ? 60 : (parsed < 15 ? 15 : parsed);
                    _saveOk = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x4),
          for (var i = 0; i < 7; i++) ...[
            _DiaRow(
              nome: _kDiasSemana[i],
              dia: _dias[i],
              enabled: !_saving,
              onChanged: (d) => _updateDia(i, d),
            ),
            const SizedBox(height: ClxSpace.x2),
          ],
        ],
      ),
    );
  }
}

class _DiaRow extends StatelessWidget {
  const _DiaRow({
    required this.nome,
    required this.dia,
    required this.onChanged,
    required this.enabled,
  });

  final String nome;
  final DisponibilidadeDiaPB dia;
  final ValueChanged<DisponibilidadeDiaPB> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x3,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        color: dia.ativo ? clx.bg2 : Colors.transparent,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Row(
              children: [
                Checkbox(
                  value: dia.ativo,
                  activeColor: clx.primary,
                  onChanged: enabled
                      ? (v) => onChanged(
                          DisponibilidadeDiaPB(
                            ativo: v ?? false,
                            inicio: dia.inicio,
                            fim: dia.fim,
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (dia.ativo)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      value: dia.inicio,
                      enabled: enabled,
                      onChanged: (t) => onChanged(
                        DisponibilidadeDiaPB(
                          ativo: true,
                          inicio: t,
                          fim: dia.fim,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClxSpace.x2,
                    ),
                    child: Text(
                      'até',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ),
                  Expanded(
                    child: _TimeField(
                      value: dia.fim,
                      enabled: enabled,
                      onChanged: (t) => onChanged(
                        DisponibilidadeDiaPB(
                          ativo: true,
                          inicio: dia.inicio,
                          fim: t,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Text(
                'Indisponível',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campo de horário 'HH:MM' via `showTimePicker` (MD3, acessível).
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String value; // 'HH:MM'
  final ValueChanged<String> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final parts = value.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      onChanged(
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: ClxRadii.rMd,
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: ClxSpace.x3,
            vertical: ClxSpace.x2,
          ),
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink)),
      ),
    );
  }
}
