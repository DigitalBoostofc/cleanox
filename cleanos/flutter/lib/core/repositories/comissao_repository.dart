/// comissao_repository.dart — Contrato de comissões do profissional.
library;

import '../models/collections.dart';
import '../models/prof_comissao.dart';
import '../models/user.dart';

abstract class ComissaoRepository {
  /// Lista profissionais (users role=profissional) com config de comissão.
  Future<List<User>> listProfissionais({bool incluirInativos = false});

  /// Atualiza comissão + frequência + dia(s) de pagamento no user.
  Future<User> setComissao({
    required String profissionalId,
    required ComissaoTipo tipo,
    required double valor,
    RemuneracaoTipo remuneracaoTipo = RemuneracaoTipo.nenhuma,
    double remuneracaoValor = 0,
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

  /// Marca várias comissões como pagas (fecha ciclo em lote).
  /// Cada uma dispara o hook de despesa (via_comissao).
  Future<void> marcarLotePagas(List<String> ids);

  /// Exclui uma bonificação manual ainda pendente.
  Future<void> excluirBonificacao(String id);

  /// Cria uma bonificação manual, independente da configuração automática.
  Future<ProfComissao> criarBonificacao({
    required String profissionalId,
    required double valor,
    String descricao,
    String? osId,
  });
}
