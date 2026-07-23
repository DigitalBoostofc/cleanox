/// checklist_execucao.dart — Checklist EXECUTÁVEL da OS (marcável pelo profissional).
///
/// Widget GENÉRICO (dono: Time B, reusável pelo Painel): recebe a lista de
/// [ChecklistExecItem] + `onChange` (controlado) + `concluidoPor`. Porte de
/// `components/os/ChecklistExecucao.tsx`. Cada item alterna pendente↔concluído
/// (gravando `concluidoEm`/`concluidoPor`) e aceita observação inline. A
/// PERSISTÊNCIA (auto-save) é do pai — este widget só emite a nova lista.
///
/// Serviços extras (`adicionais`) ficam em seções separadas do checklist do
/// serviço principal: itens com [ChecklistExecItem.adicionalId] (ou legado
/// "Nome: item" casando com [adicionais]) formam blocos próprios.
library;

import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_surface_provider.dart';
import '../core/design/design.dart';
import '../core/formatters/formatters.dart';
import '../core/models/os_execucao.dart';

/// Uma seção visual do checklist (principal ou um extra).
class ChecklistSecao {
  const ChecklistSecao({
    required this.key,
    required this.titulo,
    required this.items,
    this.extra = false,
    this.valorLabel,
  });

  final String key;
  final String titulo;
  final List<ChecklistExecItem> items;
  final bool extra;

  /// Ex.: "R$ 150,00" no cabeçalho do serviço extra.
  final String? valorLabel;
}

/// Agrupa [items] em seção principal + uma por serviço extra.
///
/// Itens com [ChecklistExecItem.adicionalId] vão no extra correspondente.
/// Legado (sem `adicionalId`, título `"Nome do extra: item"`) também é
/// agrupado pelo prefixo do [ServicoAdicionalOS.nome].
List<ChecklistSecao> agruparChecklistSecoes(
  List<ChecklistExecItem> items, {
  List<ServicoAdicionalOS> adicionais = const [],
}) {
  final byAdd = <String, List<ChecklistExecItem>>{};
  final principal = <ChecklistExecItem>[];
  final knownIds = {for (final a in adicionais) a.id};
  final nomeToId = <String, String>{
    for (final a in adicionais)
      if (a.nome.trim().isNotEmpty) a.nome.trim().toLowerCase(): a.id,
  };

  for (final it in items) {
    final aid = (it.adicionalId ?? '').trim();
    if (aid.isNotEmpty) {
      byAdd.putIfAbsent(aid, () => []).add(it);
      continue;
    }
    // Legado: "Sofá 2 lugares: Fotos de antes"
    final sep = it.titulo.indexOf(': ');
    if (sep > 0) {
      final prefix = it.titulo.substring(0, sep).trim().toLowerCase();
      final matched = nomeToId[prefix];
      if (matched != null) {
        byAdd.putIfAbsent(matched, () => []).add(it);
        continue;
      }
    }
    principal.add(it);
  }

  final secoes = <ChecklistSecao>[];
  if (principal.isNotEmpty || byAdd.isEmpty) {
    secoes.add(
      ChecklistSecao(
        key: 'principal',
        titulo: 'Serviço principal',
        items: principal,
      ),
    );
  }

  // Ordem: adicionais conhecidos na ordem em que foram anexados.
  final seen = <String>{};
  for (final a in adicionais) {
    final list = byAdd[a.id];
    if (list == null || list.isEmpty) continue;
    seen.add(a.id);
    final subtotal = a.valor * a.quantidade;
    secoes.add(
      ChecklistSecao(
        key: a.id,
        titulo: a.nome.isEmpty ? 'Serviço extra' : a.nome,
        items: list,
        extra: true,
        valorLabel: subtotal > 0 ? formatCurrency(subtotal) : null,
      ),
    );
  }
  // Extras referenciados só no checklist (adicional sumiu da lista).
  for (final entry in byAdd.entries) {
    if (seen.contains(entry.key) || knownIds.contains(entry.key)) continue;
    if (entry.value.isEmpty) continue;
    secoes.add(
      ChecklistSecao(
        key: entry.key,
        titulo: 'Serviço extra',
        items: entry.value,
        extra: true,
      ),
    );
  }

  return secoes;
}

/// Título de item para exibir: remove o prefixo "Nome: " em seções de extra
/// quando o item é legado e o prefixo repete o título da seção.
String tituloChecklistExibicao(ChecklistExecItem item, {String? secaoTitulo}) {
  final t = item.titulo;
  final sep = t.indexOf(': ');
  if (sep <= 0 || secaoTitulo == null || secaoTitulo.isEmpty) return t;
  final prefix = t.substring(0, sep).trim();
  if (prefix.toLowerCase() == secaoTitulo.trim().toLowerCase()) {
    final rest = t.substring(sep + 2).trim();
    return rest.isEmpty ? t : rest;
  }
  return t;
}

/// Título “nu” (sem prefixo de serviço extra) para regras de foto.
String tituloChecklistNu(String titulo) {
  final sep = titulo.indexOf(': ');
  if (sep <= 0) return titulo.trim();
  return titulo.substring(sep + 2).trim();
}

/// Itens "Fotos de antes" / "Fotos de depois" exigem foto na própria linha
/// para **marcar** o check — não para concluir a OS.
/// Devolve a [FaseFoto] exigida, ou `null` se o item não for de evidência.
FaseFoto? faseFotoExigida(ChecklistExecItem item) =>
    faseFotoDoTituloChecklist(item.titulo);

/// Fotos vinculadas a este item do checklist (por `checklistItemId`).
List<EvidenciaFoto> fotosDoItemChecklist(
  List<EvidenciaFoto> fotos,
  String itemId,
) {
  if (itemId.isEmpty) return const [];
  return [for (final f in fotos) if (f.checklistItemId == itemId) f];
}

/// Pode marcar o item como concluído? Itens de foto exigem ≥1 evidência vinculada.
bool checklistItemPodeConcluir(
  ChecklistExecItem item,
  List<EvidenciaFoto> fotos,
) {
  final fase = faseFotoExigida(item);
  if (fase == null) return true;
  return fotosDoItemChecklist(fotos, item.id).isNotEmpty;
}

class ChecklistExecucao extends StatefulWidget {
  const ChecklistExecucao({
    super.key,
    required this.items,
    required this.onChange,
    this.concluidoPor = 'Profissional',
    this.readOnly = false,
    this.nowIso,
    this.onAddExtra,
    this.adicionais = const [],
    this.fotos = const [],
    this.onPickFotoItem,
    this.onRemoveFoto,
    this.pendingIds = const {},
    this.onBloqueioFoto,
  });

  final List<ChecklistExecItem> items;
  final ValueChanged<List<ChecklistExecItem>> onChange;

  /// Serviços extras da OS — definem seções e títulos do checklist separado.
  final List<ServicoAdicionalOS> adicionais;

  /// Evidências da OS — para gate e thumbs nos itens "Fotos de antes/depois".
  final List<EvidenciaFoto> fotos;

  /// Anexar foto no item (fase + id do item). Só itens com [faseFotoExigida].
  final void Function(ChecklistExecItem item, FaseFoto fase)? onPickFotoItem;

  /// Remover foto a partir da miniatura no checklist.
  final ValueChanged<String>? onRemoveFoto;

  /// IDs ainda em upload (badge na miniatura).
  final Set<String> pendingIds;

  /// Aviso quando o usuário tenta marcar sem foto (toast no pai).
  final ValueChanged<String>? onBloqueioFoto;

  /// Modo leitura (OS concluída): nenhum toggle/observação editável.
  final bool readOnly;

  /// Nome gravado em `concluidoPor` ao marcar um item.
  final String concluidoPor;

  /// Injeta o "agora" ISO ao concluir um item (default: DateTime.now()).
  /// Existe para tornar o toggle testável de forma determinística.
  final String Function()? nowIso;

  /// Botão no fim do checklist: profissional adiciona serviço extra do catálogo.
  final VoidCallback? onAddExtra;

  @override
  State<ChecklistExecucao> createState() => _ChecklistExecucaoState();
}

class _ChecklistExecucaoState extends State<ChecklistExecucao> {
  final Set<String> _openObs = {};

  String _now() =>
      widget.nowIso?.call() ?? DateTime.now().toUtc().toIso8601String();

  void _toggle(ChecklistExecItem item) {
    if (widget.readOnly) return;
    // Marcar como feito: itens de foto exigem anexo no próprio item.
    if (!item.concluido && !checklistItemPodeConcluir(item, widget.fotos)) {
      final fase = faseFotoExigida(item);
      final label = fase == FaseFoto.depois ? 'depois' : 'antes';
      widget.onBloqueioFoto?.call(
        'Anexe a foto de $label neste item antes de marcar como concluído.',
      );
      return;
    }
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
    final secoes = agruparChecklistSecoes(
      items,
      adicionais: widget.adicionais,
    );
    final multiSecao = secoes.length > 1 ||
        (secoes.isNotEmpty && secoes.any((s) => s.extra));

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
            for (var si = 0; si < secoes.length; si++) ...[
              if (si > 0) const SizedBox(height: ClxSpace.x4),
              if (multiSecao || secoes[si].extra)
                _SecaoHeader(
                  titulo: secoes[si].titulo,
                  extra: secoes[si].extra,
                  done: secoes[si].items.where((i) => i.concluido).length,
                  total: secoes[si].items.length,
                  valorLabel: secoes[si].valorLabel,
                ),
              if (multiSecao || secoes[si].extra)
                const SizedBox(height: ClxSpace.x2),
              for (final it in secoes[si].items) ...[
                _ChecklistTile(
                  item: it,
                  tituloExibicao: tituloChecklistExibicao(
                    it,
                    secaoTitulo: secoes[si].extra ? secoes[si].titulo : null,
                  ),
                  faseExigida: faseFotoExigida(it),
                  fotosItem: fotosDoItemChecklist(widget.fotos, it.id),
                  pendingIds: widget.pendingIds,
                  podeConcluir: checklistItemPodeConcluir(it, widget.fotos),
                  obsOpen: _openObs.contains(it.id),
                  readOnly: widget.readOnly,
                  onToggle: () => _toggle(it),
                  onToggleObs: () => setState(() {
                    if (!_openObs.add(it.id)) _openObs.remove(it.id);
                  }),
                  onObsChanged: (v) => _setObs(it, v),
                  onPickFoto: widget.readOnly || widget.onPickFotoItem == null
                      ? null
                      : () {
                          final fase = faseFotoExigida(it);
                          if (fase == null) return;
                          widget.onPickFotoItem!(it, fase);
                        },
                  onRemoveFoto: widget.readOnly ? null : widget.onRemoveFoto,
                ),
                const SizedBox(height: ClxSpace.x2),
              ],
            ],
          ],
          if (!widget.readOnly && widget.onAddExtra != null) ...[
            const SizedBox(height: ClxSpace.x2),
            ClxButton(
              label: 'Adicionar serviço extra',
              variant: ClxButtonVariant.ghost,
              icon: Icons.add_circle_outline_rounded,
              expand: true,
              onPressed: widget.onAddExtra,
            ),
          ],
        ],
      ),
    );
  }
}

class _SecaoHeader extends StatelessWidget {
  const _SecaoHeader({
    required this.titulo,
    required this.extra,
    required this.done,
    required this.total,
    this.valorLabel,
  });

  final String titulo;
  final bool extra;
  final int done;
  final int total;
  final String? valorLabel;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x3,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        color: extra
            ? clx.primary.withValues(alpha: 0.08)
            : clx.bg2,
        borderRadius: ClxRadii.rMd,
        border: Border.all(
          color: extra ? clx.primary.withValues(alpha: 0.22) : clx.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            extra ? Icons.add_circle_outline_rounded : Icons.checklist_rounded,
            size: 18,
            color: extra ? clx.primary : clx.ink2,
          ),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (extra)
                  Text(
                    'Serviço extra',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: clx.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (valorLabel != null) ...[
            Text(
              valorLabel!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: extra ? clx.primary : clx.ink2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
          ],
          if (total > 0)
            Text(
              '$done/$total',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: done == total ? clx.success : clx.ink3,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.item,
    required this.tituloExibicao,
    required this.faseExigida,
    required this.fotosItem,
    required this.pendingIds,
    required this.podeConcluir,
    required this.obsOpen,
    required this.readOnly,
    required this.onToggle,
    required this.onToggleObs,
    required this.onObsChanged,
    this.onPickFoto,
    this.onRemoveFoto,
  });

  final ChecklistExecItem item;
  final String tituloExibicao;
  final FaseFoto? faseExigida;
  final List<EvidenciaFoto> fotosItem;
  final Set<String> pendingIds;
  final bool podeConcluir;
  final bool obsOpen;
  final bool readOnly;
  final VoidCallback onToggle;
  final VoidCallback onToggleObs;
  final ValueChanged<String> onObsChanged;
  final VoidCallback? onPickFoto;
  final ValueChanged<String>? onRemoveFoto;

  bool get _exigeFoto => faseExigida != null;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final concluido = item.concluido;
    final semFoto = _exigeFoto && !podeConcluir;
    return Container(
      key: ValueKey('checklist-tile-${item.id}'),
      decoration: BoxDecoration(
        border: Border.all(
          color: concluido
              ? clx.success.withValues(alpha: 0.25)
              : semFoto
              ? clx.warning.withValues(alpha: 0.55)
              : clx.line,
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
              Consumer(
                builder: (context, ref, _) {
                  if (!ref.watch(isFintechCleanProvider) &&
                      !ref.watch(isNarrowWebProvider)) {
                    return SizedBox(
                      key: ValueKey('checklist-toggle-${item.id}'),
                      width: 40,
                      height: 40,
                      child: Checkbox(
                        value: concluido,
                        activeColor: clx.success,
                        // Sem foto: ainda chama onToggle (mostra bloqueio/toast).
                        onChanged: readOnly ? null : (_) => onToggle(),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    );
                  }
                  return Semantics(
                    checked: concluido,
                    label: tituloExibicao,
                    child: SizedBox(
                      key: ValueKey('checklist-toggle-${item.id}'),
                      width: ClxLayout.minTouchTarget,
                      height: ClxLayout.minTouchTarget,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: readOnly ? null : onToggle,
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: AnimatedContainer(
                              duration: ClxMotion.shortDuration,
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: concluido
                                    ? clx.success
                                    : Colors.transparent,
                                borderRadius: ClxRadii.rMd,
                                border: Border.all(
                                  color: concluido
                                      ? clx.success
                                      : semFoto
                                      ? clx.warning
                                      : clx.line2,
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
                  );
                },
              ),
              Expanded(
                child: InkWell(
                  onTap: readOnly ? null : onToggle,
                  borderRadius: ClxRadii.rMd,
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
                              tituloExibicao,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: clx.ink,
                                    decoration: concluido
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                            // "Obrigatório" de OS: itens de foto antes/depois
                            // não bloqueiam concluir a OS — só o check do item.
                            if (item.obrigatorio &&
                                !concluido &&
                                !_exigeFoto)
                              ClxChip(
                                label: 'Obrigatório',
                                color: clx.error,
                                dense: true,
                              ),
                            if (_exigeFoto && !concluido)
                              ClxChip(
                                label: semFoto
                                    ? 'Foto p/ marcar'
                                    : 'Foto ok',
                                color: semFoto ? clx.warning : clx.success,
                                dense: true,
                              ),
                          ],
                        ),
                        if (semFoto && !readOnly)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              'Anexe a foto de ${faseExigida == FaseFoto.depois ? 'depois' : 'antes'} '
                              'para marcar este item (opcional para concluir a OS).',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: clx.warning),
                            ),
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
              ),
              if (!readOnly)
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
          if (_exigeFoto) ...[
            const SizedBox(height: ClxSpace.x2),
            _FotosDoItemRow(
              itemId: item.id,
              fotos: fotosItem,
              pendingIds: pendingIds,
              readOnly: readOnly,
              onPick: onPickFoto,
              onRemove: onRemoveFoto,
            ),
          ],
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

class _FotosDoItemRow extends StatelessWidget {
  const _FotosDoItemRow({
    required this.itemId,
    required this.fotos,
    required this.pendingIds,
    required this.readOnly,
    this.onPick,
    this.onRemove,
  });

  final String itemId;
  final List<EvidenciaFoto> fotos;
  final Set<String> pendingIds;
  final bool readOnly;
  final VoidCallback? onPick;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return SizedBox(
      height: 72,
      child: ListView(
        key: ValueKey('checklist-fotos-$itemId'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in fotos) ...[
            _MiniThumb(
              foto: f,
              uploading: pendingIds.contains(f.id),
              readOnly: readOnly,
              onRemove: onRemove == null ? null : () => onRemove!(f.id),
            ),
            const SizedBox(width: ClxSpace.x2),
          ],
          if (!readOnly && onPick != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('checklist-anexar-$itemId'),
                onTap: onPick,
                borderRadius: ClxRadii.rMd,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: clx.bg,
                    borderRadius: ClxRadii.rMd,
                    border: Border.all(color: clx.primary.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: clx.primary, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        'Anexar',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: clx.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniThumb extends StatelessWidget {
  const _MiniThumb({
    required this.foto,
    required this.uploading,
    required this.readOnly,
    this.onRemove,
  });

  final EvidenciaFoto foto;
  final bool uploading;
  final bool readOnly;
  final VoidCallback? onRemove;

  bool get _isNetwork =>
      foto.url.startsWith('http://') || foto.url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: ClxRadii.rMd,
          child: SizedBox(
            width: 72,
            height: 72,
            child: _isNetwork
                ? CachedNetworkImage(
                    imageUrl: foto.url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: clx.bg2),
                    errorWidget: (_, __, ___) => Container(
                      color: clx.bg2,
                      child: Icon(Icons.broken_image_outlined, color: clx.ink3),
                    ),
                  )
                : (!kIsWeb
                      ? Image.file(
                          File(foto.url),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: clx.bg2,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: clx.ink3,
                            ),
                          ),
                        )
                      : Container(
                          color: clx.bg2,
                          child: Icon(Icons.image_outlined, color: clx.ink3),
                        )),
          ),
        ),
        if (uploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: ClxRadii.rMd,
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (!readOnly && onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
