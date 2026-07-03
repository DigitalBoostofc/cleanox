/// pb_financeiro_repository_test.dart — Testes do contrato de SALDO SERVER-SIDE
/// do `PbFinanceiroRepository` (BLOQUEADOR). Exercita a impl REAL sobre o SDK
/// PocketBase com transporte HTTP mockado ([FakeFinPb]) — sem PB real.
///
/// O que MUDOU (fin-saldo-serverside): o cliente NÃO muta mais `saldo_atual`.
/// Estes testes provam:
///   • CRUD de lançamento só mexe no lançamento — NENHUM PATCH em `fin_contas`
///     (o hook de modelo server-side ajusta o saldo);
///   • `ajustarSaldo` → POST `/api/cleanos/fin/conta/{id}/ajuste` com `{delta}`;
///   • `definirSaldo` → mesma rota com `{novoSaldo}` (valor ABSOLUTO; o servidor
///     converte para delta lendo o saldo fresco na transação — sem lost-update);
///   • `transferir` → POST `/api/cleanos/fin/transferencia` com `{from,to,valor}`,
///     erros do backend (from==to, valor<=0, 404, 403) propagados SEM rollback
///     client-side;
///   • `updateConta` não envia `saldo_atual`.
///
/// `efeitoNoSaldo` (derivação pura) segue coberto aqui — continua usado só para
/// EXIBIÇÃO (agregados de Visão geral/Relatórios), não para mutar saldo.
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/data/pb_financeiro_repository.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart'
    show efeitoNoSaldo;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'fakes_fin_pb.dart';

/// Body de um lançamento no formato que o form envia (wire snake_case).
Map<String, dynamic> lancBody({
  required String tipo,
  required num valor,
  required String status,
  required String conta,
}) => {'tipo': tipo, 'valor': valor, 'status': status, 'conta_id': conta};

void main() {
  /* ─────────────────── 1. efeitoNoSaldo (derivação pura, EXIBIÇÃO) ─────────────────── */

  group('1. efeitoNoSaldo (só exibição — não muta saldo)', () {
    test('receita paga → +valor', () {
      expect(
        efeitoNoSaldo(TipoLancamento.receita, 100, LancamentoStatus.pago),
        100,
      );
    });
    test('despesa paga → −valor', () {
      expect(
        efeitoNoSaldo(TipoLancamento.despesa, 100, LancamentoStatus.pago),
        -100,
      );
    });
    test('qualquer tipo pendente/previsto/atraso → 0', () {
      for (final s in [
        LancamentoStatus.pendente,
        LancamentoStatus.previsto,
        LancamentoStatus.emAtraso,
      ]) {
        expect(efeitoNoSaldo(TipoLancamento.receita, 100, s), 0);
        expect(efeitoNoSaldo(TipoLancamento.despesa, 100, s), 0);
      }
    });
  });

  /* ─────────────────── 2. createLancamento NÃO muta saldo ─────────────────── */

  group('2. createLancamento só cria o lançamento (saldo é server-side)', () {
    test('receita paga → cria o registro e NÃO PATCHa fin_contas', () async {
      final pb = FakeFinPb(saldos: {'a': 500});
      final lanc = await PbFinanceiroRepository(pb.client()).createLancamento(
        lancBody(tipo: 'receita', valor: 100, status: 'pago', conta: 'a'),
      );
      // Lançamento criado…
      expect(lanc.contaId, 'a');
      expect(pb.lancamentos.length, 1);
      // …e NENHUM ajuste de saldo no cliente (nem PATCH, nem rota).
      expect(pb.contaPatches, isEmpty);
      expect(pb.saldos['a'], 500); // saldo intacto do lado do cliente
      expect(pb.ajustes, isEmpty);
    });

    test('despesa pendente → idem (sem PATCH de saldo)', () async {
      final pb = FakeFinPb(saldos: {'a': 500});
      await PbFinanceiroRepository(pb.client()).createLancamento(
        lancBody(tipo: 'despesa', valor: 100, status: 'pendente', conta: 'a'),
      );
      expect(pb.contaPatches, isEmpty);
      expect(pb.saldos['a'], 500);
    });
  });

  /* ─────────────────── 3. updateLancamento NÃO muta saldo ─────────────────── */

  group('3. updateLancamento só atualiza o lançamento', () {
    test(
      'troca de conta A→B: PATCHa só o lançamento, NÃO fin_contas, sem GET do antigo',
      () async {
        final pb = FakeFinPb(
          saldos: {'a': 500, 'b': 200},
          lancamentos: {
            'L1': {
              'id': 'L1',
              ...lancBody(
                tipo: 'receita',
                valor: 100,
                status: 'pago',
                conta: 'a',
              ),
            },
          },
        );
        await PbFinanceiroRepository(pb.client()).updateLancamento(
          'L1',
          lancBody(tipo: 'receita', valor: 100, status: 'pago', conta: 'b'),
        );
        // Lançamento atualizado…
        expect(pb.lancamentos['L1']!['conta_id'], 'b');
        // …sem PATCH de saldo e sem read-then-write (não lê o antigo).
        expect(pb.contaPatches, isEmpty);
        expect(pb.saldos['a'], 500);
        expect(pb.saldos['b'], 200);
        expect(pb.lancGetCount, 0);
      },
    );

    test('mudança de status pendente→pago: sem PATCH de saldo', () async {
      final pb = FakeFinPb(
        saldos: {'a': 500},
        lancamentos: {
          'L1': {
            'id': 'L1',
            ...lancBody(
              tipo: 'receita',
              valor: 100,
              status: 'pendente',
              conta: 'a',
            ),
          },
        },
      );
      await PbFinanceiroRepository(pb.client()).updateLancamento(
        'L1',
        lancBody(tipo: 'receita', valor: 100, status: 'pago', conta: 'a'),
      );
      expect(pb.lancamentos['L1']!['status'], 'pago');
      expect(pb.contaPatches, isEmpty);
      expect(pb.saldos['a'], 500);
    });
  });

  /* ─────────────────── 4. deleteLancamento NÃO muta saldo ─────────────────── */

  group(
    '4. deleteLancamento só apaga o lançamento (estorno é server-side)',
    () {
      test(
        'despesa paga apagada → some o registro, sem PATCH de saldo',
        () async {
          final pb = FakeFinPb(
            saldos: {'a': 500},
            lancamentos: {
              'L1': {
                'id': 'L1',
                ...lancBody(
                  tipo: 'despesa',
                  valor: 100,
                  status: 'pago',
                  conta: 'a',
                ),
              },
            },
          );
          await PbFinanceiroRepository(pb.client()).deleteLancamento('L1');
          expect(pb.lancamentos.containsKey('L1'), isFalse);
          expect(pb.contaPatches, isEmpty);
          expect(pb.saldos['a'], 500);
          expect(pb.lancGetCount, 0); // não lê o registro antes de apagar
        },
      );
    },
  );

  /* ─────────────────── 5. ajustarSaldo → rota transacional ─────────────────── */

  group('5. ajustarSaldo → POST /api/cleanos/fin/conta/{id}/ajuste', () {
    test('POSTa {delta} para a conta certa (sem PATCH de saldo)', () async {
      final pb = FakeFinPb(saldos: {'a': 100});
      await PbFinanceiroRepository(pb.client()).ajustarSaldo('a', 25.5);
      expect(pb.ajustes.length, 1);
      expect(pb.ajustes.single.contaId, 'a');
      expect(pb.ajustes.single.body, {'delta': 25.5});
      expect(pb.contaPatches, isEmpty); // nunca PATCHa fin_contas
    });

    test('delta 0 é no-op (não chama a rota)', () async {
      final pb = FakeFinPb(saldos: {'a': 100});
      await PbFinanceiroRepository(pb.client()).ajustarSaldo('a', 0);
      expect(pb.ajustes, isEmpty);
    });

    test('403 (só admin/gerente) propaga como ClientException', () async {
      final pb = FakeFinPb(saldos: {'a': 100})
        ..ajusteFailStatus = 403
        ..ajusteFailMsg = 'Rota exclusiva para admin/gerente.';
      await expectLater(
        PbFinanceiroRepository(pb.client()).ajustarSaldo('a', 10),
        throwsA(
          isA<ClientException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });

    test(
      '400 (conta inexistente via delta) propaga como ClientException',
      () async {
        final pb = FakeFinPb(saldos: const {}); // conta "x" não existe
        await expectLater(
          PbFinanceiroRepository(pb.client()).ajustarSaldo('x', 50),
          throwsA(
            isA<ClientException>().having((e) => e.statusCode, 'status', 400),
          ),
        );
      },
    );
  });

  /* ─────────── 5b. definirSaldo → rota transacional {novoSaldo} ─────────── */

  group('5b. definirSaldo → POST /api/cleanos/fin/conta/{id}/ajuste', () {
    test('POSTa {novoSaldo} (valor absoluto) para a conta certa', () async {
      final pb = FakeFinPb(saldos: {'a': 100});
      await PbFinanceiroRepository(pb.client()).definirSaldo('a', 150.5);
      expect(pb.ajustes.length, 1);
      expect(pb.ajustes.single.contaId, 'a');
      // Manda o valor ABSOLUTO — nunca um delta calculado no cliente.
      expect(pb.ajustes.single.body, {'novoSaldo': 150.5});
      // O backend converteu lendo o saldo fresco e setou; sem PATCH client-side.
      expect(pb.saldos['a'], 150.5);
      expect(pb.contaPatches, isEmpty);
    });

    test('novoSaldo 0 é enviado (zerar saldo é legítimo, não no-op)', () async {
      final pb = FakeFinPb(saldos: {'a': 100});
      await PbFinanceiroRepository(pb.client()).definirSaldo('a', 0);
      expect(pb.ajustes.length, 1);
      expect(pb.ajustes.single.body, {'novoSaldo': 0});
      expect(pb.saldos['a'], 0);
    });

    test('403 (só admin/gerente) propaga como ClientException', () async {
      final pb = FakeFinPb(saldos: {'a': 100})
        ..ajusteFailStatus = 403
        ..ajusteFailMsg = 'Rota exclusiva para admin/gerente.';
      await expectLater(
        PbFinanceiroRepository(pb.client()).definirSaldo('a', 10),
        throwsA(
          isA<ClientException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });

    test(
      '404 (conta inexistente via novoSaldo) propaga como ClientException',
      () async {
        final pb = FakeFinPb(saldos: const {}); // conta "x" não existe
        await expectLater(
          PbFinanceiroRepository(pb.client()).definirSaldo('x', 50),
          throwsA(
            isA<ClientException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
      },
    );
  });

  /* ─────────────────── 6. transferir → rota transacional ─────────────────── */

  group('6. transferir → POST /api/cleanos/fin/transferencia', () {
    test('POSTa {from,to,valor} (sem rollback / PATCH client-side)', () async {
      final pb = FakeFinPb(saldos: {'a': 500, 'b': 200});
      await PbFinanceiroRepository(pb.client()).transferir('a', 'b', 100);
      expect(pb.transferencias.length, 1);
      expect(pb.transferencias.single.body, {
        'from': 'a',
        'to': 'b',
        'valor': 100,
      });
      // Nenhum PATCH de saldo no cliente — o backend é transacional.
      expect(pb.contaPatches, isEmpty);
    });

    test('from==to → backend 400 propaga (sem no-op silencioso)', () async {
      final pb = FakeFinPb(saldos: {'a': 500});
      await expectLater(
        PbFinanceiroRepository(pb.client()).transferir('a', 'a', 100),
        throwsA(
          isA<ClientException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
      expect(pb.transferencias.length, 1); // chegou ao backend
    });

    test('valor <= 0 → backend 400 propaga', () async {
      final pb = FakeFinPb(saldos: {'a': 500, 'b': 200});
      await expectLater(
        PbFinanceiroRepository(pb.client()).transferir('a', 'b', 0),
        throwsA(
          isA<ClientException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
    });

    test('conta inexistente → backend 404 propaga (nada é debitado)', () async {
      final pb = FakeFinPb(saldos: {'a': 500}); // "x" não existe
      await expectLater(
        PbFinanceiroRepository(pb.client()).transferir('a', 'x', 100),
        throwsA(
          isA<ClientException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      expect(pb.contaPatches, isEmpty); // sem rollback client-side
    });
  });

  /* ─────────────────── 7. updateConta não envia saldo_atual ─────────────────── */

  group('7. updateConta NÃO envia saldo_atual (saldo é server-side)', () {
    test('remove saldo_atual do body; demais campos seguem normais', () async {
      final pb = FakeFinPb(saldos: {'a': 100});
      await PbFinanceiroRepository(pb.client()).updateConta('a', {
        'nome': 'Nova',
        'tipo': 'banco',
        'ativo': true,
        'saldo_atual': 999, // deve ser removido pelo repo
      });
      expect(pb.contaPatchBodies.length, 1);
      final body = pb.contaPatchBodies.single;
      expect(body.containsKey('saldo_atual'), isFalse);
      expect(body['nome'], 'Nova');
      expect(body['tipo'], 'banco');
      // Nunca contabilizado como mutação de saldo.
      expect(pb.contaPatches, isEmpty);
      expect(pb.saldos['a'], 100);
    });
  });
}
