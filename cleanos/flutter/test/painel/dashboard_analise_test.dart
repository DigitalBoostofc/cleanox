library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/dashboard/dashboard_controller.dart';
import 'package:cleanos/painel/ordens/ordens_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_painel.dart';

User _prof(String id, String nome, {String corAgenda = ''}) =>
    User(id: id, name: nome, role: Role.profissional, corAgenda: corAgenda);

OrdemServico _os({
  required String id,
  required OSStatus status,
  String? profId,
  String? profNome,
  String? prof2Id,
  String? prof2Nome,
  String localTipo = 'cliente',
  String corAgenda = '',
  String corAgenda2 = '',
}) {
  return painelOS(id: id, status: status).copyWith(
    profissional: profId,
    profissional2: prof2Id,
    localTipo: localTipo,
    expand: OSExpand(
      profissional: profId == null
          ? null
          : _prof(profId, profNome ?? profId, corAgenda: corAgenda),
      profissional2: prof2Id == null
          ? null
          : _prof(prof2Id, prof2Nome ?? prof2Id, corAgenda: corAgenda2),
    ),
  );
}

void main() {
  test('ranking conta principal e 2º, ignora cancelada e ordena por OS', () {
    final ranking = dashboardRankingProfissionais([
      _os(
        id: '1',
        status: OSStatus.concluida,
        profId: 'h',
        profNome: 'Hendrio',
      ),
      _os(
        id: '2',
        status: OSStatus.atribuida,
        profId: 'h',
        profNome: 'Hendrio',
      ),
      _os(id: '3', status: OSStatus.concluida, profId: 'b', profNome: 'Breno'),
      _os(
        id: '4',
        status: OSStatus.concluida,
        profId: 'h',
        profNome: 'Hendrio',
        prof2Id: 'b',
        prof2Nome: 'Breno',
      ),
      _os(id: '5', status: OSStatus.cancelada, profId: 'b', profNome: 'Breno'),
    ]);

    expect(ranking.map((e) => e.nome).toList(), ['Hendrio', 'Breno']);
    expect(ranking.first.osCount, 3);
    expect(ranking.last.osCount, 2);
  });

  test('ranking guarda a cor cadastrada do usuário', () {
    final ranking = dashboardRankingProfissionais([
      _os(
        id: '1',
        status: OSStatus.concluida,
        profId: 'h',
        profNome: 'Hendrio',
        corAgenda: '#16A34A',
      ),
      _os(
        id: '2',
        status: OSStatus.atribuida,
        profId: 'b',
        profNome: 'Breno',
        corAgenda: '#0F172A',
      ),
    ]);
    expect(
      ranking.firstWhere((e) => e.nome == 'Hendrio').corAgenda,
      '#16A34A',
    );
    expect(ranking.firstWhere((e) => e.nome == 'Breno').corAgenda, '#0F172A');
    expect(
      dashboardCorProfissional(ranking.firstWhere((e) => e.nome == 'Hendrio')),
      const Color(0xFF16A34A),
    );
    expect(
      dashboardCorProfissional(ranking.firstWhere((e) => e.nome == 'Breno')),
      const Color(0xFF0F172A),
    );
  });

  test('local split: ponto físico vs domicílio, ignora cancelada', () {
    final split = dashboardLocalSplit([
      _os(id: '1', status: OSStatus.concluida),
      _os(id: '2', status: OSStatus.atribuida, localTipo: 'ponto_fisico'),
      _os(id: '3', status: OSStatus.emAndamento, localTipo: 'ponto_fisico'),
      _os(id: '4', status: OSStatus.cancelada, localTipo: 'ponto_fisico'),
    ]);
    expect(split.domicilio, 1);
    expect(split.pontoFisico, 2);
    expect(split.total, 3);
  });

  test('filtro PB de Hoje usa a janela do dia', () {
    final now = DateTime.utc(2026, 8, 15, 18);
    final range = ordensPeriodoRange(OrdensPeriodo.hoje, now: now)!;
    final f = dashboardPeriodoFilter(const DashboardPeriodo(), now: now);
    expect(f, isNotNull);
    expect(f, contains(range.start));
    expect(f, contains(range.end));
  });

  test('Tudo não restringe data_hora', () {
    expect(
      dashboardPeriodoFilter(
        const DashboardPeriodo(periodo: OrdensPeriodo.tudo),
      ),
      isNull,
    );
  });

  test('rótulos mudam com o período', () {
    expect(dashboardTitulo(const DashboardPeriodo()), 'Hoje');
    expect(
      dashboardTitulo(const DashboardPeriodo(periodo: OrdensPeriodo.semana)),
      'Esta semana',
    );
    expect(dashboardFaturamentoLabel(const DashboardPeriodo()), 'Faturamento hoje');
    expect(
      dashboardFaturamentoLabel(
        const DashboardPeriodo(periodo: OrdensPeriodo.mes),
      ),
      'Faturamento',
    );
    expect(dashboardAnaliseTitulo(const DashboardPeriodo()), 'Análise de hoje');
    expect(
      dashboardAnaliseTitulo(const DashboardPeriodo(periodo: OrdensPeriodo.tudo)),
      'Análise',
    );
  });

  test('domicílio e ponto físico usam cores bem distintas', () {
    expect(kDashboardCorDomicilio, isNot(kDashboardCorPontoFisico));
    final d = kDashboardCorDomicilio;
    final p = kDashboardCorPontoFisico;
    final dist =
        (d.r - p.r).abs() + (d.g - p.g).abs() + (d.b - p.b).abs();
    expect(dist, greaterThan(0.8));
  });
}
