/// clientes_screen.dart — 🔒 COFRE. Lista + CRUD de Clientes do Painel.
///
/// Espelha `Clientes.tsx` com mitigações de Flutter Web (§4): PAGINAÇÃO NO SERVIDOR
/// + scroll infinito VIRTUALIZADO (`ListView.builder`), nunca `getFullList`. Layout
/// adaptativo MD3: tabela densa (≥ 720px) / cards (mobile). Todos os estados:
/// carregando, vazio (com/sem busca), erro (com retry) e sucesso. A identidade
/// petrol+cyan/Sora vem do design system do core.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/cliente.dart';
import 'cliente_form.dart';
import 'clientes_controller.dart';
import 'config_atuacao_editor.dart';

/// Abaixo desta largura → cards; acima → tabela densa.
const double _kTableBreakpoint = 720;

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(clientesControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(clientesControllerProvider.notifier).setQuery(value);
    });
  }

  Future<void> _openForm({Cliente? editing}) async {
    final saved = await showClienteForm(context, editing: editing);
    if (saved == true) {
      await ref.read(clientesControllerProvider.notifier).refresh();
      if (mounted) {
        showClxToast(
          context,
          editing == null ? 'Cliente criado.' : 'Cliente atualizado.',
          type: ToastType.success,
        );
      }
    }
  }

  Future<void> _openConfigAtuacao() async {
    final saved = await showConfigAtuacaoEditor(context);
    if (saved == true && mounted) {
      showClxToast(
        context,
        'Área de atuação atualizada.',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientesControllerProvider);
    // Config de atuação é admin/gerente (Painel), igual ao React (canManageConfig).
    final canConfig = ref.watch(currentRoleProvider)?.isPainel ?? false;
    return Column(
      children: [
        _Toolbar(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          onNovo: () => _openForm(),
          onConfig: canConfig ? _openConfigAtuacao : null,
          total: state.totalItems,
        ),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(ClientesState state) {
    if (state.loading) {
      return const Center(child: Spinner(size: 26));
    }
    if (state.error != null && state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () =>
                  ref.read(clientesControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }
    if (state.isEmpty) {
      final hasQuery = state.query.trim().isNotEmpty;
      return EmptyState(
        icon: hasQuery ? Icons.search_off_rounded : Icons.people_alt_outlined,
        title: hasQuery
            ? 'Nenhum cliente encontrado'
            : 'Nenhum cliente cadastrado',
        message: hasQuery
            ? 'Tente outros termos de busca.'
            : 'Clique em "Novo cliente" para começar.',
        action: hasQuery
            ? null
            : ClxButton(
                label: 'Novo cliente',
                icon: Icons.add_rounded,
                onPressed: () => _openForm(),
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final table = c.maxWidth >= _kTableBreakpoint;
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(clientesControllerProvider.notifier).refresh(),
          color: context.clx.primary,
          child: table ? _tableView(state) : _cardsView(state),
        );
      },
    );
  }

  // Rodapé comum (spinner de "carregar mais").
  int _extra(ClientesState s) => s.hasMore ? 1 : 0;

  Widget _footerOrNull(ClientesState state, int i) {
    if (i < state.items.length) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.all(ClxSpace.x4),
      child: Center(child: Spinner(size: 20)),
    );
  }

  /// Tabela densa virtualizada (header fixo + linhas em ListView.builder).
  Widget _tableView(ClientesState state) {
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
              _HeaderCell('Telefone', flex: 2),
              _HeaderCell('Bairro', flex: 2),
              _HeaderCell('Cidade', flex: 2),
              _HeaderCell('Status', flex: 2),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            itemCount: state.items.length + _extra(state),
            separatorBuilder: (_, __) => Divider(height: 1, color: clx.line),
            itemBuilder: (context, i) {
              if (i >= state.items.length) return _footerOrNull(state, i);
              final cli = state.items[i];
              return _TableRow(
                cliente: cli,
                onTap: () => _openForm(editing: cli),
                onToggle: () => ref
                    .read(clientesControllerProvider.notifier)
                    .toggleAtivo(cli),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Lista de cards (mobile), virtualizada.
  Widget _cardsView(ClientesState state) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: state.items.length + _extra(state),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _footerOrNull(state, i);
        final cli = state.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: _ClienteCard(
            cliente: cli,
            onTap: () => _openForm(editing: cli),
            onToggle: () =>
                ref.read(clientesControllerProvider.notifier).toggleAtivo(cli),
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onChanged,
    required this.onNovo,
    required this.onConfig,
    required this.total,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onNovo;

  /// Abre o editor de área de atuação (admin/gerente); `null` esconde o botão.
  final VoidCallback? onConfig;
  final int total;

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
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar por nome, telefone ou bairro…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: clx.bg2,
                  border: const OutlineInputBorder(
                    borderRadius: ClxRadii.rMd,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (onConfig != null) ...[
            const SizedBox(width: ClxSpace.x2),
            IconButton(
              tooltip: 'Área de atuação',
              icon: const Icon(Icons.tune_rounded),
              color: clx.ink2,
              onPressed: onConfig,
            ),
          ],
          const SizedBox(width: ClxSpace.x3),
          ClxButton(
            label: 'Novo cliente',
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
        style: TextStyle(
          color: clx.ink3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.cliente,
    required this.onTap,
    required this.onToggle,
  });

  final Cliente cliente;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final nomeCompleto = [
      cliente.nome,
      cliente.sobrenome,
    ].where((s) => (s ?? '').isNotEmpty).join(' ');
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeCompleto.isEmpty ? '—' : nomeCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: clx.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((cliente.email ?? '').isNotEmpty)
                    Text(
                      cliente.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: clx.ink3, fontSize: 12),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                cliente.telefone.isEmpty ? '—' : maskPhoneBR(cliente.telefone),
                style: TextStyle(color: clx.ink2, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                cliente.enderecoBairro.isEmpty ? '—' : cliente.enderecoBairro,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink2, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (cliente.enderecoCidade ?? '').isEmpty
                    ? '—'
                    : cliente.enderecoCidade!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink2, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _AtivoChip(ativo: cliente.ativo, onTap: onToggle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({
    required this.cliente,
    required this.onTap,
    required this.onToggle,
  });

  final Cliente cliente;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final nomeCompleto = [
      cliente.nome,
      cliente.sobrenome,
    ].where((s) => (s ?? '').isNotEmpty).join(' ');
    final local = [
      cliente.enderecoBairro,
      cliente.enderecoCidade ?? '',
    ].where((s) => s.isNotEmpty).join(', ');
    return ClxCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: clx.accent,
                child: Text(
                  nomeCompleto.isEmpty ? 'C' : nomeCompleto[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeCompleto.isEmpty ? '—' : nomeCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((cliente.email ?? '').isNotEmpty)
                      Text(
                        cliente.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: clx.ink3, fontSize: 12.5),
                      ),
                  ],
                ),
              ),
              _AtivoChip(ativo: cliente.ativo, onTap: onToggle),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          _cardRow(
            clx,
            Icons.phone_outlined,
            cliente.telefone.isEmpty ? '—' : maskPhoneBR(cliente.telefone),
          ),
          if (local.isNotEmpty) ...[
            const SizedBox(height: ClxSpace.x1),
            _cardRow(clx, Icons.place_outlined, local),
          ],
        ],
      ),
    );
  }

  Widget _cardRow(CleanoxColors clx, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: clx.ink3),
        const SizedBox(width: ClxSpace.x2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: clx.ink2, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

/// Chip clicável de status ativo/inativo (toggle).
class _AtivoChip extends StatelessWidget {
  const _AtivoChip({required this.ativo, required this.onTap});

  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = ativo ? clx.success : clx.error;
    return Tooltip(
      message: ativo ? 'Clique para inativar' : 'Clique para ativar',
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rPill,
        child: ClxChip(label: ativo ? 'Ativo' : 'Inativo', color: color),
      ),
    );
  }
}
