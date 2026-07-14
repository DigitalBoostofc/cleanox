/// usuarios_screen.dart — CRUD de Usuários do Painel (admin/gerente/profissional).
///
/// Espelha `Usuarios.tsx`: tabela (Nome / E-mail / Papel) no desktop, cards no
/// mobile; criar/editar via [UsuarioForm]; excluir com confirmação. Para
/// profissionais, expõe também o editor de DISPONIBILIDADE semanal (alimenta a
/// Agenda). Guardas de segurança (não excluir a própria conta) espelhadas do React;
/// o servidor continua sendo a linha de defesa. Todos os estados.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/user.dart';
import 'disponibilidade_editor.dart';
import 'usuario_form.dart';
import 'usuarios_controller.dart';

const double _kTableBreakpoint = 720;

/// Extrai a mensagem real do PocketBase (campo `message` da resposta HTTP).
/// Para erros 400 do hook de exclusão segura, o backend devolve a frase PT-BR
/// verbatim — exibimos ela em vez de uma string genérica.
String _deleteErrorMessage(Object? err) {
  if (err is ClientException) {
    final msg = err.response['message'];
    if (msg is String && msg.isNotEmpty) return msg;
  }
  return 'Não foi possível excluir o usuário.';
}

class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  Future<void> _novo(BuildContext context, WidgetRef ref) async {
    final saved = await showUsuarioForm(context);
    if (saved == true) {
      await ref.read(usuariosControllerProvider.notifier).refresh();
      if (context.mounted) {
        showClxToast(context, 'Usuário criado.', type: ToastType.success);
      }
    }
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, User u) async {
    final saved = await showUsuarioForm(context, editing: u);
    if (saved == true) {
      await ref.read(usuariosControllerProvider.notifier).refresh();
      if (context.mounted) {
        showClxToast(context, 'Usuário atualizado.', type: ToastType.success);
      }
    }
  }

  Future<void> _disponibilidade(BuildContext context, User u) async {
    // O editor mostra o próprio feedback de sucesso/erro (inline).
    await showDisponibilidadeEditor(context, profissional: u);
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref, User u) async {
    final myId = ref.read(currentUserProvider)?.id;
    if (myId != null && u.id == myId) {
      showClxToast(
        context,
        'Não é possível excluir a própria conta.',
        type: ToastType.warning,
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(
        nome: u.displayName,
        isProfissional: u.role == Role.profissional,
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(usuariosControllerProvider.notifier).delete(u.id);
      if (context.mounted) {
        showClxToast(context, 'Usuário excluído.', type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        showClxToast(
          context,
          _deleteErrorMessage(e),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usuariosControllerProvider);
    // 🔒 Guard de UI: só admin exclui usuário (espelha o React — o botão de
    // excluir só aparece para admin). O servidor é a linha de defesa final.
    final canDelete = ref.watch(currentRoleProvider) == Role.admin;
    return Column(
      children: [
        _Toolbar(onNovo: () => _novo(context, ref)),
        Expanded(child: _body(context, ref, state, canDelete)),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    UsuariosState state,
    bool canDelete,
  ) {
    if (state.loading) return const Center(child: Spinner(size: 26));
    if (state.error != null && state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () =>
                  ref.read(usuariosControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }
    if (state.isEmpty) {
      return EmptyState(
        icon: Icons.badge_outlined,
        title: 'Nenhum usuário cadastrado',
        message: 'Clique em "Novo usuário" para adicionar.',
        action: ClxButton(
          label: 'Novo usuário',
          icon: Icons.add_rounded,
          onPressed: () => _novo(context, ref),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(usuariosControllerProvider.notifier).refresh(),
      color: context.clx.primary,
      child: LayoutBuilder(
        builder: (context, c) {
          final table = c.maxWidth >= _kTableBreakpoint;
          return table
              ? _tableView(context, ref, state, canDelete)
              : _cardsView(context, ref, state, canDelete);
        },
      ),
    );
  }

  Widget _tableView(
    BuildContext context,
    WidgetRef ref,
    UsuariosState state,
    bool canDelete,
  ) {
    final clx = context.clx;
    return Column(
      children: [
        Container(
          color: clx.bg3,
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x6,
            vertical: ClxSpace.x3,
          ),
          child: Row(
            children: const [
              _HeaderCell('Nome', flex: 3),
              _HeaderCell('E-mail', flex: 4),
              _HeaderCell('Papel', flex: 2),
              _HeaderCell('', flex: 2),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Expanded(
          child: ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: clx.line),
            itemBuilder: (context, i) {
              final u = state.items[i];
              return _UsuarioRow(
                user: u,
                onTap: () => _editar(context, ref, u),
                onDisponibilidade: u.role == Role.profissional
                    ? () => _disponibilidade(context, u)
                    : null,
                onExcluir: canDelete ? () => _excluir(context, ref, u) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cardsView(
    BuildContext context,
    WidgetRef ref,
    UsuariosState state,
    bool canDelete,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: state.items.length,
      itemBuilder: (context, i) {
        final u = state.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: _UsuarioCard(
            user: u,
            onTap: () => _editar(context, ref, u),
            onDisponibilidade: u.role == Role.profissional
                ? () => _disponibilidade(context, u)
                : null,
            onExcluir: canDelete ? () => _excluir(context, ref, u) : null,
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onNovo});
  final VoidCallback onNovo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x4,
        ClxSpace.x6,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          ClxButton(
            label: 'Novo usuário',
            icon: Icons.add_rounded,
            onPressed: onNovo,
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.flex = 1});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: clx.ink3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = switch (role) {
      Role.admin => clx.accent,
      Role.gerente => clx.info,
      Role.profissional => clx.ink3,
    };
    return ClxChip(label: roleLabel(role), color: color, dense: true);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(user: user, radius: 18);
  }
}

class _UsuarioRow extends StatelessWidget {
  const _UsuarioRow({
    required this.user,
    required this.onTap,
    required this.onDisponibilidade,
    required this.onExcluir,
  });

  final User user;
  final VoidCallback onTap;
  final VoidCallback? onDisponibilidade;

  /// `null` esconde a ação de excluir (só admin exclui — espelha o React).
  final VoidCallback? onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x6,
          vertical: ClxSpace.x3,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _Avatar(user: user),
                  const SizedBox(width: ClxSpace.x3),
                  Expanded(
                    child: Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink2),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Flexible(child: _RoleChip(role: user.role)),
                  // "(app)" — o profissional acessa pelo app (espelha o React).
                  if (user.role == Role.profissional) ...[
                    const SizedBox(width: ClxSpace.x2),
                    Text(
                      '(app)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onDisponibilidade != null)
                    IconButton(
                      tooltip: 'Disponibilidade',
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                      ),
                      onPressed: onDisponibilidade,
                    ),
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onTap,
                  ),
                  if (onExcluir != null)
                    IconButton(
                      tooltip: 'Excluir',
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: clx.error,
                      ),
                      onPressed: onExcluir,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({
    required this.user,
    required this.onTap,
    required this.onDisponibilidade,
    required this.onExcluir,
  });

  final User user;
  final VoidCallback onTap;
  final VoidCallback? onDisponibilidade;

  /// `null` esconde a ação de excluir (só admin exclui — espelha o React).
  final VoidCallback? onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(user: user),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              _RoleChip(role: user.role),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onDisponibilidade != null)
                ClxButton(
                  label: 'Disponibilidade',
                  variant: ClxButtonVariant.ghost,
                  icon: Icons.event_available_outlined,
                  onPressed: onDisponibilidade,
                ),
              if (onExcluir != null)
                IconButton(
                  tooltip: 'Excluir',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: clx.error,
                  ),
                  onPressed: onExcluir,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({
    required this.nome,
    this.isProfissional = false,
  });
  final String nome;
  final bool isProfissional;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final content = isProfissional
        ? 'Tem certeza que deseja excluir o profissional "$nome"? '
          'A agenda de disponibilidade deste profissional também será excluída. '
          'Esta ação não pode ser desfeita.'
        : 'Tem certeza que deseja excluir o usuário "$nome"? Esta ação não pode '
          'ser desfeita.';
    return AlertDialog(
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: const Text('Excluir usuário'),
      content: Text(
        content,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink2, height: 1.5),
      ),
      actions: [
        ClxButton(
          label: 'Cancelar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ClxButton(
          label: 'Excluir',
          variant: ClxButtonVariant.danger,
          icon: Icons.delete_outline_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
