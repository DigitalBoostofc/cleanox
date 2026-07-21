/// fin_objetivos_screen.dart — CRUD de metas de caixa (fin_objetivos).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_form_kit.dart';
import 'fin_providers.dart';
import 'ui/fin_ui.dart';

class FinObjetivosScreen extends ConsumerWidget {
  const FinObjetivosScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    FinObjetivo? editing,
  }) async {
    final ok = await showFinModal<bool>(
      context,
      _ObjetivoForm(editing: editing),
    );
    if (ok == true) {
      ref.invalidate(finObjetivosProvider);
      if (context.mounted) {
        showClxToast(
          context,
          editing == null ? 'Objetivo criado.' : 'Objetivo atualizado.',
          type: ToastType.success,
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FinObjetivo o,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir objetivo'),
        content: Text('Excluir "${o.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.clx.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(financeiroRepositoryProvider).deleteObjetivo(o.id);
      ref.invalidate(finObjetivosProvider);
      if (context.mounted) {
        showClxToast(context, 'Objetivo excluído.', type: ToastType.success);
      }
    } catch (_) {
      if (context.mounted) {
        showClxToast(
          context,
          'Não foi possível excluir.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final async = ref.watch(finObjetivosProvider);

    return ColoredBox(
      color: clx.bg2,
      child: async.when(
        loading: () => const Center(child: Spinner(size: 28)),
        error: (e, _) => Center(
          child: ErrorBanner(
            message: finErrorMessage(e, fallback: 'Erro ao carregar objetivos.'),
            onRetry: () => ref.invalidate(finObjetivosProvider),
          ),
        ),
        data: (list) {
          final ativos = list.where((o) => o.ativo).toList();
          final inativos = list.where((o) => !o.ativo).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Objetivos',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openForm(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo'),
                  ),
                ],
              ),
              const SizedBox(height: ClxSpace.x2),
              Text(
                'Metas de caixa da operação',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: clx.ink3,
                    ),
              ),
              const SizedBox(height: ClxSpace.x5),
              if (list.isEmpty)
                FinEmptyCta(
                  icon: Icons.track_changes_outlined,
                  message: 'Opa! Você ainda não possui objetivos definidos.',
                  hint: 'Melhore o controle financeiro da operação!',
                  ctaLabel: 'Definir meus objetivos',
                  onCta: () => _openForm(context, ref),
                )
              else ...[
                for (final o in ativos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ObjetivoCard(
                      o: o,
                      onEdit: () => _openForm(context, ref, editing: o),
                      onDelete: () => _delete(context, ref, o),
                      onAddValor: () => _addValor(context, ref, o),
                    ),
                  ),
                if (inativos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Inativos',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: clx.ink3,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final o in inativos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ObjetivoCard(
                        o: o,
                        onEdit: () => _openForm(context, ref, editing: o),
                        onDelete: () => _delete(context, ref, o),
                        onAddValor: () => _addValor(context, ref, o),
                      ),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _addValor(
    BuildContext context,
    WidgetRef ref,
    FinObjetivo o,
  ) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar progresso'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Valor a somar (R\$)',
            hintText: '0,00',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Somar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final v = parseMoedaBr(ctrl.text);
    if (v == null || v <= 0) {
      if (context.mounted) {
        showClxToast(context, 'Valor inválido.', type: ToastType.warning);
      }
      return;
    }
    try {
      await ref.read(financeiroRepositoryProvider).updateObjetivo(o.id, {
        'valor_atual': o.valorAtual + v,
      });
      ref.invalidate(finObjetivosProvider);
      if (context.mounted) {
        showClxToast(context, 'Progresso atualizado.', type: ToastType.success);
      }
    } catch (_) {
      if (context.mounted) {
        showClxToast(
          context,
          'Não foi possível atualizar.',
          type: ToastType.error,
        );
      }
    }
  }
}

class _ObjetivoCard extends StatelessWidget {
  const _ObjetivoCard({
    required this.o,
    required this.onEdit,
    required this.onDelete,
    required this.onAddValor,
  });

  final FinObjetivo o;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddValor;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final pct = o.progresso;
    final done = pct >= 1;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.track_changes_outlined,
                color: done ? clx.finIncome : clx.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  o.nome,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: o.ativo ? clx.ink : clx.ink3,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'add':
                      onAddValor();
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'add', child: Text('Somar valor')),
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                formatCurrency(o.valorAtual),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: done ? clx.finIncome : clx.ink,
                ),
              ),
              Text(
                '  de  ${formatCurrency(o.metaValor)}',
                style: TextStyle(color: clx.ink3),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: done ? clx.finIncome : clx.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: ClxRadii.rPill,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: clx.line2,
              color: done ? clx.finIncome : clx.primary,
            ),
          ),
          if (o.dataLimite != null && o.dataLimite!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Prazo: ${formatDateOnlyBr(o.dataLimite!)}',
              style: TextStyle(color: clx.ink3, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObjetivoForm extends ConsumerStatefulWidget {
  const _ObjetivoForm({this.editing});
  final FinObjetivo? editing;

  @override
  ConsumerState<_ObjetivoForm> createState() => _ObjetivoFormState();
}

class _ObjetivoFormState extends ConsumerState<_ObjetivoForm> {
  final _nome = TextEditingController();
  final _meta = TextEditingController();
  final _atual = TextEditingController();
  final _obs = TextEditingController();
  DateTime? _prazo;
  bool _ativo = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nome.text = e.nome;
      _meta.text = e.metaValor > 0 ? e.metaValor.toStringAsFixed(2).replaceAll('.', ',') : '';
      _atual.text =
          e.valorAtual > 0 ? e.valorAtual.toStringAsFixed(2).replaceAll('.', ',') : '';
      _obs.text = e.observacao ?? '';
      _ativo = e.ativo;
      if (e.dataLimite != null && e.dataLimite!.length >= 10) {
        _prazo = DateTime.tryParse(e.dataLimite!.substring(0, 10));
      }
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _meta.dispose();
    _atual.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nome = _nome.text.trim();
    final meta = parseMoedaBr(_meta.text);
    final atual = parseMoedaBr(_atual.text) ?? 0;
    if (nome.isEmpty) {
      showClxToast(context, 'Informe o nome.', type: ToastType.warning);
      return;
    }
    if (meta == null || meta <= 0) {
      showClxToast(context, 'Informe a meta (R\$).', type: ToastType.warning);
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'nome': nome,
      'meta_valor': meta,
      'valor_atual': atual < 0 ? 0 : atual,
      'ativo': _ativo,
      'observacao': _obs.text.trim(),
      'data_limite': _prazo == null
          ? ''
          : '${_prazo!.year.toString().padLeft(4, '0')}-'
              '${_prazo!.month.toString().padLeft(2, '0')}-'
              '${_prazo!.day.toString().padLeft(2, '0')}',
    };
    try {
      final repo = ref.read(financeiroRepositoryProvider);
      if (widget.editing == null) {
        await repo.createObjetivo(body);
      } else {
        await repo.updateObjetivo(widget.editing!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showClxToast(
          context,
          finErrorMessage(e, fallback: 'Não foi possível salvar.'),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return FinModalScaffold(
      title: widget.editing == null ? 'Novo objetivo' : 'Editar objetivo',
      onSave: _saving ? () {} : _save,
      saving: _saving,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nome,
            decoration: const InputDecoration(labelText: 'Nome da meta'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _meta,
            decoration: const InputDecoration(
              labelText: 'Valor meta (R\$)',
              hintText: '0,00',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _atual,
            decoration: const InputDecoration(
              labelText: 'Valor atual (R\$)',
              hintText: '0,00',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prazo (opcional)'),
            subtitle: Text(
              _prazo == null
                  ? 'Sem data'
                  : '${_prazo!.day.toString().padLeft(2, '0')}/'
                      '${_prazo!.month.toString().padLeft(2, '0')}/'
                      '${_prazo!.year}',
              style: TextStyle(color: clx.ink3),
            ),
            trailing: Icon(Icons.calendar_today_outlined, color: clx.primary),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _prazo ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) setState(() => _prazo = picked);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativo'),
            value: _ativo,
            onChanged: (v) => setState(() => _ativo = v),
          ),
          TextField(
            controller: _obs,
            decoration: const InputDecoration(labelText: 'Observação'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
