/// usuarios_screen.dart — CRUD de Usuários do Painel (admin/gerente/profissional).
///
/// Tabela/cards de Usuários (admin/gerente/profissional).
///
/// Criar/editar via [UsuarioForm]; excluir com confirmação.
/// Status ativo/inativo (migration 52) + filtro. Horários/disponibilidade
/// semanal **não** são expostos aqui (agenda livre — feature legada).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/user.dart';
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

enum _FiltroAtivo { todos, ativos, inativos }

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  _FiltroAtivo _filtro = _FiltroAtivo.ativos;

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
  Widget build(BuildContext context) {
    final state = ref.watch(usuariosControllerProvider);
    // 🔒 Guard de UI: só admin exclui usuário (espelha o React — o botão de
    // excluir só aparece para admin). O servidor é a linha de defesa final.
    final canDelete = ref.watch(currentRoleProvider) == Role.admin;
    final filtered = switch (_filtro) {
      _FiltroAtivo.todos => state.items,
      _FiltroAtivo.ativos => state.items.where((u) => u.ativo).toList(),
      _FiltroAtivo.inativos => state.items.where((u) => !u.ativo).toList(),
    };
    final viewState = state.copyWith(items: filtered);
    return Column(
      children: [
        _Toolbar(
          onNovo: () => _novo(context, ref),
          filtro: _filtro,
          onFiltro: (f) => setState(() => _filtro = f),
          total: state.items.length,
          visiveis: filtered.length,
        ),
        Expanded(child: _body(context, ref, viewState, canDelete)),
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
              _HeaderCell('E-mail', flex: 3),
              _HeaderCell('Papel', flex: 2),
              _HeaderCell('Status', flex: 2),
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
            onExcluir: canDelete ? () => _excluir(context, ref, u) : null,
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onNovo,
    required this.filtro,
    required this.onFiltro,
    required this.total,
    required this.visiveis,
  });
  final VoidCallback onNovo;
  final _FiltroAtivo filtro;
  final ValueChanged<_FiltroAtivo> onFiltro;
  final int total;
  final int visiveis;

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
      child: Wrap(
        spacing: ClxSpace.x3,
        runSpacing: ClxSpace.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ClxButton(
            label: 'Novo usuário',
            icon: Icons.add_rounded,
            onPressed: onNovo,
          ),
          SegmentedButton<_FiltroAtivo>(
            segments: const [
              ButtonSegment(value: _FiltroAtivo.ativos, label: Text('Ativos')),
              ButtonSegment(
                value: _FiltroAtivo.inativos,
                label: Text('Inativos'),
              ),
              ButtonSegment(value: _FiltroAtivo.todos, label: Text('Todos')),
            ],
            selected: {filtro},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onFiltro(s.first);
            },
          ),
          Text(
            '$visiveis de $total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: clx.ink3,
                ),
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
    required this.onExcluir,
  });

  final User user;
  final VoidCallback onTap;

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
              flex: 3,
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: _AtivoChip(ativo: user.ativo),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
    required this.onExcluir,
  });

  final User user;
  final VoidCallback onTap;

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
              const SizedBox(width: ClxSpace.x2),
              _AtivoChip(ativo: user.ativo),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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


class _AtivoChip extends StatelessWidget {
  const _AtivoChip({required this.ativo});
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxChip(
      label: ativo ? 'Ativo' : 'Inativo',
      color: ativo ? clx.success : clx.ink3,
      dense: true,
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
