/// checklist_execucao.dart — Checklist EXECUTÁVEL da OS (marcável pelo profissional).
///
/// Widget GENÉRICO (dono: Time B, reusável pelo Painel): recebe a lista de
/// [ChecklistExecItem] + `onChange` (controlado) + `concluidoPor`. Porte de
/// `components/os/ChecklistExecucao.tsx`. Cada item alterna pendente↔concluído
/// (gravando `concluidoEm`/`concluidoPor`) e aceita observação inline. A
/// PERSISTÊNCIA (auto-save) é do pai — este widget só emite a nova lista.
library;

import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../core/formatters/formatters.dart';
import '../core/models/os_execucao.dart';

class ChecklistExecucao extends StatefulWidget {
  const ChecklistExecucao({
    super.key,
    required this.items,
    required this.onChange,
    this.concluidoPor = 'Profissional',
    this.nowIso,
  });

  final List<ChecklistExecItem> items;
  final ValueChanged<List<ChecklistExecItem>> onChange;

  /// Nome gravado em `concluidoPor` ao marcar um item.
  final String concluidoPor;

  /// Injeta o "agora" ISO ao concluir um item (default: DateTime.now()).
  /// Existe para tornar o toggle testável de forma determinística.
  final String Function()? nowIso;

  @override
  State<ChecklistExecucao> createState() => _ChecklistExecucaoState();
}

class _ChecklistExecucaoState extends State<ChecklistExecucao> {
  final Set<String> _openObs = {};

  String _now() =>
      widget.nowIso?.call() ?? DateTime.now().toUtc().toIso8601String();

  void _toggle(ChecklistExecItem item) {
    final next = widget.items.map((it) {
      if (it.id != item.id) return it;
      if (it.concluido) {
        return it.copyWith(
          status: ChecklistExecStatus.pendente,
          concluidoEm: null,
          concluidoPor: null,
        );
      }
      return it.copyWith(
        status: ChecklistExecStatus.concluido,
        concluidoEm: _now(),
        concluidoPor: widget.concluidoPor,
      );
    }).toList();
    widget.onChange(next);
  }

  void _setObs(ChecklistExecItem item, String texto) {
    final trimmed = texto.trim();
    final next = widget.items
        .map(
          (it) => it.id == item.id
              ? it.copyWith(observacao: trimmed.isEmpty ? null : texto)
              : it,
        )
        .toList();
    widget.onChange(next);
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final items = widget.items;
    final total = items.length;
    final done = items.where((i) => i.concluido).length;
    final pct = total == 0 ? 0.0 : done / total;

    return ClxCard(
      padding: const EdgeInsets.all(ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Checklist de execução',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ClxChip(
                label: '$done de $total concluídos',
                color: done == total && total > 0 ? clx.success : clx.primary,
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Column(
                children: [
                  Text(
                    'Checklist vazio',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: clx.ink2),
                  ),
                  const SizedBox(height: ClxSpace.x1),
                  Text(
                    'Este serviço não tem itens de checklist configurados.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                  ),
                ],
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: ClxRadii.rPill,
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: clx.bg2,
                valueColor: AlwaysStoppedAnimation<Color>(clx.success),
              ),
            ),
            const SizedBox(height: ClxSpace.x3),
            for (final it in items) ...[
              _ChecklistTile(
                item: it,
                obsOpen: _openObs.contains(it.id),
                onToggle: () => _toggle(it),
                onToggleObs: () => setState(() {
                  if (!_openObs.add(it.id)) _openObs.remove(it.id);
                }),
                onObsChanged: (v) => _setObs(it, v),
              ),
              const SizedBox(height: ClxSpace.x2),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.item,
    required this.obsOpen,
    required this.onToggle,
    required this.onToggleObs,
    required this.onObsChanged,
  });

  final ChecklistExecItem item;
  final bool obsOpen;
  final VoidCallback onToggle;
  final VoidCallback onToggleObs;
  final ValueChanged<String> onObsChanged;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final concluido = item.concluido;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: concluido ? clx.success.withValues(alpha: 0.25) : clx.line,
        ),
        borderRadius: ClxRadii.rLg,
        color: concluido ? clx.successBg : clx.bg2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x3,
        vertical: ClxSpace.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Caixa de marcação (toque mínimo 48, alvo maior que o
              // quadrado visual de 22dp — Fitts' Law).
              Semantics(
                checked: concluido,
                label: item.titulo,
                child: SizedBox(
                  key: ValueKey('checklist-toggle-${item.id}'),
                  width: ClxLayout.minTouchTarget,
                  height: ClxLayout.minTouchTarget,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onToggle,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: AnimatedContainer(
                          duration: ClxMotion.shortDuration,
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: concluido ? clx.success : Colors.transparent,
                            borderRadius: ClxRadii.rMd,
                            border: Border.all(
                              color: concluido ? clx.success : clx.line2,
                              width: 2,
                            ),
                          ),
                          child: concluido
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: clx.onPrimary,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: ClxSpace.x2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: ClxSpace.x2,
                        children: [
                          Text(
                            item.titulo,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: clx.ink,
                                  decoration: concluido
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          if (item.obrigatorio && !concluido)
                            ClxChip(
                              label: 'Obrigatório',
                              color: clx.error,
                              dense: true,
                            ),
                        ],
                      ),
                      if (concluido && (item.concluidoEm ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: clx.primary2,
                              ),
                              const SizedBox(width: ClxSpace.x1),
                              Flexible(
                                child: Text(
                                  '${item.concluidoPor != null ? '${item.concluidoPor} · ' : ''}'
                                  '${formatDateTime(item.concluidoEm!)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: clx.primary2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if ((item.observacao ?? '').isNotEmpty && !obsOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: ClxSpace.x1),
                          child: Text(
                            '“${item.observacao}”',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: clx.ink2,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: (item.observacao ?? '').isNotEmpty
                    ? 'Editar observação'
                    : 'Adicionar observação',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: (item.observacao ?? '').isNotEmpty
                      ? clx.accent
                      : clx.ink3,
                ),
                onPressed: onToggleObs,
              ),
            ],
          ),
          if (obsOpen)
            Padding(
              padding: const EdgeInsets.only(
                top: ClxSpace.x2,
                bottom: ClxSpace.x2,
              ),
              child: TextFormField(
                initialValue: item.observacao ?? '',
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                onChanged: onObsChanged,
                decoration: const InputDecoration(
                  hintText: 'Observação sobre este item (opcional)…',
                  isDense: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
