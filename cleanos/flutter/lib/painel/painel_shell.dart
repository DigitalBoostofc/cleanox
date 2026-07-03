/// painel_shell.dart — Re-export do casco do PAINEL para o resto do app.
///
/// O casco real (`PainelShell`) vive em `shell/painel_shell.dart`. As ROTAS da
/// superfície (o `StatefulShellRoute.indexedStack` do `/painel`) ficam em
/// `painel_routes.dart` e são penduradas no `core/router` via `painelShellRoute`.
library;

export 'shell/painel_shell.dart' show PainelShell;
