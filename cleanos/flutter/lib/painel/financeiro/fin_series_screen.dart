/// fin_series_screen.dart — Lista de despesas/receitas fixas (regras ativas).
///
/// Uma linha por `fin_series`: ver ativas, pausar, retomar, encerrar, editar valor.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_form_kit.dart';
import 'fin_providers.dart';
import 'fin_recorrencia.dart';
import 'fin_serie_actions.dart';
import 'ui/fin_ui.dart';

class FinSeriesScreen extends ConsumerWidget {
  const FinSeriesScreen({super.key});

  Future<void> _editSerie(
    BuildContext context,
    WidgetRef ref,
    FinSerie s,
  ) async {
    final ok = await showFinModal<bool>(
      context,
      _SerieEditForm(serie: s),
    );
    if (ok == true) {
      ref.invalidate(finSeriesProvider);
      await refreshAfterSerieMutation(ref);
      if (context.mounted) {
        showClxToast(context, 'Cobrança atualizada.', type: ToastType.success);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final async = ref.watch(finSeriesProvider);
    final cats = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final catById = {for (final c in cats) c.id: c};
    final contaById = {for (final c in contas) c.id: c};

    return ColoredBox(
      color: clx.bg2,
      child: async.when(
        loading: () => const Center(child: Spinner(size: 28)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(
              message: finErrorMessage(
                e,
                fallback:
                    'Erro ao carregar cobranças fixas. '
                    'Confira se a migration fin_series está aplicada.',
              ),
              onRetry: () => ref.invalidate(finSeriesProvider),
            ),
          ),
        ),
        data: (list) {
          final ativas =
              list.where((s) => s.status == FinSerieStatus.ativa).toList();
          final pausadas =
              list.where((s) => s.status == FinSerieStatus.pausada).toList();
          final encerradas =
              list.where((s) => s.status == FinSerieStatus.encerrada).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              Text(
                'Cobranças fixas',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: ClxSpace.x2),
              Text(
                'Despesas e receitas que se repetem (aluguel, internet, software…). '
                'Aqui você vê o que está ativo e pode pausar ou encerrar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: clx.ink3,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: ClxSpace.x5),
              if (list.isEmpty)
                const FinEmptyCta(
                  icon: Icons.autorenew_rounded,
                  message: 'Nenhuma cobrança fixa cadastrada.',
                  hint:
                      'Ao criar um lançamento no extrato, marque “é uma despesa fixa” '
                      'para ela aparecer aqui.',
                )
              else ...[
                _SectionHeader(
                  title: 'Ativas',
                  count: ativas.length,
                  color: clx.success,
                ),
                if (ativas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Nenhuma ativa no momento.',
                      style: TextStyle(color: clx.ink3),
                    ),
                  )
                else
                  for (final s in ativas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SerieCard(
                        serie: s,
                        categoria: catById[s.categoriaId],
                        conta: contaById[s.contaId],
                        onEdit: () => _editSerie(context, ref, s),
                        onPausar: () => pausarSerieUi(context, ref, s),
                        onRetomar: null,
                        onEncerrar: () => encerrarSerieUi(context, ref, s),
                      ),
                    ),
                if (pausadas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: 'Pausadas',
                    count: pausadas.length,
                    color: clx.warning,
                  ),
                  for (final s in pausadas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SerieCard(
                        serie: s,
                        categoria: catById[s.categoriaId],
                        conta: contaById[s.contaId],
                        onEdit: () => _editSerie(context, ref, s),
                        onPausar: null,
                        onRetomar: () => retomarSerieUi(context, ref, s),
                        onEncerrar: () => encerrarSerieUi(context, ref, s),
                      ),
                    ),
                ],
                if (encerradas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: 'Encerradas',
                    count: encerradas.length,
                    color: clx.ink3,
                  ),
                  for (final s in encerradas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SerieCard(
                        serie: s,
                        categoria: catById[s.categoriaId],
                        conta: contaById[s.contaId],
                        onEdit: () => _editSerie(context, ref, s),
                        onPausar: null,
                        onRetomar: () => retomarSerieUi(context, ref, s),
                        onEncerrar: null,
                      ),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SerieCard extends StatelessWidget {
  const _SerieCard({
    required this.serie,
    this.categoria,
    this.conta,
    required this.onEdit,
    this.onPausar,
    this.onRetomar,
    this.onEncerrar,
  });

  final FinSerie serie;
  final FinCategoria? categoria;
  final FinConta? conta;
  final VoidCallback onEdit;
  final VoidCallback? onPausar;
  final VoidCallback? onRetomar;
  final VoidCallback? onEncerrar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final s = serie;
    final isReceita = s.tipo == TipoLancamento.receita;
    final statusColor = switch (s.status) {
      FinSerieStatus.ativa => clx.success,
      FinSerieStatus.pausada => clx.warning,
      FinSerieStatus.encerrada => clx.ink3,
    };

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.status.label,
                  style: tt.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isReceita ? clx.success : clx.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isReceita ? 'Receita' : 'Despesa',
                  style: tt.labelSmall?.copyWith(
                    color: isReceita ? clx.success : clx.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                s.frequenciaEfetiva.labelSingular,
                style: tt.labelMedium?.copyWith(color: clx.ink3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.descricao.isEmpty ? '(sem descrição)' : s.descricao,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(s.valor),
            style: tt.titleLarge?.copyWith(
              color: isReceita ? clx.success : clx.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (categoria != null) categoria!.nome,
              if (conta != null) conta!.nome,
              if (s.dataInicio.isNotEmpty)
                'desde ${formatDateOnlyBr(s.dataInicio)}',
              if (s.dataFim != null && s.dataFim!.isNotEmpty)
                'até ${formatDateOnlyBr(s.dataFim!)}',
            ].where((e) => e.isNotEmpty).join(' · '),
            style: tt.bodySmall?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
              if (onPausar != null)
                OutlinedButton.icon(
                  onPressed: onPausar,
                  icon: const Icon(Icons.pause_circle_outline, size: 16),
                  label: const Text('Pausar'),
                ),
              if (onRetomar != null)
                FilledButton.tonalIcon(
                  onPressed: onRetomar,
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('Retomar'),
                ),
              if (onEncerrar != null)
                OutlinedButton.icon(
                  onPressed: onEncerrar,
                  style: OutlinedButton.styleFrom(foregroundColor: clx.error),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Encerrar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Edita a regra (descrição, valor, conta, categoria, frequência, data fim).
/// Ocorrências não pagas recebem o template; se a frequência mudar, o calendário
/// de previstos é refeito (pagos ficam).
class _SerieEditForm extends ConsumerStatefulWidget {
  const _SerieEditForm({required this.serie});
  final FinSerie serie;

  @override
  ConsumerState<_SerieEditForm> createState() => _SerieEditFormState();
}

class _SerieEditFormState extends ConsumerState<_SerieEditForm> {
  late final TextEditingController _desc;
  late final TextEditingController _valor;
  late final TextEditingController _dataFim;
  String? _contaId;
  String? _categoriaId;
  late FrequenciaRecorrencia _frequencia;
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final s = widget.serie;
    _desc = TextEditingController(text: s.descricao);
    _valor = TextEditingController(
      text: s.valor.toStringAsFixed(2).replaceAll('.', ','),
    );
    _dataFim = TextEditingController(text: s.dataFim ?? '');
    _contaId = s.contaId.isEmpty ? null : s.contaId;
    _categoriaId = s.categoriaId.isEmpty ? null : s.categoriaId;
    _frequencia = s.frequenciaEfetiva;
  }

  @override
  void dispose() {
    _desc.dispose();
    _valor.dispose();
    _dataFim.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = parseMoedaBr(_valor.text);
    if (_desc.text.trim().isEmpty || v == null || v <= 0) {
      setState(() => _err = 'Descrição e valor válidos são obrigatórios.');
      return;
    }
    final fimRaw = _dataFim.text.trim();
    if (fimRaw.isNotEmpty) {
      final okFim = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fimRaw) &&
          parseYmdLocal(fimRaw) != null;
      if (!okFim) {
        setState(() => _err = 'Data fim inválida. Use AAAA-MM-DD ou deixe vazio.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final body = <String, dynamic>{
        'descricao': _desc.text.trim(),
        'valor': v,
        'conta_id': _contaId ?? widget.serie.contaId,
        'categoria_id': _categoriaId ?? widget.serie.categoriaId,
        'frequencia': _frequencia.wire,
        'data_fim': fimRaw,
      };
      // Propaga template; se frequência mudou, recria calendário de não-pagos.
      await ref
          .read(financeiroRepositoryProvider)
          .updateSeriePropagando(widget.serie.id, body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _err = finErrorMessage(e, fallback: 'Falha ao salvar.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final cats = (ref.watch(finCategoriasProvider).valueOrNull ?? const [])
        .where((c) => c.parentId == null && !c.arquivada)
        .where((c) => c.tipo == widget.serie.tipo)
        .toList();

    return FinModalScaffold(
      title: 'Editar cobrança fixa',
      onSave: _saving ? () {} : _save,
      saving: _saving,
      error: _err,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Descrição'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valor,
            decoration: const InputDecoration(
              labelText: 'Valor (R\$)',
              hintText: '0,00',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FrequenciaRecorrencia>(
            // ignore: deprecated_member_use
            value: _frequencia,
            decoration: const InputDecoration(
              labelText: 'Frequência',
              helperText: 'Diário, semanal, quinzenal, mensal…',
            ),
            items: [
              for (final f in FrequenciaRecorrencia.values)
                DropdownMenuItem(
                  value: f,
                  child: Text(f.labelSingular),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _frequencia = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _contaId,
            decoration: const InputDecoration(labelText: 'Conta'),
            items: [
              for (final c in contas)
                DropdownMenuItem(value: c.id, child: Text(c.nome)),
            ],
            onChanged: (v) => setState(() => _contaId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _categoriaId,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final c in cats)
                DropdownMenuItem(value: c.id, child: Text(c.nome)),
            ],
            onChanged: (v) => setState(() => _categoriaId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dataFim,
            decoration: const InputDecoration(
              labelText: 'Data fim (AAAA-MM-DD, opcional)',
              hintText: 'Vazio = sem data fim',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ao mudar a frequência, os lançamentos ainda não pagos são '
            'recalculados. Os já pagos permanecem no extrato.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.clx.ink3,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
