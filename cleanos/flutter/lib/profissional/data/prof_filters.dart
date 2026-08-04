/// prof_filters.dart — Construtores PUROS de filtros PocketBase do app do
/// PROFISSIONAL (A-04).
///
/// Mesmo molde de `painel/data/painel_filters.dart`: valores SEMPRE via
/// [pbStringLiteral] (escaping idêntico ao `pb.filter` do SDK) — nunca
/// interpolação crua, mesmo quando o valor é interno (id do usuário autenticado,
/// bounds BRT). Funções puras → testáveis em unidade, sem instância PocketBase.
library;

import '../../core/formatters/formatters.dart' show PbDayBounds;
import '../../core/models/collections.dart';
import '../../core/pb/pb_filters.dart';

/// Dono da OS = 1º ou 2º profissional (dupla).
String _owner(String profId) {
  final lit = pbStringLiteral(profId);
  return '(profissional = $lit || profissional2 = $lit)';
}

/// OS do profissional HOJE (janela BRT [todayStart, tomorrowStart)).
/// Canceladas nunca aparecem no app do profissional.
String profOrdensHojeFilter(String profId, PbDayBounds bounds) =>
    '${_owner(profId)} '
    '&& data_hora >= ${pbStringLiteral(bounds.todayStart)} '
    '&& data_hora < ${pbStringLiteral(bounds.tomorrowStart)} '
    '&& status != ${pbStringLiteral(OSStatus.cancelada.wire)}';

/// OS do profissional PRÓXIMAS (a partir de amanhã BRT).
/// Canceladas nunca aparecem no app do profissional.
String profOrdensProximasFilter(String profId, PbDayBounds bounds) =>
    '${_owner(profId)} '
    '&& data_hora >= ${pbStringLiteral(bounds.tomorrowStart)} '
    '&& status != ${pbStringLiteral(OSStatus.cancelada.wire)}';

/// OS do profissional ATRASADAS em aberto (antes de hoje BRT, ainda
/// atribuída/em andamento).
String profOrdensAtrasadasAbertasFilter(String profId, PbDayBounds bounds) =>
    '${_owner(profId)} '
    '&& (status = ${pbStringLiteral(OSStatus.atribuida.wire)} '
    '|| status = ${pbStringLiteral(OSStatus.emAndamento.wire)}) '
    '&& data_hora < ${pbStringLiteral(bounds.todayStart)}';

/// OS ATIVA do profissional (em andamento) — aba Mapa.
String profOsEmAndamentoFilter(String profId) =>
    '${_owner(profId)} '
    '&& status = ${pbStringLiteral(OSStatus.emAndamento.wire)}';

/// OS concluídas E avaliadas do profissional — média de avaliação do Perfil.
String profAvaliadasFilter(String profId) =>
    '${_owner(profId)} '
    '&& status = ${pbStringLiteral(OSStatus.concluida.wire)} '
    '&& avaliacao_nota >= 1';
