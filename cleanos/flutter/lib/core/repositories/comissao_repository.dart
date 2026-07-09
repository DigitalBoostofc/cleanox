/// comissao_repository.dart — Contrato de comissões do profissional.
library;

import '../models/collections.dart';
import '../models/prof_comissao.dart';
import '../models/user.dart';

abstract class ComissaoRepository {
  /// Lista profissionais (users role=profissional) com config de comissão.
  Future<List<User>> listProfissionais();

  /// Atualiza comissao_tipo + comissao_valor no user.
  Future<User> setComissao({
    required String profissionalId,
    required ComissaoTipo tipo,
    required double valor,
  });

  /// Extrato de comissões (admin: todos ou filtro; prof: só as próprias via rule).
  Future<List<ProfComissao>> listComissoes({
    String? profissionalId,
    String sort,
  });

  /// Marca comissão como paga (admin/gerente).
  Future<ProfComissao> marcarPaga(String id);
}
