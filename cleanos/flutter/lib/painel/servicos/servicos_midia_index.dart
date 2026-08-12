/// Índice de fotos da Vitrine por serviço (para a lista do painel).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../vitrine/admin/vitrine_midia_repository.dart';

/// Fotos ativas de `vitrine_midia` agrupadas por `servico`.
final servicosMidiaIndexProvider =
    FutureProvider.autoDispose<Map<String, List<VitrineMidiaItem>>>((
      ref,
    ) async {
      final repo = VitrineMidiaRepository(ref.watch(pocketBaseProvider));
      final all = await repo.list();
      final map = <String, List<VitrineMidiaItem>>{};
      for (final item in all) {
        if (!item.ativo) continue;
        final sid = item.servicoId.trim();
        if (sid.isEmpty) continue;
        map.putIfAbsent(sid, () => <VitrineMidiaItem>[]).add(item);
      }
      for (final entry in map.entries) {
        entry.value.sort((a, b) {
          final pa = a.papel == 'capa' ? 0 : 1;
          final pb = b.papel == 'capa' ? 0 : 1;
          if (pa != pb) return pa - pb;
          return a.ordem.compareTo(b.ordem);
        });
      }
      return map;
    });
