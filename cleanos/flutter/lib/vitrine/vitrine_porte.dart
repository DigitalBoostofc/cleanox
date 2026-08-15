/// Agrupa lavagens de carro por porte (Popular / SUV / Caminhonete).
///
/// No catálogo público aparecem 2 cards (Prime e Detail). O add abre o porte.
library;

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/formatters/formatters.dart';
import 'vitrine_api.dart';

const kPortesLavagem = ['Popular', 'SUV', 'Caminhonete'];

final _porteRe = RegExp(
  r'^(.*)\s+[—–-]\s+(Popular|SUV|Caminhonete)$',
  caseSensitive: false,
);

/// `Lavagem Prime — SUV` → família + porte. Senão null.
({String familia, String porte})? parsePorteLavagem(String nome) {
  final m = _porteRe.firstMatch(nome.trim());
  if (m == null) return null;
  final familia = m.group(1)!.trim();
  if (familia.isEmpty) return null;
  final raw = m.group(2)!.trim();
  final porte = kPortesLavagem.firstWhere(
    (p) => p.toLowerCase() == raw.toLowerCase(),
    orElse: () => raw,
  );
  return (familia: familia, porte: porte);
}

int _ordemPorte(String porte) {
  final i = kPortesLavagem.indexWhere(
    (p) => p.toLowerCase() == porte.toLowerCase(),
  );
  return i < 0 ? 99 : i;
}

/// Irmãos de porte no mesmo grupo, ou null se não for família.
List<VitrineServico>? variantesPorteDoCard(
  VitrineServico card,
  List<VitrineServico> catalogo,
) {
  final parsed = parsePorteLavagem(card.nome);
  final String familia;
  if (parsed != null) {
    familia = parsed.familia;
  } else if (card.vitrineTitulo.trim().isNotEmpty) {
    familia = card.vitrineTitulo.trim();
  } else {
    familia = card.nome.trim();
  }
  final grupo = card.grupo.trim().toLowerCase();
  final vars = catalogo.where((s) {
    final p = parsePorteLavagem(s.nome);
    if (p == null) return false;
    if (p.familia != familia) return false;
    return s.grupo.trim().toLowerCase() == grupo;
  }).toList();
  if (vars.length < 2) return null;
  vars.sort((a, b) {
    final pa = parsePorteLavagem(a.nome)!;
    final pb = parsePorteLavagem(b.nome)!;
    return _ordemPorte(pa.porte).compareTo(_ordemPorte(pb.porte));
  });
  return vars;
}

VitrineServico _capaFamilia(String familia, List<VitrineServico> vars) {
  final capa = vars.reduce(
    (a, b) => a.valorBase <= b.valorBase ? a : b,
  );
  return VitrineServico(
    id: capa.id,
    nome: familia,
    descricao: capa.descricao,
    categoria: capa.categoria,
    grupo: capa.grupo,
    subgrupo: capa.subgrupo,
    valorBase: capa.valorBase,
    valorBaseMax: 0,
    tempoMedioMin: capa.tempoMedioMin,
    tempoMedioLabel: capa.tempoMedioLabel,
    orientacoesPre: capa.orientacoesPre,
    vitrineDestaque: capa.vitrineDestaque,
    layout: capa.layout,
    vitrineTitulo: familia,
    vitrineDescricao: capa.vitrineDescricao,
    vitrineBadge: capa.vitrineBadge,
    vitrineCta: capa.vitrineCta,
    precoModo: VitrinePrecoModo.aPartirDe,
    vitrineOrdem: capa.vitrineOrdem,
  );
}

/// 6 lavagens → 2 cards. O resto passa igual.
List<VitrineServico> catalogoAgrupadoPorPorte(List<VitrineServico> origem) {
  final used = <String>{};
  final out = <VitrineServico>[];
  for (final s in origem) {
    if (used.contains(s.id)) continue;
    final parsed = parsePorteLavagem(s.nome);
    if (parsed == null) {
      out.add(s);
      used.add(s.id);
      continue;
    }
    final vars = variantesPorteDoCard(s, origem);
    if (vars == null) {
      out.add(s);
      used.add(s.id);
      continue;
    }
    for (final v in vars) {
      used.add(v.id);
    }
    out.add(_capaFamilia(parsed.familia, vars));
  }
  return out;
}

/// Marca o card da família se qualquer porte estiver no carrinho.
Set<String> idsSelecaoComPorte({
  required List<VitrineServico> exibidos,
  required List<VitrineServico> catalogo,
  required Set<String> selecionados,
}) {
  final out = <String>{};
  for (final card in exibidos) {
    final vars = variantesPorteDoCard(card, catalogo);
    if (vars != null) {
      if (vars.any((v) => selecionados.contains(v.id))) out.add(card.id);
    } else if (selecionados.contains(card.id)) {
      out.add(card.id);
    }
  }
  return out;
}

Future<VitrineServico?> showVitrinePorteSheet(
  BuildContext context, {
  required String titulo,
  required List<VitrineServico> variantes,
}) {
  return showModalBottomSheet<VitrineServico>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                key: const Key('vitrine-porte-titulo'),
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ClxBrand.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escolha o porte do veículo',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 13,
                  color: ClxBrand.muted,
                ),
              ),
              const SizedBox(height: 16),
              for (final v in variantes) ...[
                const SizedBox(height: 8),
                Material(
                  color: const Color(0xFFF4F7FA),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('vitrine-porte-${parsePorteLavagem(v.nome)?.porte ?? v.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(ctx).pop(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              parsePorteLavagem(v.nome)?.porte ?? v.nome,
                              style: const TextStyle(
                                fontFamily: kFontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ClxBrand.navy,
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(v.valorBase),
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ClxBrand.navy,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: ClxBrand.cyan,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.add,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
