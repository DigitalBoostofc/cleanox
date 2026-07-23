/// lancamento_detail_panel.dart — Painel de detalhes de um Lançamento.
///
/// Espelha `LancamentoDetailPanel.tsx`: painel lateral (à direita) em telas
/// largas, bottom-sheet no mobile. Mostra categoria, valor, conta, data/venc,
/// recorrência, parcelas, status, vínculo com OS, observação, anexos e tags, com
/// as ações Duplicar / Editar / Excluir no rodapé.
///
/// É "burro": renderiza o lançamento resolvido e RESOLVE com a ação escolhida
/// ('edit' | 'repeat' | 'duplicate' | 'delete') — quem persiste e recarrega é a
/// tela de Lançamentos.
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/models/financeiro.dart';
import '../fin_chips.dart';
import '../fin_derivations.dart';
import '../fin_labels.dart';

/// Abre o painel de detalhes. Resolve com a ação escolhida (ou `null` se fechou).
/// [readOnly] esconde Editar/Duplicar/Excluir (OS e comissão).
Future<String?> showLancamentoDetail(
  BuildContext context, {
  required FinLancamento lancamento,
  FinCategoria? categoria,
  FinCategoria? subcategoria,
  FinConta? conta,
  bool readOnly = false,
}) {
  final panel = _LancamentoDetailPanel(
    lancamento: lancamento,
    categoria: categoria,
    subcategoria: subcategoria,
    conta: conta,
    readOnly: readOnly,
  );
  final wide = MediaQuery.sizeOf(context).width >= 720;
  final clx = context.clx;

  if (wide) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: clx.bg,
          child: SizedBox(
            width: 440,
            height: double.infinity,
            child: SafeArea(child: panel),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: clx.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ClxRadii.xl)),
    ),
    builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: panel),
  );
}

class _LancamentoDetailPanel extends StatelessWidget {
  const _LancamentoDetailPanel({
    required this.lancamento,
    this.categoria,
    this.subcategoria,
    this.conta,
    this.readOnly = false,
  });

  final FinLancamento lancamento;
  final FinCategoria? categoria;
  final FinCategoria? subcategoria;
  final FinConta? conta;
  final bool readOnly;

  String _recorrenciaDescricao(FinLancamento l) => switch (l.recorrencia) {
    RecorrenciaTipo.unica => 'Não se aplica',
    RecorrenciaTipo.fixa =>
      '${l.frequenciaEfetiva.labelSingular} (fixa, até cancelar)',
    RecorrenciaTipo.recorrente =>
      '${l.frequenciaEfetiva.labelSingular} (recorrente)',
    RecorrenciaTipo.parcelada =>
      'Parcelada em ${l.parcelasTotal ?? '—'}x',
  };

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final l = lancamento;
    final isReceita = l.tipo == TipoLancamento.receita;
    final temVinculoOs =
        l.origem == OrigemLancamento.viaOs ||
        (l.osId?.isNotEmpty ?? false) ||
        (l.osNumero?.isNotEmpty ?? false);
    final parcelaTexto = l.recorrencia == RecorrenciaTipo.parcelada
        ? '${l.parcelaAtual ?? 1} de ${l.parcelasTotal ?? 1}'
        : '1 de 1';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x5,
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              ClxChip(
                label: tipoLancamentoLabel(l.tipo),
                color: tipoColor(clx, l.tipo),
                background: isReceita ? clx.successBg : clx.errorBg,
                dense: true,
              ),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: Icon(Icons.close_rounded, color: clx.ink3),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        // Conteúdo rolável.
        Flexible(
          child: ListView(
            padding: const EdgeInsets.all(ClxSpace.x5),
            children: [
              _Section(
                title: 'Categoria',
                child: Row(
                  children: [
                    FinCategoriaAvatar(categoria: categoria, size: 30),
                    const SizedBox(width: ClxSpace.x2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria?.nome ?? 'Sem categoria',
                            style: tt.titleSmall?.copyWith(color: clx.ink),
                          ),
                          if (subcategoria != null)
                            Text(
                              subcategoria!.nome,
                              style: tt.bodySmall?.copyWith(color: clx.ink3),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Valor',
                child: Text(
                  formatCurrency(l.valor),
                  style: tt.titleLarge?.copyWith(
                    color: tipoColor(clx, l.tipo),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _Section(
                title: 'Conta',
                child: conta != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: ContaBadge(conta: conta!),
                      )
                    : Text('—', style: TextStyle(color: clx.ink3)),
              ),
              _Section(
                title: 'Data',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateOnlyBr(l.data),
                      style: tt.bodyLarge?.copyWith(color: clx.ink),
                    ),
                    if (l.vencimento?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Vencimento: ${formatDateOnlyBr(l.vencimento!)}',
                          style: tt.bodyMedium?.copyWith(color: clx.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'Recorrência',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RecorrenciaChip(recorrencia: l.recorrencia),
                    ),
                    const SizedBox(height: ClxSpace.x1),
                    Text(
                      _recorrenciaDescricao(l),
                      style: tt.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                    if (l.recorrencia == RecorrenciaTipo.parcelada)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Parcela $parcelaTexto',
                          style: tt.bodyMedium?.copyWith(color: clx.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'Status',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusLancamentoChip(status: l.status),
                ),
              ),
              if (temVinculoOs)
                _Section(
                  title: 'Vínculo com OS',
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 15, color: clx.info),
                      const SizedBox(width: ClxSpace.x2),
                      Expanded(
                        child: Text(
                          (l.osNumero?.isNotEmpty ?? false)
                              ? 'OS #${l.osNumero}'
                                    '${l.servicoNome != null ? ' · ${l.servicoNome}' : l.clienteNome != null ? ' · ${l.clienteNome}' : ''}'
                              : 'OS vinculada',
                          style: tt.bodyMedium?.copyWith(color: clx.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              if (l.formaPagamento?.isNotEmpty ?? false)
                _Section(
                  title: 'Forma de pagamento',
                  child: Text(
                    l.formaPagamento!,
                    style: tt.bodyLarge?.copyWith(color: clx.ink2),
                  ),
                ),
              if (l.observacao?.isNotEmpty ?? false)
                _Section(
                  title: 'Observação',
                  child: Text(
                    l.observacao!,
                    style: tt.bodyLarge?.copyWith(color: clx.ink2, height: 1.4),
                  ),
                ),
              if (l.anexos.isNotEmpty)
                _Section(
                  title: 'Anexos',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in l.anexos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: ClxSpace.x1),
                          child: Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: clx.ink3,
                              ),
                              const SizedBox(width: ClxSpace.x2),
                              Expanded(
                                child: Text(
                                  a.nome.isEmpty ? a.url : a.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodyMedium?.copyWith(
                                    color: clx.ink2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (l.tags.isNotEmpty)
                _Section(
                  title: 'Tags',
                  child: Wrap(
                    spacing: ClxSpace.x2,
                    runSpacing: ClxSpace.x2,
                    children: [
                      for (final t in l.tags) FinTagChip(label: t),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (readOnly) ...[
          Divider(height: 1, color: clx.line),
          Padding(
            padding: const EdgeInsets.all(ClxSpace.x4),
            child: Text(
              isLancamentoComissao(l)
                  ? 'Comissão gerenciada em Equipe — não editável na movimentação.'
                  : 'Lançamento da OS — status e valores seguem a ordem de serviço.',
              style: tt.bodySmall?.copyWith(color: clx.ink3, height: 1.35),
            ),
          ),
        ] else ...[
          Divider(height: 1, color: clx.line),
          // Rodapé: ações.
          // "Duplicar" cria outra movimentação idêntica (não "próxima parcela").
          Padding(
            padding: const EdgeInsets.all(ClxSpace.x4),
            child: Row(
              children: [
                _Action(
                  icon: Icons.copy_rounded,
                  label: 'Duplicar',
                  onTap: () => Navigator.of(context).pop('duplicate'),
                ),
                _Action(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onTap: () => Navigator.of(context).pop('edit'),
                ),
                _Action(
                  icon: Icons.delete_outline_rounded,
                  label: 'Excluir',
                  danger: true,
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: clx.ink3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          child,
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = danger ? clx.error : clx.ink2;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: ClxSpace.x1),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
