/// fin_export.dart — Export CSV de lançamentos (Financeiro v2).
///
/// Web: download de arquivo. Outras plataformas: copia para a área de
/// transferência (toast informa o usuário).
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';
import '../../core/models/financeiro.dart';
import 'fin_derivations.dart';
import 'fin_export_download_stub.dart'
    if (dart.library.html) 'fin_export_download_web.dart' as dl;
import 'fin_labels.dart';

/// Escapa campo CSV (RFC 4180 simplificado).
String _csvCell(String raw) {
  final s = raw.replaceAll('"', '""');
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains(';')) {
    return '"$s"';
  }
  return s;
}

/// Monta CSV (`;` como separador — padrão BR Excel).
String finLancamentosToCsv({
  required List<FinLancamento> lancs,
  required Map<String, FinCategoria> catById,
  required Map<String, FinConta> contaById,
}) {
  final buf = StringBuffer();
  buf.writeln(
    [
      'data',
      'tipo',
      'descricao',
      'valor',
      'status',
      'categoria',
      'conta',
      'recorrencia',
      'origem',
      'tags',
      'os_numero',
      'cliente',
      'observacao',
    ].join(';'),
  );
  final sorted = [...lancs]
    ..sort((a, b) => dateOnly(b.data).compareTo(dateOnly(a.data)));
  for (final l in sorted) {
    final cat = catById[l.categoriaId]?.nome ?? '';
    final conta = contaById[l.contaId]?.nome ?? '';
    buf.writeln(
      [
        dateOnly(l.data),
        l.tipo.wire,
        _csvCell(l.descricao),
        l.valor.toStringAsFixed(2).replaceAll('.', ','),
        statusLancamentoLabel(l.status),
        _csvCell(cat),
        _csvCell(conta),
        l.recorrencia.wire,
        l.origem.wire,
        _csvCell(l.tags.join('|')),
        _csvCell(l.osNumero ?? ''),
        _csvCell(l.clienteNome ?? ''),
        _csvCell(l.observacao ?? ''),
      ].join(';'),
    );
  }
  return buf.toString();
}

/// Exporta CSV: download na web; clipboard + toast no restante.
Future<void> finExportLancamentosCsv(
  BuildContext context, {
  required List<FinLancamento> lancs,
  required Map<String, FinCategoria> catById,
  required Map<String, FinConta> contaById,
  required String filename,
}) async {
  if (lancs.isEmpty) {
    showClxToast(
      context,
      'Não há lançamentos para exportar neste período.',
      type: ToastType.warning,
    );
    return;
  }
  final csv = finLancamentosToCsv(
    lancs: lancs,
    catById: catById,
    contaById: contaById,
  );
  try {
    if (kIsWeb) {
      await dl.finDownloadTextFile(filename, csv);
      if (context.mounted) {
        showClxToast(
          context,
          'CSV baixado (${lancs.length} linhas).',
          type: ToastType.success,
        );
      }
    } else {
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        showClxToast(
          context,
          'CSV copiado (${lancs.length} linhas). Cole num editor ou planilha.',
          type: ToastType.success,
        );
      }
    }
  } on UnsupportedError {
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      showClxToast(
        context,
        'CSV copiado para a área de transferência.',
        type: ToastType.success,
      );
    }
  } catch (_) {
    if (context.mounted) {
      showClxToast(
        context,
        'Não foi possível exportar o CSV.',
        type: ToastType.error,
      );
    }
  }
}
