/// laudo_pdf.dart — Geração do LAUDO/RELATÓRIO da OS em PDF (pkg pdf + printing).
///
/// Substitui `web/src/lib/os/pdfOS.ts` (que montava HTML + window.print). Aqui o
/// documento A4 é construído com o pacote `pdf` e entregue via `printing`
/// (diálogo de impressão → "salvar como PDF" — ou compartilhar). Preenchido com
/// os dados da OS; deixa em BRANCO só os campos de conferência no local
/// (checkboxes, observação do cliente, avaliação e assinaturas).
///
/// Widget GENÉRICO (dono: Time B): recebe um [RelatorioOS] puro; reusável pelo Painel.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters/formatters.dart';
import '../core/models/os_execucao.dart';
import 'labels.dart';
import 'relatorio_os.dart';

const PdfColor _petrol = PdfColor.fromInt(0xFF0F4C5C);
const PdfColor _teal = PdfColor.fromInt(0xFF00C2B8);
const PdfColor _tealDark = PdfColor.fromInt(0xFF00A39B);
const PdfColor _ink = PdfColor.fromInt(0xFF0B1F2A);
const PdfColor _muted = PdfColor.fromInt(0xFF7A8893);
const PdfColor _line = PdfColor.fromInt(0xFFE2EAEF);
const PdfColor _headBg = PdfColor.fromInt(0xFFF2F7F9);

/// Resolve os bytes de uma imagem de evidência (rede ou arquivo local).
/// Retorna null em falha/offline — a foto simplesmente não entra no PDF.
Future<pw.ImageProvider?> _resolveImage(EvidenciaFoto ev) async {
  try {
    if (ev.url.startsWith('http://') || ev.url.startsWith('https://')) {
      return await networkImage(ev.url);
    }
    final file = File(ev.url);
    if (await file.exists()) {
      return pw.MemoryImage(await file.readAsBytes());
    }
  } catch (_) {
    /* imagem indisponível — pula */
  }
  return null;
}

/// Monta os bytes do PDF do laudo. Pré-resolve as imagens (rede/arquivo) fora do
/// build síncrono do documento.
Future<Uint8List> generateLaudoPdfBytes(RelatorioOS rel) async {
  final doc = pw.Document(
    title:
        'Relatório de Serviço${rel.numeroOS != null ? ' — ${rel.numeroOS}' : ''}',
  );

  // Pré-resolve imagens (antes/depois; durante só se houver legado).
  final fases = [
    FaseFoto.antes,
    FaseFoto.depois,
    if (rel.evidencias.any((e) => e.fase == FaseFoto.durante)) FaseFoto.durante,
  ];
  final imagensPorFase = <FaseFoto, List<(pw.ImageProvider, String?)>>{};
  for (final fase in fases) {
    final doGrupo = rel.evidencias.where((e) => e.fase == fase);
    final resolved = <(pw.ImageProvider, String?)>[];
    for (final ev in doGrupo) {
      final img = await _resolveImage(ev);
      if (img != null) resolved.add((img, ev.legenda));
    }
    if (resolved.isNotEmpty) imagensPorFase[fase] = resolved;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginTop: 1.4 * PdfPageFormat.cm,
        marginBottom: 1.4 * PdfPageFormat.cm,
        marginLeft: 1.4 * PdfPageFormat.cm,
        marginRight: 1.4 * PdfPageFormat.cm,
      ),
      build: (context) => [
        _header(rel),
        pw.SizedBox(height: 14),
        _sectionDados(rel),
        _sectionServico(rel),
        if (rel.adicionais.isNotEmpty) _sectionAdicionais(rel),
        _sectionFinanceiro(rel),
        if (rel.checklist.isNotEmpty) _sectionChecklist(rel),
        if (imagensPorFase.isNotEmpty)
          _sectionEvidencias(fases, imagensPorFase),
        _sectionOrientacoes(rel),
        if (rel.observacoesVisiveis.isNotEmpty) _sectionObservacoes(rel),
        _footerNote(rel),
        _sectionRodapeManual(rel),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Documento gerado em ${formatDateTime(rel.geradoEm)}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

/// Abre o diálogo de impressão do sistema (o usuário pode salvar como PDF).
/// Espelha o `gerarPDFOS` do web, mas nativo (Printing.layoutPdf).
Future<void> imprimirLaudo(RelatorioOS rel) async {
  await Printing.layoutPdf(
    onLayout: (format) => generateLaudoPdfBytes(rel),
    name: 'laudo-${rel.numeroOS ?? rel.osId}.pdf',
  );
}

/// Compartilha o PDF (WhatsApp, e-mail, drive…).
Future<void> compartilharLaudo(RelatorioOS rel) async {
  final bytes = await generateLaudoPdfBytes(rel);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'laudo-${rel.numeroOS ?? rel.osId}.pdf',
  );
}

/* ─────────────────────────── seções ─────────────────────────── */

pw.Widget _header(RelatorioOS rel) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 12),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _teal, width: 3)),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Clean',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _petrol,
                  ),
                ),
                pw.TextSpan(
                  text: 'ox',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _teal,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'Relatório de Ordem de Serviço',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'ORDEM DE SERVIÇO',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            rel.numeroOS ?? rel.osId,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _petrol,
            ),
          ),
        ],
      ),
    ],
  ),
);

pw.Widget _sectionTitle(String t) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 6),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _line)),
  ),
  child: pw.Text(
    t.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: _petrol,
      letterSpacing: 0.4,
    ),
  ),
);

pw.Widget _block(String title, pw.Widget child) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 14),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [_sectionTitle(title), child],
  ),
);

pw.Widget _infoRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 90,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: _muted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 9, color: _ink),
        ),
      ),
    ],
  ),
);

pw.Widget _sectionDados(RelatorioOS rel) {
  final rows = <pw.Widget>[
    _infoRow('Nº da OS', rel.numeroOS ?? rel.osId),
    _infoRow('Data e hora', formatDateTime(rel.dataHora)),
    _infoRow('Cliente', rel.clienteNome),
    if ((rel.clienteTelefone ?? '').isNotEmpty)
      _infoRow('Telefone', rel.clienteTelefone!),
    if ((rel.enderecoCompleto ?? '').isNotEmpty)
      _infoRow('Endereço', rel.enderecoCompleto!),
    if ((rel.bairro ?? '').isNotEmpty) _infoRow('Bairro', rel.bairro!),
    if ((rel.profissionalNome ?? '').isNotEmpty)
      _infoRow('Profissional', rel.profissionalNome!),
  ];
  return _block(
    'Dados do atendimento',
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows),
  );
}

pw.Widget _sectionServico(RelatorioOS rel) {
  final s = rel.snapshot;
  final tempo = formatTempoMedio(s.tempoMedioMin, s.tempoMedioLabel);
  return _block(
    'Serviço contratado',
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _infoRow('Serviço', s.nome),
        _infoRow('Valor do serviço', formatCurrency(rel.valorPrincipal)),
        if (tempo.isNotEmpty) _infoRow('Tempo médio', tempo),
        if ((s.observacaoTecnica ?? '').isNotEmpty)
          _infoRow('Observação técnica', s.observacaoTecnica!),
      ],
    ),
  );
}

pw.Widget _sectionAdicionais(RelatorioOS rel) => _block(
  'Serviços adicionais',
  pw.Table(
    border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: _line)),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1.4),
      3: const pw.FlexColumnWidth(1.4),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headBg),
        children: [
          _th('Item'),
          _th('Qtd', right: true),
          _th('Valor', right: true),
          _th('Subtotal', right: true),
        ],
      ),
      for (final a in rel.adicionais)
        pw.TableRow(
          children: [
            _td(a.nome),
            _td('${a.quantidade}', right: true),
            _td(formatCurrency(a.valor), right: true),
            _td(formatCurrency(a.valor * a.quantidade), right: true),
          ],
        ),
    ],
  ),
);

pw.Widget _sectionFinanceiro(RelatorioOS rel) {
  final rows = <pw.TableRow>[
    pw.TableRow(
      children: [
        _td('Serviço principal'),
        _td(formatCurrency(rel.valorPrincipal), right: true),
      ],
    ),
    if (rel.valorAdicionais > 0)
      pw.TableRow(
        children: [
          _td('Serviços adicionais'),
          _td(formatCurrency(rel.valorAdicionais), right: true),
        ],
      ),
    if ((rel.descontos ?? 0) > 0)
      pw.TableRow(
        children: [
          _td('Descontos'),
          _td('- ${formatCurrency(rel.descontos!)}', right: true),
        ],
      ),
    pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _petrol, width: 2)),
      ),
      children: [
        _td('Total', bold: true),
        _td(formatCurrency(rel.valorTotal), right: true, bold: true),
      ],
    ),
  ];
  return _block(
    'Resumo financeiro',
    pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.4),
      },
      children: rows,
    ),
  );
}

pw.Widget _sectionChecklist(RelatorioOS rel) => _block(
  'Checklist executado',
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final c in rel.checklist)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                c.concluido ? '[x] ' : '[  ] ',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: c.concluido ? _tealDark : _muted,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  c.titulo +
                      ((c.observacao ?? '').isNotEmpty
                          ? ' — ${c.observacao}'
                          : ''),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: c.concluido ? _ink : _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

pw.Widget _sectionEvidencias(
  List<FaseFoto> fases,
  Map<FaseFoto, List<(pw.ImageProvider, String?)>> imagens,
) => _block(
  'Registro fotográfico',
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final fase in fases)
        if (imagens[fase] != null) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
            child: pw.Text(
              fase.label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _petrol,
              ),
            ),
          ),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (img, legenda) in imagens[fase]!)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 150,
                      height: 112,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _line),
                        image: pw.DecorationImage(
                          image: img,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                    if ((legenda ?? '').isNotEmpty)
                      pw.SizedBox(
                        width: 150,
                        child: pw.Text(
                          legenda!,
                          style: const pw.TextStyle(fontSize: 7, color: _muted),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
    ],
  ),
);

pw.Widget _sectionOrientacoes(RelatorioOS rel) {
  final pre = rel.snapshot.orientacoesPreServico?.trim() ?? '';
  final pos = (rel.orientacoesPos ?? '').trim();
  if (pre.isEmpty && pos.isEmpty) return pw.SizedBox();
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (pre.isNotEmpty) ...[
          _sectionTitle('Orientações pré-serviço'),
          pw.Text(pre, style: const pw.TextStyle(fontSize: 9, color: _ink)),
          pw.SizedBox(height: 8),
        ],
        if (pos.isNotEmpty) ...[
          _sectionTitle('Orientações pós-serviço'),
          pw.Text(pos, style: const pw.TextStyle(fontSize: 9, color: _ink)),
        ],
      ],
    ),
  );
}

pw.Widget _sectionObservacoes(RelatorioOS rel) => _block(
  'Observações',
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final o in rel.observacoesVisiveis)
        pw.Bullet(
          text: o.texto,
          style: const pw.TextStyle(fontSize: 9, color: _ink),
        ),
    ],
  ),
);

pw.Widget _footerNote(RelatorioOS rel) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 14),
  padding: const pw.EdgeInsets.all(10),
  decoration: const pw.BoxDecoration(
    color: _headBg,
    border: pw.Border(left: pw.BorderSide(color: _teal, width: 3)),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        rel.textoPadrao,
        style: pw.TextStyle(
          fontSize: 9,
          color: _petrol,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Prazo de até ${rel.prazoIntercorrenciaDias} dias para relatar qualquer '
        'falha ou intercorrência.',
        style: const pw.TextStyle(fontSize: 9, color: _ink),
      ),
    ],
  ),
);

pw.Widget _sectionRodapeManual(RelatorioOS rel) => _block(
  'Conferência no local (preencher com o cliente)',
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _manualCheck('Serviço conferido e aprovado pelo cliente'),
      _manualCheck('Ambiente/veículo entregue limpo e organizado'),
      _manualCheck('Orientações pós-serviço explicadas ao cliente'),
      pw.SizedBox(height: 10),
      pw.Text(
        'Observação adicional do cliente',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _petrol,
        ),
      ),
      pw.SizedBox(height: 8),
      _writeLine(),
      pw.SizedBox(height: 8),
      _writeLine(),
      pw.SizedBox(height: 12),
      pw.Text(
        'Avaliação do cliente',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _petrol,
        ),
      ),
      pw.Text(
        '☆  ☆  ☆  ☆  ☆   (marque de 1 a 5 estrelas)',
        style: const pw.TextStyle(fontSize: 12, color: _petrol),
      ),
      pw.SizedBox(height: 18),
      pw.Row(
        children: [
          pw.Expanded(child: _signature('Assinatura do cliente')),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: _signature(
              'Assinatura do profissional'
              '${(rel.profissionalNome ?? '').isNotEmpty ? ' — ${rel.profissionalNome}' : ''}',
            ),
          ),
        ],
      ),
    ],
  ),
);

pw.Widget _manualCheck(String label) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: 12,
        height: 12,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _petrol, width: 1.2),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _ink)),
    ],
  ),
);

pw.Widget _writeLine() => pw.Container(
  height: 1,
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFB9C6CE)),
    ),
  ),
);

pw.Widget _signature(String label) => pw.Column(
  children: [
    pw.SizedBox(height: 28),
    pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _ink)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Text(
        label,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
    ),
  ],
);

pw.Widget _th(String t, {bool right = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  child: pw.Text(
    t.toUpperCase(),
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: _petrol,
    ),
  ),
);

pw.Widget _td(String t, {bool right = false, bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  child: pw.Text(
    t,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: 9,
      color: bold ? _petrol : _ink,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);
