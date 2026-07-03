/// lazy_section.dart — Padrão de carregamento preguiçoso (deferred) para as
/// seções PESADAS do Painel que chegam nas próximas ondas (Financeiro, Agenda,
/// Relatórios com fl_chart etc.).
///
/// ── POR QUÊ ──────────────────────────────────────────────────────────────────
/// No Flutter Web, `import '...' deferred as x;` faz o compilador emitir a seção
/// num *chunk* JS separado, baixado só quando `x.loadLibrary()` é chamado. Isso
/// reduz o tamanho do bundle inicial do Painel — o admin que só abre o Dashboard
/// não paga o download do módulo Financeiro (fl_chart + PDFs) até clicar nele.
///
/// ── COMO USAR (nas próximas ondas) ───────────────────────────────────────────
/// No `painel_shell.dart`, ao despachar a seção:
///
///   import '../financeiro/financeiro_screen.dart' deferred as financeiro;
///   // ...
///   PainelSection.financeiro => LazySection(
///     load: financeiro.loadLibrary,
///     builder: () => financeiro.FinanceiroScreen(),
///   ),
///
/// `LazySection` cuida do estado de carregamento (spinner) e de erro (retry) do
/// download do chunk — as seções LEVES desta onda (Dashboard/Conta) são
/// importadas normalmente (eager), sem `deferred`, porque são baratas.
///
/// Se/quando o `core/router` ganhar um ponto de extensão para rotas filhas, este
/// mesmo `load`/`builder` migra para um `GoRoute` lazy sem reescrever as telas.
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Carrega uma biblioteca `deferred` e renderiza [builder] quando pronta.
/// Mostra [Spinner] enquanto baixa o chunk e um [ErrorBanner] com retry se falhar.
class LazySection extends StatefulWidget {
  const LazySection({super.key, required this.load, required this.builder});

  /// A função `loadLibrary` do import `deferred as`.
  final Future<void> Function() load;

  /// Constrói a tela DEPOIS que o chunk carregou (aí os símbolos existem).
  final Widget Function() builder;

  @override
  State<LazySection> createState() => _LazySectionState();
}

class _LazySectionState extends State<LazySection> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _retry() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ClxSpace.x6),
              child: ErrorBanner(
                message: 'Não foi possível carregar este módulo.',
                onRetry: _retry,
              ),
            ),
          );
        }
        return widget.builder();
      },
    );
  }
}
