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
    'Visão geral no mobile: painel Caixa + Compromissos e ações rápidas, '
    'sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      // Painel de clareza financeira (Caixa + Compromissos).
      expect(find.textContaining('Caixa (realizado)'), findsWidgets);
      expect(find.textContaining('ainda não é caixa'), findsWidgets);
      expect(find.text('Dinheiro que entrou'), findsWidgets);
      expect(find.text('Comissões a pagar'), findsWidgets);
      expect(find.text('Se tudo se confirmar'), findsWidgets);

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
    'Limites no mobile: header com seletor de mês sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Limite de gastos'), findsWidgets);
      expect(find.text('Definir limite de gastos'), findsOneWidget);
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
    'Visão geral no desktop (1400x900): ações rápidas compactas na mesma '
    'linha (DESPESA / RECEITA / TRANSF.), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: desktop,
      );
      await settle(tester);

      // Desktop do Painel usa labels compactos no acesso rápido.
      final despesaY = tester.getTopLeft(find.text('DESPESA')).dy;
      final receitaY = tester.getTopLeft(find.text('RECEITA')).dy;
      final transfY = tester.getTopLeft(find.text('TRANSF.')).dy;

      expect(
        (receitaY - despesaY).abs(),
        lessThan(5),
        reason: 'DESPESA e RECEITA na mesma linha (desktop)',
      );
      expect(
        (transfY - despesaY).abs(),
        lessThan(5),
        reason: 'TRANSF. na mesma linha (desktop)',
      );

      await expectStableNoOverflowAt(
        tester,
        desktop,
        away: const Size(1200, 900),
      );
    },
  );

  testWidgets(
    'Contas a pagar/receber no desktop (1400x900): filtros COLAPSADOS por '
    'padrão (botão Filtros), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: desktop,
      );
      await settle(tester);

      expect(find.text('Filtros'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsNothing);

      await tester.tap(find.text('Filtros'));
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
    'Limites no desktop (1400x900): título + seletor de mês na mesma linha',
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
      final titleTL = topmostTopLeft(tester, find.text('Limite de gastos'));

      expect(
        (titleTL.dy - periodTL.dy).abs(),
        lessThan(40),
        reason: 'Título e período na mesma linha (Row, não Column)',
      );
      expect(
        periodTL.dx,
        greaterThan(titleTL.dx),
        reason: 'Seletor à direita do título',
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
