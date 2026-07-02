/// painel_filters.dart — Construtores PUROS de filtros PocketBase do Painel.
///
/// Espelham exatamente o escaping de string do `pb.filter` do SDK (envolve em
/// aspas simples e escapa `'` → `\'`) — assim são seguros contra injeção como manda
/// a skill pocketbase-cleanos, mas SEM depender de uma instância `PocketBase`
/// (funções puras → testáveis em unidade e reutilizáveis pelos controllers).
library;

import '../../core/models/collections.dart';

/// Escapa um valor de string como literal de filtro do PB (`'…'`, com `'` → `\'`).
String pbStringLiteral(String value) => "'${value.replaceAll("'", "\\'")}'";

/// Filtro de busca de clientes por nome/sobrenome/telefone/bairro/cidade
/// (operador `~` = contém). Retorna `null` quando a busca está vazia (lista tudo).
///
/// F-601: cada PALAVRA do termo precisa casar em ALGUM campo (AND por token, OR
/// entre campos). Sem isso, um termo que atravessa a fronteira nome↔sobrenome —
/// ex.: "QA Teste" onde `nome`="QA" e `sobrenome`="Teste Silva" — nunca casava,
/// pois nenhum campo isolado contém a string inteira "QA Teste". Equivalente
/// funcional do React para o caso F-601, com binding seguro via [pbStringLiteral]
/// e server-side. Difere do React (`Clientes.tsx`), que concatena nome+sobrenome
/// num único `fullName.includes(termo)` (substring na frase), enquanto aqui é
/// AND por token / OR entre campos — mas produz resultados equivalentes para
/// buscas típicas.
String? clienteSearchFilter(String query) {
  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;
  return tokens.map((token) {
    final lit = pbStringLiteral(token);
    return '(nome ~ $lit || sobrenome ~ $lit || telefone ~ $lit '
        '|| endereco_bairro ~ $lit || endereco_cidade ~ $lit)';
  }).join(' && ');
}

/// Filtro fixo de profissionais (papel = profissional). Sem entrada do usuário.
String profissionaisFilter() =>
    'role = ${pbStringLiteral(Role.profissional.wire)}';

/// Filtro do catálogo de Serviços: busca por nome (`~`) + categoria/grupo (`=`).
/// Retorna `null` quando não há nenhum critério (lista tudo). Valores escapados
/// via [pbStringLiteral] (seguro contra injeção).
String? servicosFilter({String? search, String? categoria, String? grupo}) {
  final q = (search ?? '').trim();
  return andAll([
    if (q.isNotEmpty) 'nome ~ ${pbStringLiteral(q)}',
    if (categoria != null && categoria.isNotEmpty)
      'categoria = ${pbStringLiteral(categoria)}',
    if (grupo != null && grupo.isNotEmpty) 'grupo = ${pbStringLiteral(grupo)}',
  ]);
}

/// Filtro de disponibilidade por profissional (`=`). Sempre não-nulo.
String disponibilidadeDoProfissionalFilter(String profId) =>
    'profissional = ${pbStringLiteral(profId)}';

/// Filtro das OS que OCUPAM a agenda de um profissional num dia [inicio, fim)
/// (strings UTC do PB). Exclui canceladas — elas não ocupam slot. Espelha o
/// filtro de disponibilidade do `OSFormSection.tsx` (seletor de slot da Nova OS):
/// `profissional='id' && data_hora>='start' && data_hora<'end' && status!='cancelada'`.
/// Valores escapados via [pbStringLiteral] (seguro contra injeção).
String ordensOcupamAgendaFilter({
  required String profissionalId,
  required String dataInicio,
  required String dataFim,
}) =>
    'profissional = ${pbStringLiteral(profissionalId)} '
    '&& data_hora >= ${pbStringLiteral(dataInicio)} '
    '&& data_hora < ${pbStringLiteral(dataFim)} '
    '&& status != ${pbStringLiteral(OSStatus.cancelada.wire)}';

/// Filtro das Avaliações do Painel: só OS já avaliadas (`avaliacao_nota >= 1`),
/// opcionalmente por nota exata (1..5) e/ou a partir de uma data de avaliação
/// [desde] (string UTC do PB). A nota é um inteiro de faixa fixa (não é entrada
/// livre do usuário), então entra como literal numérico — nunca precisa de aspas.
String avaliacoesFilter({int? nota, String? desde}) {
  final parts = <String>['avaliacao_nota >= 1'];
  if (nota != null) parts.add('avaliacao_nota = ${nota.clamp(1, 5)}');
  if (desde != null && desde.isNotEmpty) {
    parts.add('avaliacao_em >= ${pbStringLiteral(desde)}');
  }
  return parts.join(' && ');
}

/// Compõe fragmentos não-nulos com ` && ` (retorna `null` se todos vazios).
String? andAll(List<String?> parts) {
  final kept = parts.where((p) => p != null && p.isNotEmpty).cast<String>();
  if (kept.isEmpty) return null;
  return kept.join(' && ');
}

/// Filtro de Ordens de Serviço para a lista do Painel: por status e/ou
/// profissional e/ou janela de datas [inicio, fim) (strings UTC do PB).
String? ordensFilter({
  OSStatus? status,
  String? profissionalId,
  String? dataInicio,
  String? dataFim,
}) {
  return andAll([
    if (status != null) 'status = ${pbStringLiteral(status.wire)}',
    if (profissionalId != null && profissionalId.isNotEmpty)
      'profissional = ${pbStringLiteral(profissionalId)}',
    if (dataInicio != null && dataInicio.isNotEmpty)
      "data_hora >= ${pbStringLiteral(dataInicio)}",
    if (dataFim != null && dataFim.isNotEmpty)
      "data_hora < ${pbStringLiteral(dataFim)}",
  ]);
}
