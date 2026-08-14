/// Taxonomia de serviços: Categoria → Grupo → Serviço.
///
/// Fallback estático de grupos por categoria (editor/lista quando a árvore
/// dinâmica ainda não carregou). Subgrupo é legado e não entra no fluxo.
library;

import 'servico.dart';

/// Opção de subgrupo (valor gravado no PB + rótulo PT-BR).
class ServicoSubgrupo {
  const ServicoSubgrupo(this.wire, this.label);
  final String wire;
  final String label;
}

/// Grupos permitidos em cada categoria.
List<Grupo> gruposDaCategoria(Categoria categoria) => switch (categoria) {
      Categoria.veicular => const [
          Grupo.plano,
          Grupo.promocao,
          Grupo.adicional,
          Grupo.avulsos,
        ],
      Categoria.residencial => const [
          Grupo.sofa,
          Grupo.colchao,
          Grupo.outros,
        ],
    };

/// Subgrupos permitidos para o par categoria + grupo.
/// Lista vazia = subgrupo opcional/livre não listado (UI esconde o campo).
List<ServicoSubgrupo> subgruposDoGrupo(
  Categoria categoria,
  Grupo grupo,
) {
  switch (categoria) {
    case Categoria.veicular:
      switch (grupo) {
        case Grupo.plano:
          return const [
            ServicoSubgrupo('essencial', 'Essencial'),
            ServicoSubgrupo('completo', 'Completo'),
            ServicoSubgrupo('premium', 'Premium'),
          ];
        case Grupo.promocao:
          return const [
            ServicoSubgrupo('completo_promo', 'Completo (promo)'),
            ServicoSubgrupo('premium_promo', 'Premium (promo)'),
          ];
        case Grupo.adicional:
          return const [
            ServicoSubgrupo('muito_sujo', 'Veículo muito sujo'),
            ServicoSubgrupo('deslocamento', 'Taxa de deslocamento'),
            ServicoSubgrupo('outro_adicional', 'Outro adicional'),
          ];
        case Grupo.avulsos:
          return const [
            ServicoSubgrupo('bancos', 'Bancos'),
            ServicoSubgrupo('teto', 'Teto'),
            ServicoSubgrupo('cintos', 'Cintos'),
            ServicoSubgrupo('forros_porta', 'Forros de porta'),
            ServicoSubgrupo('painel', 'Painel / plásticos'),
            ServicoSubgrupo('carpete', 'Carpete / porta-malas / tapetes'),
            ServicoSubgrupo('outro_avulso', 'Outro avulso'),
          ];
        case Grupo.sofa:
        case Grupo.colchao:
        case Grupo.outros:
          return const [];
      }
    case Categoria.residencial:
      switch (grupo) {
        case Grupo.sofa:
          return const [
            ServicoSubgrupo('sofa_2', '2 lugares'),
            ServicoSubgrupo('sofa_3', '3 lugares'),
            ServicoSubgrupo('sofa_4', '4 lugares'),
            ServicoSubgrupo('sofa_56', '5/6 lugares'),
            ServicoSubgrupo('sofa_retratil', 'Retrátil'),
            ServicoSubgrupo('sofa_outro', 'Outro sofá'),
          ];
        case Grupo.colchao:
          return const [
            ServicoSubgrupo('solteiro', 'Solteiro'),
            ServicoSubgrupo('casal', 'Casal'),
            ServicoSubgrupo('queen', 'Queen'),
            ServicoSubgrupo('king', 'King'),
            ServicoSubgrupo('box_solteiro', 'Cama box solteiro'),
            ServicoSubgrupo('box_casal', 'Cama box casal'),
            ServicoSubgrupo('colchao_outro', 'Outro colchão/box'),
          ];
        case Grupo.outros:
          return const [
            ServicoSubgrupo('poltrona', 'Poltrona'),
            ServicoSubgrupo('cadeira', 'Cadeira'),
            ServicoSubgrupo('puff', 'Puff'),
            ServicoSubgrupo('tapete', 'Tapete'),
            ServicoSubgrupo('resid_outro', 'Outro'),
          ];
        case Grupo.plano:
        case Grupo.promocao:
        case Grupo.adicional:
        case Grupo.avulsos:
          return const [];
      }
  }
}

/// Garante grupo válido na categoria (senão o primeiro da lista).
Grupo normalizarGrupoNaCategoria(Categoria categoria, Grupo? grupo) {
  final permitidos = gruposDaCategoria(categoria);
  if (grupo != null && permitidos.contains(grupo)) return grupo;
  return permitidos.first;
}

/// Garante subgrupo válido no grupo (senão '' se lista vazia, ou o primeiro).
String normalizarSubgrupo({
  required Categoria categoria,
  required Grupo grupo,
  required String? subgrupo,
}) {
  final ops = subgruposDoGrupo(categoria, grupo);
  if (ops.isEmpty) return '';
  final s = (subgrupo ?? '').trim();
  for (final o in ops) {
    if (o.wire == s) return s;
  }
  return ops.first.wire;
}

String? subgrupoLabel(Categoria categoria, Grupo grupo, String wire) {
  final w = wire.trim();
  if (w.isEmpty) return null;
  for (final o in subgruposDoGrupo(categoria, grupo)) {
    if (o.wire == w) return o.label;
  }
  return w;
}

bool grupoPertenceACategoria(Categoria categoria, Grupo grupo) =>
    gruposDaCategoria(categoria).contains(grupo);

bool subgrupoPertenceAoGrupo(
  Categoria categoria,
  Grupo grupo,
  String subgrupo,
) {
  final ops = subgruposDoGrupo(categoria, grupo);
  if (ops.isEmpty) return subgrupo.trim().isEmpty;
  final s = subgrupo.trim();
  return ops.any((o) => o.wire == s);
}
