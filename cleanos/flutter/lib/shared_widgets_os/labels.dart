/// labels.dart — Rótulos PT-BR + helpers de formatação do módulo Serviços/OS.
///
/// Porte fiel de `web/src/lib/servicos/labels.ts`. Fica nos widgets compartilhados
/// (dono: Time B) porque tanto a execução (profissional) quanto o Painel (Time A)
/// consomem estes rótulos ao renderizar snapshot, adicionais e laudo. Reaproveita
/// os enums congelados de `core/models` — não redefine nada.
library;

import '../core/models/os_execucao.dart';
import '../core/models/servico.dart';

/// Categoria do serviço (veicular/residencial).
String categoriaLabel(Categoria? c) => switch (c) {
  Categoria.veicular => 'Veicular',
  Categoria.residencial => 'Residencial',
  null => '—',
};

/// Grupo do serviço (plano/promoção/…).
String grupoLabel(Grupo? g) => switch (g) {
  Grupo.plano => 'Plano',
  Grupo.promocao => 'Promoção',
  Grupo.adicional => 'Adicional',
  Grupo.avulsos => 'Avulsos',
  Grupo.sofa => 'Sofá',
  Grupo.colchao => 'Colchão',
  Grupo.outros => 'Outros',
  null => '—',
};

/// Tipo de valor (fixo/faixa/variável).
String tipoValorLabel(TipoValor? t) => switch (t) {
  TipoValor.fixo => 'Fixo',
  TipoValor.faixa => 'Faixa',
  TipoValor.variavel => 'Variável',
  null => '—',
};

/// Status de aprovação de um adicional.
String aprovacaoLabel(AprovacaoStatus a) => switch (a) {
  AprovacaoStatus.naoRequer => 'Não precisa aprovar',
  AprovacaoStatus.aguardando => 'Aguardando aprovação do cliente',
  AprovacaoStatus.aprovado => 'Aprovado',
  AprovacaoStatus.recusado => 'Recusado',
};

/// Rótulo da fase da foto (antes/durante/depois).
String faseFotoLabel(FaseFoto f) => f.label;

/// Formata o tempo médio para exibição (espelha `formatTempoMedio`).
/// Prefere o rótulo humano; senão deriva dos minutos. Sem ambos → "Variável".
String formatTempoMedio(double? min, String? label) {
  if (label != null && label.trim().isNotEmpty) return label.trim();
  if (min == null || min <= 0) return 'Variável';
  final total = min.round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h == 0) return '${m}min';
  if (m == 0) return '${h}h';
  return '${h}h${m.toString().padLeft(2, '0')}';
}

/// Texto padrão do rodapé do relatório enviado ao cliente.
const String kRelatorioTextoPadrao =
    'Seu serviço foi concluído. Confira abaixo o resumo do que foi executado pela '
    'equipe Cleanox. Caso identifique qualquer falha, intercorrência ou ponto que '
    'precise de revisão, entre em contato em até 3 dias após a execução para '
    'análise e possível correção.';

/// Prazo padrão (em dias) para o cliente relatar intercorrências.
const int kRelatorioPrazoDias = 3;
