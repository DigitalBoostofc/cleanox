/// agenda_layout_test.dart — Núcleo PURO do calendário (agenda estilo Google).
///
/// Cobre os casos obrigatórios da spec (§5): duração efetiva (OS > prof > 60,
/// incluindo o `0` que o PB devolve em campo numérico vazio), intervalo em
/// minutos-BRT, sobreposições (aviso do form == desenho da grade) e o layout em
/// colunas — sem overlap, overlap parcial, total, cadeia A/B/C (largura 1/2), N
/// idênticos (teto + "+N"), duração zero, fora da janela e cruzando meia-noite.
///
/// Tudo determinístico: nenhum `DateTime.now()` no meio do cálculo (gate G-8).
library;

import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:flutter_test/flutter_test.dart';

/// OS com `data_hora` no relógio de parede BRT (convertido p/ UTC como o PB grava).
OrdemServico _os({
  required String id,
  String hhmm = '08:00',
  int? duracaoMin,
  String data = '2026-07-20',
  String nomeCurto = 'Cliente',
}) => OrdemServico(
  id: id,
  nomeCurto: nomeCurto,
  dataHora: localInputToPBDate('${data}T$hhmm'),
  duracaoMin: duracaoMin,
);

Intervalo _iv(String id, int start, int end, {String groupKey = ''}) =>
    Intervalo(id: id, startMin: start, endMin: end, groupKey: groupKey);

/// Minutos-BRT de 'HH:MM'.
int _min(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

void main() {
  group('duracaoEfetivaMin (OS > profissional > 60)', () {
    test('duração da OS vence a do profissional', () {
      final disp = const Disponibilidade(id: 'd', duracaoMin: 90);
      expect(duracaoEfetivaMin(_os(id: 'a', duracaoMin: 45), disp), 45);
    });

    test('sem duração na OS → cai na do profissional', () {
      final disp = const Disponibilidade(id: 'd', duracaoMin: 90);
      expect(duracaoEfetivaMin(_os(id: 'a'), disp), 90);
    });

    test('sem OS e sem profissional → 60', () {
      expect(duracaoEfetivaMin(_os(id: 'a')), 60);
    });

    test('profissional com duracao_min 0 (campo PB vazio) → 60', () {
      final disp = const Disponibilidade(id: 'd');
      expect(duracaoEfetivaMin(_os(id: 'a'), disp), 60);
    });

    test('OS ANTIGA do PB ("duracao_min": 0) → normaliza p/ null e usa o prof', () {
      // Record REAL de antes da migration 27: o NumberField vazio volta 0.
      final antiga = OrdemServico.fromJson(const {
        'id': 'velha',
        'cliente': 'c1',
        'nome_curto': 'Carlos S.',
        'data_hora': '2026-07-20 11:00:00.000Z',
        'duracao_min': 0,
        'status': 'agendada',
      });
      expect(antiga.duracaoMin, isNull, reason: 'R2 numérica: 0 → null');
      expect(
        duracaoEfetivaMin(antiga, const Disponibilidade(id: 'd', duracaoMin: 120)),
        120,
      );
      expect(duracaoEfetivaMin(antiga), 60);
    });
  });

  group('intervaloBrtMin', () {
    test('08:00 BRT + 90min → [480, 570)', () {
      final i = intervaloBrtMin(_os(id: 'a', hhmm: '08:00', duracaoMin: 90));
      expect(i.startMin, 480);
      expect(i.endMin, 570);
    });

    test('serviço noturno (23:00 BRT = 02:00 UTC do dia seguinte)', () {
      final os = _os(id: 'noturna', hhmm: '23:00', duracaoMin: 120);
      // O PB guarda em UTC (+3h): vira 02:00 do dia seguinte.
      expect(os.dataHora, contains('2026-07-21 02:00'));
      // ...mas o relógio de parede BRT é 23:00 → 25:00 (cruza a meia-noite).
      final i = intervaloBrtMin(os);
      expect(i.startMin, 23 * 60);
      expect(i.endMin, 25 * 60);
    });

    test('data_hora vazia não explode', () {
      final i = intervaloBrtMin(const OrdemServico(id: 'x'));
      expect(i.startMin, 0);
      expect(i.endMin, 60);
    });

    test('faixaHorariaDaOs formata "08:00–10:00"', () {
      expect(faixaHorariaDaOs(_os(id: 'a', hhmm: '08:00', duracaoMin: 120)), '08:00–10:00');
    });
  });

  group('sobreposicoes', () {
    final ocupados = [
      _iv('a', _min('08:00'), _min('10:00')),
      _iv('b', _min('14:00'), _min('15:00')),
    ];

    test('encaixe sem colisão → vazio', () {
      expect(sobreposicoes(ocupados, _min('11:00'), 60), isEmpty);
    });

    test('encostar não é sobrepor (half-open)', () {
      expect(sobreposicoes(ocupados, _min('10:00'), 60), isEmpty);
      expect(sobreposicoes(ocupados, _min('07:00'), 60), isEmpty);
    });

    test('colisão parcial → devolve a OS colidida', () {
      final r = sobreposicoes(ocupados, _min('09:30'), 60);
      expect(r.map((e) => e.id), ['a']);
    });

    test('um novo evento pode colidir com vários', () {
      final r = sobreposicoes(ocupados, _min('09:00'), 8 * 60);
      expect(r.map((e) => e.id), ['a', 'b']);
    });

    test('duração 0 é elevada ao mínimo de layout (15min) — igual à grade', () {
      // 09:59 + 0min não sobreporia nada; com o mínimo de 15min, invade a 'a'.
      expect(sobreposicoes(ocupados, _min('09:59'), 0).map((e) => e.id), ['a']);
    });
  });

  group('layoutDayEvents', () {
    test('sem sobreposição → todos em coluna única', () {
      final l = layoutDayEvents([
        _iv('a', _min('08:00'), _min('09:00')),
        _iv('b', _min('10:00'), _min('11:00')),
      ]);
      expect(l.eventos.length, 2);
      for (final e in l.eventos) {
        expect(e.column, 0);
        expect(e.columnCount, 1);
      }
      expect(l.excedentes, isEmpty);
    });

    test('sobreposição PARCIAL → 2 colunas', () {
      final l = layoutDayEvents([
        _iv('a', _min('08:00'), _min('10:00')),
        _iv('b', _min('09:00'), _min('11:00')),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['a']!.column, 0);
      expect(byId['b']!.column, 1);
      expect(byId['a']!.columnCount, 2);
      expect(byId['b']!.columnCount, 2);
    });

    test('sobreposição TOTAL (mesmo horário) → colunas distintas', () {
      final l = layoutDayEvents([
        _iv('a', _min('08:00'), _min('09:00')),
        _iv('b', _min('08:00'), _min('09:00')),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      expect({byId['a']!.column, byId['b']!.column}, {0, 1});
      expect(byId['a']!.columnCount, 2);
    });

    test('mesmo horário: profissionais distintos ficam em colunas estáveis', () {
      // Sem groupOrder: fallback lexicográfico do groupKey.
      final l = layoutDayEvents([
        _iv('os-g', _min('14:00'), _min('16:00'), groupKey: 'gabriela'),
        _iv('os-j', _min('14:00'), _min('16:00'), groupKey: 'jose'),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      // groupKey lexicográfico: gabriela < jose → Gabriela à esquerda.
      expect(byId['os-g']!.column, 0);
      expect(byId['os-j']!.column, 1);
      expect(byId['os-g']!.columnCount, 2);
    });

    test('groupOrder: 1º prof sempre à esquerda (mesmo se id for depois no lexico)', () {
      // Ordem canônica: José = 1º, Gabriela = 2º — José à esquerda SEMPRE.
      final l = layoutDayEvents(
        [
          _iv('os-g', _min('14:00'), _min('16:00'), groupKey: 'gabriela'),
          _iv('os-j', _min('14:00'), _min('16:00'), groupKey: 'jose'),
        ],
        groupOrder: const ['jose', 'gabriela'],
      );
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['os-j']!.column, 0, reason: '1º da lista → esquerda');
      expect(byId['os-g']!.column, 1, reason: '2º da lista → direita');
    });

    test('groupOrder: 1º/2º/3º/4º no mesmo horário', () {
      final l = layoutDayEvents(
        [
          _iv('d', _min('10:00'), _min('11:00'), groupKey: 'd'),
          _iv('b', _min('10:00'), _min('11:00'), groupKey: 'b'),
          _iv('a', _min('10:00'), _min('11:00'), groupKey: 'a'),
          _iv('c', _min('10:00'), _min('11:00'), groupKey: 'c'),
        ],
        groupOrder: const ['a', 'b', 'c', 'd'],
      );
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['a']!.column, 0);
      expect(byId['b']!.column, 1);
      expect(byId['c']!.column, 2);
      expect(byId['d']!.column, 3);
      for (final e in l.eventos) {
        expect(e.columnCount, 4);
      }
    });

    test('groupOrder: só 1º e 3º no slot — 1º esquerda, 3º direita (sem buraco)', () {
      final l = layoutDayEvents(
        [
          _iv('p3', _min('10:00'), _min('12:00'), groupKey: 'p3'),
          _iv('p1', _min('10:00'), _min('12:00'), groupKey: 'p1'),
        ],
        groupOrder: const ['p1', 'p2', 'p3', 'p4'],
      );
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['p1']!.column, 0);
      expect(byId['p3']!.column, 1);
      expect(byId['p1']!.columnCount, 2);
    });

    test('1º prof com 2 OS no mesmo horário NÃO invade o lado do 2º', () {
      // Regressão print 2026-07-23: 2 OS verdes (Hendrio) + 1 azul (João)
      // → verdes à esquerda (cols 0 e 1), azul à direita (col 2). Nunca
      // verde–azul–verde.
      final l = layoutDayEvents(
        [
          _iv('h1', _min('13:00'), _min('16:00'), groupKey: 'hendrio'),
          _iv('h2', _min('13:00'), _min('16:00'), groupKey: 'hendrio'),
          _iv('j1', _min('14:00'), _min('17:00'), groupKey: 'joao'),
        ],
        groupOrder: const ['hendrio', 'joao'],
      );
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['h1']!.column, 0);
      expect(byId['h2']!.column, 1);
      expect(byId['j1']!.column, 2, reason: '2º prof fica DEPOIS da faixa do 1º');
      for (final e in l.eventos) {
        expect(e.columnCount, 3);
      }
      // Todas as cols de hendrio < joao
      expect(byId['h1']!.column < byId['j1']!.column, isTrue);
      expect(byId['h2']!.column < byId['j1']!.column, isTrue);
    });

    test('no mesmo aglomerado, o mesmo profissional reusa a coluna', () {
      // G 09–12 mantém o aglomerado aberto; J 09–10 e J 10:30–11:30 ficam
      // no MESMO cluster (half-open: 11:00 encostando em 11:00 sairia).
      final l = layoutDayEvents([
        _iv('j1', _min('09:00'), _min('10:00'), groupKey: 'jose'),
        _iv('g1', _min('09:00'), _min('12:00'), groupKey: 'gabriela'),
        _iv('j2', _min('10:30'), _min('11:30'), groupKey: 'jose'),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      // gabriela < jose → G col 0, J col 1; j2 prefere a coluna 1 de jose.
      expect(byId['g1']!.column, 0);
      expect(byId['j1']!.column, 1);
      expect(byId['j2']!.column, 1, reason: 'mesmo prof reusa a coluna dele');
      for (final e in l.eventos) {
        expect(e.columnCount, 2);
      }
    });

    test('lados estáveis no DIA: manhã e tarde não trocam profissional de lado', () {
      // Com groupOrder fixo: José = 1º (esquerda), Gabriela = 2º (direita).
      final l = layoutDayEvents(
        [
          _iv('j-manha', _min('08:00'), _min('10:00'), groupKey: 'jose'),
          _iv('g-manha', _min('09:00'), _min('11:00'), groupKey: 'gabriela'),
          _iv('g-tarde', _min('14:00'), _min('16:00'), groupKey: 'gabriela'),
          _iv('j-tarde', _min('15:00'), _min('17:00'), groupKey: 'jose'),
        ],
        groupOrder: const ['jose', 'gabriela'],
      );
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['j-manha']!.column, 0, reason: 'José 1º à esquerda de manhã');
      expect(byId['g-manha']!.column, 1, reason: 'Gabriela 2º à direita de manhã');
      expect(byId['j-tarde']!.column, 0, reason: 'José 1º à esquerda à tarde');
      expect(byId['g-tarde']!.column, 1, reason: 'Gabriela 2º à direita à tarde');
      for (final id in ['g-manha', 'j-manha', 'g-tarde', 'j-tarde']) {
        expect(byId[id]!.columnCount, 2);
      }
    });

    test('profissional sozinho no slot usa largura cheia (sem buraco)', () {
      final l = layoutDayEvents(
        [
          _iv('so-j', _min('08:00'), _min('10:00'), groupKey: 'jose'),
          _iv('so-g', _min('14:00'), _min('16:00'), groupKey: 'gabriela'),
        ],
        groupOrder: const ['jose', 'gabriela'],
      );
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['so-j']!.column, 0);
      expect(byId['so-j']!.columnCount, 1);
      expect(byId['so-g']!.column, 0);
      expect(byId['so-g']!.columnCount, 1);
    });

    test('rankProfissionais respeita 1º/2º/3º da lista', () {
      final r = rankProfissionais(
        ['c', 'a'],
        groupOrder: const ['a', 'b', 'c', 'd'],
      );
      expect(r['a'], 0);
      expect(r['c'], 1);
      expect(r.containsKey('b'), isFalse);
    });

    test('sem groupKey, cadeia clássica A/B/C não muda', () {
      // Regressão: empacotamento antigo (sem profissional) continua válido.
      final l = layoutDayEvents([
        _iv('A', _min('09:00'), _min('12:00')),
        _iv('B', _min('09:00'), _min('10:00')),
        _iv('C', _min('10:00'), _min('11:00')),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['A']!.column, 0);
      expect(byId['B']!.column, 1);
      expect(byId['C']!.column, 1);
    });

    test('cadeia A(9–12) / B(9–10) / C(10–11) → largura 1/2 em todas', () {
      // C não sobrepõe B, então reusa a coluna 1: o aglomerado tem 2 colunas —
      // e A precisa saber disso (maxColumns FINAL, não o corrente).
      final l = layoutDayEvents([
        _iv('A', _min('09:00'), _min('12:00')),
        _iv('B', _min('09:00'), _min('10:00')),
        _iv('C', _min('10:00'), _min('11:00')),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['A']!.column, 0);
      expect(byId['B']!.column, 1);
      expect(byId['C']!.column, 1, reason: 'C reusa a coluna livre de B');
      for (final e in l.eventos) {
        expect(e.columnCount, 2, reason: 'largura = 1/2 no aglomerado inteiro');
      }
      expect(l.excedentes, isEmpty);
    });

    test('N idênticos além do teto → colunas capadas + excedente "+N"', () {
      final l = layoutDayEvents([
        for (var i = 0; i < 8; i++)
          _iv('os$i', _min('13:00'), _min('14:00')),
      ], maxColunas: kMaxColunasDesktop);

      expect(l.eventos.length, kMaxColunasDesktop);
      expect(l.eventos.every((e) => e.columnCount == kMaxColunasDesktop), isTrue);
      expect(l.excedentes.length, 1);
      expect(l.excedentes.first.count, 3); // 8 - 5
      expect(l.excedentes.first.startMin, _min('13:00'));
    });

    test('teto mobile (3 colunas) é mais apertado que o desktop', () {
      final eventos = [
        for (var i = 0; i < 5; i++) _iv('os$i', _min('13:00'), _min('14:00')),
      ];
      final mobile = layoutDayEvents(eventos, maxColunas: kMaxColunasMobile);
      expect(mobile.eventos.length, 3);
      expect(mobile.excedentes.first.count, 2);
    });

    test('duração ZERO ocupa o mínimo de 15min (e sobrepõe de verdade)', () {
      final l = layoutDayEvents([
        _iv('zero', _min('09:00'), _min('09:00')),
        _iv('outra', _min('09:05'), _min('10:00')),
      ]);
      final byId = {for (final e in l.eventos) e.id: e};
      expect(byId['zero']!.duracaoMin, kDuracaoMinimaMin);
      // As duas se sobrepõem (09:00–09:15 × 09:05–10:00) → 2 colunas.
      expect(byId['zero']!.columnCount, 2);
      expect(byId['outra']!.columnCount, 2);
    });

    test('evento FORA da janela padrão expande a janela (não some)', () {
      final l = layoutDayEvents([
        _iv('madrugada', _min('05:30'), _min('06:30')),
        _iv('noite', _min('21:00'), _min('23:30')),
      ]);
      expect(l.dayStart, _min('05:00'), reason: 'chão da hora do 1º início');
      expect(l.dayEnd, kMinutosNoDia, reason: 'teto da HORA CHEIA do último fim');
      expect(l.eventos.length, 2);
      expect(l.eventos.every((e) => !e.truncTop && !e.truncBottom), isTrue);
    });

    test('janela padrão 6h–22h quando tudo cabe nela', () {
      final l = layoutDayEvents([_iv('a', _min('09:00'), _min('10:00'))]);
      expect(l.dayStart, kDiaInicioPadraoMin);
      expect(l.dayEnd, kDiaFimPadraoMin);
    });

    test('CRUZANDO a meia-noite: recorta ao dia e marca truncBottom', () {
      // 23:00 + 120min = 25:00 → a fração depois de 00:00 é do dia seguinte.
      final l = layoutDayEvents([_iv('noturna', _min('23:00'), 25 * 60)]);
      final e = l.eventos.single;
      expect(e.startMin, _min('23:00'));
      expect(e.endMin, kMinutosNoDia, reason: 'recortado à meia-noite');
      expect(e.truncBottom, isTrue);
      expect(e.truncTop, isFalse);
      expect(l.dayEnd, kMinutosNoDia);
    });

    test('a FRAÇÃO herdada do dia anterior (início negativo) marca truncTop', () {
      // Mesma OS acima, vista da coluna do DIA SEGUINTE: começa "−60min".
      final l = layoutDayEvents([_iv('noturna', -60, 60)]);
      final e = l.eventos.single;
      expect(e.startMin, 0);
      expect(e.endMin, 60);
      expect(e.truncTop, isTrue);
      expect(e.truncBottom, isFalse);
      expect(l.dayStart, 0);
    });

    test('lista vazia → janela padrão, sem eventos', () {
      final l = layoutDayEvents(const []);
      expect(l.eventos, isEmpty);
      expect(l.dayStart, kDiaInicioPadraoMin);
      expect(l.dayEnd, kDiaFimPadraoMin);
    });

    test('ordenação estável (início ↑, fim ↓, id ↑) → layout determinístico', () {
      final entrada = [
        _iv('z', _min('09:00'), _min('10:00')),
        _iv('a', _min('09:00'), _min('11:00')),
        _iv('m', _min('09:00'), _min('10:00')),
      ];
      final l1 = layoutDayEvents(entrada);
      final l2 = layoutDayEvents(entrada.reversed.toList());
      expect(
        l1.eventos.map((e) => '${e.id}:${e.column}'),
        l2.eventos.map((e) => '${e.id}:${e.column}'),
      );
      // 'a' (fim maior) vem primeiro no empate de início → coluna 0.
      expect(l1.eventos.first.id, 'a');
      expect(l1.eventos.first.column, 0);
    });

    test('o aviso do form e a grade concordam (mesma função de sobreposição)', () {
      final ocupados = [_iv('a', _min('08:00'), _min('10:00'))];
      final colisoes = sobreposicoes(ocupados, _min('09:00'), 60);
      final l = layoutDayEvents([
        ...ocupados,
        _iv('nova', _min('09:00'), _min('10:00')),
      ]);
      expect(colisoes, isNotEmpty);
      expect(l.eventos.every((e) => e.columnCount == 2), isTrue);
    });
  });
}
