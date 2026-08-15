library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/dashboard/dashboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_painel.dart';

User _prof(String id, String nome) =>
    User(id: id, name: nome, role: Role.profissional);

OrdemServico _os({
  required String id,
  required OSStatus status,
  String? profId,
  String? profNome,
  String? prof2Id,
  String? prof2Nome,
  String localTipo = 'cliente',
}) {
  return painelOS(id: id, status: status).copyWith(
    profissional: profId,
    profissional2: prof2Id,
    localTipo: localTipo,
    expand: OSExpand(
      profissional: profId == null ? null : _prof(profId, profNome ?? profId),
      profissional2:
          prof2Id == null ? null : _prof(prof2Id, prof2Nome ?? prof2Id),
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
}
