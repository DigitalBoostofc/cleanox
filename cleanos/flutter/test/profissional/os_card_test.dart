/// os_card_test.dart — Fluxos críticos do card de OS:
///  - ações por status (atribuida → Iniciar; em_andamento → Checklist/Concluir),
///  - conclusão exige pagamento (botão Concluir desabilitado sem pagamento),
///  - ANTI-DESVIO: endereço só aparece em em_andamento; nunca telefone/cliente.
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/profissional/meus_servicos/os_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrdemServico _os({
  required OSStatus status,
  double? valorPago,
  FormaPagamento? forma,
  String? endereco,
}) => OrdemServico(
  id: 'os_abc123',
  cliente: 'cliente_secreto_id',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  tipoServicoNome: 'Higienização',
  // Data no passado → podeIniciar determinístico.
  dataHora: '2020-01-01 13:00:00Z',
  profissional: 'p1',
  status: status,
  valorServico: 150,
  valorPago: valorPago,
  formaPagamento: forma,
  enderecoLiberado: endereco,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('atribuida mostra "Iniciar serviço" e esconde o endereço', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OSCard(
          os: _os(status: OSStatus.atribuida, endereco: 'Rua Secreta, 123'),
          onIniciar: () {},
          onAvisar: () {},
          onPagar: () {},
          onConcluir: () {},
          onChecklist: () {},
        ),
      ),
    );

    expect(find.text('Iniciar serviço'), findsOneWidget);
    // ANTI-DESVIO: endereço NÃO pode aparecer fora de em_andamento.
    expect(find.textContaining('Rua Secreta'), findsNothing);
    // Visão-de-job: nome_curto/bairro/tipo aparecem; cliente-id nunca.
    expect(find.text('Carlos S.'), findsOneWidget);
    expect(find.textContaining('cliente_secreto_id'), findsNothing);
  });

  testWidgets('em_andamento libera endereço e Checklist e fotos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OSCard(
          os: _os(status: OSStatus.emAndamento, endereco: 'Rua Liberada, 456'),
          onIniciar: () {},
          onAvisar: () {},
          onPagar: () {},
          onConcluir: () {},
          onChecklist: () {},
        ),
      ),
    );

    expect(find.text('Checklist e fotos'), findsOneWidget);
    expect(find.textContaining('Rua Liberada, 456'), findsWidgets);
  });

  testWidgets('conclusão exige pagamento — botão desabilitado sem pagamento', (
    tester,
  ) async {
    var concluiu = false;
    await tester.pumpWidget(
      _wrap(
        OSCard(
          os: _os(status: OSStatus.emAndamento, endereco: 'Rua X'),
          onIniciar: () {},
          onAvisar: () {},
          onPagar: () {},
          onConcluir: () => concluiu = true,
          onChecklist: () {},
        ),
      ),
    );

    expect(find.text('Concluir serviço'), findsOneWidget);
    expect(find.textContaining('Registre o pagamento'), findsOneWidget);
    await tester.tap(find.text('Concluir serviço'));
    await tester.pump();
    expect(concluiu, isFalse, reason: 'sem pagamento não pode concluir');
  });

  testWidgets('com pagamento registrado, Concluir dispara o callback', (
    tester,
  ) async {
    var concluiu = false;
    await tester.pumpWidget(
      _wrap(
        OSCard(
          os: _os(
            status: OSStatus.emAndamento,
            endereco: 'Rua X',
            valorPago: 150,
            forma: FormaPagamento.pixMaquininha,
          ),
          onIniciar: () {},
          onAvisar: () {},
          onPagar: () {},
          onConcluir: () => concluiu = true,
          onChecklist: () {},
        ),
      ),
    );

    await tester.tap(find.text('Concluir serviço'));
    await tester.pump();
    expect(concluiu, isTrue);
  });
}
