/// Providers da taxonomia de serviços.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import 'taxonomia_models.dart';
import 'taxonomia_repository.dart';

final taxonomiaRepositoryProvider = Provider<TaxonomiaRepository>((ref) {
  return TaxonomiaRepository(ref.watch(pocketBaseProvider));
});

final taxonomiaArvoreProvider =
    FutureProvider.autoDispose<TaxonomiaArvore>((ref) async {
  return ref.watch(taxonomiaRepositoryProvider).load();
});
