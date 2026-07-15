/// fin_widget_cov_test.dart — Cobertura de widget do FINANCEIRO (fan-out pane 1/5).
///
/// Cobre comportamentos que o E2E só validou VISUALMENTE, com fakes (sem rede):
///  • TRANSFERÊNCIA entre carteiras (`FinCarteirasScreen` + `TransferenciaForm`):
///    fluxo feliz chama a rota transacional `transferir(from,to,valor)` com os
///    argumentos certos (saldo é server-side atômico — o cliente NÃO muta saldo);
///    botão desabilitado com < 2 contas ativas; valor ≤ 0 é barrado sem chamar o
///    repo.
///  • LIMITE (`FinLimitesScreen`): casos ADJACENTES ao já coberto (limite 0 e 75%
///    já existem em fin_paridade/fin_screens) — cálculo do ratio quando o gasto
///    ESTOURA o teto (pct clampa em 100% + chip "Estourou") e a faixa de ATENÇÃO
///    (≥ 80% + chip "Atenção"), ambos com a barra presente (limite > 0).
///  • LANÇAMENTO detalhe/edição (`FinLancamentosScreen`): abrir o painel de
///    detalhe de um lançamento e conferir os campos; abrir a edição a partir do
///    detalhe, alterar o valor e asserir a chamada `updateLancamento` ao repo
///    (sem tocar `origem` — anti-desvio).
///
/// Reaproveita os fakes de `fakes_onda4.dart` (FakeFinanceiro + builders) e os
/// helpers de `painel_test_helpers.dart` (pumpPainel/painelOverrides/painelUser).
library;

import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/carteiras/fin_carteiras_screen.dart';
import 'package:cleanos/painel/financeiro/fin_limites_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_screen.dart';
import 'package:cleanos/painel/financeiro/lancamentos/lancamento_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  // Alguns providers do Financeiro resolvem em cascata (repo → futuros); um punhado
  // de pumps curtos deixa os FutureProviders assentarem sem `pumpAndSettle` (que
  // travaria no spinner de loading inicial).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  List<Override> withFin(FakeFinanceiro fake) => [
    ...painelOverrides(user: painelUser()),
    financeiroRepositoryProvider.overrideWithValue(fake),
  ];

  // ─── TRANSFERÊNCIA entre carteiras ─────────────────────────────────────────

  group('Transferência entre carteiras', () {
    FakeFinanceiro fakeComDuasContas() => FakeFinanceiro(
      contas: [
        fakeConta(
          id: 'a',
          nome: 'Carteira Loja',
          tipo: ContaTipo.carteira,
          saldoAtual: 100,
        ),
        fakeConta(
          id: 'b',
          nome: 'Banco X',
          tipo: ContaTipo.banco,
          saldoAtual: 50,
        ),
      ],
    );

    testWidgets(
      'transferir A→B chama a rota transacional com from/to/valor certos '
      '(sem mutar saldo no cliente)',
      (tester) async {
        final fake = fakeComDuasContas();
        await pumpPainel(
          tester,
          const FinCarteirasScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);

        // Abre o modal de transferência (semeia origem=A, destino=B).
        await tester.tap(find.text('Transferência'));
        await tester.pumpAndSettle();
        expect(find.text('Transferência entre contas'), findsOneWidget);

        // Informa o valor e confirma.
        final valorField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0,00',
        );
        await tester.enterText(valorField, '30');
        await tester.pump();

        await tester.tap(find.text('Transferir'));
        await tester.pumpAndSettle();

        // Contrato server-side: uma única chamada à rota transacional, com os
        // argumentos corretos (débito+crédito na MESMA transação do backend).
        expect(fake.transferirCount, 1);
        expect(fake.lastTransfer?.from, 'a');
        expect(fake.lastTransfer?.to, 'b');
        expect(fake.lastTransfer?.valor, 30.0);

        // O cliente NÃO mutou saldo local (segue igual ao seed) e a UI reflete o
        // sucesso via toast.
        expect(fake.contas.firstWhere((c) => c.id == 'a').saldoAtual, 100);
        expect(fake.contas.firstWhere((c) => c.id == 'b').saldoAtual, 50);
        expect(find.text('Transferência concluída.'), findsOneWidget);
      },
    );

    testWidgets(
      'botão de transferência desabilitado com menos de 2 contas ativas',
      (tester) async {
        // Duas contas, mas só UMA ativa → não dá pra transferir.
        final fake = FakeFinanceiro(
          contas: [
            fakeConta(id: 'a', nome: 'Carteira', saldoAtual: 100),
            fakeConta(id: 'b', nome: 'Inativa', saldoAtual: 0, ativo: false),
          ],
        );
        await pumpPainel(
          tester,
          const FinCarteirasScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);

        // Tenta abrir o modal: como o handler é nulo, nada acontece.
        await tester.tap(find.text('Transferência'));
        await tester.pumpAndSettle();

        expect(find.text('Transferência entre contas'), findsNothing);
        expect(fake.transferirCount, 0);
      },
    );

    testWidgets('valor ≤ 0 é barrado sem chamar o repo', (tester) async {
      final fake = fakeComDuasContas();
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      await tester.tap(find.text('Transferência'));
      await tester.pumpAndSettle();

      final valorField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0,00',
      );
      await tester.enterText(valorField, '0');
      await tester.pump();

      await tester.tap(find.text('Transferir'));
      await tester.pump();

      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      expect(fake.transferirCount, 0);
      // Modal continua aberto (não fechou por erro de validação).
      expect(find.text('Transferência entre contas'), findsOneWidget);
    });
  });

  // ─── LIMITE: cálculo do ratio quando limite > 0 ────────────────────────────
  // (limite 0 → "Limite zerado" já está em fin_paridade_test; 75% em fin_screens_test.)

  group('Limite — barra e ratio (limite > 0)', () {
    testWidgets(
      'gasto acima do teto: pct clampa em 100% e mostra "Estourou"',
      (tester) async {
        final fake = FakeFinanceiro(
          categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
          limites: [fakeLimite(id: 'l', categoriaId: 'cat', limite: 100)],
          lancamentos: [
            fakeLanc(
              id: '1',
              tipo: TipoLancamento.despesa,
              valor: 150,
              categoriaId: 'cat',
            ),
          ],
        );
        await pumpPainel(
          tester,
          const FinLimitesScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);

        expect(find.text('Estourou'), findsOneWidget);
        expect(find.text('Atenção'), findsNothing);
        // clamp em 1.0 → "100%" (não "150%").
        expect(find.text('100%'), findsOneWidget);
        // Barra global + barra da categoria; texto "gasto de teto".
        expect(find.byType(LinearProgressIndicator), findsWidgets);
        // Aparece no total global e na linha da categoria.
        expect(
          find.text('${formatCurrency(150)} de ${formatCurrency(100)}'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'gasto ≥ 80% do teto (sem estourar): faixa de "Atenção" com pct correto',
      (tester) async {
        final fake = FakeFinanceiro(
          categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
          limites: [fakeLimite(id: 'l', categoriaId: 'cat', limite: 100)],
          lancamentos: [
            fakeLanc(
              id: '1',
              tipo: TipoLancamento.despesa,
              valor: 90,
              categoriaId: 'cat',
            ),
          ],
        );
        await pumpPainel(
          tester,
          const FinLimitesScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);

        expect(find.text('Atenção'), findsOneWidget);
        expect(find.text('Estourou'), findsNothing);
        expect(find.text('90%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsWidgets);
      },
    );
  });

  // ─── LANÇAMENTO: detalhe + edição ──────────────────────────────────────────

  group('Lançamento — detalhe e edição', () {
    testWidgets(
      'abrir detalhe mostra os campos do lançamento',
      (tester) async {
        final fake = FakeFinanceiro(
          contas: [fakeConta(id: 'conta', nome: 'Caixa')],
          categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
          lancamentos: [
            fakeLanc(
              id: '1',
              descricao: 'Compra de tinta',
              tipo: TipoLancamento.despesa,
              valor: 120,
              categoriaId: 'cat',
              contaId: 'conta',
            ),
          ],
        );
        await pumpPainel(
          tester,
          const FinLancamentosScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);

        // Toca a linha para abrir o painel de detalhes (viewport larga → lateral).
        await tester.tap(find.text('Compra de tinta').first);
        await tester.pumpAndSettle();

        // Seções exclusivas do painel de detalhe.
        expect(find.text('Recorrência'), findsOneWidget);
        expect(find.text('Não se aplica'), findsOneWidget);
        // Valor formatado, escopado à seção "Valor" do painel de detalhe.
        // (o mesmo texto também aparece no tile de resumo "Saídas", já que a
        // única despesa soma R$ 120,00 — então NÃO dá pra usar o finder global.)
        final valorSection = find
            .ancestor(of: find.text('Valor'), matching: find.byType(Column))
            .first;
        expect(
          find.descendant(
            of: valorSection,
            matching: find.text(formatCurrency(120)),
          ),
          findsOneWidget,
        );
        // Ações do rodapé.
        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Repetir'), findsOneWidget);
        expect(find.text('Copiar'), findsOneWidget);
      },
    );

    testWidgets(
      'editar a partir do detalhe: alterar valor chama updateLancamento '
      'sem tocar origem',
      (tester) async {
        final fake = FakeFinanceiro(
          contas: [fakeConta(id: 'conta', nome: 'Caixa')],
          categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
          lancamentos: [
            fakeLanc(
              id: '1',
              descricao: 'Compra de tinta',
              tipo: TipoLancamento.despesa,
              valor: 120,
              categoriaId: 'cat',
              contaId: 'conta',
            ),
          ],
        );
        await pumpPainel(
          tester,
          const FinLancamentosScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);

        // Detalhe → Editar → form de edição pré-preenchido.
        await tester.tap(find.text('Compra de tinta').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();

        expect(find.byType(LancamentoForm), findsOneWidget);
        expect(find.text('Editar lançamento'), findsOneWidget);

        // Troca o valor de 120 → 250 e salva.
        final valorField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0,00',
        );
        await tester.enterText(valorField, '250');
        await tester.pump();

        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        // Uma única chamada de update, com o novo valor.
        expect(fake.updateLancCount, 1);
        expect(fake.createLancCount, 0);
        expect((fake.lastUpdateLanc?['valor'] as num?)?.toDouble(), 250.0);
        // Anti-desvio: a edição NÃO envia 'origem' (não fabrica/limpa vínculo OS).
        expect(fake.lastUpdateLanc?.containsKey('origem'), isFalse);
      },
    );
  });
}
