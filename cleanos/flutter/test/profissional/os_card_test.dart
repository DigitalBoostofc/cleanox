/// os_card_test.dart — Fluxos críticos do card de OS:
///  - ações por status (atribuida → Iniciar; em_andamento → Checklist/Concluir),
///  - conclusão exige pagamento (botão Concluir desabilitado sem pagamento),
///  - endereço em atribuida e em_andamento; nunca id bruto de cliente.
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
  /// null = agora (hoje BRT) — WhatsApp liberado; string fixa para “outro dia”.
  String? dataHora,
}) => OrdemServico(
  id: 'os_abc123',
  cliente: 'cliente_secreto_id',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  tipoServicoNome: 'Higienização',
  // Default: hoje → WhatsApp liberado; use dataHora: passado/futuro nos testes.
  dataHora: dataHora ?? DateTime.now().toUtc().toIso8601String(),
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
  testWidgets(
    'atribuida: endereço, observações, Em deslocamento, WhatsApp e Iniciar',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OSCard(
            os: _os(status: OSStatus.atribuida, endereco: 'Rua Liberada, 123')
                .copyWith(observacoes: 'Portão azul, interfone 12'),
            onIniciar: () {},
            onAvisar: () {},
            onCheguei: () {},
            onPagar: () {},
            onConcluir: () {},
            onChecklist: () {},
            onWhatsAppCliente: () {},
          ),
        ),
      );

      expect(find.text('Iniciar serviço'), findsOneWidget);
      expect(find.text('WhatsApp cliente'), findsOneWidget);
      expect(find.text('Em deslocamento'), findsOneWidget);
      expect(find.textContaining('Rua Liberada'), findsWidgets);
      expect(find.text('Observações'), findsOneWidget);
      expect(find.textContaining('Portão azul'), findsOneWidget);
      expect(find.text('Carlos S.'), findsOneWidget);
      expect(find.textContaining('cliente_secreto_id'), findsNothing);
    },
  );

  testWidgets(
    'aviso_a_caminho_em vazio ("") NÃO marca Em deslocamento (R2)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OSCard(
            os: _os(status: OSStatus.atribuida, endereco: 'Rua X')
                .copyWith(avisoACaminhoEm: ''),
            onIniciar: () {},
            onAvisar: () {},
            onCheguei: () {},
            onPagar: () {},
            onConcluir: () {},
            onChecklist: () {},
            onWhatsAppCliente: () {},
          ),
        ),
      );
      expect(find.text('Em deslocamento'), findsOneWidget);
      expect(find.textContaining('cliente avisado'), findsNothing);
    },
  );

  testWidgets('em_andamento: Em deslocamento + checklist principal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OSCard(
          os: _os(status: OSStatus.emAndamento, endereco: 'Rua Liberada, 456'),
          onIniciar: () {},
          onAvisar: () {},
            onCheguei: () {},
          onPagar: () {},
          onConcluir: () {},
          onChecklist: () {},
          onWhatsAppCliente: () {},
        ),
      ),
    );

    expect(find.text('Em deslocamento'), findsOneWidget);
    expect(find.text('Checklist, pagamento e concluir'), findsOneWidget);
    expect(find.textContaining('Rua Liberada, 456'), findsWidgets);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('WhatsApp NÃO aparece em OS de outro dia', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OSCard(
          os: _os(
            status: OSStatus.atribuida,
            endereco: 'Rua Futura, 1',
            dataHora: '2030-06-15 12:00:00Z',
          ),
          onIniciar: () {},
          onAvisar: () {},
          onCheguei: () {},
          onPagar: () {},
          onConcluir: () {},
          onChecklist: () {},
          onWhatsAppCliente: () {},
        ),
      ),
    );
    expect(find.text('WhatsApp cliente'), findsNothing);
    expect(find.text('Ver rota'), findsOneWidget);
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
            onCheguei: () {},
          onPagar: () {},
          onConcluir: () => concluiu = true,
          onChecklist: () {},
          onWhatsAppCliente: () {},
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
            onCheguei: () {},
          onPagar: () {},
          onConcluir: () => concluiu = true,
          onChecklist: () {},
          onWhatsAppCliente: () {},
        ),
      ),
    );

    await tester.tap(find.text('Concluir serviço'));
    await tester.pump();
    expect(concluiu, isTrue);
  });

  testWidgets(
    'concluida mostra "Ver detalhes do serviço" e abre a execução (leitura)',
    (tester) async {
      var abriu = false;
      await tester.pumpWidget(
        _wrap(
          OSCard(
            os: _os(
              status: OSStatus.concluida,
              valorPago: 150,
              forma: FormaPagamento.pixMaquininha,
            ),
            onIniciar: () {},
            onAvisar: () {},
            onCheguei: () {},
            onPagar: () {},
            onConcluir: () {},
            onChecklist: () => abriu = true,
            onWhatsAppCliente: () {},
          ),
        ),
      );

      expect(find.text('Ver detalhes do serviço'), findsOneWidget);
      await tester.tap(find.text('Ver detalhes do serviço'));
      await tester.pump();
      expect(abriu, isTrue);
    },
  );
}
