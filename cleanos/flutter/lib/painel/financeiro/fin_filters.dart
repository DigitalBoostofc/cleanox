/// fin_filters.dart — Construtores PUROS de filtros PocketBase do Financeiro.
///
/// Mesmo contrato de `painel_filters.dart`: envolvem valores em literal escapado
/// ([pbStringLiteral]) — seguros contra injeção como manda a skill
/// pocketbase-cleanos — sem depender de uma instância `PocketBase` (puros,
/// testáveis). As datas de período são de PAREDE ('YYYY-MM-DD') e comparadas
/// como o campo `data` (date) do PB.
library;

import '../../core/models/financeiro.dart';
import '../data/painel_filters.dart';
import 'fin_derivations.dart';

/// Filtro de um período (mês) sobre o campo `data`.
String finPeriodoFilter(Periodo p) =>
    'data >= ${pbStringLiteral(p.start)} && data < ${pbStringLiteral(p.end)}';

/// Filtro da lista de Lançamentos: período + busca (descrição) + tipo + status +
/// conta + categoria. Fragmentos nulos são ignorados; `null` = sem filtro.
String? finLancamentosFilter({
  Periodo? periodo,
  String? search,
  TipoLancamento? tipo,
  LancamentoStatus? status,
  String? contaId,
  String? categoriaId,
}) {
  final q = (search ?? '').trim();
  return andAll([
    if (periodo != null) finPeriodoFilter(periodo),
    if (q.isNotEmpty)
      '(descricao ~ ${pbStringLiteral(q)} '
          '|| cliente_nome ~ ${pbStringLiteral(q)} '
          '|| os_numero ~ ${pbStringLiteral(q)})',
    if (tipo != null) 'tipo = ${pbStringLiteral(tipo.wire)}',
    if (status != null) 'status = ${pbStringLiteral(status.wire)}',
    if (contaId != null && contaId.isNotEmpty)
      'conta_id = ${pbStringLiteral(contaId)}',
    if (categoriaId != null && categoriaId.isNotEmpty)
      '(categoria_id = ${pbStringLiteral(categoriaId)} '
          '|| subcategoria_id = ${pbStringLiteral(categoriaId)})',
  ]);
}

/// Filtro de "Contas a pagar/receber": em aberto (não pago) do tipo dado.
/// `tipo` = despesa → a pagar · receita → a receber.
String finContasPendentesFilter(TipoLancamento tipo) =>
    'tipo = ${pbStringLiteral(tipo.wire)} && status != '
    '${pbStringLiteral(LancamentoStatus.pago.wire)}';
