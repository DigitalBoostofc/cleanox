/// pontos_fisicos_repository.dart — CRUD de pontos físicos (admin/gerente).
library;

import '../models/ponto_fisico.dart';

abstract class PontosFisicosRepository {
  Future<List<PontoFisico>> list({bool somenteAtivos = false});
  Future<PontoFisico> create(Map<String, dynamic> data);
  Future<PontoFisico> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}
