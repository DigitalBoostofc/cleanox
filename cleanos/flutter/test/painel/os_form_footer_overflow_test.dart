/// os_form_footer_overflow_test.dart — Regressão do F-603.
///
/// O rodapé de ações do form de OS (Cancelar / Salvar) era um
/// `Row(mainAxisAlignment: end)` com os dois botões de largura intrínseca. Em
/// telas muito estreitas (≤ ~366px de largura útil — aparelhos pequenos ou
/// split-screen) o par não cabia numa linha e a `Row` estourava ~5,5px
/// (`RenderFlex overflowed`). O fix troca a `Row` por um `Wrap` (alinhado à
/// direita): em largura comum os botões seguem lado a lado; em tela estreita o
/// "Salvar" desce para uma segunda linha — rótulos preservados, sem overflow.
///
/// Este teste monta o form numa viewport de celular muito estreita (340px) e
/// verifica que NÃO há exceção de layout (`RenderFlex overflowed`) e que os dois
/// rótulos continuam presentes e inteiros (não cortados). É NÃO-tautológico:
/// revertendo o `Wrap` para a `Row` original o teste falha com overflow.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

/// Disponibilidade vazia → form entra no modo livre, estado de dados normal
/// (sem spinner/erro), com o rodapé de ações renderizado.
class _FakeDispVazia implements DisponibilidadeRepository {
  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async => const PageResult<Disponibilidade>(
    items: [],
    page: 1,
    perPage: 30,
    totalItems: 0,
    totalPages: 1,
  );

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

/// Verdadeiro se o `Text` [label] está com o texto cortado por falta de largura
/// (largura alocada < largura mínima intrínseca) — mesmo critério do teste do
/// F-602.
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
    'F-603: rodapé Cancelar/Salvar não estoura em tela estreita',
    (tester) async {
      await pumpPainel(
        tester,
        const OSForm(),
        // Viewport muito estreita (< ~366px úteis) onde a Row original estourava.
        size: const Size(340, 820),
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
          disponibilidadeRepositoryProvider.overrideWithValue(_FakeDispVazia()),
        ],
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      // Os dois botões de ação do rodapé estão presentes...
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);

      // ...com os rótulos inteiros (sem elipse/corte)...
      expect(_clipped(tester, 'Cancelar'), isFalse, reason: '"Cancelar" cortado');
      expect(_clipped(tester, 'Salvar'), isFalse, reason: '"Salvar" cortado');

      // ...e SEM overflow de layout (RenderFlex) em nenhum ponto da tela.
      expect(tester.takeException(), isNull);
    },
  );
}
