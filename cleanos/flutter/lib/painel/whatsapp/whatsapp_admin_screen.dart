/// whatsapp_admin_screen.dart — Seção WhatsApp do Painel (ADMIN-ONLY, Onda 5).
///
/// Espelha `WhatsApp.tsx`: painel de status/conexão UAZAPI (QR code / paircode
/// quando desconectado, conectar/desconectar, polling de status) + editor dos
/// templates de mensagem — INCLUINDO os 3 de rastreamento do doc 09 §3
/// (`aviso_5min_texto`, `aviso_1min_texto`, `aviso_cheguei_texto`).
///
/// 🔒 Guard de papel: a seção é ADMIN-only. O menu do shell já esconde o item
/// para gerente; ainda assim a tela reforça a trava (defesa em profundidade,
/// espelha o `Navigate` do React) — o servidor é a linha de defesa final.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/collections.dart';
import 'whatsapp_controller.dart';

/// Intervalo do polling de status enquanto aguarda a leitura do QR.
const Duration _kPollInterval = Duration(seconds: 3);

class WhatsAppAdminScreen extends ConsumerStatefulWidget {
  const WhatsAppAdminScreen({super.key});

  @override
  ConsumerState<WhatsAppAdminScreen> createState() =>
      _WhatsAppAdminScreenState();
}

class _WhatsAppAdminScreenState extends ConsumerState<WhatsAppAdminScreen> {
  @override
  Widget build(BuildContext context) {
    // 🔒 Guard admin-only (defesa em profundidade; o menu já filtra o gerente).
    final role = ref.watch(currentRoleProvider);
    if (role != Role.admin) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Acesso restrito',
        message: 'Apenas administradores podem gerir o WhatsApp da empresa.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _StatusPanel(),
                SizedBox(height: ClxSpace.x5),
                _TemplatesPanel(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────────── Status / conexão ─────────────────────────── */

class _StatusPanel extends ConsumerStatefulWidget {
  const _StatusPanel();

  @override
  ConsumerState<_StatusPanel> createState() => _StatusPanelState();
}

class _StatusPanelState extends ConsumerState<_StatusPanel> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // B3: o polling é efeito colateral — NUNCA inicie um Timer no corpo do
    // `build()` (roda a cada rebuild). O `ref.listen` (no build) cobre as
    // MUDANÇAS de estado; aqui cobrimos o PRIMEIRO estado já ser "aguardando QR"
    // (o listen não dispara na montagem). Pós-frame: lê o estado sem tocar o build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPolling(ref.read(whatsAppConnControllerProvider));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _syncPolling(WhatsAppConnState s) {
    if (s.aguardandoQr) {
      _poll ??= Timer.periodic(
        _kPollInterval,
        (_) =>
            ref.read(whatsAppConnControllerProvider.notifier).refreshStatus(),
      );
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    // Liga/desliga o polling conforme o estado muda (ex.: conectou → para).
    // Efeito colateral fica SÓ no listen — nunca no corpo do build (o primeiro
    // estado é coberto pelo post-frame do initState).
    ref.listen<WhatsAppConnState>(whatsAppConnControllerProvider, (_, next) {
      _syncPolling(next);
    });
    final state = ref.watch(whatsAppConnControllerProvider);
    final notifier = ref.read(whatsAppConnControllerProvider.notifier);

    return ClxCard(
      padding: const EdgeInsets.all(ClxSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_rounded, size: 20, color: clx.primary),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  'WhatsApp da empresa',
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar status',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: state.loading || state.actionLoading
                    ? null
                    : notifier.loadStatus,
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          _Nota(
            texto:
                'Este é o número da empresa pelo qual os avisos são enviados aos '
                'clientes. Os profissionais nunca usam o próprio telefone.',
          ),
          const SizedBox(height: ClxSpace.x4),
          if (state.loading)
            Row(
              children: [
                const Spinner(size: 18),
                const SizedBox(width: ClxSpace.x3),
                Text(
                  'Verificando status…',
                  style: TextStyle(color: clx.ink2, fontSize: 14),
                ),
              ],
            )
          else ...[
            if (state.error != null) ...[
              ErrorBanner(message: state.error!, onRetry: notifier.loadStatus),
              const SizedBox(height: ClxSpace.x4),
            ],
            _StatusBadge(state: state),
            const SizedBox(height: ClxSpace.x4),
            _ConnActions(state: state, notifier: notifier),
            if (state.aguardandoQr) ...[
              const SizedBox(height: ClxSpace.x5),
              _QrBlock(qrcode: state.qrcode, paircode: state.paircode),
            ],
          ],
        ],
      ),
    );
  }
}

/// Ponto colorido + rótulo do estado (conectado / desconectado / aguardando).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});
  final WhatsAppConnState state;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final (color, label) = state.connected
        ? (clx.success, 'Conectado')
        : state.aguardandoQr
        ? (clx.warning, 'Aguardando conexão…')
        : (clx.error, 'Desconectado');
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: ClxSpace.x2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (state.aguardandoQr) ...[
          const SizedBox(width: ClxSpace.x3),
          const Spinner(size: 14),
        ],
      ],
    );
  }
}

class _ConnActions extends StatelessWidget {
  const _ConnActions({required this.state, required this.notifier});
  final WhatsAppConnState state;
  final WhatsAppConnController notifier;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    if (state.connected) {
      return Row(
        children: [
          ClxButton(
            label: 'Desconectar',
            variant: ClxButtonVariant.danger,
            icon: Icons.close_rounded,
            loading: state.actionLoading,
            onPressed: notifier.disconnect,
          ),
          const SizedBox(width: ClxSpace.x4),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: clx.success),
                const SizedBox(width: ClxSpace.x1),
                Flexible(
                  child: Text(
                    'Avisos ativos',
                    style: TextStyle(color: clx.success, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ClxButton(
      label: state.aguardandoQr ? 'Gerar novo QR code' : 'Conectar WhatsApp',
      icon: Icons.chat_rounded,
      loading: state.actionLoading,
      onPressed: notifier.connect,
    );
  }
}

/// Bloco do QR code (imagem base64 do backend) + paircode alternativo.
class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.qrcode, required this.paircode});
  final String? qrcode;
  final String? paircode;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final bytes = _decodeQr(qrcode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escaneie o QR code',
          style: TextStyle(
            color: clx.ink,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        Text(
          'Abra o WhatsApp da empresa → Aparelhos conectados → Conectar '
          'aparelho e aponte a câmera para o código.',
          style: TextStyle(color: clx.ink2, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: ClxSpace.x4),
        if (bytes != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(ClxSpace.x4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: ClxRadii.rMd,
                border: Border.all(color: clx.line),
              ),
              child: Image.memory(
                bytes,
                width: 220,
                height: 220,
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) => const _QrIndisponivel(),
              ),
            ),
          )
        else
          const _QrIndisponivel(),
        if (paircode != null && paircode!.trim().isNotEmpty) ...[
          const SizedBox(height: ClxSpace.x4),
          Center(
            child: Column(
              children: [
                Text(
                  'Ou use o código de pareamento:',
                  style: TextStyle(color: clx.ink2, fontSize: 12.5),
                ),
                const SizedBox(height: ClxSpace.x1),
                SelectableText(
                  paircode!.trim(),
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ClxSpace.x4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spinner(size: 14),
            const SizedBox(width: ClxSpace.x2),
            Text(
              'Aguardando leitura do QR code…',
              style: TextStyle(color: clx.ink3, fontSize: 12.5),
            ),
          ],
        ),
      ],
    );
  }

  /// Decodifica o QR base64 entregue pelo backend (com ou sem prefixo data URI).
  /// Retorna `null` se ausente/ilegível — o backend é a fonte da imagem, o
  /// cliente NÃO gera QR (mitigação Web).
  Uint8List? _decodeQr(String? qr) {
    if (qr == null || qr.trim().isEmpty) return null;
    var s = qr.trim();
    final comma = s.indexOf(',');
    if (s.startsWith('data:') && comma != -1) s = s.substring(comma + 1);
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }
}

class _QrIndisponivel extends StatelessWidget {
  const _QrIndisponivel();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClxSpace.x4),
        child: Column(
          children: [
            Icon(Icons.qr_code_2_rounded, size: 40, color: clx.ink3),
            const SizedBox(height: ClxSpace.x2),
            Text(
              'QR code indisponível. Toque em "Gerar novo QR code".',
              textAlign: TextAlign.center,
              style: TextStyle(color: clx.ink3, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────── Templates ─────────────────────────── */

class _TemplatesPanel extends ConsumerWidget {
  const _TemplatesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final state = ref.watch(whatsAppTemplatesControllerProvider);
    final notifier = ref.read(whatsAppTemplatesControllerProvider.notifier);

    return ClxCard(
      padding: const EdgeInsets.all(ClxSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mensagens automáticas',
            style: TextStyle(
              color: clx.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          _Nota(texto: 'Placeholders disponíveis: {nome} e {servico}.'),
          const SizedBox(height: ClxSpace.x4),
          if (state.loading)
            Row(
              children: [
                const Spinner(size: 18),
                const SizedBox(width: ClxSpace.x3),
                Text(
                  'Carregando mensagens…',
                  style: TextStyle(color: clx.ink2, fontSize: 14),
                ),
              ],
            )
          else ...[
            if (state.error != null) ...[
              ErrorBanner(message: state.error!, onRetry: notifier.load),
              const SizedBox(height: ClxSpace.x4),
            ],
            if (state.saved) ...[
              _SuccessBanner(),
              const SizedBox(height: ClxSpace.x4),
            ],
            _TemplateField(
              label: 'Aviso "estou a caminho"',
              value: state.templates.avisoTemplate,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(avisoTemplate: v)),
            ),
            _TemplateField(
              label: 'Pergunta da avaliação (enquete)',
              value: state.templates.avaliacaoPollTexto,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(avaliacaoPollTexto: v)),
            ),
            _TemplateField(
              label: 'Pergunta do motivo (notas 1–3)',
              value: state.templates.avaliacaoMotivoTexto,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(avaliacaoMotivoTexto: v)),
            ),
            _TemplateField(
              label: 'Mensagem de agradecimento',
              value: state.templates.avaliacaoAgradecimento,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(avaliacaoAgradecimento: v)),
            ),
            // doc 09 §3 — templates de rastreamento "estou a caminho".
            _TemplateField(
              label: 'Rastreamento: chega em ~5 minutos',
              value: state.templates.aviso5minTexto,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(aviso5minTexto: v)),
            ),
            _TemplateField(
              label: 'Rastreamento: chega em ~1 minuto',
              value: state.templates.aviso1minTexto,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(aviso1minTexto: v)),
            ),
            _TemplateField(
              label: 'Rastreamento: cheguei ao local',
              value: state.templates.avisoChegueiTexto,
              onChanged: (v) =>
                  notifier.edit((t) => t.copyWith(avisoChegueiTexto: v)),
            ),
            const SizedBox(height: ClxSpace.x4),
            Align(
              alignment: Alignment.centerLeft,
              child: ClxButton(
                label: 'Salvar',
                variant: ClxButtonVariant.secondary,
                icon: Icons.save_outlined,
                loading: state.saving,
                onPressed: notifier.save,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Campo de template (label + textarea). `TextField` sem controller: o valor é
/// dirigido pelo estado do controller (fonte única) via [_ControlledField].
class _TemplateField extends StatelessWidget {
  const _TemplateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: clx.ink2,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          _ControlledField(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// TextField cujo texto acompanha [value] (estado do controller) sem perder o
/// cursor durante a digitação. Só sincroniza quando [value] muda por fora
/// (ex.: recarregar do servidor / salvar).
class _ControlledField extends StatefulWidget {
  const _ControlledField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ControlledField> createState() => _ControlledFieldState();
}

class _ControlledFieldState extends State<_ControlledField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _ControlledField old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      minLines: 2,
      maxLines: 5,
      decoration: const InputDecoration(
        isDense: true,
        hintText: 'Texto da mensagem…',
      ),
    );
  }
}

/* ─────────────────────────── Compartilhados ─────────────────────────── */

class _Nota extends StatelessWidget {
  const _Nota({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.primary.withValues(alpha: 0.06),
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: clx.ink2, fontSize: 12.5, height: 1.5),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.successBg,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: clx.success, size: 18),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: Text(
              'Mensagens salvas com sucesso!',
              style: TextStyle(color: clx.ink2, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
