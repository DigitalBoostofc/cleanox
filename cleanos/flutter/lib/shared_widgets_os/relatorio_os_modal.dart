/// relatorio_os_modal.dart — Pré-visualização do LAUDO + ações (imprimir/compartilhar).
///
/// Widget GENÉRICO (dono: Time B, reusável pelo Painel): recebe um [RelatorioOS]
/// puro e mostra um resumo rolável do que irá para o PDF, com botões para gerar
/// (imprimir → "salvar como PDF") ou compartilhar. Porte de
/// `components/os/RelatorioOSModal.tsx` (parte de pré-visualização) + a ação de PDF.
library;

import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../core/formatters/formatters.dart';
import '../core/models/os_execucao.dart';
import 'laudo_pdf.dart';
import 'relatorio_os.dart';

/// Abre o laudo como tela cheia (mobile-first). Retorna quando fechado.
Future<void> showRelatorioOSModal(
  BuildContext context, {
  required RelatorioOS relatorio,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RelatorioOSModal(relatorio: relatorio),
    ),
  );
}

class RelatorioOSModal extends StatefulWidget {
  const RelatorioOSModal({super.key, required this.relatorio});

  final RelatorioOS relatorio;

  @override
  State<RelatorioOSModal> createState() => _RelatorioOSModalState();
}

class _RelatorioOSModalState extends State<RelatorioOSModal> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String erroMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) showClxToast(context, erroMsg, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final rel = widget.relatorio;
    final concluidos = rel.checklist.where((c) => c.concluido).length;

    return Scaffold(
      backgroundColor: clx.bg2,
      appBar: AppBar(
        title: const Text('Laudo do serviço'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ClxSpace.x4),
          children: [
            _card(context, 'Dados do atendimento', [
              _row('Nº da OS', rel.numeroOS ?? rel.osId),
              _row('Data e hora', formatDateTime(rel.dataHora)),
              _row('Cliente', rel.clienteNome),
              if ((rel.enderecoCompleto ?? '').isNotEmpty)
                _row('Endereço', rel.enderecoCompleto!),
              if ((rel.bairro ?? '').isNotEmpty) _row('Bairro', rel.bairro!),
              if ((rel.profissionalNome ?? '').isNotEmpty)
                _row('Profissional', rel.profissionalNome!),
            ]),
            _card(context, 'Serviço', [
              _row('Serviço', rel.snapshot.nome),
              _row('Valor do serviço', formatCurrency(rel.valorPrincipal)),
              if (rel.valorAdicionais > 0)
                _row('Adicionais', formatCurrency(rel.valorAdicionais)),
              if ((rel.descontos ?? 0) > 0)
                _row('Descontos', '- ${formatCurrency(rel.descontos!)}'),
              _row('Total', formatCurrency(rel.valorTotal), strong: true),
            ]),
            if (rel.checklist.isNotEmpty)
              _card(
                context,
                'Checklist ($concluidos/${rel.checklist.length})',
                [
                  for (final c in rel.checklist)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            c.concluido
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: c.concluido ? clx.success : clx.ink3,
                          ),
                          const SizedBox(width: ClxSpace.x2),
                          Expanded(
                            child: Text(
                              c.titulo,
                              style: TextStyle(color: clx.ink, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            _EvidenciasResumo(evidencias: rel.evidencias),
            if (rel.observacoesVisiveis.isNotEmpty)
              _card(context, 'Observações', [
                for (final o in rel.observacoesVisiveis)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '• ${o.texto}',
                      style: TextStyle(color: clx.ink, fontSize: 14),
                    ),
                  ),
              ]),
            const SizedBox(height: ClxSpace.x2),
            Text(
              rel.textoPadrao,
              style: TextStyle(color: clx.ink3, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: ClxSpace.x10),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Row(
            children: [
              Expanded(
                child: ClxButton(
                  label: 'Compartilhar',
                  variant: ClxButtonVariant.ghost,
                  icon: Icons.share_outlined,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => compartilharLaudo(rel),
                          'Não foi possível compartilhar o laudo.',
                        ),
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                flex: 2,
                child: ClxButton(
                  label: 'Gerar PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  loading: _busy,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => imprimirLaudo(rel),
                          'Não foi possível gerar o PDF.',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> children) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x3),
      child: ClxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: clx.ink3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Builder(
      builder: (context) {
        final clx = context.clx;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: TextStyle(
                    color: clx.ink3,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: strong ? 15 : 14,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EvidenciasResumo extends StatelessWidget {
  const _EvidenciasResumo({required this.evidencias});

  final List<EvidenciaFoto> evidencias;

  @override
  Widget build(BuildContext context) {
    if (evidencias.isEmpty) return const SizedBox.shrink();
    final clx = context.clx;
    int count(FaseFoto f) => evidencias.where((e) => e.fase == f).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x3),
      child: ClxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'REGISTRO FOTOGRÁFICO',
              style: TextStyle(
                color: clx.ink3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
            Text(
              'Antes: ${count(FaseFoto.antes)} · '
              'Durante: ${count(FaseFoto.durante)} · '
              'Depois: ${count(FaseFoto.depois)}',
              style: TextStyle(color: clx.ink2, fontSize: 14),
            ),
            const SizedBox(height: ClxSpace.x1),
            Text(
              '${evidencias.length} foto(s) entram no PDF.',
              style: TextStyle(color: clx.ink3, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
