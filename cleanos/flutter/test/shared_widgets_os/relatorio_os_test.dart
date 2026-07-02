/// relatorio_os_test.dart — Montagem PURA do laudo (buildRelatorioOS/calcTotalOS):
///  - só adicionais cobráveis (aprovado/nao_requer) entram no total e no relatório,
///  - só observações visíveis ao cliente aparecem,
///  - total = principal + adicionais − descontos (nunca negativo).
library;

import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/shared_widgets_os/relatorio_os.dart';
import 'package:flutter_test/flutter_test.dart';

const _snapshot = ServiceSnapshot(
  serviceId: 's1',
  nome: 'Higienização',
  valorBase: 200,
  orientacoesPosServico: 'Não pisar por 2h',
  capturedAt: '2026-07-01 09:00:00Z',
);

void main() {
  test('só adicionais cobráveis entram no total e no relatório', () {
    final rel = buildRelatorioOS(
      BuildRelatorioOSInput(
        osId: 'os_abc123',
        clienteNome: 'Carlos S.',
        dataHora: '2026-07-01 10:00:00Z',
        snapshot: _snapshot,
        adicionais: const [
          ServicoAdicionalOS(
            id: 'a1',
            nome: 'Impermeabilização',
            valor: 50,
            aprovacao: AprovacaoStatus.aprovado,
          ),
          ServicoAdicionalOS(
            id: 'a2',
            nome: 'Extra recusado',
            valor: 999,
            aprovacao: AprovacaoStatus.recusado,
          ),
          ServicoAdicionalOS(
            id: 'a3',
            nome: 'Aguardando',
            valor: 999,
            aprovacao: AprovacaoStatus.aguardando,
          ),
        ],
        descontos: 30,
        geradoEm: '2026-07-01 11:00:00Z',
      ),
    );

    // Só o aprovado entra.
    expect(rel.adicionais.map((a) => a.id), ['a1']);
    expect(rel.valorPrincipal, 200);
    expect(rel.valorAdicionais, 50);
    // 200 + 50 - 30 = 220.
    expect(rel.valorTotal, 220);
  });

  test('total nunca é negativo', () {
    expect(calcTotalOS(100, const [], 500), 0);
  });

  test('só observações visíveis ao cliente aparecem', () {
    final rel = buildRelatorioOS(
      BuildRelatorioOSInput(
        osId: 'os1',
        clienteNome: 'Carlos',
        dataHora: '2026-07-01 10:00:00Z',
        snapshot: _snapshot,
        observacoes: const [
          ObservacaoProfissional(
            id: 'o1',
            texto: 'Visível',
            visivelCliente: true,
          ),
          ObservacaoProfissional(
            id: 'o2',
            texto: 'Interna',
            visivelCliente: false,
          ),
        ],
        geradoEm: '2026-07-01 11:00:00Z',
      ),
    );
    expect(rel.observacoesVisiveis.map((o) => o.id), ['o1']);
    expect(rel.orientacoesPos, 'Não pisar por 2h');
  });

  test('numeroFromId usa os últimos 6 chars em maiúsculas', () {
    expect(numeroFromId('rec_abc123'), '#ABC123');
    expect(numeroFromId('xyz'), '#XYZ');
  });
}
