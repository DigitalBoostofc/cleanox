/// relatorio_os.dart — Montagem PURA do RELATÓRIO FINAL da OS ao cliente.
///
/// Porte de `web/src/lib/os/relatorioOS.ts` (buildRelatorioOS) + `calcTotalOS`.
/// Toda a lógica é pura e síncrona: não toca rede nem UI. O caller (tela de
/// execução) materializa o [RelatorioOS] a partir do record PB, e os widgets
/// compartilhados (modal/PDF) consomem o resultado. Classe simples e imutável —
/// sem codegen — para que Painel (Time A) e Profissional (Time B) reusem sem
/// depender de nenhuma feature.
library;

import '../core/models/os_execucao.dart';
import '../core/models/servico.dart';
import 'labels.dart';

/// Pacote pronto para pré-visualizar / virar PDF. Espelha `RelatorioOS` (types.ts).
class RelatorioOS {
  const RelatorioOS({
    required this.osId,
    this.numeroOS,
    required this.clienteNome,
    this.clienteTelefone,
    this.enderecoCompleto,
    this.bairro,
    this.profissionalNome,
    required this.dataHora,
    required this.snapshot,
    required this.adicionais,
    required this.checklist,
    required this.evidencias,
    required this.observacoesVisiveis,
    this.orientacoesPos,
    required this.valorPrincipal,
    required this.valorAdicionais,
    this.descontos,
    required this.valorTotal,
    required this.textoPadrao,
    required this.prazoIntercorrenciaDias,
    this.avaliacaoNota,
    required this.geradoEm,
  });

  final String osId;
  final String? numeroOS;

  final String clienteNome;

  /// 🔒 nunca preenchido pela superfície do PROFISSIONAL (anti-desvio). Existe no
  /// tipo apenas para o Painel poder reusar o mesmo laudo.
  final String? clienteTelefone;
  final String? enderecoCompleto;
  final String? bairro;
  final String? profissionalNome;
  final String dataHora;

  final ServiceSnapshot snapshot;
  final List<ServicoAdicionalOS> adicionais;

  final List<ChecklistExecItem> checklist;
  final List<EvidenciaFoto> evidencias;
  final List<ObservacaoProfissional> observacoesVisiveis;
  final String? orientacoesPos;

  final double valorPrincipal;
  final double valorAdicionais;
  final double? descontos;
  final double valorTotal;

  final String textoPadrao;
  final int prazoIntercorrenciaDias;

  final double? avaliacaoNota;

  /// ISO datetime de quando o relatório foi gerado.
  final String geradoEm;
}

/// Um adicional entra na cobrança (e no relatório do cliente) quando está
/// 'aprovado' ou 'nao_requer'. 'aguardando'/'recusado' não contam. Espelha
/// `isAdicionalCobravel`/`calcTotalOS`.
bool isAdicionalCobravel(ServicoAdicionalOS a) =>
    a.aprovacao == AprovacaoStatus.aprovado ||
    a.aprovacao == AprovacaoStatus.naoRequer;

/// Total da OS: principal + Σ adicionais cobráveis − descontos (nunca negativo).
/// Espelha `calcTotalOS`.
double calcTotalOS(
  double valorPrincipal,
  List<ServicoAdicionalOS> adicionais,
  double? descontos,
) {
  final extras = adicionais
      .where(isAdicionalCobravel)
      .fold<double>(0, (sum, a) => sum + a.valor * a.quantidade);
  final total = valorPrincipal + extras - (descontos ?? 0);
  return total < 0 ? 0 : total;
}

/// Entrada de [buildRelatorioOS]. Campos derivados são calculados na montagem.
class BuildRelatorioOSInput {
  const BuildRelatorioOSInput({
    required this.osId,
    this.numeroOS,
    required this.clienteNome,
    this.clienteTelefone,
    this.enderecoCompleto,
    this.bairro,
    this.profissionalNome,
    required this.dataHora,
    required this.snapshot,
    this.adicionais = const [],
    this.checklist = const [],
    this.evidencias = const [],
    this.observacoes = const [],
    this.descontos,
    this.avaliacaoNota,
    required this.geradoEm,
  });

  final String osId;
  final String? numeroOS;
  final String clienteNome;
  final String? clienteTelefone;
  final String? enderecoCompleto;
  final String? bairro;
  final String? profissionalNome;
  final String dataHora;
  final ServiceSnapshot snapshot;
  final List<ServicoAdicionalOS> adicionais;
  final List<ChecklistExecItem> checklist;
  final List<EvidenciaFoto> evidencias;
  final List<ObservacaoProfissional> observacoes;
  final double? descontos;
  final double? avaliacaoNota;

  /// ISO datetime de "agora" — injetado pelo caller (mantém a função pura).
  final String geradoEm;
}

/// Monta o [RelatorioOS] a partir dos dados da execução. Espelha `buildRelatorioOS`.
RelatorioOS buildRelatorioOS(BuildRelatorioOSInput input) {
  final cobraveis = input.adicionais.where(isAdicionalCobravel).toList();
  final valorPrincipal = input.snapshot.valorBase;
  final valorAdicionais = cobraveis.fold<double>(
    0,
    (sum, a) => sum + a.valor * a.quantidade,
  );
  final valorTotal = calcTotalOS(
    valorPrincipal,
    input.adicionais,
    input.descontos,
  );

  return RelatorioOS(
    osId: input.osId,
    numeroOS: input.numeroOS,
    clienteNome: input.clienteNome,
    clienteTelefone: input.clienteTelefone,
    enderecoCompleto: input.enderecoCompleto,
    bairro: input.bairro,
    profissionalNome: input.profissionalNome,
    dataHora: input.dataHora,
    snapshot: input.snapshot,
    adicionais: cobraveis,
    checklist: input.checklist,
    evidencias: input.evidencias,
    observacoesVisiveis: input.observacoes
        .where((o) => o.visivelCliente)
        .toList(),
    orientacoesPos: input.snapshot.orientacoesPosServico,
    valorPrincipal: valorPrincipal,
    valorAdicionais: valorAdicionais,
    descontos: input.descontos,
    valorTotal: valorTotal,
    textoPadrao: kRelatorioTextoPadrao,
    prazoIntercorrenciaDias: kRelatorioPrazoDias,
    avaliacaoNota: input.avaliacaoNota,
    geradoEm: input.geradoEm,
  );
}

/// Número humano da OS a partir do id (espelha `numeroFromId`).
String numeroFromId(String id) =>
    '#${(id.length <= 6 ? id : id.substring(id.length - 6)).toUpperCase()}';

/// Link de avaliação enviado ao cliente (produção). Espelha `avaliacaoLink`.
String avaliacaoLink(String osId) =>
    'https://cleanox.wenox.com.br/avaliar/${Uri.encodeComponent(osId)}';
