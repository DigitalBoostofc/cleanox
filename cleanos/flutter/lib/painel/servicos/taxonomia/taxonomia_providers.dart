/// Providers da taxonomia de serviços (Categoria → Grupo → Serviço).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/models/servico.dart';
import '../../data/painel_filters.dart';
import '../../data/painel_providers.dart';
import 'taxonomia_models.dart';
import 'taxonomia_repository.dart';

final taxonomiaRepositoryProvider = Provider<TaxonomiaRepository>((ref) {
  return TaxonomiaRepository(ref.watch(pocketBaseProvider));
});

final taxonomiaArvoreProvider =
    FutureProvider.autoDispose<TaxonomiaArvore>((ref) async {
  return ref.watch(taxonomiaRepositoryProvider).load();
});

/// Serviços do grupo selecionado na engrenagem (filtro por slugs).
final servicosDoGrupoProvider = FutureProvider.autoDispose
    .family<List<ServicoPB>, ({String categoria, String grupo})>((
      ref,
      key,
    ) async {
      final repo = ref.watch(servicosRepositoryProvider);
      final page = await repo.list(
        page: 1,
        perPage: 200,
        filter: servicosFilter(categoria: key.categoria, grupo: key.grupo),
        sort: 'ordem,nome',
      );
      final cat = key.categoria.trim().toLowerCase();
      final grupo = key.grupo.trim().toLowerCase();
      return [
        for (final s in page.items)
          if (s.categoria.trim().toLowerCase() == cat &&
              s.grupo.trim().toLowerCase() == grupo)
            s,
      ];
    });
