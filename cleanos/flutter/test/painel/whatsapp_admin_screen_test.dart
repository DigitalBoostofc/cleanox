/// whatsapp_admin_screen_test.dart — Seção WhatsApp do Painel (Onda 5):
/// status conectado × desconectado (com QR), salvar templates (incl. os 3 de
/// rastreamento do doc 09) e guard admin-only.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/repositories/whatsapp_repository.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/data/whatsapp_config_repository.dart';
import 'package:cleanos/painel/whatsapp/whatsapp_admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda5.dart';
import 'painel_test_helpers.dart';

/// PNG 1×1 válido (base64) — o backend entrega o QR como base64; a tela decodifica.
const String _kQrPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  group('WhatsAppAdminScreen', () {
    testWidgets('conectado: mostra "Conectado" e botão desconectar, sem QR', (
      tester,
    ) async {
      final conn = FakeWhatsAppConn(
        initial: const WhatsAppStatus(connected: true),
      );
      await pumpPainel(
        tester,
        const WhatsAppAdminScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          painelWhatsappRepositoryProvider.overrideWithValue(conn),
          whatsappConfigRepositoryProvider.overrideWithValue(
            FakeWhatsAppConfig(),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Conectado'), findsOneWidget);
      expect(find.text('Desconectar'), findsOneWidget);
      expect(find.text('Escaneie o QR code'), findsNothing);
    });

    testWidgets('desconectado → conectar exibe o QR code', (tester) async {
      final conn = FakeWhatsAppConn(
        initial: const WhatsAppStatus(connected: false),
        connectResult: const WhatsAppStatus(connected: false, qr: _kQrPng),
      );
      await pumpPainel(
        tester,
        const WhatsAppAdminScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          painelWhatsappRepositoryProvider.overrideWithValue(conn),
          whatsappConfigRepositoryProvider.overrideWithValue(
            FakeWhatsAppConfig(),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      // Estado inicial: desconectado, com botão de conectar.
      expect(find.text('Desconectado'), findsOneWidget);
      expect(find.text('Conectar WhatsApp'), findsOneWidget);

      await tester.tap(find.text('Conectar WhatsApp'));
      await tester.pump(); // dispara connect()
      await tester.pump(); // resolve o Future

      expect(conn.connectCount, 1);
      expect(find.text('Escaneie o QR code'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Simula o cliente escaneando: o polling detecta e para (encerra o timer).
      conn.setStatus(const WhatsAppStatus(connected: true));
      await tester.pump(const Duration(seconds: 3)); // dispara o polling
      await tester.pump(); // resolve o refreshStatus

      expect(find.text('Conectado'), findsOneWidget);
      expect(find.text('Escaneie o QR code'), findsNothing);
    });

    testWidgets('templates: carrega e salva (incl. os de rastreamento)', (
      tester,
    ) async {
      final config = FakeWhatsAppConfig(
        seed: const WhatsAppTemplates(
          avisoTemplate: 'Estou a caminho!',
          aviso5minTexto: 'Chego em 5',
          aviso1minTexto: 'Chego em 1',
          avisoChegueiTexto: 'Cheguei!',
        ),
      );
      await pumpPainel(
        tester,
        const WhatsAppAdminScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          painelWhatsappRepositoryProvider.overrideWithValue(
            FakeWhatsAppConn(initial: const WhatsAppStatus(connected: true)),
          ),
          whatsappConfigRepositoryProvider.overrideWithValue(config),
        ],
      );
      await tester.pump();
      await tester.pump();

      // Os campos de rastreamento (doc 09) renderizam com os valores carregados.
      expect(find.widgetWithText(TextField, 'Chego em 5'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Chego em 1'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cheguei!'), findsOneWidget);

      // Edita o template de "chega em ~5 min" e salva.
      await tester.enterText(
        find.widgetWithText(TextField, 'Chego em 5'),
        'Chego em ~5 minutos, {nome}!',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(config.saveCount, 1);
      expect(config.lastSaved?.aviso5minTexto, 'Chego em ~5 minutos, {nome}!');
      // Os demais templates de rastreamento seguem no payload.
      expect(config.lastSaved?.aviso1minTexto, 'Chego em 1');
      expect(config.lastSaved?.avisoChegueiTexto, 'Cheguei!');
      expect(find.text('Mensagens salvas com sucesso!'), findsOneWidget);
    });

    testWidgets('guard: gerente vê "Acesso restrito", não o painel', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const WhatsAppAdminScreen(),
        overrides: [...painelOverrides(user: painelUser(role: Role.gerente))],
      );
      await tester.pump();

      expect(find.text('Acesso restrito'), findsOneWidget);
      expect(find.text('WhatsApp da empresa'), findsNothing);
      expect(find.text('Mensagens automáticas'), findsNothing);
    });
  });
}
