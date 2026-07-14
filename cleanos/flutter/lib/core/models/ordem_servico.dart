/// ordem_servico.dart — Porte de `OrdemServico` de collections.ts (coleção `ordens_servico`).
///
/// Campos de TOPO em **snake_case** (contrato PB). Campos JSON ricos delegam aos
/// tipos camelCase de servico.dart/os_execucao.dart.
///
/// 🔒 ANTI-DESVIO: o profissional só recebe a "visão-de-job" (`nome_curto`, `bairro`,
/// `tipo_servico_nome`, `data_hora`, `valor_servico`, `status`) e `endereco_liberado`
/// APENAS em `em_andamento`. O expand `cliente` (dados sensíveis) só existe no Painel;
/// o repositório do profissional NUNCA pede esse expand.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'cliente.dart';
import 'collections.dart';
import 'os_execucao.dart';
import 'servico.dart';
import 'user.dart';

part 'ordem_servico.freezed.dart';
part 'ordem_servico.g.dart';

/// Registros expandidos (`?expand=...`). NÃO faz parte do JSON plano do record —
/// preenchido manualmente em [OrdemServico.fromRecord]. `cliente` só é preenchido
/// no Painel (admin/gerente); o app do profissional jamais o expande.
@freezed
class OSExpand with _$OSExpand {
  const factory OSExpand({
    User? profissional,
    ServicoPB? servico,
    Cliente? cliente,
  }) = _OSExpand;
}

@freezed
class OrdemServico with _$OrdemServico {
  const factory OrdemServico({
    required String id,

    /// Relation → clientes (ID opaco). O profissional recebe só o ID, nunca o expand.
    @Default('') String cliente,

    /// "Carlos S." — denormalizado por hook.
    @JsonKey(name: 'nome_curto') @Default('') String nomeCurto,

    /// endereco_bairro do cliente — denormalizado por hook.
    @Default('') String bairro,

    /// Relation → servicos (ID).
    String? servico,
    @JsonKey(name: 'tipo_servico_nome') String? tipoServicoNome,

    /// ISO datetime UTC.
    @JsonKey(name: 'data_hora') @Default('') String dataHora,

    /// Duração do atendimento em minutos (fim = [dataHora] + [duracaoMin]).
    ///
    /// ⚠️ R2 (variante NUMÉRICA): NumberField opcional do PB volta como **0**
    /// quando vazio — nunca `null`. Toda OS anterior à migration 27 chega com
    /// `"duracao_min": 0`. [_duracaoMinFromJson] normaliza `<= 0 → null` já no
    /// parse (fromJson e fromRecord), para o resto do app poder confiar em
    /// `null == sem duração própria` e cair no fallback do
    /// `duracaoEfetivaMin` (OS > profissional > 60).
    @JsonKey(name: 'duracao_min', fromJson: _duracaoMinFromJson) int? duracaoMin,

    /// Relation → users (ID).
    String? profissional,
    @JsonKey(unknownEnumValue: OSStatus.agendada)
    @Default(OSStatus.agendada)
    OSStatus status,
    @JsonKey(name: 'valor_servico') double? valorServico,

    /// Endereço completo — só preenchido quando status === 'em_andamento'.
    @JsonKey(name: 'endereco_liberado') String? enderecoLiberado,

    /// Pagamento (preenchido pelo profissional ao concluir).
    @JsonKey(name: 'valor_pago') double? valorPago,
    @JsonKey(
      name: 'forma_pagamento',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    FormaPagamento? formaPagamento,

    /// Repasse — gerenciado manualmente pelo admin.
    @JsonKey(
      name: 'repasse_status',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    RepasseStatus? repasseStatus,
    @JsonKey(name: 'repasse_valor') double? repasseValor,
    @JsonKey(name: 'aviso_a_caminho_em') String? avisoACaminhoEm,

    /// Avaliação (preenchida pelo backend após pesquisa).
    @JsonKey(name: 'avaliacao_nota') double? avaliacaoNota,
    @JsonKey(name: 'avaliacao_motivo') String? avaliacaoMotivo,
    @JsonKey(name: 'avaliacao_em') String? avaliacaoEm,
    @JsonKey(name: 'avaliacao_solicitada_em') String? avaliacaoSolicitadaEm,
    String? observacoes,

    /* ---- campos RICOS do módulo Serviços/OS (JSON) ---- */
    @JsonKey(name: 'service_snapshot') ServiceSnapshot? serviceSnapshot,
    @JsonKey(name: 'checklist_exec')
    @Default(<ChecklistExecItem>[])
    List<ChecklistExecItem> checklistExec,
    @Default(<ServicoAdicionalOS>[]) List<ServicoAdicionalOS> adicionais,
    @JsonKey(name: 'observacoes_prof')
    @Default(<ObservacaoProfissional>[])
    List<ObservacaoProfissional> observacoesProf,

    /// Desconto (R$) aplicado no resumo da execução.
    @Default(0) double descontos,
    @JsonKey(name: 'relatorio_enviado_em') String? relatorioEnviadoEm,
    String? created,
    String? updated,

    /// Preenchido só em [fromRecord] a partir de `?expand=...`.
    @JsonKey(includeFromJson: false, includeToJson: false) OSExpand? expand,
  }) = _OrdemServico;

  const OrdemServico._();

  factory OrdemServico.fromJson(Map<String, dynamic> json) =>
      _$OrdemServicoFromJson(json);

  /// Constrói do RecordModel, resolvendo os expands que o SDK não inclui no
  /// `toJson()`. Só monta o expand `cliente` se ele veio na resposta (Painel).
  factory OrdemServico.fromRecord(RecordModel record) {
    final base = OrdemServico.fromJson(record.toJson());
    final profRec = _expandOne(record, 'profissional');
    final servRec = _expandOne(record, 'servico');
    final cliRec = _expandOne(record, 'cliente');
    if (profRec == null && servRec == null && cliRec == null) return base;
    return base.copyWith(
      expand: OSExpand(
        profissional: profRec == null ? null : User.fromRecord(profRec),
        servico: servRec == null ? null : ServicoPB.fromRecord(servRec),
        cliente: cliRec == null ? null : Cliente.fromRecord(cliRec),
      ),
    );
  }

  /// Total do resumo financeiro da execução: serviço + adicionais COBRÁVEIS −
  /// descontos. Espelha `calcTotalOS`/`isAdicionalCobravel` do React: só entram
  /// os adicionais `aprovado` ou `nao_requer` (aguardando/recusado não contam).
  double get valorTotal {
    final principal = valorServico ?? 0;
    final extras = adicionais
        .where(
          (a) =>
              a.aprovacao == AprovacaoStatus.aprovado ||
              a.aprovacao == AprovacaoStatus.naoRequer,
        )
        .fold<double>(0, (sum, a) => sum + a.valor * a.quantidade);
    final total = principal + extras - descontos;
    return total < 0 ? 0 : total;
  }

  bool get temItensObrigatoriosPendentes => checklistExec.any(
    (i) => i.obrigatorio && i.status != ChecklistExecStatus.concluido,
  );

  /// Nome do cliente para EXIBIR — nome inteiro quando o cofre veio expandido
  /// (só o Painel expande `cliente`), abreviado caso contrário.
  ///
  /// 🔒 É este fallback que mantém a fronteira de privacidade: o app do
  /// profissional nunca pede `expand=cliente`, então [expand] vem sem cliente e
  /// ele continua vendo "Carlos S." — sem nenhum `if (isPainel)` espalhado pela
  /// UI. Use SEMPRE este getter na UI; `nomeCurto` cru só onde o abreviado é o
  /// objetivo.
  String get clienteNomeExibicao {
    final completo = expand?.cliente?.nomeCompleto.trim() ?? '';
    return completo.isNotEmpty ? completo : nomeCurto;
  }
}

/// `duracao_min` do PB → minutos, ou `null` quando "sem duração própria".
///
/// NumberField opcional vazio chega como `0` (e, em records antigos/serializações
/// tolerantes, pode chegar como `null` ou `""`). Tudo isso vira `null` aqui —
/// nunca um `0` que o layout interpretaria como evento de duração zero.
int? _duracaoMinFromJson(Object? raw) {
  final n = switch (raw) {
    final num v => v.toInt(),
    final String s => int.tryParse(s.trim()) ?? 0,
    _ => 0,
  };
  return n > 0 ? n : null;
}

RecordModel? _expandOne(RecordModel record, String key) {
  try {
    final rec = record.get<RecordModel?>('expand.$key', null);
    if (rec != null && rec.id.isNotEmpty) return rec;
  } catch (_) {
    /* sem expand desta chave */
  }
  return null;
}
