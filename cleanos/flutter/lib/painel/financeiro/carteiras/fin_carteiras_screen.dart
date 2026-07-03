/// fin_carteiras_screen.dart — Contas/Carteiras (`fin_contas`) + saldos.
///
/// Espelha `ContasCarteiras.tsx`: saldo geral no topo + grade de carteiras com
/// tipo/saldo/status, CRUD via modal. Estados carregando/erro/vazio/sucesso.
/// Conjunto pequeno (carteiras) → `getFullList` no repo é aceitável.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/models/financeiro.dart';
import '../fin_common.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';
import 'conta_form.dart';
import 'transferencia_form.dart';

class FinCarteirasScreen extends ConsumerWidget {
  const FinCarteirasScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    FinConta? editing,
  }) async {
    final saved = await showContaForm(context, editing: editing);
    if (saved == true) {
      ref.invalidate(finContasProvider);
      if (context.mounted) {
        showClxToast(
          context,
          editing == null ? 'Carteira criada.' : 'Carteira atualizada.',
          type: ToastType.success,
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FinConta conta,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir carteira'),
        content: Text(
          'Excluir "${conta.nome}"? Os lançamentos vinculados não são apagados.',
        ),
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
      await ref.read(financeiroRepositoryProvider).deleteConta(conta.id);
      ref.invalidate(finContasProvider);
      if (context.mounted) {
        showClxToast(context, 'Carteira excluída.', type: ToastType.success);
      }
    } catch (_) {
      if (context.mounted) {
        showClxToast(
          context,
          'Não foi possível excluir a carteira.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _openTransfer(BuildContext context, WidgetRef ref) async {
    final done = await showTransferenciaForm(context);
    if (done == true) {
      ref.invalidate(finContasProvider);
      if (context.mounted) {
        showClxToast(context, 'Transferência concluída.', type: ToastType.success);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(finContasProvider);
    final contas = async.valueOrNull ?? const <FinConta>[];
    final podeTransferir = contas.where((c) => c.ativo).length >= 2;
    return Column(
      children: [
        _Toolbar(
          onNova: () => _openForm(context, ref),
          onTransfer: podeTransferir ? () => _openTransfer(context, ref) : null,
        ),
        Expanded(
          child: FinAsync<List<FinConta>>(
            value: async,
            onRetry: () => ref.invalidate(finContasProvider),
            data: (contas) {
              if (contas.isEmpty) {
                return EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Nenhuma carteira cadastrada',
                  message: 'Crie carteiras/contas para organizar seus saldos.',
                  action: ClxButton(
                    label: 'Nova carteira',
                    icon: Icons.add_rounded,
                    onPressed: () => _openForm(context, ref),
                  ),
                );
              }
              return _Body(
                contas: contas,
                onEdit: (c) => _openForm(context, ref, editing: c),
                onDelete: (c) => _confirmDelete(context, ref, c),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onNova, this.onTransfer});
  final VoidCallback onNova;

  /// `null` desabilita o botão (menos de 2 contas ativas), como no web.
  final VoidCallback? onTransfer;

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
            child: Text(
              'Carteiras e contas',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Tooltip(
            message: onTransfer == null
                ? 'É preciso ao menos 2 contas ativas'
                : 'Transferir entre contas',
            child: ClxButton(
              label: 'Transferência',
              icon: Icons.swap_horiz_rounded,
              variant: ClxButtonVariant.ghost,
              onPressed: onTransfer,
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          ClxButton(
            label: 'Nova carteira',
            icon: Icons.add_rounded,
            onPressed: onNova,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.contas,
    required this.onEdit,
    required this.onDelete,
  });

  final List<FinConta> contas;
  final ValueChanged<FinConta> onEdit;
  final ValueChanged<FinConta> onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final total = contas.fold<double>(0, (s, c) => s + c.saldoAtual);
    final ativas = contas.where((c) => c.ativo).length;

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x6),
      children: [
        // Saldo geral.
        ClxCard(
          elevated: true,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: clx.primary.withValues(alpha: 0.14),
                  borderRadius: ClxRadii.rMd,
                ),
                child: Icon(Icons.account_balance_outlined, color: clx.primary),
              ),
              const SizedBox(width: ClxSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo geral',
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                    Text(
                      formatCurrency(total),
                      style: tt.headlineMedium?.copyWith(
                        color: total < 0 ? clx.finExpense : clx.ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${contas.length} carteira${contas.length == 1 ? '' : 's'} · '
                '$ativas ativa${ativas == 1 ? '' : 's'}',
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x5),
        // Grade de carteiras.
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900
                ? 3
                : c.maxWidth >= 560
                ? 2
                : 1;
            const gap = ClxSpace.x3;
            final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final conta in contas)
                  SizedBox(
                    width: itemW,
                    child: _ContaCard(
                      conta: conta,
                      onEdit: () => onEdit(conta),
                      onDelete: () => onDelete(conta),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ContaCard extends StatelessWidget {
  const _ContaCard({
    required this.conta,
    required this.onEdit,
    required this.onDelete,
  });

  final FinConta conta;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final accent = _parseHex(conta.cor) ?? clx.primary;
    return ClxCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: ClxRadii.rMd,
                ),
                child: Icon(contaTipoIcon(conta.tipo), size: 18, color: accent),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conta.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      contaTipoLabel(conta.tipo),
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ações',
                icon: Icon(Icons.more_vert_rounded, size: 20, color: clx.ink3),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          Text(
            formatCurrency(conta.saldoAtual),
            style: tt.titleLarge?.copyWith(
              color: conta.saldoAtual < 0 ? clx.finExpense : clx.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              ClxChip(
                label: conta.ativo ? 'Ativa' : 'Inativa',
                color: conta.ativo ? clx.success : clx.ink3,
                dense: true,
              ),
              const Spacer(),
              Text(
                'Inicial ${formatCurrency(conta.saldoInicial)}',
                style: tt.bodySmall?.copyWith(color: clx.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}
