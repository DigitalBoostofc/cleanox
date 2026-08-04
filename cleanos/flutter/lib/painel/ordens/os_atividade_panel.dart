/// os_atividade_panel.dart — Comentários e atividade da OS (estilo Trello).
///
/// Interno: admin/gerente. Log automático + comentários com @menção.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/os_atividade.dart';
import '../../core/models/user.dart';

/// Provider da timeline de uma OS (invalidate após comentar).
final osAtividadeListProvider =
    FutureProvider.autoDispose.family<List<OsAtividade>, String>((ref, osId) {
  return ref.watch(osAtividadeRepositoryProvider).listByOs(osId);
});

final osMencionaveisProvider =
    FutureProvider.autoDispose<List<User>>((ref) {
  return ref.watch(osAtividadeRepositoryProvider).listMencionaveis();
});

class OsAtividadePanel extends ConsumerStatefulWidget {
  const OsAtividadePanel({
    super.key,
    required this.osId,
    /// Coluna direita do modal OS (Trello): preenche altura, timeline com scroll.
    this.sidePanel = false,
  });

  final String osId;
  final bool sidePanel;

  @override
  ConsumerState<OsAtividadePanel> createState() => _OsAtividadePanelState();
}

class _OsAtividadePanelState extends ConsumerState<OsAtividadePanel> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _error;
  List<String> _pendingMentions = [];
  bool _showMentions = false;
  String _mentionQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // Detecta @query no final do texto para autocomplete.
    final m = RegExp(r'@([A-Za-zÀ-ÿ0-9._-]*)$').firstMatch(value);
    if (m != null) {
      setState(() {
        _showMentions = true;
        _mentionQuery = m.group(1) ?? '';
      });
    } else if (_showMentions) {
      setState(() {
        _showMentions = false;
        _mentionQuery = '';
      });
    }
  }

  void _insertMention(User u) {
    final text = _ctrl.text;
    final m = RegExp(r'@([A-Za-zÀ-ÿ0-9._-]*)$').firstMatch(text);
    final name = u.displayName;
    if (m != null) {
      final start = m.start;
      final newText = '${text.substring(0, start)}@$name ';
      _ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else {
      final newText = '${text.trimRight()} @$name '.trimLeft();
      _ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    if (!_pendingMentions.contains(u.id)) {
      _pendingMentions = [..._pendingMentions, u.id];
    }
    setState(() {
      _showMentions = false;
      _mentionQuery = '';
    });
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(osAtividadeRepositoryProvider).addComentario(
            osId: widget.osId,
            texto: texto,
            mentionIds: _pendingMentions,
          );
      _ctrl.clear();
      _pendingMentions = [];
      ref.invalidate(osAtividadeListProvider(widget.osId));
      // Atualiza contador de notificações do shell (outro usuário).
      ref.invalidate(notificacoesUnreadCountProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível enviar o comentário.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(osAtividadeListProvider(widget.osId));
    final mencionaveis = ref.watch(osMencionaveisProvider);
    final side = widget.sidePanel;

    final header = Row(
      children: [
        Icon(Icons.forum_outlined, size: 18, color: clx.ink3),
        const SizedBox(width: ClxSpace.x2),
        Expanded(
          child: Text(
            side ? 'Comentários e atividade' : 'COMENTÁRIOS E ATIVIDADE',
            style: (side ? tt.titleSmall : tt.labelSmall)?.copyWith(
              color: side ? clx.ink : clx.ink3,
              fontWeight: FontWeight.w700,
              letterSpacing: side ? 0 : 0.4,
            ),
          ),
        ),
      ],
    );

    final composer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          minLines: side ? 2 : 2,
          maxLines: side ? 4 : 5,
          onChanged: _onTextChanged,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: side
                ? 'Escrever um comentário…'
                : 'Escreva um comentário… Use @ para mencionar',
            isDense: true,
            filled: true,
            fillColor: side ? clx.bg : clx.bg2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: clx.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: clx.line),
            ),
          ),
        ),
        if (_showMentions)
          mencionaveis.when(
            data: (users) {
              final q = _mentionQuery.toLowerCase();
              final filtered = users.where((u) {
                if (q.isEmpty) return true;
                return u.displayName.toLowerCase().contains(q);
              }).take(6).toList();
              if (filtered.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: clx.bg,
                  border: Border.all(color: clx.line),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final u in filtered)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: clx.primary.withValues(alpha: 0.15),
                          child: Text(
                            u.displayName.isNotEmpty
                                ? u.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: clx.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(u.displayName, style: tt.bodyMedium),
                        subtitle: Text(
                          u.role.wire,
                          style: tt.labelSmall?.copyWith(color: clx.ink3),
                        ),
                        onTap: () => _insertMention(u),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        const SizedBox(height: ClxSpace.x2),
        Row(
          children: [
            if (_error != null)
              Expanded(
                child: Text(
                  _error!,
                  style: tt.bodySmall?.copyWith(color: clx.error),
                ),
              )
            else
              const Spacer(),
            ClxButton(
              label: 'Comentar',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: _sending ? null : _enviar,
            ),
          ],
        ),
      ],
    );

    Widget timelineBody() {
      return async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => Text(
          'Não foi possível carregar a atividade.',
          style: tt.bodyMedium?.copyWith(color: clx.ink3),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'Nenhuma atividade ainda. Comente ou altere a OS para gerar o histórico.',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            );
          }
          if (side) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x4,
                0,
                ClxSpace.x4,
                ClxSpace.x4,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: ClxSpace.x2),
              itemBuilder: (_, i) => _AtividadeTile(item: items[i]),
            );
          }
          return Column(
            children: [
              for (final item in items) ...[
                _AtividadeTile(item: item),
                const SizedBox(height: ClxSpace.x2),
              ],
            ],
          );
        },
      );
    }

    if (side) {
      // Coluna direita: header + composer fixos, timeline com scroll próprio.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x4,
              ClxSpace.x4,
              ClxSpace.x4,
              ClxSpace.x3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: ClxSpace.x3),
                composer,
              ],
            ),
          ),
          Divider(height: 1, color: clx.line),
          Expanded(child: timelineBody()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: ClxSpace.x2),
        composer,
        const SizedBox(height: ClxSpace.x4),
        timelineBody(),
      ],
    );
  }
}

class _AtividadeTile extends StatelessWidget {
  const _AtividadeTile({required this.item});

  final OsAtividade item;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final isComment = item.tipo == OsAtividadeTipo.comentario;
    final icon = switch (item.tipo) {
      OsAtividadeTipo.comentario => Icons.chat_bubble_outline_rounded,
      OsAtividadeTipo.alteracao => Icons.edit_note_rounded,
      OsAtividadeTipo.sistema => Icons.info_outline_rounded,
    };
    final iconColor = switch (item.tipo) {
      OsAtividadeTipo.comentario => clx.primary,
      OsAtividadeTipo.alteracao => clx.ink3,
      OsAtividadeTipo.sistema => clx.ink3,
    };

    final when = (item.created == null || item.created!.isEmpty)
        ? ''
        : formatDateTime(item.created!);

    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: isComment ? clx.bg2 : clx.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComment ? clx.line : clx.line.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isComment)
                  Text(
                    item.autorNome,
                    style: tt.labelLarge?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  item.texto,
                  style: tt.bodyMedium?.copyWith(
                    color: isComment ? clx.ink : clx.ink2,
                    height: 1.35,
                  ),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: tt.labelSmall?.copyWith(color: clx.ink3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contagem de não-lidas (poll leve via FutureProvider; invalidate no comentar).
final notificacoesUnreadCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final role = ref.watch(currentRoleProvider);
  if (role == null || !role.isPainel) return 0;
  try {
    return await ref.watch(osAtividadeRepositoryProvider).countNaoLidas();
  } catch (_) {
    return 0;
  }
});

final notificacoesListProvider =
    FutureProvider.autoDispose<List<NotificacaoInApp>>((ref) async {
  final role = ref.watch(currentRoleProvider);
  if (role == null || !role.isPainel) return const [];
  try {
    return await ref.watch(osAtividadeRepositoryProvider).listNotificacoes();
  } catch (_) {
    return const [];
  }
});
