/// os_form_hora_layout_test.dart — Regressão do F-602.
///
/// Em telas estreitas (mobile) o par Data+Hora dividia a linha e a Hora ficava
/// com ~metade dela; os dois dropdowns (hora + minuto) não cabiam e o segundo
/// dígito era cortado — "10" virava "1". O fix empilha Data e Hora abaixo de
/// 640px (espelha o colapso do `.form-grid-2` do React) e dá largura suficiente
/// ao dropdown de minutos.
///
/// Este teste monta o form numa viewport de celular, seleciona um profissional
/// cuja janela cobre horas de 2 dígitos (10h–17h) e verifica que NENHUM texto
/// do seletor de hora é cortado (largura alocada ≥ largura intrínseca).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

class _FakeDispFiltrada implements DisponibilidadeRepository {
  _FakeDispFiltrada(this.seed);
  final List<Disponibilidade> seed;
  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async {
    final items = filter == null
        ? seed
        : seed.where((d) => filter.contains("'${d.profissional}'")).toList();
    return PageResult<Disponibilidade>(
      items: items,
      page: 1,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  Never _u() => throw UnimplementedError();
  @override
  Future<Disponibilidade> getOne(String id) => _u();
  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) => _u();
  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) => _u();
  @override
  Future<void> delete(String id) => _u();
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

/// Verdadeiro se algum `Text` que casa [label] está com o texto cortado por
/// falta de largura (largura alocada < largura mínima intrínseca).
bool _clipped(WidgetTester tester, String label) {
  final elements = find.text(label).evaluate();
  expect(elements, isNotEmpty, reason: 'esperava encontrar "$label"');
  for (final e in elements) {
    final ro = e.renderObject! as RenderParagraph;
    if (ro.size.width + 0.5 < ro.getMinIntrinsicWidth(double.infinity)) {
      return true;
    }
  }
  return false;
}

void main() {
  testWidgets(
    'F-602: em tela de celular os campos de hora/duração não são cortados',
    (tester) async {
      // Duração de 90min → o rótulo "1h30" é dos mais largos do seletor.
      final disp = _FakeDispFiltrada([
        fakeDisponibilidade(
          id: 'd1',
          profissional: 'p1',
          inicio: '10:00',
          fim: '18:00',
          duracaoMin: 90,
        ),
      ]);
      await pumpPainel(
        tester,
        const OSForm(),
        // Viewport de celular MUITO estreita (< 640): Data e Hora empilham e o
        // seletor de hora ocupa a linha inteira. Uso 360px (o cenário real do
        // finding); o overflow PRÉ-EXISTENTE do rodapé de botões que antes
        // obrigava a subir p/ 400px foi corrigido no F-603 (rodapé vira Wrap),
        // então o form inteiro fica limpo a 360px.
        size: const Size(360, 820),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(FakeOrdens()),
          clientesRepositoryProvider.overrideWithValue(FakeClientes()),
          servicosRepositoryProvider.overrideWithValue(FakeServicos()),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuarios(
              profissionais: const [
                User(id: 'p1', name: 'Pedro', role: Role.profissional),
              ],
            ),
          ),
          disponibilidadeRepositoryProvider.overrideWithValue(disp),
        ],
      );
      await _settle(tester);

      // Escolhe hoje e o profissional → a Duração é prefilada com a dele (1h30).
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('os-profissional')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedro').last);
      await _settle(tester);

      // Hora virou entrada livre 'HH:MM' (o dropdown de slots foi aposentado).
      // Num TextField o texto rola em vez de "cortar", então o que importa é o
      // campo ter largura suficiente para 'HH:MM' — e o rótulo da duração
      // (o mais largo: "1h30") não ser cortado.
      await tester.enterText(
        find.byKey(const ValueKey('os-hora-input')),
        '10:30',
      );
      await tester.pump();

      final hora = tester.getRect(find.byKey(const ValueKey('os-hora-input')));
      expect(hora.width, greaterThan(88), reason: 'campo de hora espremido');
      expect(_clipped(tester, '1h30'), isFalse, reason: 'duração cortada');

      // Sem overflow de layout (RenderFlex) na tela.
      expect(tester.takeException(), isNull);
    },
  );
}
