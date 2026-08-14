/// CRUD de compromissos da Agenda.
library;

import '../models/agenda_compromisso.dart';

abstract class AgendaCompromissosRepository {
  Future<List<AgendaCompromisso>> list({
    String? dataInicio,
    String? dataFim,
    String? profissionalId,
  });

  Future<AgendaCompromisso> create(Map<String, dynamic> data);

  Future<AgendaCompromisso> update(String id, Map<String, dynamic> data);

  Future<void> delete(String id);
}
