/// servicos_labels.dart — Rótulos PT-BR + helpers de formatação do módulo Serviços.
///
/// Porte de `web/src/lib/servicos/labels.ts` (categoriaLabel/grupoLabel/…,
/// parseTempoMedio, formatTempoMedio, formatValorServico) para os enums Dart de
/// `core/models/servico.dart`. Reaproveita `formatCurrency` do core (BRT/moeda).
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/servico.dart';

String categoriaLabel(Categoria c) => switch (c) {
  Categoria.veicular => 'Veicular',
  Categoria.residencial => 'Residencial',
};

String grupoLabel(Grupo g) => switch (g) {
  Grupo.plano => 'Plano',
  Grupo.promocao => 'Promoção',
  Grupo.adicional => 'Adicional',
  Grupo.avulsos => 'Avulsos',
  Grupo.sofa => 'Sofá',
  Grupo.colchao => 'Colchão',
  Grupo.outros => 'Outros',
};

String tipoValorLabel(TipoValor t) => switch (t) {
  TipoValor.fixo => 'Fixo',
  TipoValor.faixa => 'Faixa',
  TipoValor.variavel => 'Variável',
};

String servicoStatusLabel(ServicoStatus s) =>
    s == ServicoStatus.ativo ? 'Ativo' : 'Inativo';

/// Converte um rótulo de tempo médio em minutos, usando SEMPRE o limite superior
/// do intervalo (protege a agenda contra estouro). Espelha `parseTempoMedio`.
///
/// Ex.: "1h30 a 2h" → 120 · "40min a 1h" → 60 · "3h+" → 180 · "Variável" → null.
int? parseTempoMedio(String label) {
  if (label.isEmpty) return null;
  final normalized = label.toLowerCase();
  if (normalized.contains('vari')) return null;

  final re = RegExp(r'(\d+)\s*h\s*(\d+)?|(\d+)\s*min');
  int? max;
  for (final m in re.allMatches(normalized)) {
    final int minutos;
    if (m.group(1) != null) {
      minutos =
          int.parse(m.group(1)!) * 60 +
          (m.group(2) != null ? int.parse(m.group(2)!) : 0);
    } else {
      minutos = int.parse(m.group(3)!);
    }
    if (max == null || minutos > max) max = minutos;
  }
  return max;
}

/// Formata o tempo médio para exibição (prefere o rótulo humano). Espelha
/// `formatTempoMedio`.
String formatTempoMedio(num? min, String? label) {
  final l = label?.trim();
  if (l != null && l.isNotEmpty) return l;
  if (min == null || min <= 0) return 'Variável';
  final h = min ~/ 60;
  final m = (min % 60).toInt();
  if (h == 0) return '${m}min';
  if (m == 0) return '${h}h';
  return '${h}h${m.toString().padLeft(2, '0')}';
}

/// Formata o valor de um serviço ('faixa' com máximo → "R$ x a R$ y"). Espelha
/// `formatValorServico`.
String formatValorServico(ServicoPB s) {
  if (s.tipoValor == TipoValor.faixa && s.valorBaseMax != null) {
    return '${formatCurrency(s.valorBase)} a ${formatCurrency(s.valorBaseMax!)}';
  }
  return formatCurrency(s.valorBase);
}

/// Payload snake_case a partir de um `ServicoPB` de domínio (espelha `servicoToPB`),
/// incluindo os legados sincronizados `preco_base`/`ativo`. Usado ao DUPLICAR — o
/// `slug` é (re)gerado na camada de dados. Não inclui id/created/updated.
Map<String, dynamic> servicoToPayload(ServicoPB s) {
  return <String, dynamic>{
    'categoria': (s.categoria ?? Categoria.veicular).wire,
    'grupo': (s.grupo ?? Grupo.outros).wire,
    'nome': s.nome,
    'valor_base': s.valorBase,
    'preco_base': s.valorBase, // 🔁 legado sincronizado
    'valor_base_max': s.tipoValor == TipoValor.faixa
        ? (s.valorBaseMax ?? 0)
        : 0,
    'tipo_valor': (s.tipoValor ?? TipoValor.fixo).wire,
    'tempo_medio_min': s.tempoMedioMin ?? 0,
    'tempo_medio_label': s.tempoMedioLabel ?? '',
    'status': (s.status ?? ServicoStatus.ativo).wire,
    'ativo': (s.status ?? ServicoStatus.ativo) == ServicoStatus.ativo,
    'observacao': s.observacao ?? '',
    'checklist_padrao': [
      for (final c in s.checklistPadrao)
        {
          'id': c.id,
          'titulo': c.titulo,
          'ordem': c.ordem,
          'obrigatorio': c.obrigatorio,
        },
    ],
    'orientacoes_pre': s.orientacoesPre ?? '',
    'orientacoes_pos': s.orientacoesPos ?? '',
    'adicionais_relacionados': <String>[],
  };
}
