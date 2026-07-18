/// os_card.dart — Card de uma OS na lista do profissional (visão-de-job).
///
/// Mostra nome_curto, bairro, tipo, horário, valor e status. O endereço
/// (`endereco_liberado`) aparece em `atribuida` e `em_andamento` (pedido do
/// dono 18/07: ver localização ANTES de Iniciar). Telefone não fica no card —
/// contato via botão WhatsApp (rota server-side `contato-cliente`).
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../mapa/rota_in_app_sheet.dart';

class OSCard extends StatelessWidget {
  const OSCard({
    super.key,
    required this.os,
    required this.onIniciar,
    required this.onAvisar,
    required this.onPagar,
    required this.onConcluir,
    required this.onChecklist,
    required this.onWhatsAppCliente,
    this.actionLoading = false,
    this.actionError,
    this.avisoLoading = false,
    this.contatoLoading = false,
  });

  final OrdemServico os;
  final VoidCallback onIniciar;
  final VoidCallback onAvisar;
  final VoidCallback onPagar;
  final VoidCallback onConcluir;
  final VoidCallback onChecklist;
  final VoidCallback onWhatsAppCliente;
  final bool actionLoading;
  final String? actionError;
  final bool avisoLoading;
  final bool contatoLoading;

  bool get _temEndereco => (os.enderecoLiberado ?? '').trim().isNotEmpty;

  bool get _mostraEndereco =>
      _temEndereco &&
      (os.status == OSStatus.atribuida || os.status == OSStatus.emAndamento);

  /// R2: DateField opcional no PB volta `""` (não null). Só conta se houver data.
  bool get _jaAvisouDeslocamento =>
      (os.avisoACaminhoEm ?? '').trim().isNotEmpty;

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

  /// Abre a rota **dentro do app** (mapa + distância/tempo). Sem sair do APK.
  Future<void> _abrirRota(BuildContext context) async {
    await openRotaInApp(context, os);
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

                  // Endereço (atribuida + em_andamento) — ver antes de Iniciar.
                  if (_mostraEndereco)
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
                                os.enderecoLiberado!.trim(),
                                style: tt.bodyLarge?.copyWith(color: clx.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Observações do painel (campo `observacoes` da OS) — o prof lê.
                  if ((os.observacoes ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ClxSpace.x4,
                        0,
                        ClxSpace.x4,
                        ClxSpace.x2,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ClxSpace.x3),
                        decoration: BoxDecoration(
                          color: clx.bg2,
                          borderRadius: ClxRadii.rMd,
                          border: Border.all(color: clx.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 16,
                                  color: clx.ink3,
                                ),
                                const SizedBox(width: ClxSpace.x2),
                                Text(
                                  'Observações',
                                  style: tt.labelMedium?.copyWith(
                                    color: clx.ink3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: ClxSpace.x1),
                            Text(
                              os.observacoes!.trim(),
                              style: tt.bodyMedium?.copyWith(
                                color: clx.ink,
                                height: 1.4,
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
                          '${os.formaPagamentoExibicao}',
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
        // Fluxo: detalhes (endereço/obs/rota/WhatsApp) → Em deslocamento
        // (avisa cliente) → Iniciar (checklist).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_temEndereco) ...[
                  Expanded(
                    child: ClxButton(
                      label: 'Ver rota',
                      variant: ClxButtonVariant.ghost,
                      icon: Icons.map_outlined,
                      onPressed: () => _abrirRota(context),
                    ),
                  ),
                  const SizedBox(width: ClxSpace.x2),
                ],
                Expanded(
                  child: ClxButton(
                    label: 'WhatsApp cliente',
                    variant: ClxButtonVariant.ghost,
                    icon: Icons.chat_rounded,
                    loading: contatoLoading,
                    onPressed: contatoLoading ? null : onWhatsAppCliente,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x2),
            ClxButton(
              label: _jaAvisouDeslocamento
                  ? 'Em deslocamento ✓ (cliente avisado)'
                  : 'Em deslocamento',
              variant: ClxButtonVariant.secondary,
              icon: Icons.directions_car_filled_outlined,
              expand: true,
              loading: avisoLoading && !_jaAvisouDeslocamento,
              onPressed: _jaAvisouDeslocamento ? null : onAvisar,
            ),
            if (!_jaAvisouDeslocamento)
              Padding(
                padding: const EdgeInsets.only(top: ClxSpace.x1),
                child: Text(
                  'Avisa o cliente pelo WhatsApp da empresa que você está a caminho.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: clx.ink3,
                    height: 1.35,
                  ),
                ),
              ),
            const SizedBox(height: ClxSpace.x2),
            ClxButton(
              label: _podeIniciar
                  ? 'Iniciar serviço'
                  : 'Iniciar (disponível no dia)',
              variant: ClxButtonVariant.primary,
              icon: Icons.play_arrow_rounded,
              expand: true,
              loading: actionLoading,
              onPressed: _podeIniciar ? onIniciar : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: ClxSpace.x1),
              child: Text(
                'Inicie só quando for começar o serviço. Depois você preenche '
                'checklist, pagamento e conclui.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: clx.ink3, height: 1.35),
              ),
            ),
          ],
        );
      case OSStatus.emAndamento:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClxButton(
              label: _jaAvisouDeslocamento
                  ? 'Em deslocamento ✓ (cliente avisado)'
                  : 'Em deslocamento',
              variant: ClxButtonVariant.secondary,
              icon: Icons.directions_car_filled_outlined,
              expand: true,
              loading: avisoLoading && !_jaAvisouDeslocamento,
              onPressed: _jaAvisouDeslocamento ? null : onAvisar,
            ),
            if (!_jaAvisouDeslocamento)
              Padding(
                padding: const EdgeInsets.only(top: ClxSpace.x1, bottom: ClxSpace.x2),
                child: Text(
                  'Notifica o cliente (WhatsApp da empresa) que você está a caminho.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: clx.ink3,
                    height: 1.35,
                  ),
                ),
              )
            else
              const SizedBox(height: ClxSpace.x2),
            ClxButton(
              label: 'Checklist, pagamento e concluir',
              variant: ClxButtonVariant.primary,
              icon: Icons.checklist_rounded,
              expand: true,
              onPressed: onChecklist,
            ),
            const SizedBox(height: ClxSpace.x2),
            Row(
              children: [
                if (_temEndereco) ...[
                  Expanded(
                    child: ClxButton(
                      label: 'Ver rota',
                      variant: ClxButtonVariant.ghost,
                      icon: Icons.map_outlined,
                      onPressed: () => _abrirRota(context),
                    ),
                  ),
                  const SizedBox(width: ClxSpace.x2),
                ],
                Expanded(
                  child: ClxButton(
                    label: 'WhatsApp',
                    variant: ClxButtonVariant.ghost,
                    icon: Icons.chat_rounded,
                    loading: contatoLoading,
                    onPressed: contatoLoading ? null : onWhatsAppCliente,
                  ),
                ),
              ],
            ),
            // Atalhos de pagamento/concluir ainda no card.
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
                    '${os.formaPagamentoExibicao}',
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
                  'Registre o pagamento antes de concluir (ou faça no checklist).',
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
      case OSStatus.concluida:
        // O serviço fechou, mas o profissional ainda pode REVER o que fez
        // (checklist, fotos, laudo) — a execução abre em modo leitura.
        return ClxButton(
          label: 'Ver detalhes do serviço',
          variant: ClxButtonVariant.ghost,
          icon: Icons.receipt_long_outlined,
          expand: true,
          onPressed: onChecklist,
        );
      case OSStatus.agendada:
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
