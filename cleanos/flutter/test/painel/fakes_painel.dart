/// fakes_painel.dart — Fake de `OrdensRepository` para os testes do Painel.
///
/// Cobre os três estados do Dashboard: dados (por índice de chamada de `list`),
/// vazio e erro. Só implementa o que o Painel consome; o resto lança para
/// flagrar uso indevido.
library;

import 'dart:async';

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';

/// OS mínima para os testes do Painel.
OrdemServico painelOS({
  required String id,
  required OSStatus status,
  String nomeCurto = 'Cliente X',
  String bairro = 'Centro',
  String? tipo = 'Higienização',
  String dataHora = '2026-07-01 13:00:00Z',
  double? valorPago,
}) => OrdemServico(
  id: id,
  nomeCurto: nomeCurto,
  bairro: bairro,
  tipoServicoNome: tipo,
  dataHora: dataHora,
  status: status,
  valorPago: valorPago,
);

class FakePainelOrdens implements OrdensRepository {
  FakePainelOrdens({this.byIndex, this.error});

  /// Resolve os itens de `list` pela ordem da chamada (0 = hoje, 1 = próximos).
  final List<OrdemServico> Function(int index)? byIndex;

  /// Se setado, `list` lança (estado de erro).
  final Object? error;

  int _calls = 0;

  factory FakePainelOrdens.empty() =>
      FakePainelOrdens(byIndex: (_) => const []);

  factory FakePainelOrdens.throwing() =>
      FakePainelOrdens(error: Exception('falha de rede'));

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    final idx = _calls++;
    if (error != null) throw error!;
    final items = byIndex?.call(idx) ?? const <OrdemServico>[];
    return PageResult<OrdemServico>(
      items: items,
      page: 1,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  // ── não usados pelo Painel nesta onda ──
  Never _unused() => throw UnimplementedError('não usado nos testes do Painel');

  @override
  Future<OrdemServico> getExec(String osId) => _unused();
  @override
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch) => _unused();
  @override
  Future<OrdemServico> updateStatus(String osId, OSStatus novo) => _unused();
  @override
  Future<OrdemServico> cancelar(String osId, {required String motivo}) =>
      _unused();
  @override
  Stream<OrdemServicoEvent> subscribe({String topic = '*', String? filter}) =>
      const Stream.empty();
  @override
  Future<List<OrdemServico>> listDoProfissional(
    String profId, {
    DateRange? janela,
  }) => _unused();
  @override
  Future<OrdemServico> getOne(String osId, {String? expand}) => _unused();
  @override
  Future<OrdemServico> create(Map<String, dynamic> data, {String? expand}) =>
      _unused();
  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) => _unused();
  @override
  Future<void> delete(String osId) => _unused();
}
