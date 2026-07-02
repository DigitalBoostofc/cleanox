/// os_execucao_screen.dart — Tela de execução da OS (Slice B2).
///
/// Espelha `OSExecucaoApp.tsx`: cabeçalho + snapshot + checklist (auto-save) +
/// evidências (câmera/galeria via image_picker → fila de upload) + gerar laudo.
/// Usa os WIDGETS COMPARTILHADOS (ChecklistExecucao, EvidenciasSection,
/// SnapshotResumo, RelatorioOSModal). Trata 403 graciosamente (describeOSError).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/design.dart';
import '../../core/errors/os_error.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/os_execucao.dart';
import '../../shared_widgets_os/shared_widgets_os.dart';
import 'os_execucao_controller.dart';

class OSExecucaoScreen extends ConsumerStatefulWidget {
  const OSExecucaoScreen({
    super.key,
    required this.osId,
    this.obrigatoriosPendentes = false,
  });

  final String osId;
  final bool obrigatoriosPendentes;

  @override
  ConsumerState<OSExecucaoScreen> createState() => _OSExecucaoScreenState();
}

class _OSExecucaoScreenState extends ConsumerState<OSExecucaoScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _gerandoLaudo = false;

  OSExecucaoController get _ctrl =>
      ref.read(osExecucaoProvider(widget.osId).notifier);

  Future<void> _pick(FaseFoto fase) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      if (source == ImageSource.gallery) {
        final files = await _picker.pickMultiImage(imageQuality: 82);
        for (final x in files) {
          await _ctrl.enqueueFoto(file: File(x.path), fase: fase);
        }
      } else {
        final x = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
        );
        if (x != null) {
          await _ctrl.enqueueFoto(file: File(x.path), fase: fase);
        }
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível acessar a câmera/galeria.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _removeFoto(String id) async {
    try {
      await _ctrl.removeFoto(id);
    } catch (err) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível remover a foto: ${describeOSError(err).message}',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _gerarLaudo() async {
    if (_gerandoLaudo) return;
    setState(() => _gerandoLaudo = true);
    try {
      final rel = await _ctrl.montarLaudo();
      if (rel == null) {
        if (mounted) {
          showClxToast(
            context,
            'OS sem serviço definido — laudo indisponível.',
            type: ToastType.error,
          );
        }
        return;
      }
      if (mounted) await showRelatorioOSModal(context, relatorio: rel);
    } finally {
      if (mounted) setState(() => _gerandoLaudo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    // Avisa quando uma foto é descartada (arquivo de origem sumiu após kill).
    ref.listen(
      osExecucaoProvider(widget.osId).select((s) => s.discardedCount),
      (prev, next) {
        if (next > (prev ?? 0) && mounted) {
          showClxToast(
            context,
            'Uma foto pendente foi descartada (arquivo indisponível).',
            type: ToastType.warning,
          );
        }
      },
    );
    final state = ref.watch(osExecucaoProvider(widget.osId));
    final os = state.os;

    final vinculoOptions = [
      for (final it in state.checklist)
        VinculoOption(kind: VinculoKind.checklist, id: it.id, label: it.titulo),
    ];

    return Scaffold(
      backgroundColor: clx.bg2,
      appBar: AppBar(
        title: Text(
          os != null ? 'OS ${numeroFromId(os.id)}' : 'Execução da OS',
        ),
        actions: [
          if (os != null)
            Padding(
              padding: const EdgeInsets.only(right: ClxSpace.x3),
              child: Center(child: StatusBadge(status: os.status, dense: true)),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, state, vinculoOptions)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    OSExecucaoState state,
    List<VinculoOption> vinculoOptions,
  ) {
    final clx = context.clx;

    if (state.loading && state.os == null) {
      return const Center(child: Spinner(size: 26));
    }

    if (state.loadError != null && state.os == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(message: state.loadError!, onRetry: _ctrl.load),
              const SizedBox(height: ClxSpace.x4),
              ClxButton(
                label: 'Voltar',
                variant: ClxButtonVariant.ghost,
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      );
    }

    final os = state.os!;

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        if (widget.obrigatoriosPendentes)
          Padding(
            padding: const EdgeInsets.only(bottom: ClxSpace.x3),
            child: ErrorBanner(
              message:
                  'Há itens obrigatórios pendentes — conclua-os para finalizar a OS.',
              icon: Icons.warning_amber_rounded,
            ),
          ),

        // (a) Cabeçalho da OS.
        ClxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                os.nomeCurto.isNotEmpty ? os.nomeCurto : 'Cliente',
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ClxSpace.x2),
              Wrap(
                spacing: ClxSpace.x4,
                runSpacing: ClxSpace.x1,
                children: [
                  _MetaChip(
                    icon: Icons.event_outlined,
                    text: formatDateTime(os.dataHora),
                  ),
                  if (os.bairro.isNotEmpty)
                    _MetaChip(icon: Icons.place_outlined, text: os.bairro),
                  // Nome do profissional (do expand) — espelha o IconUser do
                  // cabeçalho de `OSExecucaoApp.tsx`. É o próprio profissional,
                  // não PII do cliente.
                  if (os.expand?.profissional != null &&
                      os.expand!.profissional!.displayName != '—')
                    _MetaChip(
                      icon: Icons.person_outline,
                      text: os.expand!.profissional!.displayName,
                    ),
                ],
              ),
              if (os.status == OSStatus.emAndamento &&
                  (os.enderecoLiberado ?? '').isNotEmpty) ...[
                const SizedBox(height: ClxSpace.x3),
                Container(
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
                      Icon(Icons.place, size: 16, color: clx.primary2),
                      const SizedBox(width: ClxSpace.x2),
                      Expanded(
                        child: Text(
                          os.enderecoLiberado!,
                          style: TextStyle(
                            color: clx.ink,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.saveState != SaveState.idle) ...[
                const SizedBox(height: ClxSpace.x2),
                _SaveIndicator(
                  saveState: state.saveState,
                  error: state.saveError,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x3),

        // (b) Snapshot do serviço.
        if (state.snapshot != null)
          SnapshotResumo(snapshot: state.snapshot!)
        else
          ClxCard(
            child: Column(
              children: [
                Text(
                  'Serviço não definido',
                  style: TextStyle(
                    color: clx.ink2,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: ClxSpace.x1),
                Text(
                  'O administrador ainda não configurou o serviço desta OS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: clx.ink3, fontSize: 13),
                ),
              ],
            ),
          ),
        const SizedBox(height: ClxSpace.x3),

        // (c) Checklist (auto-save).
        ChecklistExecucao(
          items: state.checklist,
          onChange: _ctrl.setChecklist,
          concluidoPor: os.expand?.profissional?.displayName ?? 'Profissional',
        ),
        const SizedBox(height: ClxSpace.x3),

        // (d) Evidências.
        EvidenciasSection(
          fotos: state.fotos,
          onPick: _pick,
          onRemove: _removeFoto,
          onLegenda: _ctrl.setLegenda,
          onVinculo: _ctrl.setVinculo,
          vinculoOptions: vinculoOptions,
          pendingIds: state.pendingIds,
          failedIds: state.failedIds,
          deletingId: state.deletingId,
          onRetry: _ctrl.retryFoto,
          disabled: state.fotosLoading,
        ),
        const SizedBox(height: ClxSpace.x3),

        // (e) Gerar laudo.
        ClxCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.checklist.isNotEmpty
                      ? '${state.checklistDone} de ${state.checklist.length} itens · ${state.fotos.length} foto${state.fotos.length != 1 ? 's' : ''}'
                      : '${state.fotos.length} foto${state.fotos.length != 1 ? 's' : ''}',
                  style: TextStyle(color: clx.ink2, fontSize: 13),
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              ClxButton(
                label: 'Gerar laudo',
                icon: Icons.picture_as_pdf_outlined,
                loading: _gerandoLaudo,
                onPressed: state.snapshot == null || state.fotosLoading
                    ? null
                    : _gerarLaudo,
              ),
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x8),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: clx.ink3),
        const SizedBox(width: ClxSpace.x1),
        Text(text, style: TextStyle(color: clx.ink2, fontSize: 13)),
      ],
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.saveState, required this.error});

  final SaveState saveState;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final (icon, text, color) = switch (saveState) {
      SaveState.saving => (null, 'Salvando…', clx.ink3),
      SaveState.saved => (Icons.check_circle_rounded, 'Salvo', clx.ink3),
      SaveState.error => (
        Icons.error_outline_rounded,
        error ?? 'Erro ao salvar',
        clx.error,
      ),
      SaveState.idle => (null, '', clx.ink3),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saveState == SaveState.saving)
          const Spinner(size: 12)
        else if (icon != null)
          Icon(icon, size: 13, color: color),
        const SizedBox(width: ClxSpace.x1),
        Flexible(
          child: Text(text, style: TextStyle(color: color, fontSize: 12)),
        ),
      ],
    );
  }
}
