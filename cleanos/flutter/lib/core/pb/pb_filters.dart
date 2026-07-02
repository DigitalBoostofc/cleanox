/// pb_filters.dart — Escaping CANÔNICO de literais de filtro PocketBase.
///
/// Movido de `painel/data/painel_filters.dart` para o core (A-04): as DUAS
/// superfícies montam filtros e nenhuma pode interpolar valor cru. Espelha
/// exatamente o escaping do `pb.filter` do SDK Dart (envolve em aspas simples
/// e escapa `'` → `\'`), como funções puras testáveis sem instância PocketBase.
///
/// ⚠️ Como no SDK, apenas `'` é escapado: um valor terminado em `\` produz
/// filtro malformado. Os call sites atuais só passam ids/bounds internos —
/// se algum dia aceitar entrada livre com backslash, escape `\` também.
library;

/// Escapa um valor de string como literal de filtro do PB (`'…'`, com `'` → `\'`).
String pbStringLiteral(String value) => "'${value.replaceAll("'", "\\'")}'";
