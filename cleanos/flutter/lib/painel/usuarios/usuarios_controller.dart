/// usuarios_controller.dart — Estado/dados do CRUD de Usuários do Painel.
///
/// Espelha `Usuarios.tsx`: carrega a equipe (admin/gerente/profissional) da coleção
/// auth `users`. Equipe é pequena e fechada → a interface `UsuariosRepository.list`
/// usa `getFullList` (não é lista de UI paginável). Consome só a interface congelada.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../data/painel_providers.dart';

class UsuariosState {
  const UsuariosState({this.items = const [], this.loading = true, this.error});

  final List<User> items;
  final bool loading;
  final String? error;

  bool get isEmpty => items.isEmpty;

  UsuariosState copyWith({
    List<User>? items,
    bool? loading,
    Object? error = _s,
  }) => UsuariosState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: error == _s ? this.error : error as String?,
  );

  static const Object _s = Object();
}

class UsuariosController extends StateNotifier<UsuariosState> {
  UsuariosController(this._ref) : super(const UsuariosState()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final users = await _ref
          .read(usuariosRepositoryProvider)
          .list(sort: 'name');
      state = state.copyWith(items: users, loading: false, error: null);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar os usuários.',
      );
    }
  }

  Future<void> delete(String id) async {
    await _ref.read(usuariosRepositoryProvider).delete(id);
    await refresh();
  }
}

final usuariosControllerProvider =
    StateNotifierProvider.autoDispose<UsuariosController, UsuariosState>(
      UsuariosController.new,
    );
