/// fin_comissoes_screen.dart — Config de comissão por profissional + extrato.
///
/// Aba Financeiro "Comissões": lista profissionais com tipo (nenhuma / % / fixo)
/// e valor; extrato das comissões geradas ao concluir OS; admin marca como paga.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../data/painel_providers.dart';

final _comissoesProfissionaisProvider = FutureProvider.autoDispose<List<User>>((
  ref,
) {
  return ref.watch(comissaoRepositoryProvider).listProfissionais();
});

final _comissoesExtratoProvider =
    FutureProvider.autoDispose<List<ProfComissao>>((ref) {
      return ref.watch(comissaoRepositoryProvider).listComissoes();
    });

class FinComissoesScreen extends ConsumerWidget {
  const FinComissoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final profs = ref.watch(_comissoesProfissionaisProvider);
    final extrato = ref.watch(_comissoesExtratoProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_comissoesProfissionaisProvider);
        ref.invalidate(_comissoesExtratoProvider);
      },
      // Lista preenche a altura do card (borda fecha no fundo do painel).
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ClxSpace.x5,
          ClxSpace.x4,
          ClxSpace.x5,
          ClxSpace.x8,
        ),
        children: [
          Text(
            'Comissão por profissional',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            'Defina se cada profissional recebe comissão e se é percentual sobre o valor pago da OS ou valor fixo. '
            'Quando houver comissão, o app do profissional exibe a aba Financeiro com o extrato.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink2),
          ),
          const SizedBox(height: ClxSpace.x4),
          profs.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(ClxSpace.x6),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner(
              message: 'Não foi possível carregar profissionais.',
              onRetry: () => ref.invalidate(_comissoesProfissionaisProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Nenhum profissional',
                  message: 'Cadastre profissionais em Usuários.',
                );
              }
              return Column(
                children: [
                  for (final u in list) ...[
                    _ProfComissaoCard(
                      user: u,
                      onSaved: () {
                        ref.invalidate(_comissoesProfissionaisProvider);
                        showClxToast(
                          context,
                          'Comissão atualizada.',
                          type: ToastType.success,
                        );
                      },
                    ),
                    const SizedBox(height: ClxSpace.x3),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: ClxSpace.x6),
          Text(
            'Extrato de comissões',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          extrato.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(ClxSpace.x4),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner(
              message: 'Não foi possível carregar o extrato.',
              onRetry: () => ref.invalidate(_comissoesExtratoProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return ClxCard(
                  child: Text(
                    'Nenhuma comissão gerada ainda. Elas aparecem ao concluir OS de profissionais com comissão ativa.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
                  ),
                );
              }
              final pendente = items
                  .where((c) => c.status == ComissaoStatus.pendente)
                  .fold<double>(0, (s, c) => s + c.valorComissao);
              final paga = items
                  .where((c) => c.status == ComissaoStatus.paga)
                  .fold<double>(0, (s, c) => s + c.valorComissao);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KpiMini(
                          label: 'Pendente',
                          value: formatCurrency(pendente),
                          color: clx.warning,
                        ),
                      ),
                      const SizedBox(width: ClxSpace.x3),
                      Expanded(
                        child: _KpiMini(
                          label: 'Paga',
                          value: formatCurrency(paga),
                          color: clx.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  for (final c in items) ...[
                    _ComissaoExtratoTile(
                      item: c,
                      profNome: _nomeProf(profs.asData?.value, c.profissional),
                      onMarcarPaga: c.status == ComissaoStatus.pendente
                          ? () async {
                              try {
                                await ref
                                    .read(comissaoRepositoryProvider)
                                    .marcarPaga(c.id);
                                ref.invalidate(_comissoesExtratoProvider);
                                if (context.mounted) {
                                  showClxToast(
                                    context,
                                    'Comissão marcada como paga.',
                                    type: ToastType.success,
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  showClxToast(
                                    context,
                                    'Falha ao atualizar comissão.',
                                    type: ToastType.error,
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: ClxSpace.x2),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: ClxSpace.x8),
        ],
      ),
    );
  }

  String _nomeProf(List<User>? list, String id) {
    if (list == null) return id;
    for (final u in list) {
      if (u.id == id) return u.displayName;
    }
    return id;
  }
}

class _KpiMini extends StatelessWidget {
  const _KpiMini({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: clx.ink2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfComissaoCard extends ConsumerStatefulWidget {
  const _ProfComissaoCard({required this.user, required this.onSaved});

  final User user;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ProfComissaoCard> createState() => _ProfComissaoCardState();
}

class _ProfComissaoCardState extends ConsumerState<_ProfComissaoCard> {
  late ComissaoTipo _tipo;
  late TextEditingController _valor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.user.comissaoTipo;
    _valor = TextEditingController(
      text: widget.user.comissaoValor > 0
          ? (widget.user.comissaoValor ==
                    widget.user.comissaoValor.roundToDouble()
                ? widget.user.comissaoValor.toStringAsFixed(0)
                : widget.user.comissaoValor.toStringAsFixed(2))
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant _ProfComissaoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.comissaoTipo != widget.user.comissaoTipo ||
        oldWidget.user.comissaoValor != widget.user.comissaoValor) {
      _tipo = widget.user.comissaoTipo;
      _valor.text = widget.user.comissaoValor > 0
          ? widget.user.comissaoValor.toStringAsFixed(
              widget.user.comissaoValor ==
                      widget.user.comissaoValor.roundToDouble()
                  ? 0
                  : 2,
            )
          : '';
    }
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _valor.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw) ?? 0;
    if (_tipo != ComissaoTipo.nenhuma && v <= 0) {
      showClxToast(
        context,
        'Informe um valor maior que zero.',
        type: ToastType.warning,
      );
      return;
    }
    if (_tipo == ComissaoTipo.percentual && v > 100) {
      showClxToast(
        context,
        'Percentual deve ser no máximo 100.',
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(comissaoRepositoryProvider)
          .setComissao(
            profissionalId: widget.user.id,
            tipo: _tipo,
            valor: _tipo == ComissaoTipo.nenhuma ? 0 : v,
          );
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível salvar a comissão.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final u = widget.user;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: clx.primary.withValues(alpha: 0.12),
                child: Text(
                  u.displayName.isNotEmpty
                      ? u.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: clx.primary,
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
                      u.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      u.email,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                    ),
                  ],
                ),
              ),
              if (u.hasComissaoAtiva)
                ClxChip(label: u.comissaoResumo, color: clx.success),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          DropdownButtonFormField<ComissaoTipo>(
            // ignore: deprecated_member_use
            value: _tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo de comissão',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final t in ComissaoTipo.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: _saving
                ? null
                : (t) {
                    if (t != null) setState(() => _tipo = t);
                  },
          ),
          if (_tipo != ComissaoTipo.nenhuma) ...[
            const SizedBox(height: ClxSpace.x3),
            TextField(
              controller: _valor,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: _tipo == ComissaoTipo.percentual
                    ? 'Percentual (%)'
                    : 'Valor fixo (R\$)',
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: _tipo == ComissaoTipo.percentual ? 'ex: 10' : 'ex: 30',
              ),
            ),
          ],
          const SizedBox(height: ClxSpace.x3),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComissaoExtratoTile extends StatelessWidget {
  const _ComissaoExtratoTile({
    required this.item,
    required this.profNome,
    this.onMarcarPaga,
  });

  final ProfComissao item;
  final String profNome;
  final VoidCallback? onMarcarPaga;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final dataLabel = item.data != null && item.data!.isNotEmpty
        ? formatDate(item.data!)
        : '—';
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.descricao.isNotEmpty ? item.descricao : 'Comissão OS',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              ClxChip(
                label: item.status.label,
                color: item.status == ComissaoStatus.paga
                    ? clx.success
                    : clx.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$profNome · $dataLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink2),
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            formatCurrency(item.valorComissao),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.primary,
            ),
          ),
          Text(
            'OS ${formatCurrency(item.valorOs)} · '
            '${item.tipoAplicado == ComissaoTipo.percentual ? '${item.baseValor}%' : 'fixo'}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink2),
          ),
          if (onMarcarPaga != null) ...[
            const SizedBox(height: ClxSpace.x2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMarcarPaga,
                child: const Text('Marcar como paga'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
