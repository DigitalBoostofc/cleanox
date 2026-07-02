/// auth_providers.dart — Providers Riverpod de auth + acesso ao PocketBase.
///
/// Fronteira do §3.1: ambas as superfícies leem `currentUserProvider` /
/// `currentRoleProvider`. Usa providers "manuais" (sem codegen) de propósito —
/// são poucos e globais; mantém a superfície de geração menor e previsível.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/user.dart';
import '../pb/pb_client.dart';
import '../repositories/ordens_repository.dart';
import 'auth_service.dart';

/// PocketBase singleton (deve ter passado por [PbClient.init] no boot).
/// Sobrescrevível em teste via ProviderScope(overrides: [...]).
final pocketBaseProvider = Provider<PocketBase>((ref) => PbClient.instance.pb);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(pocketBaseProvider)),
);

/// Stream do estado de auth (estado atual + mudanças do authStore).
final authStateProvider = StreamProvider<AuthSnapshot>((ref) {
  return ref.watch(authServiceProvider).watch();
});

/// Usuário autenticado atual (null se deslogado).
final currentUserProvider = Provider<User?>((ref) {
  final async = ref.watch(authStateProvider);
  return async.valueOrNull?.user ?? ref.watch(authServiceProvider).currentUser;
});

/// Papel do usuário atual.
final currentRoleProvider = Provider<Role?>(
  (ref) => ref.watch(currentUserProvider)?.role,
);

/// Repositório real de Ordens de Serviço (impl PB sobre o singleton).
final ordensRepositoryProvider = Provider<OrdensRepository>(
  (ref) => PbOrdensRepository(ref.watch(pocketBaseProvider)),
);
