/// os_card.dart — Card de uma OS na lista do profissional (visão-de-job).
///
/// 🔒 ANTI-DESVIO: mostra APENAS nome_curto, bairro, tipo, horário, valor e
/// status. NUNCA telefone/cliente/e-mail. O endereço só aparece quando a OS está
/// `em_andamento` (campo `endereco_liberado`, liberado pelo servidor). Porte do
/// `OSCard` de `MeusServicos.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';

class OSCard extends StatelessWidget {
  const OSCard({
    super.key,
    required this.os,
    required this.onIniciar,
    required this.onAvisar,
    required this.onPagar,
    required this.onConcluir,
    required this.onChecklist,
    this.actionLoading = false,
    this.actionError,
    this.avisoLoading = false,
  });

  final OrdemServico os;
  final VoidCallback onIniciar;
  final VoidCallback onAvisar;
  final VoidCallback onPagar;
  final VoidCallback onConcluir;
  final VoidCallback onChecklist;
  final bool actionLoading;
  final String? actionError;
  final bool avisoLoading;

  bool get _hoje {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return formatDate(os.dataHora) == formatDate(nowIso);
  }

  bool get _podeIniciar {
    if (_hoje) return true;
    final dt = parsePbUtc(os.dataHora);
    return dt != null && dt.isBefore(DateTime.now().toUtc());
  }

  bool get _pagamentoRegistrado =>
      (os.valorPago ?? 0) > 0 && os.formaPagamento != null;

  /// Abre a rota no Google Maps (endereço só liberado em `em_andamento`).
  /// Espelha o link "Ver rota" do `OSCard` de `MeusServicos.tsx`.
  Future<void> _abrirRota(BuildContext context, String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent(address)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showClxToast(
        context,
        'Não foi possível abrir o Google Maps.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final statusColor = clx.statusColor(os.status);

    // Card Easypay: sombra, stripe superior + faixa lateral de status.
    return Container(
      margin: const EdgeInsets.only(bottom: ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: clx.line),
        boxShadow: [
          BoxShadow(
            color: clx.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, clx.primary.withValues(alpha: 0.45)],
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: statusColor),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          ClxSpace.x4,
                          ClxSpace.x3,
                          ClxSpace.x4,
                          ClxSpace.x2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: [
                                    clx.primary.withValues(alpha: 0.18),
                                    clx.accent.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                formatHour(os.dataHora),
                                style: tt.titleSmall?.copyWith(
                                  color: clx.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: ClxSpace.x3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    os.nomeCurto,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.titleSmall?.copyWith(
                                      color: clx.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: ClxSpace.x2,
                                    children: [
                                      if ((os.tipoServicoNome ?? '').isNotEmpty)
                                        Text(
                                          os.tipoServicoNome!,
                                          style: tt.bodySmall?.copyWith(
                                            color: clx.ink2,
                                          ),
                                        ),
                                      if (os.bairro.isNotEmpty)
                                        Text(
                                          os.bairro,
                                          style: tt.bodySmall?.copyWith(
                                            color: clx.ink3,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: ClxSpace.x2),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge(status: os.status, dense: true),
                                const SizedBox(height: ClxSpace.x1),
                                Text(
                                  formatCurrency(os.valorTotal),
                                  style: tt.titleSmall?.copyWith(
                                    color: clx.accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                  // Endereço liberado (só em_andamento).
                  if (os.status == OSStatus.emAndamento &&
                      (os.enderecoLiberado ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ClxSpace.x4,
                        0,
                        ClxSpace.x4,
                        ClxSpace.x2,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(ClxSpace.x3),
                        decoration: BoxDecoration(
                          color: clx.primary.withValues(alpha: 0.08),
                          borderRadius: ClxRadii.rMd,
                          border: Border.all(
                            color: clx.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: clx.primary2,
                            ),
                            const SizedBox(width: ClxSpace.x2),
                            Expanded(
                              child: Text(
                                os.enderecoLiberado!,
                                style: tt.bodyLarge?.copyWith(color: clx.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Pagamento (concluida).
                  if (os.status == OSStatus.concluida &&
                      (os.valorPago ?? 0) > 0 &&
                      os.formaPagamento != null)
                    _InfoStrip(
                      color: clx.primary2,
                      bg: clx.successBg,
                      text:
                          'Pago: ${formatCurrency(os.valorPago!)} via '
                          '${os.formaPagamento!.label}',
                    ),

                  // Erro de ação.
                  if ((actionError ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ClxSpace.x4,
                        0,
                        ClxSpace.x4,
                        ClxSpace.x2,
                      ),
                      child: ErrorBanner(message: actionError!),
                    ),

                  // Ações por status.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ClxSpace.x4,
                      ClxSpace.x1,
                      ClxSpace.x4,
                      ClxSpace.x3,
                    ),
                    child: _actions(context),
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final clx = context.clx;
    switch (os.status) {
      case OSStatus.atribuida:
        return ClxButton(
          label: _podeIniciar
              ? 'Iniciar serviço'
              : 'Iniciar (disponível no dia)',
          variant: ClxButtonVariant.secondary,
          icon: Icons.play_arrow_rounded,
          expand: true,
          loading: actionLoading,
          onPressed: _podeIniciar ? onIniciar : null,
        );
      case OSStatus.emAndamento:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClxButton(
              label: 'Checklist e fotos',
              variant: ClxButtonVariant.secondary,
              icon: Icons.checklist_rounded,
              expand: true,
              onPressed: onChecklist,
            ),
            const SizedBox(height: ClxSpace.x2),
            Row(
              children: [
                // "Ver rota" — só quando o endereço já foi liberado (em_andamento).
                if ((os.enderecoLiberado ?? '').isNotEmpty) ...[
                  Expanded(
                    child: ClxButton(
                      label: 'Ver rota',
                      variant: ClxButtonVariant.ghost,
                      icon: Icons.map_outlined,
                      onPressed: () =>
                          _abrirRota(context, os.enderecoLiberado!),
                    ),
                  ),
                  const SizedBox(width: ClxSpace.x2),
                ],
                Expanded(
                  child: ClxButton(
                    label: os.avisoACaminhoEm != null
                        ? 'Cliente avisado ✓'
                        : 'Avisar a caminho',
                    variant: ClxButtonVariant.ghost,
                    icon: Icons.near_me_outlined,
                    loading: avisoLoading && os.avisoACaminhoEm == null,
                    onPressed: os.avisoACaminhoEm != null ? null : onAvisar,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x2),
            if (!_pagamentoRegistrado)
              ClxButton(
                label: 'Registrar pagamento',
                variant: ClxButtonVariant.ghost,
                icon: Icons.payments_outlined,
                expand: true,
                onPressed: actionLoading ? null : onPagar,
              )
            else
              _InfoStrip(
                color: clx.primary2,
                bg: clx.successBg,
                text:
                    'Pagamento: ${formatCurrency(os.valorPago!)} via '
                    '${os.formaPagamento!.label}',
                margin: EdgeInsets.zero,
                icon: Icons.check_circle_rounded,
              ),
            const SizedBox(height: ClxSpace.x2),
            ClxButton(
              label: 'Concluir serviço',
              icon: Icons.check_circle_outline_rounded,
              expand: true,
              loading: actionLoading,
              onPressed: _pagamentoRegistrado ? onConcluir : null,
            ),
            if (!_pagamentoRegistrado)
              Padding(
                padding: const EdgeInsets.only(top: ClxSpace.x1),
                child: Text(
                  'Registre o pagamento antes de concluir.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: clx.ink3),
                ),
              ),
          ],
        );
      case OSStatus.cancelada:
        return Text(
          'Serviço cancelado.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
        );
      case OSStatus.agendada:
      case OSStatus.concluida:
        return const SizedBox.shrink();
    }
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.color,
    required this.bg,
    required this.text,
    this.icon,
    this.margin = const EdgeInsets.fromLTRB(
      ClxSpace.x4,
      0,
      ClxSpace.x4,
      ClxSpace.x2,
    ),
  });

  final Color color;
  final Color bg;
  final String text;
  final IconData? icon;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x3,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: ClxSpace.x1),
          ],
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
