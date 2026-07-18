/// fin_comissoes_screen.dart — Dashboard de comissões (estilo Organizze).
///
/// KPIs (em aberto / pagas / total) + gráfico por profissional + lista com
/// toggle mãozinha (👍 verde = paga, 👎 cinza = pendente). Config de %/fixo
/// abre pela engrenagem no topo (menu flutuante). Clique no KPI ou barra do
/// profissional abre sheet filtrado.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../data/painel_providers.dart';
import 'charts/fin_charts.dart';

/// Percentual legível (F-230): 10.0 → "10%", 12.5 → "12,5%".
String formatPercent(double v) {
  final texto = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toString().replaceAll('.', ',');
  return '$texto%';
}

final _comissoesProfissionaisProvider = FutureProvider.autoDispose<List<User>>((
  ref,
) {
  return ref.watch(comissaoRepositoryProvider).listProfissionais();
});

final _comissoesExtratoProvider =
    FutureProvider.autoDispose<List<ProfComissao>>((ref) {
      return ref.watch(comissaoRepositoryProvider).listComissoes();
    });

/// Filtro do sheet flutuante (null = todos).
enum _FiltroSheet { abertas, pagas, todas }

class FinComissoesScreen extends ConsumerWidget {
  const FinComissoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final profs = ref.watch(_comissoesProfissionaisProvider);
    final extrato = ref.watch(_comissoesExtratoProvider);
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_comissoesProfissionaisProvider);
        ref.invalidate(_comissoesExtratoProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          narrow ? ClxSpace.x4 : ClxSpace.x5,
          ClxSpace.x4,
          narrow ? ClxSpace.x4 : ClxSpace.x5,
          ClxSpace.x8,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comissões',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.ink,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x1),
                    Text(
                      'Toque na mãozinha para marcar como paga (👍 verde) ou reabrir (👎 cinza). '
                      'Pagar gera despesa no financeiro; reabrir estorna.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              IconButton(
                tooltip: 'Configurar comissão',
                onPressed: () => _openConfigSheet(context),
                icon: Icon(Icons.settings_rounded, color: clx.ink2),
                style: IconButton.styleFrom(
                  backgroundColor: clx.bg2,
                  side: BorderSide(color: clx.line),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x4),
          extrato.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(ClxSpace.x8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner(
              message: 'Não foi possível carregar o extrato.',
              onRetry: () => ref.invalidate(_comissoesExtratoProvider),
            ),
            data: (items) {
              final profList = profs.asData?.value ?? const <User>[];
              return _Dashboard(
                items: items,
                profs: profList,
                narrow: narrow,
                onToggle: (c) => _toggleStatus(context, ref, c),
                onOpenSheet: (filtro, {String? profId}) => _openSheet(
                  context,
                  ref,
                  items: items,
                  profs: profList,
                  filtro: filtro,
                  profId: profId,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openConfigSheet(BuildContext context) {
    _showCenteredBlurDialog(
      context: context,
      child: const _ConfigSheet(),
    );
  }

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    ProfComissao c,
  ) async {
    final next = c.status == ComissaoStatus.paga
        ? ComissaoStatus.pendente
        : ComissaoStatus.paga;
    try {
      await ref.read(comissaoRepositoryProvider).setStatus(c.id, next);
      ref.invalidate(_comissoesExtratoProvider);
      if (!context.mounted) return;
      showClxToast(
        context,
        next == ComissaoStatus.paga
            ? 'Comissão marcada como paga.'
            : 'Comissão reaberta (pendente).',
        type: ToastType.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      showClxToast(
        context,
        'Falha ao atualizar comissão.',
        type: ToastType.error,
      );
    }
  }

  void _openSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<ProfComissao> items,
    required List<User> profs,
    required _FiltroSheet filtro,
    String? profId,
  }) {
    _showCenteredBlurDialog(
      context: context,
      child: _ComissaoSheet(
        filtroInicial: filtro,
        profId: profId,
        onToggle: (c) => _toggleStatus(context, ref, c),
      ),
    );
  }
}

/// Dialog centralizado com fundo escurecido + blur (menus flutuantes).
Future<T?> _showCenteredBlurDialog<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, _) {
      final size = MediaQuery.sizeOf(ctx);
      final maxW = size.width < 640 ? size.width - 32 : 560.0;
      final maxH = size.height * 0.86;
      return Stack(
        fit: StackFit.expand,
        children: [
          // Fundo desfocado + escurecido
          GestureDetector(
            onTap: () => Navigator.of(ctx).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          // Card central
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                  minWidth: size.width < 400 ? size.width - 32 : 320,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/* ─────────────────────── dashboard ─────────────────────── */

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.items,
    required this.profs,
    required this.narrow,
    required this.onToggle,
    required this.onOpenSheet,
  });

  final List<ProfComissao> items;
  final List<User> profs;
  final bool narrow;
  final Future<void> Function(ProfComissao) onToggle;
  final void Function(_FiltroSheet filtro, {String? profId}) onOpenSheet;

  String nomeProf(String id) {
    for (final u in profs) {
      if (u.id == id) return u.displayName;
    }
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  String shortName(String full) {
    final p = full.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '—';
    if (p.length == 1) return p.first;
    return '${p.first} ${p.last[0]}.';
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final abertas = items
        .where((c) => c.status == ComissaoStatus.pendente)
        .toList();
    final pagas = items.where((c) => c.status == ComissaoStatus.paga).toList();
    final totalAberto = abertas.fold<double>(0, (s, c) => s + c.valorComissao);
    final totalPago = pagas.fold<double>(0, (s, c) => s + c.valorComissao);
    final total = totalAberto + totalPago;

    // Agregado por profissional (total comissão).
    final byProf = <String, ({double aberto, double pago, String nome})>{};
    for (final c in items) {
      final id = c.profissional;
      final cur = byProf[id] ??
          (aberto: 0.0, pago: 0.0, nome: nomeProf(id));
      if (c.status == ComissaoStatus.paga) {
        byProf[id] = (
          aberto: cur.aberto,
          pago: cur.pago + c.valorComissao,
          nome: cur.nome,
        );
      } else {
        byProf[id] = (
          aberto: cur.aberto + c.valorComissao,
          pago: cur.pago,
          nome: cur.nome,
        );
      }
    }
    final profEntries = byProf.entries.toList()
      ..sort(
        (a, b) =>
            (b.value.aberto + b.value.pago).compareTo(a.value.aberto + a.value.pago),
      );

    final series = finSeriesColors(context, profEntries.length);
    final slices = [
      for (var i = 0; i < profEntries.length; i++)
        FinSlice(
          label: shortName(profEntries[i].value.nome),
          value: profEntries[i].value.aberto + profEntries[i].value.pago,
          color: series[i],
        ),
    ];

    final kpis = [
      _KpiTap(
        label: 'Em aberto',
        value: formatCurrency(totalAberto),
        hint: '${abertas.length} comissão${abertas.length == 1 ? '' : 'ões'}',
        color: clx.warning,
        icon: Icons.schedule_rounded,
        onTap: () => onOpenSheet(_FiltroSheet.abertas),
      ),
      _KpiTap(
        label: 'Pagas',
        value: formatCurrency(totalPago),
        hint: '${pagas.length} comissão${pagas.length == 1 ? '' : 'ões'}',
        color: clx.success,
        icon: Icons.thumb_up_alt_rounded,
        onTap: () => onOpenSheet(_FiltroSheet.pagas),
      ),
      _KpiTap(
        label: 'Total',
        value: formatCurrency(total),
        hint: '${items.length} no extrato',
        color: clx.primary,
        icon: Icons.payments_outlined,
        onTap: () => onOpenSheet(_FiltroSheet.todas),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (narrow)
          Column(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                if (i > 0) const SizedBox(height: ClxSpace.x3),
                kpis[i],
              ],
            ],
          )
        else
          Row(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                if (i > 0) const SizedBox(width: ClxSpace.x3),
                Expanded(child: kpis[i]),
              ],
            ],
          ),
        const SizedBox(height: ClxSpace.x4),
        ClxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Por profissional',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: clx.ink,
                ),
              ),
              const SizedBox(height: ClxSpace.x1),
              Text(
                'Toque na legenda para ver o extrato daquele profissional.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: clx.ink3),
              ),
              const SizedBox(height: ClxSpace.x4),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
                  child: Center(
                    child: Text(
                      'Nenhuma comissão ainda. Elas surgem ao concluir OS '
                      'de profissionais com comissão ativa.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                  ),
                )
              else if (slices.every((s) => s.value <= 0))
                const SizedBox.shrink()
              else
                FinDonutChart(slices: slices, centerLabel: 'Comissões'),
              if (profEntries.isNotEmpty) ...[
                const SizedBox(height: ClxSpace.x4),
                for (var i = 0; i < profEntries.length; i++)
                  _ProfBarRow(
                    nome: profEntries[i].value.nome,
                    aberto: profEntries[i].value.aberto,
                    pago: profEntries[i].value.pago,
                    color: series[i],
                    onTap: () => onOpenSheet(
                      _FiltroSheet.todas,
                      profId: profEntries[i].key,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x4),
        Text(
          'Extrato por profissional',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: clx.ink,
          ),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          'Profissionais que recebem comissão. Toque para ver o extrato.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: clx.ink3),
        ),
        const SizedBox(height: ClxSpace.x3),
        ..._buildProfExtratoList(
          context: context,
          clx: clx,
          items: items,
          profs: profs,
          byProf: byProf,
          onOpenSheet: onOpenSheet,
        ),
      ],
    );
  }

  /// Profissionais com comissão ativa OU com lançamentos no extrato.
  List<Widget> _buildProfExtratoList({
    required BuildContext context,
    required CleanoxColors clx,
    required List<ProfComissao> items,
    required List<User> profs,
    required Map<String, ({double aberto, double pago, String nome})> byProf,
    required void Function(_FiltroSheet filtro, {String? profId}) onOpenSheet,
  }) {
    final ids = <String>{};
    for (final u in profs) {
      if (u.hasComissaoAtiva) ids.add(u.id);
    }
    for (final c in items) {
      if (c.profissional.isNotEmpty) ids.add(c.profissional);
    }

    if (ids.isEmpty) {
      return [
        ClxCard(
          child: Text(
            'Nenhum profissional com comissão ativa. '
            'Configure pela engrenagem ⚙️.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
          ),
        ),
      ];
    }

    User? findUser(String id) {
      for (final u in profs) {
        if (u.id == id) return u;
      }
      return null;
    }

    final rows = ids.map((id) {
      final u = findUser(id);
      final agg = byProf[id];
      final nome = u?.displayName ?? agg?.nome ?? nomeProf(id);
      final aberto = agg?.aberto ?? 0.0;
      final pago = agg?.pago ?? 0.0;
      final nAbertas = items
          .where(
            (c) =>
                c.profissional == id && c.status == ComissaoStatus.pendente,
          )
          .length;
      final nPagas = items
          .where(
            (c) => c.profissional == id && c.status == ComissaoStatus.paga,
          )
          .length;
      return (
        id: id,
        nome: nome,
        email: u?.email ?? '',
        resumo: u?.comissaoResumo ?? '',
        ativo: u?.hasComissaoAtiva ?? false,
        aberto: aberto,
        pago: pago,
        nAbertas: nAbertas,
        nPagas: nPagas,
        total: aberto + pago,
      );
    }).toList()
      ..sort((a, b) {
        final t = b.total.compareTo(a.total);
        if (t != 0) return t;
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });

    return [
      for (final r in rows) ...[
        _ProfExtratoCard(
          nome: r.nome,
          email: r.email,
          resumo: r.resumo,
          ativo: r.ativo,
          aberto: r.aberto,
          pago: r.pago,
          nAbertas: r.nAbertas,
          nPagas: r.nPagas,
          onTap: () => onOpenSheet(_FiltroSheet.todas, profId: r.id),
        ),
        const SizedBox(height: ClxSpace.x2),
      ],
    ];
  }
}

class _ProfExtratoCard extends StatelessWidget {
  const _ProfExtratoCard({
    required this.nome,
    required this.email,
    required this.resumo,
    required this.ativo,
    required this.aberto,
    required this.pago,
    required this.nAbertas,
    required this.nPagas,
    required this.onTap,
  });

  final String nome;
  final String email;
  final String resumo;
  final bool ativo;
  final double aberto;
  final double pago;
  final int nAbertas;
  final int nPagas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final total = aberto + pago;
    final inicial = nome.trim().isNotEmpty ? nome.trim()[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rLg,
        child: ClxCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: clx.primary.withValues(alpha: 0.14),
                child: Text(
                  inicial,
                  style: TextStyle(
                    color: clx.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: clx.ink,
                                ),
                          ),
                        ),
                        if (resumo.isNotEmpty) ...[
                          const SizedBox(width: ClxSpace.x2),
                          ClxChip(
                            label: resumo,
                            color: ativo ? clx.success : clx.ink3,
                          ),
                        ],
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Em aberto ${formatCurrency(aberto)}'
                      '${nAbertas > 0 ? ' ($nAbertas)' : ''}'
                      ' · Pagas ${formatCurrency(pago)}'
                      '${nPagas > 0 ? ' ($nPagas)' : ''}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(total),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: clx.ink,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: clx.ink3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiTap extends StatelessWidget {
  const _KpiTap({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rLg,
        child: ClxCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: ClxRadii.rMd,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: clx.ink2),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      hint,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: clx.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfBarRow extends StatelessWidget {
  const _ProfBarRow({
    required this.nome,
    required this.aberto,
    required this.pago,
    required this.color,
    required this.onTap,
  });

  final String nome;
  final double aberto;
  final double pago;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final total = aberto + pago;
    if (total <= 0) return const SizedBox.shrink();
    final pctPago = pago / total;
    final pctAberto = aberto / total;

    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: clx.ink,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(total),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: ClxRadii.rSm,
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (pctPago > 0)
                      Expanded(
                        flex: (pctPago * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: clx.success),
                      ),
                    if (pctAberto > 0)
                      Expanded(
                        flex: (pctAberto * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: color.withValues(alpha: 0.45)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pagas ${formatCurrency(pago)} · Em aberto ${formatCurrency(aberto)}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: clx.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── linha do extrato (mãozinha) ─────────────────────── */

class _ComissaoRow extends StatelessWidget {
  const _ComissaoRow({
    required this.item,
    required this.profNome,
    required this.onToggle,
  });

  final ProfComissao item;
  final String profNome;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final paga = item.status == ComissaoStatus.paga;
    final dataLabel = item.data != null && item.data!.isNotEmpty
        ? formatDate(item.data!)
        : '—';
    final titulo = item.descricao.isNotEmpty ? item.descricao : 'Comissão OS';

    return ClxCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mãozinha Organizze: 👍 verde = paga · 👎 cinza = em aberto
          Tooltip(
            message: paga
                ? 'Paga — toque para reabrir'
                : 'Pendente — toque para marcar como paga',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: paga
                        ? clx.success.withValues(alpha: 0.14)
                        : clx.ink3.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    paga
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_down_alt_rounded,
                    color: paga ? clx.success : clx.ink3,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: clx.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$profNome · $dataLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                ),
                Text(
                  'OS ${formatCurrency(item.valorOs)} · '
                  '${item.tipoAplicado == ComissaoTipo.percentual ? formatPercent(item.baseValor) : 'fixo'}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.valorComissao),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: paga ? clx.success : clx.warning,
                ),
              ),
              Text(
                paga ? 'Paga' : 'Em aberto',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: paga ? clx.success : clx.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── sheet flutuante ─────────────────────── */

class _ComissaoSheet extends ConsumerStatefulWidget {
  const _ComissaoSheet({
    required this.filtroInicial,
    required this.onToggle,
    this.profId,
  });

  final _FiltroSheet filtroInicial;
  final String? profId;
  final Future<void> Function(ProfComissao) onToggle;

  @override
  ConsumerState<_ComissaoSheet> createState() => _ComissaoSheetState();
}

class _ComissaoSheetState extends ConsumerState<_ComissaoSheet> {
  late _FiltroSheet _filtro;

  @override
  void initState() {
    super.initState();
    _filtro = widget.filtroInicial;
  }

  String _nome(List<User> profs, String id) {
    for (final u in profs) {
      if (u.id == id) return u.displayName;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final items = ref.watch(_comissoesExtratoProvider).valueOrNull ?? const [];
    final profs =
        ref.watch(_comissoesProfissionaisProvider).valueOrNull ?? const [];

    var list = items;
    if (widget.profId != null) {
      list = list.where((c) => c.profissional == widget.profId).toList();
    }
    list = switch (_filtro) {
      _FiltroSheet.abertas =>
        list.where((c) => c.status == ComissaoStatus.pendente).toList(),
      _FiltroSheet.pagas =>
        list.where((c) => c.status == ComissaoStatus.paga).toList(),
      _FiltroSheet.todas => list,
    };

    final titulo = widget.profId != null
        ? _nome(profs, widget.profId!)
        : switch (_filtro) {
            _FiltroSheet.abertas => 'Comissões em aberto',
            _FiltroSheet.pagas => 'Comissões pagas',
            _FiltroSheet.todas => 'Todas as comissões',
          };

    return Container(
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: clx.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x5,
              ClxSpace.x4,
              ClxSpace.x3,
              ClxSpace.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: clx.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded),
                  color: clx.ink2,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: ClxSpace.x2,
                children: [
                  for (final f in _FiltroSheet.values)
                    ChoiceChip(
                      label: Text(switch (f) {
                        _FiltroSheet.abertas => 'Em aberto',
                        _FiltroSheet.pagas => 'Pagas',
                        _FiltroSheet.todas => 'Todas',
                      }),
                      selected: _filtro == f,
                      onSelected: (_) => setState(() => _filtro = f),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          Flexible(
            child: list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(ClxSpace.x6),
                    child: Text(
                      'Nenhuma comissão neste filtro.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      ClxSpace.x5,
                      0,
                      ClxSpace.x5,
                      ClxSpace.x5,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: ClxSpace.x2),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return _ComissaoRow(
                        item: c,
                        profNome: _nome(profs, c.profissional),
                        onToggle: () => widget.onToggle(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── config (engrenagem → sheet) ─────────────────────── */

class _ConfigSheet extends ConsumerWidget {
  const _ConfigSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final profsAsync = ref.watch(_comissoesProfissionaisProvider);

    return Container(
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: clx.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x5,
              ClxSpace.x4,
              ClxSpace.x3,
              ClxSpace.x2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equipe · comissão e pagamento',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: clx.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '% / fixo por OS, diária por dia trabalhado e ciclo de repasse',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded),
                  color: clx.ink2,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: clx.line),
          Flexible(
            child: profsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(ClxSpace.x8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(ClxSpace.x5),
                child: ErrorBanner(
                  message: 'Não foi possível carregar profissionais.',
                  onRetry: () =>
                      ref.invalidate(_comissoesProfissionaisProvider),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'Nenhum profissional',
                    message: 'Cadastre profissionais em Usuários.',
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    ClxSpace.x5,
                    ClxSpace.x4,
                    ClxSpace.x5,
                    ClxSpace.x5,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: ClxSpace.x3),
                  itemBuilder: (_, i) {
                    final u = list[i];
                    return _ProfComissaoCard(
                      user: u,
                      onSaved: () {
                        ref.invalidate(_comissoesProfissionaisProvider);
                        showClxToast(
                          context,
                          'Comissão atualizada.',
                          type: ToastType.success,
                        );
                      },
                    );
                  },
                );
              },
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
  late PagamentoFrequencia? _freq;
  late int _dia;
  late int _dia2;
  late TextEditingController _valor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.user.comissaoTipo;
    _freq = widget.user.pagamentoFrequencia ?? PagamentoFrequencia.quinzenal;
    _dia = widget.user.pagamentoDia;
    _dia2 = widget.user.pagamentoDia2;
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
        oldWidget.user.comissaoValor != widget.user.comissaoValor ||
        oldWidget.user.pagamentoFrequencia !=
            widget.user.pagamentoFrequencia ||
        oldWidget.user.pagamentoDia != widget.user.pagamentoDia ||
        oldWidget.user.pagamentoDia2 != widget.user.pagamentoDia2) {
      _tipo = widget.user.comissaoTipo;
      _freq = widget.user.pagamentoFrequencia ?? PagamentoFrequencia.quinzenal;
      _dia = widget.user.pagamentoDia;
      _dia2 = widget.user.pagamentoDia2;
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

  String get _valorLabel => switch (_tipo) {
    ComissaoTipo.percentual => 'Percentual (%)',
    ComissaoTipo.diaria => 'Valor da diária (R\$)',
    ComissaoTipo.fixo => 'Valor fixo por OS (R\$)',
    ComissaoTipo.nenhuma => 'Valor',
  };

  String get _valorHint => switch (_tipo) {
    ComissaoTipo.percentual => 'ex: 30',
    ComissaoTipo.diaria => 'ex: 150',
    _ => 'ex: 50',
  };

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
    if (_tipo != ComissaoTipo.nenhuma && _freq == null) {
      showClxToast(
        context,
        'Escolha a frequência de pagamento.',
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
            pagamentoFrequencia:
                _tipo == ComissaoTipo.nenhuma ? null : _freq,
            pagamentoDia: _tipo == ComissaoTipo.nenhuma ? 0 : _dia,
            pagamentoDia2: _tipo == ComissaoTipo.nenhuma ? 0 : _dia2,
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
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        border: Border.all(color: clx.line),
        borderRadius: ClxRadii.rLg,
      ),
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
                ClxChip(
                  label:
                      '${u.comissaoResumo}'
                      '${u.pagamentoFrequencia != null ? ' · ${u.pagamentoFrequencia!.label}' : ''}',
                  color: clx.success,
                ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          DropdownButtonFormField<ComissaoTipo>(
            // ignore: deprecated_member_use
            value: _tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo de remuneração',
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: _valorLabel,
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: _valorHint,
                helperText: _tipo == ComissaoTipo.diaria
                    ? '1 diária por dia BRT com pelo menos 1 OS concluída'
                    : null,
              ),
            ),
            const SizedBox(height: ClxSpace.x3),
            DropdownButtonFormField<PagamentoFrequencia>(
              // ignore: deprecated_member_use
              value: _freq,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento (repasse)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final f in PagamentoFrequencia.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: _saving
                  ? null
                  : (f) {
                      if (f != null) {
                        setState(() {
                          _freq = f;
                          // Defaults sensatos ao trocar o ciclo.
                          if (f == PagamentoFrequencia.semanal &&
                              (_dia < 1 || _dia > 7)) {
                            _dia = 5; // sexta
                          }
                          if (f == PagamentoFrequencia.mensal &&
                              (_dia < 1 || _dia > 31)) {
                            _dia = 1;
                          }
                          if (f == PagamentoFrequencia.quinzenal) {
                            if (_dia < 1 || _dia > 31) _dia = 15;
                            // 0 = último dia do mês
                          }
                        });
                      }
                    },
            ),
            if (_freq == PagamentoFrequencia.semanal) ...[
              const SizedBox(height: ClxSpace.x3),
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                value: (_dia >= 1 && _dia <= 7) ? _dia : 5,
                decoration: const InputDecoration(
                  labelText: 'Dia do pagamento (semana)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Segunda')),
                  DropdownMenuItem(value: 2, child: Text('Terça')),
                  DropdownMenuItem(value: 3, child: Text('Quarta')),
                  DropdownMenuItem(value: 4, child: Text('Quinta')),
                  DropdownMenuItem(value: 5, child: Text('Sexta')),
                  DropdownMenuItem(value: 6, child: Text('Sábado')),
                  DropdownMenuItem(value: 7, child: Text('Domingo')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _dia = v);
                      },
              ),
            ],
            if (_freq == PagamentoFrequencia.mensal) ...[
              const SizedBox(height: ClxSpace.x3),
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                value: (_dia >= 1 && _dia <= 31) ? _dia : 1,
                decoration: const InputDecoration(
                  labelText: 'Dia do pagamento (mês)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Se o mês não tiver o dia, usa o último dia',
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _dia = v);
                      },
              ),
            ],
            if (_freq == PagamentoFrequencia.quinzenal) ...[
              const SizedBox(height: ClxSpace.x3),
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                value: (_dia >= 1 && _dia <= 31) ? _dia : 15,
                decoration: const InputDecoration(
                  labelText: '1º corte da quinzena',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (var d = 1; d <= 28; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _dia = v);
                      },
              ),
              const SizedBox(height: ClxSpace.x3),
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                value: _dia2,
                decoration: const InputDecoration(
                  labelText: '2º corte da quinzena',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Último dia = 30/31 conforme o mês',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Último dia do mês'),
                  ),
                  for (var d = 16; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _dia2 = v);
                      },
              ),
            ],
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
