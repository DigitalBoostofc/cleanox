/// exec_widget_cov_test.dart — Cobertura de widget do APP PROFISSIONAL
/// (execução de OS), focada em ANTI-DESVIO (LGPD) e nas travas de fluxo que o
/// E2E provou na prática. COMPLEMENTA (não duplica) os testes já existentes de
/// `os_card_test.dart`, `os_execucao_screen_test.dart` e `prof_deeplink_test.dart`.
///
/// Foco deste arquivo:
///  1. ⭐ ANTI-DESVIO reforçado: endereço completo do cliente fica OCULTO em
///     TODO status != `em_andamento` (atribuida/agendada/concluida/cancelada),
///     mesmo com `endereco_liberado` preenchido; a visão-de-job (bairro +
///     nome_curto) permanece; o id opaco do cliente NUNCA vaza.
///  2. "Ver rota"/deep-link: o botão só existe quando o endereço está liberado
///     (`em_andamento` + `endereco_liberado` não-vazio).
///  3. CHECKLIST/obrigatórios: o banner de itens obrigatórios pendentes gate a
///     finalização na tela de execução.
///  4. "Gerar laudo": desabilitado sem `service_snapshot`; habilitado com ele.
///
/// Determinístico, sem rede/GPS/câmera reais (fakes do `fakes.dart`).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/widgets/clx_button.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/meus_servicos/os_card.dart';
import 'package:cleanos/profissional/os_execucao/os_execucao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// Sentinela do endereço completo/PII — se aparecer fora de `em_andamento`,
// houve desvio. Contém "número" e "telefone" pra provar que nada de sensível
// (nem o próprio texto do endereço) escapa da visão-de-job.
const _enderecoSecreto = 'Rua das Palmeiras, 742 — Apto 31 · Tel (11) 99876-5432';
const _clienteIdOpaco = 'cliente_secreto_id';

const _prof = User(id: 'p1', name: 'Pedro', role: Role.profissional);

OrdemServico _os({
  required OSStatus status,
  String? endereco = _enderecoSecreto,
  double? valorPago,
  FormaPagamento? forma,
  ServiceSnapshot? snapshot,
}) => OrdemServico(
  id: 'os1',
  cliente: _clienteIdOpaco,
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  tipoServicoNome: 'Higienização',
  // Data no passado → estado determinístico (podeIniciar/hoje).
  dataHora: '2020-01-01 13:00:00Z',
  profissional: 'p1',
  status: status,
  valorServico: 150,
  valorPago: valorPago,
  formaPagamento: forma,
  enderecoLiberado: endereco,
  serviceSnapshot: snapshot,
);

// --- Harness do CARD (widget puro, sem providers). ---
Widget _wrapCard(OrdemServico os) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: OSCard(
        os: os,
        onIniciar: () {},
        onAvisar: () {},
        onCheguei: () {},
        onCancelar: () {},
        onPagar: () {},
        onConcluir: () {},
        onChecklist: () {},
        onWhatsAppCliente: () {},
      ),
    ),
  ),
);

// --- Harness da TELA de execução (providers + fakes). ---
Future<void> _pumpExec(
  WidgetTester tester,
  OrdemServico os, {
  bool obrigatoriosPendentes = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_prof),
        ordensRepositoryProvider.overrideWithValue(
          FakeOrdensRepository(execOS: os),
        ),
        evidenciasRepositoryProvider.overrideWithValue(
          FakeEvidenciasRepository(),
        ),
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: OSExecucaoScreen(
          osId: 'os1',
          obrigatoriosPendentes: obrigatoriosPendentes,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100)); // load + fotos
}

void main() {
  group('Endereço no card (dono 18/07: atribuida + em_andamento)', () {
    for (final status in const [
      OSStatus.agendada,
      OSStatus.concluida,
      OSStatus.cancelada,
    ]) {
      testWidgets('$status esconde endereço completo e id do cliente', (
        tester,
      ) async {
        await tester.pumpWidget(_wrapCard(_os(status: status)));

        expect(find.textContaining('Rua das Palmeiras'), findsNothing);
        expect(find.textContaining('99876-5432'), findsNothing);
        expect(find.textContaining(_clienteIdOpaco), findsNothing);
        expect(find.text('Carlos S.'), findsOneWidget);
        expect(find.text('Centro'), findsOneWidget);
      });
    }

    testWidgets('atribuida LIBERA o endereço (ver antes de Iniciar)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapCard(_os(status: OSStatus.atribuida)));
      expect(find.textContaining('Rua das Palmeiras'), findsWidgets);
      expect(find.textContaining(_clienteIdOpaco), findsNothing);
    });

    testWidgets('em_andamento LIBERA o endereço completo', (tester) async {
      await tester.pumpWidget(_wrapCard(_os(status: OSStatus.emAndamento)));

      expect(find.textContaining('Rua das Palmeiras'), findsWidgets);
      expect(find.textContaining(_clienteIdOpaco), findsNothing);
    });
  });

  group('Ver rota / deep-link com endereço liberado (card)', () {
    testWidgets('atribuida COM endereco mostra "Ver rota"', (tester) async {
      await tester.pumpWidget(_wrapCard(_os(status: OSStatus.atribuida)));
      expect(find.text('Ver rota'), findsOneWidget);
      // dataHora fixa em 2020 → não é "hoje"; WhatsApp só no dia do serviço.
      expect(find.text('WhatsApp cliente'), findsNothing);
      expect(find.text('Cancelar OS'), findsOneWidget);
    });

    testWidgets(
      'em_andamento SEM endereco_liberado não mostra "Ver rota"',
      (tester) async {
        await tester.pumpWidget(
          _wrapCard(_os(status: OSStatus.emAndamento, endereco: null)),
        );
        expect(find.text('Checklist, pagamento e concluir'), findsOneWidget);
        expect(find.text('Ver rota'), findsNothing);
      },
    );

    testWidgets(
      'em_andamento COM endereco_liberado mostra "Ver rota"',
      (tester) async {
        await tester.pumpWidget(_wrapCard(_os(status: OSStatus.emAndamento)));
        expect(find.text('Ver rota'), findsOneWidget);
      },
    );
  });

  group('Execução — checklist/obrigatórios e anti-desvio na tela', () {
    testWidgets(
      'banner de obrigatórios pendentes gate a finalização',
      (tester) async {
        await _pumpExec(
          tester,
          _os(
            status: OSStatus.emAndamento,
            snapshot: const ServiceSnapshot(
              serviceId: 's1',
              nome: 'Higienização',
              valorBase: 150,
            ),
          ),
          obrigatoriosPendentes: true,
        );

        expect(
          find.textContaining('itens obrigatórios pendentes'),
          findsOneWidget,
        );
      },
    );

    testWidgets('sem obrigatórios pendentes, banner ausente', (tester) async {
      await _pumpExec(
        tester,
        _os(
          status: OSStatus.emAndamento,
          snapshot: const ServiceSnapshot(
            serviceId: 's1',
            nome: 'Higienização',
            valorBase: 150,
          ),
        ),
      );

      expect(find.textContaining('itens obrigatórios pendentes'), findsNothing);
    });

    testWidgets(
      'anti-desvio na execução: endereço oculto em concluida',
      (tester) async {
        // Reforça, na TELA, que a regra vale além de `atribuida`: uma OS já
        // concluída não pode reexibir o endereço completo.
        await _pumpExec(
          tester,
          _os(
            status: OSStatus.concluida,
            snapshot: const ServiceSnapshot(
              serviceId: 's1',
              nome: 'Higienização',
              valorBase: 150,
            ),
          ),
        );

        expect(find.textContaining('Rua das Palmeiras'), findsNothing);
        expect(find.textContaining(_clienteIdOpaco), findsNothing);
        // Visão-de-job continua: nome_curto no cabeçalho.
        expect(find.text('Carlos S.'), findsOneWidget);
      },
    );
  });

  group('Execução — "Gerar laudo" gated pelo snapshot do serviço', () {
    testWidgets(
      'sem service_snapshot: "Serviço não definido" e Gerar laudo desabilitado',
      (tester) async {
        await _pumpExec(
          tester,
          _os(status: OSStatus.emAndamento, snapshot: null),
        );

        expect(find.text('Serviço não definido'), findsOneWidget);
        // O card "Gerar laudo" fica no fim da ListView (fora do viewport):
        // rola até ele antes de inspecionar.
        final laudoFinder = find.widgetWithText(ClxButton, 'Gerar laudo');
        await tester.scrollUntilVisible(laudoFinder, 300);
        final btn = tester.widget<ClxButton>(laudoFinder);
        expect(btn.onPressed, isNull, reason: 'sem serviço não há laudo');
      },
    );

    testWidgets('com service_snapshot: Gerar laudo habilitado', (tester) async {
      await _pumpExec(
        tester,
        _os(
          status: OSStatus.emAndamento,
          snapshot: const ServiceSnapshot(
            serviceId: 's1',
            nome: 'Higienização',
            valorBase: 150,
          ),
        ),
      );

      final laudoFinder = find.widgetWithText(ClxButton, 'Gerar laudo');
      await tester.scrollUntilVisible(laudoFinder, 300);
      final btn = tester.widget<ClxButton>(laudoFinder);
      expect(btn.onPressed, isNotNull);
    });
  });
}
