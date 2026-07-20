/// os_rebaixar_confirm.dart — Confirmação antes de tirar uma OS de `em_andamento`
/// mexendo no profissional (F-228).
///
/// Trocar (ou remover) o profissional de uma OS que já está EM ANDAMENTO rebaixa
/// o status. O hook do servidor (`os_logic.js`, `manageEndereco`) reage a isso
/// apagando `endereco_liberado` e as coordenadas de GPS — e faz isso de
/// propósito: endereço completo e rastreamento são EFÊMEROS, só existem enquanto
/// a OS está sendo executada (anti-desvio/LGPD — o profissional não fica com o
/// endereço do cliente depois do serviço).
///
/// Ou seja: o dado apagado é uma consequência CORRETA de uma decisão do admin —
/// o defeito era ela acontecer em silêncio. Este diálogo põe a consequência na
/// frente de quem decide, em vez de bloquear a ação (o admin precisa mesmo poder
/// trocar um profissional que desistiu no meio do serviço) ou de preservar o
/// endereço (isso quebraria o invariante do anti-desvio).
///
/// O endereço não é perdido de verdade: é reconstruído a partir do cadastro do
/// cliente na próxima vez que a OS entrar em `em_andamento`.
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Pergunta ao admin se ele quer mesmo tirar a OS de `em_andamento`.
///
/// [removendo] = está REMOVENDO o profissional (OS volta para Agendada);
/// senão está TROCANDO por outro (OS volta para Atribuída).
///
/// Resolve `true` só se o admin confirmar.
Future<bool?> confirmarRebaixarEmAndamento(
  BuildContext context, {
  required bool removendo,
}) {
  final destino = removendo ? 'Em agendamento' : 'Atribuída';
  final acao = removendo ? 'Remover o profissional' : 'Trocar o profissional';
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: const Text('Esta OS está em andamento'),
      content: Text(
        '$acao interrompe a execução: a OS volta para "$destino" e o endereço '
        'liberado e o rastreamento de GPS são apagados — eles só existem '
        'enquanto a OS está em andamento.\n\n'
        'O endereço volta sozinho quando a execução recomeçar.',
      ),
      actions: [
        ClxButton(
          label: 'Voltar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        ClxButton(
          label: removendo ? 'Remover mesmo assim' : 'Trocar mesmo assim',
          variant: ClxButtonVariant.danger,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
}
