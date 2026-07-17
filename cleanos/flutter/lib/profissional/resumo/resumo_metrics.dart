/// resumo_metrics.dart — Indicadores do painel "Resumo" do profissional.
///
/// Função PURA (como `buildEstimativa`): recebe as OS do profissional e as
/// comissões congeladas e devolve os cinco números que a tela mostra. Sem
/// dependência de rede/Riverpod — dá pra testar o cálculo isolado.
///
/// Definições (decididas com o dono, 16/07):
///  * **Agendados** — OS ainda em aberto (agendada / atribuída / em andamento).
///    Cancelada não conta; concluída vira "realizado".
///  * **Realizados** — OS concluídas.
///  * **A receber** — comissões geradas ainda `pendente`.
///  * **Recebidos** — comissões já marcadas `paga` pelo admin.
///  * **Avaliação média** — média das notas de OS avaliadas (`avaliacao_nota >= 1`).
library;

import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/prof_comissao.dart';

/// Snapshot dos indicadores do profissional.
class ProfResumo {
  const ProfResumo({
    required this.agendados,
    required this.realizados,
    required this.aReceber,
    required this.recebidos,
    required this.avaliacaoMedia,
    required this.totalAvaliacoes,
  });

  const ProfResumo.vazio()
    : agendados = 0,
      realizados = 0,
      aReceber = 0,
      recebidos = 0,
      avaliacaoMedia = null,
      totalAvaliacoes = 0;

  /// OS em aberto (agendada / atribuída / em andamento).
  final int agendados;

  /// OS concluídas.
  final int realizados;

  /// Soma das comissões ainda `pendente`.
  final double aReceber;

  /// Soma das comissões já `paga`.
  final double recebidos;

  /// Média das notas (1–5); `null` quando nenhuma OS foi avaliada ainda.
  final double? avaliacaoMedia;

  /// Quantas OS entraram na média.
  final int totalAvaliacoes;
}

/// Monta os indicadores a partir das OS do profissional e das comissões.
ProfResumo buildResumo({
  required List<OrdemServico> ordens,
  required List<ProfComissao> comissoes,
}) {
  var agendados = 0;
  var realizados = 0;
  var somaNotas = 0.0;
  var nAvaliadas = 0;

  for (final os in ordens) {
    switch (os.status) {
      case OSStatus.concluida:
        realizados++;
      case OSStatus.cancelada:
        break; // cancelada não entra em nenhuma contagem
      case OSStatus.agendada:
      case OSStatus.atribuida:
      case OSStatus.emAndamento:
        agendados++;
    }
    final nota = os.avaliacaoNota;
    if (nota != null && nota >= 1) {
      somaNotas += nota;
      nAvaliadas++;
    }
  }

  var aReceber = 0.0;
  var recebidos = 0.0;
  for (final c in comissoes) {
    if (c.status == ComissaoStatus.paga) {
      recebidos += c.valorComissao;
    } else {
      aReceber += c.valorComissao;
    }
  }

  double r(double v) => (v * 100).roundToDouble() / 100;

  return ProfResumo(
    agendados: agendados,
    realizados: realizados,
    aReceber: r(aReceber),
    recebidos: r(recebidos),
    avaliacaoMedia: nAvaliadas == 0 ? null : somaNotas / nAvaliadas,
    totalAvaliacoes: nAvaliadas,
  );
}
