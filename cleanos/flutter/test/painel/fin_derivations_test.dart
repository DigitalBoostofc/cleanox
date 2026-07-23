/// fin_derivations_test.dart — Testa as derivações PURAS do Financeiro (resumo,
/// saldo, agrupamento por data, contas a pagar/receber, gasto/limite) e os
/// filtros PB. Cobre dinheiro (centavos) e datas de parede (sem fuso).
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:cleanos/painel/financeiro/fin_filters.dart';
import 'package:cleanos/painel/financeiro/fin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';

void main() {
  group('mesPeriodo', () {
    test('janela half-open do mês (vira o ano em dezembro)', () {
      expect(mesPeriodo(2026, 7).start, '2026-07-01');
      expect(mesPeriodo(2026, 7).end, '2026-08-01');
      expect(mesPeriodo(2026, 12).end, '2027-01-01');
    });
  });

  group('bordas de mês BRT (dentroDoPeriodo — data de PAREDE, sem fuso)', () {
    final julho = mesPeriodo(2026, 7); // [2026-07-01, 2026-08-01)

    test('dia 01 conta (limite inferior INCLUSIVO)', () {
      expect(
        dentroDoPeriodo(fakeLanc(id: '1', data: '2026-07-01'), julho),
        isTrue,
      );
    });

    test(
      'último dia do mês conta, mas o 1º dia do mês seguinte NÃO (superior EXCLUSIVO)',
      () {
        expect(
          dentroDoPeriodo(fakeLanc(id: '1', data: '2026-07-31'), julho),
          isTrue,
        );
        // 2026-08-01 == end → fora (não vaza pro mês seguinte).
        expect(
          dentroDoPeriodo(fakeLanc(id: '2', data: '2026-08-01'), julho),
          isFalse,
        );
      },
    );

    test('data de parede "2026-07-01 01:00" NÃO cai em junho por −3h', () {
      // Se aplicasse fuso BRT (−3h), 01:00Z viraria 2026-06-30 22:00 e cairia em
      // JUNHO. Como a comparação é por dateOnly (parede), permanece em JULHO.
      final l = fakeLanc(id: '1', data: '2026-07-01 01:00:00');
      expect(dentroDoPeriodo(l, julho), isTrue);
      expect(dentroDoPeriodo(l, mesPeriodo(2026, 6)), isFalse);
    });

    test('último instante do mês "2026-07-31 23:59" fica em julho', () {
      final l = fakeLanc(id: '1', data: '2026-07-31 23:59:59');
      expect(dentroDoPeriodo(l, julho), isTrue);
    });
  });

  group('resumoPeriodo', () {
    test('soma só os pagos e não acumula erro de float', () {
      final lancs = [
        fakeLanc(id: '1', tipo: TipoLancamento.receita, valor: 0.1),
        fakeLanc(id: '2', tipo: TipoLancamento.receita, valor: 0.2),
        fakeLanc(id: '3', tipo: TipoLancamento.despesa, valor: 0.3),
        fakeLanc(
          id: '4',
          tipo: TipoLancamento.receita,
          valor: 999,
          status: LancamentoStatus.pendente, // ignorado
        ),
      ];
      final r = resumoPeriodo(lancs);
      expect(r.entradas, closeTo(0.30, 1e-9));
      expect(r.saidas, closeTo(0.30, 1e-9));
      expect(r.saldoMes, closeTo(0.0, 1e-9)); // 0.1+0.2-0.3 == 0 exato
    });

    test('receita prevista de OS atribuída NÃO entra no mês realizado', () {
      final lancs = [
        fakeLanc(
          id: 'pago-os',
          tipo: TipoLancamento.receita,
          valor: 200,
          status: LancamentoStatus.pago,
          origem: OrigemLancamento.viaOs,
        ),
        fakeLanc(
          id: 'manual',
          tipo: TipoLancamento.receita,
          valor: 50,
          status: LancamentoStatus.pago,
          origem: OrigemLancamento.manual,
        ),
        fakeLanc(
          id: 'previsto-os',
          tipo: TipoLancamento.receita,
          valor: 600,
          status: LancamentoStatus.previsto,
          origem: OrigemLancamento.viaOs,
        ),
      ];
      final r = resumoPeriodo(lancs);
      expect(r.entradas, closeTo(250, 1e-9));
      expect(totalReceitasPrevistas(lancs), closeTo(600, 1e-9));
    });

    test('resumoPeriodoCompetencia soma pago + não pago (balanço Extrato)', () {
      final lancs = [
        fakeLanc(
          id: 'r1',
          tipo: TipoLancamento.receita,
          valor: 1000,
          status: LancamentoStatus.pago,
        ),
        fakeLanc(
          id: 'r2',
          tipo: TipoLancamento.receita,
          valor: 500,
          status: LancamentoStatus.previsto,
        ),
        fakeLanc(
          id: 'd1',
          tipo: TipoLancamento.despesa,
          valor: 300,
          status: LancamentoStatus.pendente,
        ),
        fakeLanc(
          id: 'd2',
          tipo: TipoLancamento.despesa,
          valor: 200,
          status: LancamentoStatus.pago,
        ),
      ];
      // Realizado: 1000 - 200 = 800
      expect(resumoPeriodo(lancs).saldoMes, closeTo(800, 1e-9));
      // Competência: 1500 - 500 = 1000
      final c = resumoPeriodoCompetencia(lancs);
      expect(c.entradas, closeTo(1500, 1e-9));
      expect(c.saidas, closeTo(500, 1e-9));
      expect(c.saldoMes, closeTo(1000, 1e-9));
    });

    test('compromissosResumo projeta realizado + a receber − comissões', () {
      final lancs = [
        fakeLanc(
          id: '1',
          tipo: TipoLancamento.receita,
          valor: 1000,
          status: LancamentoStatus.pago,
        ),
        fakeLanc(
          id: '2',
          tipo: TipoLancamento.receita,
          valor: 400,
          status: LancamentoStatus.previsto,
        ),
      ];
      final c = compromissosResumo(
        lancsPeriodo: lancs,
        comissoesPendentes: 300,
      );
      expect(c.resultadoRealizado, closeTo(1000, 1e-9));
      expect(c.aReceber, closeTo(400, 1e-9));
      expect(c.comissoesAPagar, closeTo(300, 1e-9));
      // 1000 + 400 - 300 = 1100
      expect(c.resultadoProjetado, closeTo(1100, 1e-9));
    });
  });

  group('saldoGeral', () {
    test('soma saldoAtual das contas em centavos', () {
      final contas = [
        fakeConta(id: 'a', saldoAtual: 100.10),
        fakeConta(id: 'b', saldoAtual: 50.05),
      ];
      expect(saldoGeral(contas), closeTo(150.15, 1e-9));
    });
  });

  group('agruparPorData', () {
    test('agrupa por dia desc com total com sinal', () {
      final lancs = [
        fakeLanc(
          id: '1',
          data: '2026-07-10',
          tipo: TipoLancamento.receita,
          valor: 300,
        ),
        fakeLanc(
          id: '2',
          data: '2026-07-10',
          tipo: TipoLancamento.despesa,
          valor: 100,
        ),
        fakeLanc(
          id: '3',
          data: '2026-07-08',
          tipo: TipoLancamento.despesa,
          valor: 50,
        ),
      ];
      final grupos = agruparPorData(lancs);
      expect(grupos.length, 2);
      expect(grupos.first.data, '2026-07-10'); // mais recente primeiro
      expect(grupos.first.totalDia, closeTo(200, 1e-9)); // 300 - 100
      expect(grupos.last.totalDia, closeTo(-50, 1e-9));
    });

    test('total do dia ignora receita prevista (OS ainda não concluída)', () {
      final lancs = [
        fakeLanc(
          id: '1',
          data: '2026-07-16',
          tipo: TipoLancamento.receita,
          valor: 200,
          status: LancamentoStatus.pago,
        ),
        fakeLanc(
          id: '2',
          data: '2026-07-16',
          tipo: TipoLancamento.receita,
          valor: 200,
          status: LancamentoStatus.previsto,
          origem: OrigemLancamento.viaOs,
        ),
      ];
      final grupos = agruparPorData(lancs);
      expect(grupos.single.itens.length, 2); // ambos na lista
      expect(grupos.single.totalDia, closeTo(200, 1e-9)); // só o pago
    });
  });

  group('isLancamentoDependenteExterno', () {
    test('via_os e os_id são dependentes da OS', () {
      expect(
        isLancamentoDependenteExterno(
          fakeLanc(id: '1', status: LancamentoStatus.pago)
              .copyWith(origem: OrigemLancamento.viaOs),
        ),
        isTrue,
      );
      expect(
        isLancamentoViaOs(
          fakeLanc(id: '2').copyWith(osId: 'os-abc'),
        ),
        isTrue,
      );
    });

    test('comissão sintética e repasse são dependentes da equipe', () {
      expect(
        isLancamentoComissao(
          fakeLanc(id: 'comissao-previsto-prof-jp'),
        ),
        isTrue,
      );
      expect(
        isLancamentoComissao(
          fakeLanc(id: 'r1', descricao: 'Repasse comissões · JP'),
        ),
        isTrue,
      );
      expect(
        isLancamentoDependenteExterno(
          fakeLanc(id: 'manual', status: LancamentoStatus.pendente),
        ),
        isFalse,
      );
    });
  });

  group('isLancamentoAtrasado', () {
    const hoje = '2026-07-22';

    test('pago nunca é atrasado', () {
      expect(
        isLancamentoAtrasado(
          fakeLanc(
            id: '1',
            status: LancamentoStatus.pago,
            data: '2026-07-01',
            vencimento: '2026-07-01',
          ),
          hoje,
        ),
        isFalse,
      );
    });

    test('pendente com data futura não é atrasado', () {
      expect(
        isLancamentoAtrasado(
          fakeLanc(
            id: '2',
            status: LancamentoStatus.pendente,
            data: '2026-07-27',
          ),
          hoje,
        ),
        isFalse,
      );
    });

    test('pendente com data passada é atrasado', () {
      expect(
        isLancamentoAtrasado(
          fakeLanc(
            id: '3',
            status: LancamentoStatus.pendente,
            data: '2026-07-10',
          ),
          hoje,
        ),
        isTrue,
      );
    });

    test('usa vencimento quando presente; data só como fallback', () {
      expect(
        isLancamentoAtrasado(
          fakeLanc(
            id: '4',
            status: LancamentoStatus.pendente,
            data: '2026-07-01',
            vencimento: '2026-07-30',
          ),
          hoje,
        ),
        isFalse,
      );
      expect(
        isLancamentoAtrasado(
          fakeLanc(
            id: '5',
            status: LancamentoStatus.pendente,
            data: '2026-07-30',
            vencimento: '2026-07-10',
          ),
          hoje,
        ),
        isTrue,
      );
    });

    test('status em_atraso conta mesmo com data futura', () {
      expect(
        isLancamentoAtrasado(
          fakeLanc(
            id: '6',
            status: LancamentoStatus.emAtraso,
            data: '2026-07-30',
          ),
          hoje,
        ),
        isTrue,
      );
    });
  });

  group('contasAPagar / contasAReceber', () {
    test('separa por tipo, marca atraso/vencendo-hoje e ordena por venc', () {
      const hoje = '2026-07-15';
      final lancs = [
        fakeLanc(
          id: 'atrasada',
          tipo: TipoLancamento.despesa,
          status: LancamentoStatus.pendente,
          vencimento: '2026-07-10',
        ),
        fakeLanc(
          id: 'hoje',
          tipo: TipoLancamento.despesa,
          status: LancamentoStatus.pendente,
          vencimento: '2026-07-15',
        ),
        fakeLanc(
          id: 'receber',
          tipo: TipoLancamento.receita,
          status: LancamentoStatus.previsto,
          vencimento: '2026-07-20',
        ),
        fakeLanc(id: 'paga', status: LancamentoStatus.pago), // fora
      ];
      final pagar = contasAPagar(lancs, hoje);
      expect(pagar.map((p) => p.lancamento.id), ['atrasada', 'hoje']);
      expect(pagar.first.emAtraso, isTrue);
      expect(pagar[1].vencendoHoje, isTrue);

      final receber = contasAReceber(lancs, hoje);
      expect(receber.length, 1);
      expect(receber.first.lancamento.id, 'receber');
    });

    test('sem vencimento usa data do lançamento para atraso', () {
      const hoje = '2026-07-15';
      final pagar = contasAPagar(
        [
          fakeLanc(
            id: 'por-data',
            tipo: TipoLancamento.despesa,
            status: LancamentoStatus.pendente,
            data: '2026-07-01',
          ),
        ],
        hoje,
      );
      expect(pagar.single.emAtraso, isTrue);
    });
  });

  group('progressoLimite', () {
    test('soma despesas pagas da categoria (mãe ou sub) e clampa pct', () {
      final limite = fakeLimite(id: 'l', categoriaId: 'cat', limite: 200);
      final lancs = [
        fakeLanc(id: '1', categoriaId: 'cat', valor: 150),
        fakeLanc(id: '2', categoriaId: 'outra', valor: 100),
        fakeLanc(
          id: '3',
          tipo: TipoLancamento.receita,
          categoriaId: 'cat',
          valor: 999,
        ), // receita ignorada
      ];
      final p = progressoLimite(limite, lancs);
      expect(p.gasto, closeTo(150, 1e-9));
      expect(p.pct, closeTo(0.75, 1e-9));

      // estouro → pct clampa em 1.
      final estourado = progressoLimite(
        fakeLimite(id: 'l', categoriaId: 'cat', limite: 100),
        lancs,
      );
      expect(estourado.pct, 1.0);
    });
  });

  group('formatDateOnlyBr', () {
    test('reordena YYYY-MM-DD → dd/MM/yyyy sem tocar no fuso', () {
      expect(formatDateOnlyBr('2026-07-01'), '01/07/2026');
      expect(formatDateOnlyBr('2026-07-01 03:00:00'), '01/07/2026');
    });
  });

  group('filtros PB', () {
    test('finPeriodoFilter usa o campo data', () {
      final f = finPeriodoFilter(mesPeriodo(2026, 7));
      expect(f, "data >= '2026-07-01' && data < '2026-08-01'");
    });

    test('finLancamentosFilter escapa a busca (anti-injeção)', () {
      final f = finLancamentosFilter(search: "a' || 1=1");
      expect(f, contains(r"a\' || 1=1"));
    });

    test('finLancamentosFilter exclui comissão 1:1 legada (via_comissao+id)', () {
      final f = finLancamentosFilter();
      expect(f, contains("origem != 'via_comissao'"));
      expect(f, contains("comissao_id = ''"));
    });

    test('finContasPendentesFilter filtra tipo + não pago + sem comissão 1:1',
        () {
      final f = finContasPendentesFilter(TipoLancamento.despesa);
      expect(f, contains("tipo = 'despesa' && status != 'pago'"));
      expect(f, contains("origem != 'via_comissao'"));
    });
  });

  group('finCategoriaComissaoIds + finComissoesPendentesComoLancamentos', () {
    final cats = [
      fakeCategoria(id: 'eq', nome: 'Equipe', tipo: TipoLancamento.despesa),
      fakeCategoria(
        id: 'prof',
        nome: 'Profissionais',
        tipo: TipoLancamento.despesa,
        parentId: 'eq',
      ),
      fakeCategoria(
        id: 'com',
        nome: 'Comissões',
        tipo: TipoLancamento.despesa,
        parentId: 'eq',
      ),
    ];

    test('resolve Equipe → Profissionais (canônico)', () {
      final ids = finCategoriaComissaoIds(cats)!;
      expect(ids.categoriaId, 'eq');
      expect(ids.subcategoriaId, 'prof');
    });

    test('1 linha por profissional com total e data de repasse', () {
      final now = DateTime.utc(2026, 7, 21, 15); // BRT 21/07
      final jp = User(
        id: 'jp',
        name: 'João Pedro',
        role: Role.profissional,
        pagamentoFrequencia: PagamentoFrequencia.quinzenal,
        pagamentoDia: 15,
        pagamentoDia2: 0, // último dia do mês
      );
      final lancs = finComissoesPendentesComoLancamentos(
        comissoes: [
          const ProfComissao(
            id: 'c1',
            profissional: 'jp',
            os: 'os1',
            valorComissao: 60,
            status: ComissaoStatus.pendente,
            data: '2026-07-16',
            descricao: 'Cleanox Completo',
          ),
          const ProfComissao(
            id: 'c2',
            profissional: 'jp',
            os: 'os2',
            valorComissao: 90,
            status: ComissaoStatus.pendente,
            data: '2026-07-18',
            descricao: 'Premium',
          ),
          const ProfComissao(
            id: 'c3',
            profissional: 'jp',
            os: 'os3',
            valorComissao: 100,
            status: ComissaoStatus.paga,
            data: '2026-07-16',
            descricao: 'já paga',
          ),
        ],
        categorias: cats,
        profissionais: [jp],
        nomePorProfId: const {'jp': 'João Pedro'},
        contaId: 'caixa',
        now: now,
      );
      expect(lancs, hasLength(1));
      final l = lancs.single;
      expect(l.id, '$kFinComissaoPrevistoProfPrefix${'jp'}');
      expect(finComissaoPrevistoProfId(l.id), 'jp');
      expect(l.tipo, TipoLancamento.despesa);
      expect(l.status, LancamentoStatus.previsto);
      expect(l.categoriaId, 'eq');
      expect(l.subcategoriaId, 'prof');
      // 60+90; paga não entra
      expect(l.valor, 150);
      // quinzenal 15 + último dia → próximo após 21/07 = 31/07
      expect(l.data, '2026-07-31');
      expect(l.vencimento, '2026-07-31');
      expect(l.descricao, 'Comissão · João Pedro');
      expect(l.descricao, isNot(contains('Cleanox Completo')));
      expect(l.descricao, isNot(contains('previsto')));
      final aPagar = contasAPagar(lancs, '2026-07-21');
      expect(aPagar, hasLength(1));
      expect(aPagar.single.lancamento.valor, 150);
    });

    test('soma por profissional (não 1 por OS)', () {
      final now = DateTime.utc(2026, 7, 21, 15);
      final profs = [
        User(
          id: 'jp',
          name: 'João Pedro',
          role: Role.profissional,
          pagamentoFrequencia: PagamentoFrequencia.quinzenal,
          pagamentoDia: 15,
          pagamentoDia2: 0,
        ),
        User(
          id: 'hp',
          name: 'Hendrio Piter',
          role: Role.profissional,
          pagamentoFrequencia: PagamentoFrequencia.quinzenal,
          pagamentoDia: 15,
          pagamentoDia2: 0,
        ),
      ];
      final lancs = finComissoesPendentesComoLancamentos(
        comissoes: [
          for (var i = 0; i < 7; i++)
            ProfComissao(
              id: 'j$i',
              profissional: 'jp',
              os: 'os$i',
              valorComissao: i == 3 ? 90 : 60,
              status: ComissaoStatus.pendente,
              data: '2026-07-16',
            ),
          for (var i = 0; i < 3; i++)
            ProfComissao(
              id: 'h$i',
              profissional: 'hp',
              os: 'osh$i',
              valorComissao: 100,
              status: ComissaoStatus.pendente,
              data: '2026-07-18',
            ),
        ],
        categorias: cats,
        profissionais: profs,
        now: now,
      );
      // 2 profissionais, não 10 linhas
      expect(lancs, hasLength(2));
      final byId = {for (final l in lancs) finComissaoPrevistoProfId(l.id)!: l};
      // 6×60 + 90 = 450
      expect(byId['jp']!.valor, 450);
      expect(byId['hp']!.valor, 300);
      expect(byId['jp']!.data, '2026-07-31');
      expect(byId['hp']!.data, '2026-07-31');
      final total = lancs.fold<int>(0, (s, x) => s + (x.valor * 100).round());
      expect(total / 100.0, 750);
    });
  });

  group('FinTab.isKnownSlug (canonicalização de slug de aba)', () {
    test('slugs reais das abas do Financeiro são conhecidos', () {
      for (final tab in FinTab.values) {
        expect(FinTab.isKnownSlug(tab.slug), isTrue, reason: tab.slug);
      }
    });

    test('slug desconhecido/null/vazio NÃO é conhecido (vira visao-geral)', () {
      expect(FinTab.isKnownSlug('lixo'), isFalse);
      expect(FinTab.isKnownSlug(null), isFalse);
      expect(FinTab.isKnownSlug(''), isFalse);
      // fromSlug segue caindo no fallback defensivo enquanto a URL é corrigida.
      expect(FinTab.fromSlug('lixo'), FinTab.principal);
    });
  });

  group('comissaoPrevistaAtribuidas (até próximo pagamento)', () {
    const prof = User(
      id: 'jp',
      name: 'João Pedro',
      role: Role.profissional,
      comissaoTipo: ComissaoTipo.percentual,
      comissaoValor: 30,
    );

    OrdemServico os({
      required String id,
      required String dataHora,
      double valor = 200,
    }) =>
        OrdemServico(
          id: id,
          nomeCurto: id,
          dataHora: dataHora,
          profissional: 'jp',
          status: OSStatus.atribuida,
          valorServico: valor,
        );

    test('sem limite: soma todas as OS abertas', () {
      final r = comissaoPrevistaAtribuidas(
        prof: prof,
        osAbertas: [
          os(id: 'a', dataHora: '2026-07-25 12:00:00.000Z'), // 25 BRT 09h
          os(id: 'b', dataHora: '2026-08-01 12:00:00.000Z'), // 01/08
        ],
      );
      // 2× 200 × 30% = 120
      expect(r.valor, 120);
      expect(r.qtdOs, 2);
    });

    test('com ate: só OS com dia BRT <= próximo pagamento', () {
      final r = comissaoPrevistaAtribuidas(
        prof: prof,
        osAbertas: [
          os(id: 'a', dataHora: '2026-07-25 12:00:00.000Z'), // 25
          os(id: 'b', dataHora: '2026-07-31 15:00:00.000Z'), // 31 BRT 12h
          os(id: 'c', dataHora: '2026-08-01 12:00:00.000Z'), // 01/08 — fora
        ],
        ate: DateTime.utc(2026, 7, 31),
      );
      // 2 × 200 × 30% = 120 (c excluída)
      expect(r.qtdOs, 2);
      expect(r.valor, 120);
    });

    test('diária conta dias únicos até o limite', () {
      const h = User(
        id: 'hp',
        name: 'Hendrio',
        role: Role.profissional,
        comissaoTipo: ComissaoTipo.diaria,
        comissaoValor: 100,
      );
      final r = comissaoPrevistaAtribuidas(
        prof: h,
        osAbertas: [
          OrdemServico(
            id: '1',
            profissional: 'hp',
            status: OSStatus.atribuida,
            dataHora: '2026-07-22 12:00:00.000Z',
          ),
          OrdemServico(
            id: '2',
            profissional: 'hp',
            status: OSStatus.atribuida,
            dataHora: '2026-07-22 18:00:00.000Z', // mesmo dia BRT
          ),
          OrdemServico(
            id: '3',
            profissional: 'hp',
            status: OSStatus.atribuida,
            dataHora: '2026-08-05 12:00:00.000Z', // após limite
          ),
        ],
        ate: DateTime.utc(2026, 7, 31),
      );
      expect(r.qtdOs, 2);
      expect(r.valor, 100); // 1 dia × 100
    });
  });

  group('consolidarViaOsPorOs', () {
    test('2 linhas via_os da mesma OS → 1 linha com valor total', () {
      const a = FinLancamento(
        id: 'l1',
        tipo: TipoLancamento.receita,
        descricao: 'OS 3041NH - Adriano - S10 · Cleanox Completo',
        valor: 200,
        data: '2026-07-25',
        status: LancamentoStatus.previsto,
        origem: OrigemLancamento.viaOs,
        osId: 'rrnwqvuac3041nh',
        clienteNome: 'Adriano - S10 e Honda City',
        servicoNome: 'Cleanox Completo - Promoção',
      );
      const b = FinLancamento(
        id: 'l2',
        tipo: TipoLancamento.receita,
        descricao: 'OS 3041NH - Adriano - S10 · Cleanox Completo',
        valor: 200,
        data: '2026-07-25',
        status: LancamentoStatus.previsto,
        origem: OrigemLancamento.viaOs,
        osId: 'rrnwqvuac3041nh',
        clienteNome: 'Adriano - S10 e Honda City',
        servicoNome: 'Cleanox Completo - Promoção',
      );
      final out = consolidarViaOsPorOs([a, b]);
      expect(out, hasLength(1));
      expect(out.first.valor, 400);
      expect(out.first.descricao, contains('2 serviços'));
      expect(out.first.clienteNome, 'Adriano - S10 e Honda City');
    });

    test('OS distintas e manual não se misturam', () {
      const osA = FinLancamento(
        id: '1',
        tipo: TipoLancamento.receita,
        valor: 200,
        data: '2026-07-25',
        origem: OrigemLancamento.viaOs,
        osId: 'osA',
        clienteNome: 'A',
      );
      const osB = FinLancamento(
        id: '2',
        tipo: TipoLancamento.receita,
        valor: 150,
        data: '2026-07-25',
        origem: OrigemLancamento.viaOs,
        osId: 'osB',
        clienteNome: 'B',
      );
      final manual = fakeLanc(id: '3', valor: 50, data: '2026-07-25');
      final out = consolidarViaOsPorOs([osA, osB, manual]);
      expect(out, hasLength(3));
      expect(out.map((e) => e.valor).toList(), [200.0, 150.0, 50.0]);
    });

    test('agruparPorData consolida por padrão', () {
      const a = FinLancamento(
        id: 'l1',
        tipo: TipoLancamento.receita,
        valor: 200,
        data: '2026-07-25',
        origem: OrigemLancamento.viaOs,
        osId: 'os1',
        status: LancamentoStatus.previsto,
      );
      const b = FinLancamento(
        id: 'l2',
        tipo: TipoLancamento.receita,
        valor: 200,
        data: '2026-07-25',
        origem: OrigemLancamento.viaOs,
        osId: 'os1',
        status: LancamentoStatus.previsto,
      );
      final g = agruparPorData([a, b]);
      expect(g, hasLength(1));
      expect(g.first.itens, hasLength(1));
      expect(g.first.itens.first.valor, 400);
    });
  });
}
