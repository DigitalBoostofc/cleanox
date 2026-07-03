/// fin_mobile_fixes_test.dart — Regressão dos 5 bugs de UI mobile reportados
/// pelo dono após instalar o APK (viewport estreito, ~360×800):
///
///  1. Visão geral: ações rápidas em grade fixa 2x2 (Nova receita/Nova despesa
///     em cima, Transferência/Importar embaixo) em vez do Wrap 3+1.
///  2. Contas a pagar/receber: painel de filtros inicia COLAPSADO no mobile
///     (não mais aberto por padrão) e o botão "Filtros" fica preenchido
///     quando o painel está aberto.
///  3. Carteiras: header (título + botões) não estoura em Column — o título
///     não deve mais colapsar para texto vertical.
///  4. Limites: header (período + "Novo limite") não corta o botão fora do
///     viewport.
///  5. Categorias: header (toggle Despesas/Receitas + "Nova categoria") não
///     corta o botão fora do viewport.
library;

import 'package:cleanos/painel/financeiro/carteiras/fin_carteiras_screen.dart';
import 'package:cleanos/painel/financeiro/categorias/fin_categorias_screen.dart';
import 'package:cleanos/painel/financeiro/fin_common.dart';
import 'package:cleanos/painel/financeiro/fin_contas_pagar_receber_screen.dart';
import 'package:cleanos/painel/financeiro/fin_limites_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/fin_visao_geral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  const narrow = Size(360, 800);
  const desktop = Size(1400, 900);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Mesma técnica de `fin_mobile_layout_test.dart`: força um relayout limpo
  /// exatamente em [target] (partindo de [away], na MESMA faixa de breakpoint),
  /// onde overflow real re-emitiria a exceção.
  Future<void> expectStableNoOverflowAt(
    WidgetTester tester,
    Size target, {
    required Size away,
  }) async {
    while (tester.takeException() != null) {}
    tester.view.physicalSize = away;
    await tester.pump();
    while (tester.takeException() != null) {}
    tester.view.physicalSize = target;
    await tester.pump();
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow no layout estável a ${target.width.toInt()} px de largura',
    );
  }

  Future<void> expectStableNoOverflow(WidgetTester tester) =>
      expectStableNoOverflowAt(tester, narrow, away: const Size(400, 800));

  /// `getTopLeft` exige um match único, mas alguns rótulos (ex.: "Novo
  /// limite", "Nova categoria") aparecem tanto no header quanto num estado
  /// vazio/empty-state do corpo. Devolve o topLeft do match mais ACIMA na
  /// tela (o do header, sempre o primeiro visualmente).
  Offset topmostTopLeft(WidgetTester tester, Finder finder) {
    Offset? best;
    for (final element in tester.elementList(finder)) {
      final box = element.renderObject! as RenderBox;
      final topLeft = box.localToGlobal(Offset.zero);
      if (best == null || topLeft.dy < best.dy) best = topLeft;
    }
    return best!;
  }

  List<Override> withFin(FakeFinanceiro fake) => [
    ...painelOverrides(user: painelUser()),
    financeiroRepositoryProvider.overrideWithValue(fake),
  ];

  testWidgets(
    'Visão geral no mobile: ações rápidas em grade 2x2 (receita/despesa em '
    'cima, transferência/importar embaixo), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      final receitaTL = tester.getTopLeft(find.text('Nova receita'));
      final despesaTL = tester.getTopLeft(find.text('Nova despesa'));
      final transferenciaTL = tester.getTopLeft(find.text('Transferência'));
      final importarTL = tester.getTopLeft(find.text('Importar'));

      // Tolerância de poucos pixels: o Row centraliza (crossAxisAlignment
      // padrão), então rótulos que quebram em 2 linhas (ex.: "Transferência")
      // deslocam o topo do texto em relação a um rótulo de 1 linha na MESMA
      // linha visual.
      expect(
        (despesaTL.dy - receitaTL.dy).abs(),
        lessThan(5),
        reason: 'Receita e despesa na mesma linha',
      );
      expect(
        (importarTL.dy - transferenciaTL.dy).abs(),
        lessThan(5),
        reason: 'Transferência e importar na mesma linha',
      );
      expect(
        transferenciaTL.dy,
        greaterThan(receitaTL.dy + 5),
        reason: 'Segunda linha abaixo da primeira',
      );

      // Ordem X: receita à esquerda de despesa (linha 1), transferência à
      // esquerda de importar (linha 2) — não apenas a mesma linha.
      expect(
        receitaTL.dx,
        lessThan(despesaTL.dx),
        reason: 'Nova receita à esquerda de Nova despesa',
      );
      expect(
        transferenciaTL.dx,
        lessThan(importarTL.dx),
        reason: 'Transferência à esquerda de Importar',
      );

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Contas a pagar/receber no mobile: filtros iniciam colapsados e o botão '
    '"Filtros" revela o painel ao tocar, sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      // Painel colapsado por padrão no mobile (bug reportado: vinha aberto).
      expect(find.text('Limpar filtros'), findsNothing);

      await tester.tap(find.text('Filtros'));
      await settle(tester);

      expect(find.text('Limpar filtros'), findsOneWidget);
      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Carteiras no mobile: header não estoura (título permanece legível, não '
    'vira texto vertical) e os botões continuam acessíveis',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(
          FakeFinanceiro(contas: [fakeConta(id: 'a', nome: 'Caixa')]),
        ),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Carteiras e contas'), findsOneWidget);
      expect(find.text('Nova carteira'), findsOneWidget);
      // Texto vertical (1 caractere por linha) resultaria numa largura ínfima;
      // o título deve ocupar largura razoável do título completo.
      final titleWidth = tester.getSize(find.text('Carteiras e contas')).width;
      expect(titleWidth, greaterThan(80));

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Limites no mobile: header quebra em coluna e "Novo limite" não é '
    'cortado fora do viewport',
    (tester) async {
      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Novo limite'), findsWidgets);
      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Categorias no mobile: header quebra em coluna e "Nova categoria" não é '
    'cortado fora do viewport',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Nova categoria'), findsWidgets);
      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Contas a pagar/receber no mobile: botão "Filtros" fica preenchido '
    '(scheme.secondaryContainer) sempre que há filtro ativo, mesmo com o '
    'painel fechado — e some sem preenchimento sem filtro ativo',
    (tester) async {
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      final scheme = Theme.of(
        tester.element(find.byType(FinContasPagarReceberScreen)),
      ).colorScheme;

      Color? filtrosButtonFill() {
        final material = tester
            .widgetList<Material>(
              find.ancestor(
                of: find.byIcon(Icons.filter_list_rounded),
                matching: find.byType(Material),
              ),
            )
            .first;
        return material.color;
      }

      // Painel fechado (default mobile) e sem filtro ativo: botão NÃO
      // preenchido.
      expect(find.text('Limpar filtros'), findsNothing);
      expect(filtrosButtonFill(), isNot(scheme.secondaryContainer));

      // Abre o painel e aplica um filtro (Tipo: Despesas).
      await tester.tap(find.text('Filtros'));
      await settle(tester);
      expect(find.text('Limpar filtros'), findsOneWidget);

      await tester.tap(find.text('Todos os tipos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Despesas (a pagar)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Painel aberto + filtro ativo: botão preenchido.
      expect(filtrosButtonFill(), scheme.secondaryContainer);

      // Fecha o painel via toggle, mantendo o filtro aplicado.
      await tester.tap(find.text('Filtros'));
      await settle(tester);
      expect(find.text('Limpar filtros'), findsNothing);

      // Painel fechado mas filtro ainda ativo: botão CONTINUA preenchido.
      expect(filtrosButtonFill(), scheme.secondaryContainer);

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Visão geral no desktop (1400x900): ações rápidas seguem em Wrap numa '
    'única linha (layout original preservado), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: desktop,
      );
      await settle(tester);

      final receitaY = tester.getTopLeft(find.text('Nova receita')).dy;
      final despesaY = tester.getTopLeft(find.text('Nova despesa')).dy;
      final transferenciaY = tester.getTopLeft(find.text('Transferência')).dy;
      final importarY = tester.getTopLeft(find.text('Importar')).dy;

      expect(
        (despesaY - receitaY).abs(),
        lessThan(5),
        reason: 'Receita e despesa na mesma linha (desktop)',
      );
      expect(
        (transferenciaY - receitaY).abs(),
        lessThan(5),
        reason: 'Transferência na mesma linha (desktop)',
      );
      expect(
        (importarY - receitaY).abs(),
        lessThan(5),
        reason: 'Importar na mesma linha (desktop)',
      );

      await expectStableNoOverflowAt(
        tester,
        desktop,
        away: const Size(1200, 900),
      );
    },
  );

  testWidgets(
    'Contas a pagar/receber no desktop (1400x900): filtros permanecem '
    'ABERTOS por padrão, sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: desktop,
      );
      await settle(tester);

      expect(find.text('Limpar filtros'), findsOneWidget);

      await expectStableNoOverflowAt(
        tester,
        desktop,
        away: const Size(1200, 900),
      );
    },
  );

  testWidgets(
    'Carteiras no desktop (1400x900): header permanece em Row (título + '
    'botões lado a lado), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(
          FakeFinanceiro(contas: [fakeConta(id: 'a', nome: 'Caixa')]),
        ),
        size: desktop,
      );
      await settle(tester);

      final titleTL = tester.getTopLeft(find.text('Carteiras e contas'));
      final novaTL = tester.getTopLeft(find.text('Nova carteira'));

      expect(
        (novaTL.dy - titleTL.dy).abs(),
        lessThan(30),
        reason: 'Título e botão na mesma linha (Row, não Column)',
      );
      expect(
        novaTL.dx,
        greaterThan(titleTL.dx),
        reason: 'Botão à direita do título (Row)',
      );

      await expectStableNoOverflowAt(
        tester,
        desktop,
        away: const Size(1200, 900),
      );
    },
  );

  testWidgets(
    'Limites no desktop (1400x900): header permanece em Row (período + '
    '"Novo limite" lado a lado), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: desktop,
      );
      await settle(tester);

      final periodTL = tester.getTopLeft(
        find.byIcon(Icons.chevron_left_rounded),
      );
      final novoTL = topmostTopLeft(tester, find.text('Novo limite'));

      expect(
        (novoTL.dy - periodTL.dy).abs(),
        lessThan(30),
        reason: 'Período e botão na mesma linha (Row, não Column)',
      );
      expect(
        novoTL.dx,
        greaterThan(periodTL.dx),
        reason: 'Botão à direita do seletor de período (Row)',
      );

      await expectStableNoOverflowAt(
        tester,
        desktop,
        away: const Size(1200, 900),
      );
    },
  );

  testWidgets(
    'Categorias no desktop (1400x900): header permanece em Row (toggle '
    'Despesas/Receitas + "Nova categoria" lado a lado), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: desktop,
      );
      await settle(tester);

      final toggleTL = tester.getTopLeft(find.text('Despesas'));
      final novaTL = topmostTopLeft(tester, find.text('Nova categoria'));

      expect(
        (novaTL.dy - toggleTL.dy).abs(),
        lessThan(30),
        reason: 'Toggle e botão na mesma linha (Row, não Column)',
      );
      expect(
        novaTL.dx,
        greaterThan(toggleTL.dx),
        reason: 'Botão à direita do toggle (Row)',
      );

      await expectStableNoOverflowAt(
        tester,
        desktop,
        away: const Size(1200, 900),
      );
    },
  );

  testWidgets(
    'Fronteira de viewport a 320px: as 5 telas do módulo Financeiro '
    'continuam sem overflow',
    (tester) async {
      const w320 = Size(320, 800);
      const away = Size(360, 800);

      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: w320,
      );
      await settle(tester);
      await expectStableNoOverflowAt(tester, w320, away: away);

      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: w320,
      );
      await settle(tester);
      await expectStableNoOverflowAt(tester, w320, away: away);

      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(
          FakeFinanceiro(contas: [fakeConta(id: 'a', nome: 'Caixa')]),
        ),
        size: w320,
      );
      await settle(tester);
      await expectStableNoOverflowAt(tester, w320, away: away);

      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: w320,
      );
      await settle(tester);
      await expectStableNoOverflowAt(tester, w320, away: away);

      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: w320,
      );
      await settle(tester);
      await expectStableNoOverflowAt(tester, w320, away: away);
    },
  );

  testWidgets(
    'finIsMobile: fronteira exata do breakpoint (kFinMobileBreakpoint = '
    '${kFinMobileBreakpoint.toInt()}px) — 599px é mobile, 600px é desktop',
    (tester) async {
      bool? result;

      Future<bool> isMobileAt(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                result = finIsMobile(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return result!;
      }

      expect(
        await isMobileAt(Size(kFinMobileBreakpoint - 1, 800)),
        isTrue,
        reason: '${kFinMobileBreakpoint - 1}px deve ser mobile',
      );
      expect(
        await isMobileAt(const Size(600, 800)),
        isFalse,
        reason: '600px deve ser desktop',
      );
    },
  );
}
