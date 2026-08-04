/// notificacoes_bell.dart — Sino de notificações in-app (menções @ na OS).
///
/// Só faz sentido no painel (admin/gerente). Abre painel com lista e navega
/// para o detalhe da OS ao tocar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/os_atividade.dart';
import '../ordens/os_atividade_panel.dart';
import '../ordens/os_detail.dart';

/// Ícone de sino com badge de não-lidas + menu/sheet de notificações.
class NotificacoesBell extends ConsumerWidget {
  const NotificacoesBell({super.key});

  Future<void> _openOs(BuildContext context, WidgetRef ref, String osId) async {
    try {
      final os = await ref.read(ordensRepositoryProvider).getOne(
            osId,
            expand: 'profissional,cliente,servico',
          );
      if (!context.mounted) return;
      await showOSDetail(context, os);
    } catch (_) {
      if (!context.mounted) return;
      showClxToast(
        context,
        'Não foi possível abrir a OS.',
        type: ToastType.error,
      );
    }
  }

  Future<void> _showPanel(BuildContext context, WidgetRef ref) async {
    final clx = context.clx;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) {
            return _NotificacoesSheet(
              scrollController: scrollCtrl,
              onOpenOs: (osId) async {
                Navigator.of(ctx).pop();
                await _openOs(context, ref, osId);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    if (role == null || !role.isPainel) return const SizedBox.shrink();

    final unreadAsync = ref.watch(notificacoesUnreadCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;

    return IconButton(
      tooltip: 'Notificações',
      onPressed: () => _showPanel(context, ref),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificacoesSheet extends ConsumerWidget {
  const _NotificacoesSheet({
    required this.scrollController,
    required this.onOpenOs,
  });

  final ScrollController scrollController;
  final Future<void> Function(String osId) onOpenOs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(notificacoesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Notificações',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(osAtividadeRepositoryProvider)
                        .marcarTodasLidas();
                    ref.invalidate(notificacoesListProvider);
                    ref.invalidate(notificacoesUnreadCountProvider);
                  } catch (_) {}
                },
                child: const Text('Marcar todas lidas'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Expanded(
          child: async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Falha ao carregar notificações.',
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhuma notificação.',
                    style: tt.bodyMedium?.copyWith(color: clx.ink3),
                  ),
                );
              }
              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: clx.line),
                itemBuilder: (ctx, i) {
                  final n = items[i];
                  return _NotifTile(
                    n: n,
                    onTap: () async {
                      if (!n.lida) {
                        try {
                          await ref
                              .read(osAtividadeRepositoryProvider)
                              .marcarLida(n.id);
                          ref.invalidate(notificacoesListProvider);
                          ref.invalidate(notificacoesUnreadCountProvider);
                        } catch (_) {}
                      }
                      final osId = n.os;
                      if (osId != null && osId.isNotEmpty) {
                        await onOpenOs(osId);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n, required this.onTap});

  final NotificacaoInApp n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final when = (n.created == null || n.created!.isEmpty)
        ? ''
        : formatDateTime(n.created!);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: n.lida
            ? clx.bg3
            : clx.primary.withValues(alpha: 0.15),
        child: Icon(
          Icons.alternate_email_rounded,
          size: 18,
          color: n.lida ? clx.ink3 : clx.primary,
        ),
      ),
      title: Text(
        n.titulo,
        style: tt.bodyLarge?.copyWith(
          fontWeight: n.lida ? FontWeight.w500 : FontWeight.w700,
          color: clx.ink,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((n.corpo ?? '').isNotEmpty)
            Text(
              n.corpo!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: clx.ink2),
            ),
          if (when.isNotEmpty)
            Text(when, style: tt.labelSmall?.copyWith(color: clx.ink3)),
        ],
      ),
      isThreeLine: (n.corpo ?? '').isNotEmpty,
    );
  }
}
