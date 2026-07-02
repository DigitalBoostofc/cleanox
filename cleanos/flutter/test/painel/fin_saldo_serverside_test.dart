/// fin_saldo_serverside_test.dart — Testes de WIRING do contrato de saldo
/// server-side nas telas do Financeiro (fin-saldo-serverside).
///
/// As mutações de saldo (hook de modelo + rotas transacionais) usam SQL direto e
/// NÃO emitem evento realtime de `fin_contas`. Logo, as telas devem REFETCHAR as
/// contas (`finContasProvider`) após qualquer mutação. Estes testes provam esse
/// refetch de ponta a ponta:
///   • Carteiras: editar o saldo de uma conta chama [definirSaldo] com o valor
///     ABSOLUTO (semântica de SET, não delta — o servidor converte lendo o saldo
///     fresco na transação) e refetcha as contas (a tela observa
///     `finContasProvider`);
///   • Carteiras: excluir uma conta refetcha as contas;
///   • Lançamentos: excluir um lançamento invalida `finContasProvider` (um probe
///     que observa o provider refetcha) — o saldo novo é server-side.
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/carteiras/fin_carteiras_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

/// Widget mínimo que OBSERVA `finContasProvider` — mantém o provider (autoDispose)
/// vivo, de modo que uma invalidação vinda de outra tela dispare um refetch
/// observável via [FakeFinanceiro.listContasCount].
class _ContasProbe extends ConsumerWidget {
  const _ContasProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(finContasProvider).valueOrNull?.length ?? 0;
    return Text('contas:$n', textDirection: TextDirection.ltr);
  }
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  List<Override> withFin(FakeFinanceiro fake) => [
    ...painelOverrides(user: painelUser()),
    financeiroRepositoryProvider.overrideWithValue(fake),
  ];

  final saldoField = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '0,00',
  );

  group('Carteiras — refetch de contas', () {
    testWidgets(
      'editar saldo chama definirSaldo(valor absoluto) e refetcha contas',
      (tester) async {
        final fake = FakeFinanceiro(
          contas: [
            fakeConta(
              id: 'a',
              nome: 'Carteira Loja',
              tipo: ContaTipo.carteira,
              saldoAtual: 100,
            ),
          ],
        );
        await pumpPainel(
          tester,
          const FinCarteirasScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);
        final fetchesAntes = fake.listContasCount;

        // Abre o modal de edição tocando o card da carteira.
        await tester.tap(find.text('Carteira Loja'));
        await tester.pumpAndSettle();
        expect(find.text('Editar carteira'), findsOneWidget);

        // Muda o saldo 100 → 150 e salva. O campo é "Saldo atual = X" → SET.
        await tester.enterText(saldoField, '150,00');
        await tester.pump();
        await tester.tap(find.text('Salvar'));
        await settle(tester);

        // Chamou a rota transacional com o valor ABSOLUTO (não delta): o servidor
        // lê o saldo fresco na transação e converte — sem lost-update no cliente.
        expect(fake.definirSaldoCount, 1);
        expect(fake.lastDefinirContaId, 'a');
        expect(fake.lastDefinirNovoSaldo, 150);
        // …e nunca calculou/enviou delta sobre o saldo (possivelmente) defasado.
        expect(fake.ajusteCount, 0);
        // …NÃO enviou saldo_atual no updateConta…
        expect(fake.lastUpdateConta?.containsKey('saldo_atual'), isFalse);
        // …e refetchou as contas (sem realtime).
        expect(fake.listContasCount, greaterThan(fetchesAntes));
      },
    );

    testWidgets('excluir conta refetcha contas', (tester) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'a', nome: 'Carteira Loja')],
      );
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);
      final fetchesAntes = fake.listContasCount;

      // Abre o menu de ações e confirma a exclusão.
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir')); // botão do diálogo de confirmação
      await settle(tester);

      expect(fake.listContasCount, greaterThan(fetchesAntes));
    });
  });

  group('Lançamentos — refetch de contas', () {
    testWidgets('excluir lançamento refetcha contas (saldo server-side)', (
      tester,
    ) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c', nome: 'Caixa')],
        categorias: [fakeCategoria(id: 'cat')],
        lancamentos: [fakeLanc(id: '1', descricao: 'Compra A')],
      );
      await pumpPainel(
        tester,
        Column(
          children: const [
            Expanded(child: FinLancamentosScreen()),
            _ContasProbe(),
          ],
        ),
        overrides: withFin(fake),
      );
      await settle(tester);
      // O probe já carregou as contas ao menos uma vez.
      final fetchesAntes = fake.listContasCount;
      expect(fetchesAntes, greaterThan(0));
      expect(find.text('Compra A'), findsOneWidget);

      // Menu de ações do lançamento → Excluir → confirma.
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir')); // botão do diálogo
      await settle(tester);

      expect(fake.deleteLancCount, 1);
      // A invalidação de finContasProvider fez o probe refetchar.
      expect(fake.listContasCount, greaterThan(fetchesAntes));
    });
  });
}
