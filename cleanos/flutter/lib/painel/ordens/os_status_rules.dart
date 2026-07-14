/// os_status_rules.dart — Regras de consistência entre `status` e `profissional`
/// de uma OS (Painel). Funções PURAS, testáveis sem rede nem widget.
///
/// F-234: o QA E2E achou no banco `status="atribuida"` + `profissional=""` — um
/// estado que o domínio não admite. Ele nasceu de o form DEDUZIR a transição de
/// status a partir do registro que tinha em mãos: quando esse registro está
/// velho, nenhum ramo dispara, o `status` não entra no payload e o valor antigo
/// sobrevive no banco (PATCH só altera o que vem no body).
///
/// A lição virou regra: **o status que exige profissional nunca pode ser
/// deduzido de um registro que pode estar velho.**
library;

import '../../core/models/collections.dart';

/// Statuses que EXIGEM um profissional atribuído: uma OS `atribuida` está
/// atribuída A ALGUÉM, e uma OS `em_andamento` está sendo executada POR ALGUÉM.
bool statusExigeProfissional(OSStatus s) =>
    s == OSStatus.atribuida || s == OSStatus.emAndamento;

/// OS finalizada — a edição no Painel não mexe no status dessas.
bool statusFinalizado(OSStatus s) =>
    s == OSStatus.concluida || s == OSStatus.cancelada;

/// Status que a OS deve ter DEPOIS de uma edição que submete (ou não) um
/// profissional. `null` = não mandar `status` no payload.
///
/// ⚠️ [atual] PODE ESTAR VELHO — o form de edição é aberto com um registro de
/// closure, que não acompanha uma atribuição feita no detalhe. Daí a assimetria
/// deliberada das duas regras:
///
/// - **Sem profissional → INCONDICIONAL.** Sem ninguém atribuído a OS só pode
///   estar `agendada`, então o status vai EXPLÍCITO no payload mesmo quando
///   [atual] já diz `agendada`. É o que torna a guarda à prova de registro
///   velho: se o banco estiver em `atribuida` (e [atual] não souber), o
///   `agendada` explícito corrige em vez de deixar o lixo passar (F-234).
///
/// - **Com profissional → depende de [atual].** Não dá para tornar
///   incondicional: com um profissional a OS pode legitimamente estar
///   `atribuida`, `em_andamento` ou `concluida`, e o form não tem como escolher
///   entre elas. Por isso o registro passado ao form também precisa estar
///   FRESCO (ver `OSDetailResult.os`) — e por isso uma guarda de servidor ainda
///   é desejável.
OSStatus? statusAposEdicao({
  required OSStatus atual,
  required bool temProfissional,
}) {
  if (statusFinalizado(atual)) return null;
  if (!temProfissional) return OSStatus.agendada;
  return atual == OSStatus.agendada ? OSStatus.atribuida : null;
}
