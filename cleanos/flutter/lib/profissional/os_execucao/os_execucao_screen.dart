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
import '../meus_servicos/pagamento_modal.dart';
import 'add_servico_extra_sheet.dart';
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
  bool _concluindo = false;
  bool _iniciando = false;

  OSExecucaoController get _ctrl =>
      ref.read(osExecucaoProvider(widget.osId).notifier);

  /// Modo leitura: OS fechada (concluída/cancelada) abre só para consulta —
  /// checklist, fotos e observações visíveis, nada editável (o servidor
  /// barraria de qualquer forma; aqui a UI deixa isso claro).
  bool _readOnly(OSExecucaoState state) {
    final st = state.os?.status;
    return st == OSStatus.concluida || st == OSStatus.cancelada;
  }

  /// Habilita o CTA fixo "Concluir serviço": nenhum item obrigatório pendente
  /// no checklist AO VIVO. O pagamento NÃO trava mais o botão — se ainda não
  /// foi registrado, o próprio fluxo do Concluir abre o sheet de pagamento
  /// (pedido do dono, 16/07: encerrar por aqui, sem voltar à lista).
  bool _podeConcluir(OSExecucaoState state) {
    final os = state.os;
    if (os == null || os.status != OSStatus.emAndamento) return false;
    for (final i in state.checklist) {
      if (i.obrigatorio && !i.concluido) return false;
      // "Fotos de antes/depois": precisam de foto vinculada + check no item.
      if (faseFotoExigida(i) != null) {
        if (!i.concluido || !checklistItemPodeConcluir(i, state.fotos)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _pagamentoRegistrado(OSExecucaoState state) {
    final os = state.os;
    return os != null && os.pagamentoOkParaConcluir;
  }

  Future<void> _iniciar() async {
    if (_iniciando) return;
    setState(() => _iniciando = true);
    try {
      await _ctrl.iniciar();
      if (mounted) {
        showClxToast(
          context,
          'Serviço iniciado.',
          type: ToastType.success,
        );
      }
    } catch (err) {
      if (mounted) {
        showClxToast(
          context,
          describeOSError(err).message,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _concluir() async {
    if (_concluindo) return;

    // Sem pagamento registrado → registra AQUI mesmo, no sheet, e segue.
    if (!_pagamentoRegistrado(ref.read(osExecucaoProvider(widget.osId)))) {
      final os = ref.read(osExecucaoProvider(widget.osId)).os;
      if (os == null) return;
      await showPagamentoModal(
        context,
        os: os,
        onSubmit: (valor, forma, outro) =>
            _ctrl.registrarPagamento(valor: valor, forma: forma, outro: outro),
      );
      // Sheet fechado sem salvar (cancelou) → não conclui.
      if (!_pagamentoRegistrado(ref.read(osExecucaoProvider(widget.osId)))) {
        return;
      }
      if (!mounted) return;
    }

    setState(() => _concluindo = true);
    try {
      await _ctrl.concluir();
      if (mounted) {
        showClxToast(context, 'Serviço concluído!', type: ToastType.success);
        Navigator.of(context).maybePop();
      }
    } catch (err) {
      if (mounted) {
        showClxToast(
          context,
          describeOSError(err).message,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _concluindo = false);
    }
  }

  Future<void> _adicionarExtra(BuildContext context) async {
    final servico = await showAddServicoExtraSheet(context);
    if (servico == null || !mounted) return;
    try {
      await _ctrl.adicionarServicoExtra(servico);
      if (!mounted) return;
      showClxToast(
        this.context,
        'Serviço extra adicionado: ${servico.nome}',
        type: ToastType.success,
      );
    } catch (err) {
      if (!mounted) return;
      showClxToast(
        this.context,
        describeOSError(err).message,
        type: ToastType.error,
      );
    }
  }

  Future<void> _pick(
    FaseFoto fase, {
    String? checklistItemId,
  }) async {
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
          await _ctrl.enqueueFoto(
            file: File(x.path),
            fase: fase,
            checklistItemId: checklistItemId,
          );
        }
      } else {
        final x = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
        );
        if (x != null) {
          await _ctrl.enqueueFoto(
            file: File(x.path),
            fase: fase,
            checklistItemId: checklistItemId,
          );
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
              child: Center(
                child: StatusBadge(
                  status: os.status,
                  dense: true,
                  refazer: os.refazer,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, state, vinculoOptions)),
      // CTA: Iniciar (atribuída) ou Concluir (em andamento). Admin usa o mesmo.
      bottomNavigationBar: os == null || _readOnly(state)
          ? null
          : os.status == OSStatus.atribuida
          ? _StickyIniciarCta(loading: _iniciando, onPressed: _iniciar)
          : os.status == OSStatus.emAndamento
          ? _StickyConcluirCta(
              enabled: _podeConcluir(state),
              loading: _concluindo,
              pagamentoPendente: !_pagamentoRegistrado(state),
              onPressed: _concluir,
            )
          : os.status == OSStatus.agendada
          ? _StickyBannerCta(
              message:
                  'Atribua um profissional no detalhe da OS para iniciar a execução.',
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    OSExecucaoState state,
    List<VinculoOption> vinculoOptions,
  ) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;

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
    final readOnly = _readOnly(state);

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
                style: tt.titleMedium?.copyWith(color: clx.ink),
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
              // Pagamento registrado — linha própria (não cabe no Wrap de
              // chips em 320–360dp sem estourar).
              if ((os.valorPago ?? 0) > 0 && os.formaPagamento != null) ...[
                const SizedBox(height: ClxSpace.x2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.payments_outlined, size: 14, color: clx.ink3),
                    const SizedBox(width: ClxSpace.x1),
                    Expanded(
                      child: Text(
                        'Pago: ${formatCurrency(os.valorPago!)} via '
                        '${os.formaPagamentoExibicao}',
                        style: tt.bodyMedium?.copyWith(color: clx.ink2),
                      ),
                    ),
                  ],
                ),
              ],
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
                          style: tt.bodyLarge?.copyWith(color: clx.ink),
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
                  style: tt.titleSmall?.copyWith(color: clx.ink2),
                ),
                const SizedBox(height: ClxSpace.x1),
                Text(
                  'O administrador ainda não configurou o serviço desta OS.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          ),
        const SizedBox(height: ClxSpace.x3),

        // (c) Checklist (auto-save; leitura quando a OS já fechou).
        // Extras viram seções separadas (adicionalId / legado "Nome: item").
        ChecklistExecucao(
          items: state.checklist,
          adicionais: os.adicionais,
          fotos: state.fotos,
          pendingIds: state.pendingIds,
          onChange: _ctrl.setChecklist,
          readOnly: readOnly,
          concluidoPor: os.expand?.profissional?.displayName ?? 'Profissional',
          onAddExtra: readOnly ? null : () => _adicionarExtra(context),
          onPickFotoItem: readOnly
              ? null
              : (item, fase) => _pick(fase, checklistItemId: item.id),
          onRemoveFoto: readOnly ? null : _removeFoto,
          onBloqueioFoto: (msg) {
            if (!mounted) return;
            showClxToast(context, msg, type: ToastType.warning);
          },
        ),
        const SizedBox(height: ClxSpace.x3),

        // (c2) Observações do serviço (ex.: tecido rasgado, mancha que não
        // sai, muito pelo de pet…) — pedido do dono, 16/07.
        _ObservacoesProfCard(
          observacoes: os.observacoesProf,
          readOnly: readOnly,
          autorNome:
              os.expand?.profissional?.displayName ?? 'Profissional',
          onSalvar: _ctrl.salvarObservacoes,
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
          readOnly: readOnly,
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
                  style: tt.bodyMedium?.copyWith(color: clx.ink2),
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

/// CTA "Iniciar serviço" (atribuída → em andamento).
class _StickyIniciarCta extends StatelessWidget {
  const _StickyIniciarCta({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: clx.bg2,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x4,
            ClxSpace.x3,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: clx.line)),
          ),
          child: ClxButton(
            label: 'Iniciar serviço',
            icon: Icons.play_arrow_rounded,
            expand: true,
            loading: loading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Aviso no rodapé quando a OS ainda está só em agendamento.
class _StickyBannerCta extends StatelessWidget {
  const _StickyBannerCta({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: clx.bg2,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x4,
            ClxSpace.x3,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: clx.line)),
            color: clx.warning.withValues(alpha: 0.08),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: clx.ink2,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA fixo do rodapé (espec tela 3, doc 12 Onda 2 — `sticky-cta` do mock):
/// barra com borda superior sobre `clx.bg2` (o mesmo tom do Scaffold), CTA
/// pill full-width. Desabilitado enquanto [enabled] é false — não esconde o
/// botão (o profissional precisa ver que a ação existe e por que está presa).
class _StickyConcluirCta extends StatelessWidget {
  const _StickyConcluirCta({
    required this.enabled,
    required this.loading,
    required this.pagamentoPendente,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;

  /// Sem pagamento registrado o CTA continua ATIVO, mas avisa que o fluxo
  /// começa pelo sheet de pagamento.
  final bool pagamentoPendente;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: clx.bg2,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x4,
            ClxSpace.x3,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: clx.line)),
          ),
          child: ClxButton(
            label: pagamentoPendente
                ? 'Registrar pagamento e concluir'
                : 'Concluir serviço',
            icon: pagamentoPendente
                ? Icons.payments_outlined
                : Icons.check_circle_outline_rounded,
            expand: true,
            loading: loading,
            onPressed: enabled ? onPressed : null,
          ),
        ),
      ),
    );
  }
}

/// Card "Observações do serviço" — notas livres do profissional sobre o
/// atendimento (ex.: "Tecido rasgado", "Muito pelo de pet", "Mancha que não
/// sai"). Persistem em `observacoes_prof` (campo liberado pela denylist) e
/// aparecem no laudo e no painel do admin.
class _ObservacoesProfCard extends StatefulWidget {
  const _ObservacoesProfCard({
    required this.observacoes,
    required this.readOnly,
    required this.autorNome,
    required this.onSalvar,
  });

  final List<ObservacaoProfissional> observacoes;
  final bool readOnly;
  final String autorNome;
  final Future<void> Function(List<ObservacaoProfissional>) onSalvar;

  @override
  State<_ObservacoesProfCard> createState() => _ObservacoesProfCardState();
}

class _ObservacoesProfCardState extends State<_ObservacoesProfCard> {
  bool _salvando = false;

  String _novoId() =>
      'obs_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  Future<void> _persistir(List<ObservacaoProfissional> lista) async {
    setState(() => _salvando = true);
    try {
      await widget.onSalvar(lista);
    } catch (err) {
      if (mounted) {
        showClxToast(
          context,
          describeOSError(err).message,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _abrirEditor({ObservacaoProfissional? existente}) async {
    final textoCtrl = TextEditingController(text: existente?.texto ?? '');
    bool visivel = existente?.visivelCliente ?? false;
    final salvar = await showClxSheet<bool>(
      context,
      title: existente == null ? 'Nova observação' : 'Editar observação',
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textoCtrl,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Ex.: tecido rasgado, muito pelo de pet, mancha que não sai…',
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Mostrar no relatório do cliente'),
              value: visivel,
              onChanged: (v) => setSheet(() => visivel = v),
            ),
            const SizedBox(height: ClxSpace.x3),
            Row(
              children: [
                Expanded(
                  child: ClxButton(
                    label: 'Cancelar',
                    variant: ClxButtonVariant.ghost,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: ClxSpace.x3),
                Expanded(
                  flex: 2,
                  child: ClxButton(
                    label: 'Salvar observação',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final texto = textoCtrl.text.trim();
    textoCtrl.dispose();
    if (salvar != true || texto.isEmpty) return;

    final lista = [...widget.observacoes];
    if (existente == null) {
      lista.add(
        ObservacaoProfissional(
          id: _novoId(),
          texto: texto,
          visivelCliente: visivel,
          criadoPor: widget.autorNome,
          criadoEm: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } else {
      final i = lista.indexWhere((o) => o.id == existente.id);
      if (i == -1) return;
      lista[i] = existente.copyWith(texto: texto, visivelCliente: visivel);
    }
    await _persistir(lista);
  }

  Future<void> _remover(ObservacaoProfissional obs) async {
    await _persistir(
      widget.observacoes.where((o) => o.id != obs.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final obs = widget.observacoes;

    return ClxCard(
      padding: const EdgeInsets.all(ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Observações do serviço',
                  style: tt.titleMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_salvando) const Spinner(size: 14),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          if (obs.isEmpty)
            Text(
              widget.readOnly
                  ? 'Nenhuma observação registrada.'
                  : 'Registre condições do estofado: tecido rasgado, muito '
                        'pelo de pet, mancha que não sai…',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            )
          else
            for (final o in obs)
              Container(
                margin: const EdgeInsets.only(bottom: ClxSpace.x2),
                padding: const EdgeInsets.all(ClxSpace.x3),
                decoration: BoxDecoration(
                  color: clx.bg2,
                  borderRadius: ClxRadii.rLg,
                  border: Border.all(color: clx.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      o.visivelCliente
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color: o.visivelCliente ? clx.primary : clx.ink3,
                    ),
                    const SizedBox(width: ClxSpace.x2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.texto,
                            style: tt.bodyLarge?.copyWith(color: clx.ink),
                          ),
                          if (o.criadoEm.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                formatDateTime(o.criadoEm),
                                style: tt.bodySmall?.copyWith(color: clx.ink3),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      IconButton(
                        tooltip: 'Editar',
                        iconSize: 18,
                        color: clx.ink3,
                        onPressed: _salvando
                            ? null
                            : () => _abrirEditor(existente: o),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        iconSize: 18,
                        color: clx.ink3,
                        onPressed: _salvando ? null : () => _remover(o),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ],
                ),
              ),
          if (!widget.readOnly) ...[
            const SizedBox(height: ClxSpace.x1),
            ClxButton(
              label: 'Adicionar observação',
              variant: ClxButtonVariant.ghost,
              icon: Icons.add_rounded,
              expand: true,
              onPressed: _salvando ? null : () => _abrirEditor(),
            ),
          ],
        ],
      ),
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
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
        ),
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
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
