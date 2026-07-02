/// repo_types.dart — Tipos compartilhados do contrato de repositórios.
///
/// Fazem parte da fronteira estável (§3.1): não mudam sem PR revisado no core.
library;

import '../models/collections.dart';
import '../models/ordem_servico.dart';

export '../formatters/formatters.dart' show DateRange;

/// Página de resultados (espelha `getList` do PB) — SDK-agnóstica de propósito,
/// para que as features não dependam do `ResultList` do pacote pocketbase.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
}

/// Ação de um evento realtime.
enum OSEventAction { create, update, delete, unknown }

OSEventAction osEventActionFromWire(String action) => switch (action) {
  'create' => OSEventAction.create,
  'update' => OSEventAction.update,
  'delete' => OSEventAction.delete,
  _ => OSEventAction.unknown,
};

/// Evento realtime da coleção `ordens_servico` (SSE via SDK).
class OrdemServicoEvent {
  const OrdemServicoEvent({required this.action, this.record});
  final OSEventAction action;
  final OrdemServico? record;
}

/// Patch parcial dos campos de execução que o PROFISSIONAL pode gravar.
///
/// ⭐ Inclui EXATAMENTE os campos liberados ao profissional pela denylist do
/// servidor (`guardOrdemUpdateRequest` em pb_hooks/os_logic.js):
/// `status`, `valor_pago`, `forma_pagamento`, `checklist_exec`, `adicionais`,
/// `observacoes_prof`, `descontos`. Campos ausentes NÃO são tocados — nunca
/// envie campos travados (evita 403 desnecessário; gate G-7).
///
/// ⚠️ `service_snapshot` NÃO entra aqui: é congelado server-side na criação
/// (hook `fillServiceSnapshot`) e está na denylist `locked` do hook — reenviá-lo
/// gera 403 mesmo "sem mudar nada" (footgun anti-desvio).
///
/// NB: `updateStatus→concluida` exige `valor_pago > 0` + `forma_pagamento`
/// (`assertPaymentIfConcluida`) — por isso ambos são graváveis aqui.
class OSExecPatch {
  const OSExecPatch({
    this.status,
    this.valorPago,
    this.formaPagamento,
    this.checklistExec,
    this.adicionais,
    this.observacoesProf,
    this.descontos,
  });

  final OSStatus? status;
  final double? valorPago;
  final FormaPagamento? formaPagamento;
  final List<Map<String, dynamic>>? checklistExec;
  final List<Map<String, dynamic>>? adicionais;
  final List<Map<String, dynamic>>? observacoesProf;
  final double? descontos;

  Map<String, dynamic> toBody() {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status!.wire;
    if (valorPago != null) body['valor_pago'] = valorPago;
    if (formaPagamento != null) body['forma_pagamento'] = formaPagamento!.wire;
    if (checklistExec != null) body['checklist_exec'] = checklistExec;
    if (adicionais != null) body['adicionais'] = adicionais;
    if (observacoesProf != null) body['observacoes_prof'] = observacoesProf;
    if (descontos != null) body['descontos'] = descontos;
    return body;
  }

  bool get isEmpty => toBody().isEmpty;
}
