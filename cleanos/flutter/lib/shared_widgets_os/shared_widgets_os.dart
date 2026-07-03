/// Barrel dos WIDGETS DE EXECUÇÃO COMPARTILHADOS (dono: Time B / Profissional).
///
/// Genéricos: recebem dados + callbacks via params, sem depender de nenhuma
/// feature. O Painel (Time A) consome estes mesmos widgets ao renderizar a
/// execução/laudo de uma OS. Dependem SÓ do core congelado (models, design,
/// formatters) — nunca de `profissional/` ou `painel/`.
library;

export 'checklist_execucao.dart';
export 'evidencias_section.dart';
export 'labels.dart';
export 'laudo_pdf.dart';
export 'relatorio_os.dart';
export 'relatorio_os_modal.dart';
export 'snapshot_resumo.dart';
