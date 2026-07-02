/// os_execucao_admin_test.dart — Execução admin renderiza os widgets
/// compartilhados de `lib/shared_widgets_os/` e permite enviar o relatório.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/os_execucao_admin/os_execucao_admin_screen.dart';
import 'package:cleanos/shared_widgets_os/shared_widgets_os.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

OrdemServico _osComExecucao() => const OrdemServico(
  id: 'os123456',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  tipoServicoNome: 'Higienização de sofá',
  dataHora: '2026-07-01 13:00:00Z',
  status: OSStatus.emAndamento,
  valorServico: 200,
  serviceSnapshot: ServiceSnapshot(
    serviceId: 's1',
    nome: 'Higienização de sofá',
    valorBase: 200,
    tipoValor: TipoValor.fixo,
    capturedAt: '2026-07-01 12:00:00Z',
  ),
  checklistExec: [
    ChecklistExecItem(id: 'c1', titulo: 'Aspirar', obrigatorio: true),
    ChecklistExecItem(
      id: 'c2',
      titulo: 'Aplicar produto',
      status: ChecklistExecStatus.concluido,
    ),
  ],
);

void main() {
  group('OSExecucaoAdminScreen', () {
    testWidgets('renderiza os widgets compartilhados (snapshot + checklist)', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const OSExecucaoAdminScreen(osId: 'os123456'),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(
            FakeOrdens(one: _osComExecucao()),
          ),
          painelEvidenciasRepositoryProvider.overrideWithValue(
            FakeEvidencias(),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      // Widgets compartilhados consumidos pela visão admin.
      expect(find.byType(SnapshotResumo), findsOneWidget);
      expect(find.byType(ChecklistExecucao), findsOneWidget);
      expect(find.byType(EvidenciasSection), findsOneWidget);
      // Título no AppBar.
      expect(find.textContaining('Execução'), findsWidgets);
      // Resumo financeiro (abaixo da dobra — rola até ele).
      await tester.scrollUntilVisible(
        find.text('Resumo financeiro'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Resumo financeiro'), findsOneWidget);
    });

    testWidgets('enviar relatório chama a rota de WhatsApp', (tester) async {
      final whats = FakeWhatsApp();
      await pumpPainel(
        tester,
        const OSExecucaoAdminScreen(osId: 'os123456'),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(
            FakeOrdens(one: _osComExecucao()),
          ),
          painelEvidenciasRepositoryProvider.overrideWithValue(
            FakeEvidencias(),
          ),
          painelWhatsappRepositoryProvider.overrideWithValue(whats),
        ],
      );
      await tester.pump();
      await tester.pump();

      final btn = find.widgetWithText(ClxButton, 'Enviar ao cliente');
      await tester.scrollUntilVisible(
        btn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pump();
      await tester.pump();

      expect(whats.enviarCount, 1);
    });
  });
}
