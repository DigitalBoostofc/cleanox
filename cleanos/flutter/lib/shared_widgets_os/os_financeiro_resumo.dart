/// os_financeiro_resumo.dart — Resumo de valores da OS (principal + extras).
///
/// Contrato de produto (serviço extra):
/// - valor final = serviço principal + extras cobráveis − descontos
/// - na OS: listar cada serviço com seu valor e o **total**
/// - no financeiro (hook): 1 lançamento por serviço (`via_os` multi-linha)
/// - o `valor_pago` (movimentação/caixa) é o **total** da OS
library;

import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../core/formatters/formatters.dart';
import '../core/models/ordem_servico.dart';
import '../core/models/os_execucao.dart';

/// Extras que entram no total (aprovado / não requer).
List<ServicoAdicionalOS> adicionaisCobraveis(OrdemServico os) => os.adicionais
    .where(
      (a) =>
          a.aprovacao == AprovacaoStatus.aprovado ||
          a.aprovacao == AprovacaoStatus.naoRequer,
    )
    .toList();

/// Card/bloco com breakdown de valores da OS.
class OsFinanceiroResumo extends StatelessWidget {
  const OsFinanceiroResumo({
    super.key,
    required this.os,
    this.title = 'Valores da OS',
    this.dense = false,
    this.showPago = true,
  });

  final OrdemServico os;
  final String title;
  final bool dense;
  final bool showPago;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final principal = os.valorServico ?? 0;
    final extras = adicionaisCobraveis(os);
    final nomePrincipal = (os.tipoServicoNome ?? '').trim().isEmpty
        ? 'Serviço principal'
        : os.tipoServicoNome!.trim();

    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: (dense ? tt.titleSmall : tt.titleSmall)?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: dense ? ClxSpace.x2 : ClxSpace.x3),
          _linha(
            context,
            nomePrincipal,
            formatCurrency(principal),
            subtitle: 'Serviço principal',
          ),
          for (final a in extras)
            _linha(
              context,
              a.nome.isEmpty ? 'Serviço extra' : a.nome,
              formatCurrency(a.valor * a.quantidade),
              subtitle: a.quantidade > 1
                  ? 'Serviço extra · ×${a.quantidade}'
                  : 'Serviço extra',
              accent: true,
            ),
          if (os.descontos > 0)
            _linha(
              context,
              'Descontos',
              '− ${formatCurrency(os.descontos)}',
              inkMuted: true,
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 4 : 6),
            child: Divider(height: 1, color: clx.line),
          ),
          _linha(
            context,
            'Valor total da OS',
            formatCurrency(os.valorTotal),
            strong: true,
          ),
          if (showPago && (os.valorPago ?? 0) > 0) ...[
            const SizedBox(height: ClxSpace.x1),
            _linha(
              context,
              'Valor pago (movimentação)',
              formatCurrency(os.valorPago!),
              subtitle: os.formaPagamentoExibicao,
              strong: true,
              inkMuted: false,
            ),
          ],
          if (extras.isNotEmpty) ...[
            const SizedBox(height: ClxSpace.x2),
            Text(
              'No financeiro: cada serviço vira receita separada; '
              'o pagamento registra o total da OS.',
              style: tt.bodySmall?.copyWith(color: clx.ink3, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(
    BuildContext context,
    String label,
    String value, {
    String? subtitle,
    bool strong = false,
    bool accent = false,
    bool inkMuted = false,
  }) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: tt.labelSmall?.copyWith(
                      color: accent ? clx.primary : clx.ink3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  label,
                  style: (strong ? tt.titleSmall : tt.bodyLarge)?.copyWith(
                    color: inkMuted ? clx.ink3 : clx.ink,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: (strong ? tt.titleSmall : tt.bodyLarge)?.copyWith(
              color: strong
                  ? clx.accent
                  : inkMuted
                      ? clx.ink3
                      : clx.ink,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
