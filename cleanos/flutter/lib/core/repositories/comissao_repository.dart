/// comissao_repository.dart — Contrato de comissões do profissional.
library;

import '../models/collections.dart';
import '../models/prof_comissao.dart';
import '../models/user.dart';

abstract class ComissaoRepository {
  /// Lista profissionais (users role=profissional) com config de comissão.
  Future<List<User>> listProfissionais();

  /// Atualiza comissão + frequência + dia(s) de pagamento no user.
  Future<User> setComissao({
    required String profissionalId,
    required ComissaoTipo tipo,
    required double valor,
    PagamentoFrequencia? pagamentoFrequencia,
    int pagamentoDia = 0,
    int pagamentoDia2 = 0,
  });

  /// Extrato de comissões (admin: todos ou filtro; prof: só as próprias via rule).
  Future<List<ProfComissao>> listComissoes({
    String? profissionalId,
    String sort,
  });

  /// Marca comissão como paga (admin/gerente).
  Future<ProfComissao> marcarPaga(String id);

  /// Alterna status `pendente` ↔ `paga` (paga→pendente estorna despesa via hook).
  Future<ProfComissao> setStatus(String id, ComissaoStatus status);
}
