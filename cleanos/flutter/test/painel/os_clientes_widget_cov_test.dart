/// os_clientes_widget_cov_test.dart — Cobertura de widget COMPLEMENTAR de Ordens
/// de Serviço + Clientes (pane 3/5 do fan-out de testes).
///
/// Foca no que o E2E exercita e que ainda NÃO tinha teste de widget dedicado:
///   • OS — filtro cascata Categoria → Grupo → Serviço (recurso central, c085437):
///     o encadeamento do filtro e o preenchimento de valor/snapshot ao escolher
///     o serviço.
///   • OS — validação por-campo (cliente/data/valor juntos) + submit válido que
///     chama o repo com o payload certo (servico/valor/status).
///   • CLIENTES — autofill por ViaCEP (mock via `http.runWithClient` + `MockClient`,
///     SEM rede real): CEP válido preenche endereço; `erro:true` avisa sem quebrar;
///     CEP curto não dispara consulta.
///   • CLIENTES — validação dos obrigatórios adjacentes (telefone/e-mail) não
///     coberta em `clientes_screen_test.dart`.
///
/// Determinístico e sem rede. NÃO duplica os testes já existentes de
/// `os_form_slots_test.dart` (seletor de slot), `os_form_hora_layout_test.dart`
/// (layout do dropdown de Hora), `ordens_screen_test.dart` (fluxo completo pela
/// tela) nem `clientes_screen_test.dart` (lista + nome/bairro obrigatórios).
library;

import 'dart:convert';

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/clientes/cliente_form.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

/// OS mínima só p/ dar um `seed.first` ao `FakeOrdens.create` (o retorno não é
/// inspecionado nestes testes — o que importa é o payload passado ao create).
OrdemServico fakeOS(String id) => OrdemServico(
  id: id,
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  tipoServicoNome: 'Higienização',
  dataHora: '2026-07-10 13:00:00Z',
  status: OSStatus.agendada,
  valorServico: 200,
);

/* ─────────────────────── OS: catálogo de teste ─────────────────────── */

/// Catálogo com 2 categorias × grupos distintos, p/ provar o encadeamento do
/// filtro cascata (cada nível estreita o próximo).
List<ServicoPB> _catalogoCascata() => const [
  ServicoPB(
    id: 's1',
    nome: 'Lavagem Simples',
    categoria: Categoria.veicular,
    grupo: Grupo.plano,
    valorBase: 100,
  ),
  ServicoPB(
    id: 's2',
    nome: 'Enceramento',
    categoria: Categoria.veicular,
    grupo: Grupo.avulsos,
    valorBase: 80,
  ),
  ServicoPB(
    id: 's3',
    nome: 'Higienização Sofá',
    categoria: Categoria.residencial,
    grupo: Grupo.sofa,
    valorBase: 200,
  ),
  ServicoPB(
    id: 's4',
    nome: 'Higienização Colchão',
    categoria: Categoria.residencial,
    grupo: Grupo.colchao,
    valorBase: 150,
  ),
];

List<Override> _osOverrides({
  required FakeOrdens ordens,
  required List<ServicoPB> servicos,
  FakeClientes? clientes,
}) => [
  ...painelOverrides(user: painelUser()),
  ordensRepositoryProvider.overrideWithValue(ordens),
  clientesRepositoryProvider.overrideWithValue(clientes ?? FakeClientes()),
  servicosRepositoryProvider.overrideWithValue(FakeServicos(ativos: servicos)),
  usuariosRepositoryProvider.overrideWithValue(
    FakeUsuarios(
      profissionais: const [
        User(id: 'p1', name: 'Pedro', role: Role.profissional),
      ],
    ),
  ),
];

/// Sobe o [OSForm] isolado e deixa os lookups (serviços/profissionais)
/// assentarem. Sem profissional selecionado não há timers de slot pendentes,
/// então `pumpAndSettle` é seguro.
Future<void> _pumpOSForm(WidgetTester tester, List<Override> overrides) async {
  await pumpPainel(tester, const OSForm(), overrides: overrides);
  await tester.pumpAndSettle();
}

/// Abre um [DropdownButtonFormField] pela sua key e escolhe o item [texto].
Future<void> _escolherNoDropdown(
  WidgetTester tester,
  Key key,
  String texto,
) async {
  await _escolherNoDropdownPor(tester, find.byKey(key), texto);
}

/// Dropdown cuja `ValueKey<String>` começa por [prefixo] (o campo de Categoria
/// embute a categoria atual na key — ex.: `os-cat-residencial` depois que o
/// serviço selecionado auto-preenche o filtro).
Finder _dropdownComPrefixo(String prefixo) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith(prefixo),
);

/// Abre o dropdown apontado por [finder] e escolhe o item [texto].
Future<void> _escolherNoDropdownPor(
  WidgetTester tester,
  Finder finder,
  String texto,
) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(texto).last);
  await tester.pumpAndSettle();
}

/// Abre o dropdown pela key, roda [inspecionar] com o menu ABERTO e o fecha
/// (tap fora) sem selecionar nada.
Future<void> _inspecionarDropdown(
  WidgetTester tester,
  Key key,
  void Function() inspecionar,
) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  inspecionar();
  // Fecha o menu com a tecla ESC (não seleciona item).
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

/* ────────────────────── Clientes: helpers de form ────────────────────── */

/// Índice dos `TextField` do [ClienteForm] (ordem de build):
/// 0 nome · 1 telefone · 2 e-mail · 3 CEP · 4 rua · 5 complemento · 6 bairro ·
/// 7 cidade · 8 estado · 9 observações.
Finder _clienteFieldAt(int i) => find
    .descendant(of: find.byType(ClienteForm), matching: find.byType(TextField))
    .at(i);

Future<void> _pumpClienteForm(
  WidgetTester tester, {
  FakeClientes? repo,
}) async {
  await pumpPainel(
    tester,
    const ClienteForm(),
    overrides: [
      ...painelOverrides(user: painelUser()),
      clientesRepositoryProvider.overrideWithValue(repo ?? FakeClientes()),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  /* ══════════════════ 1. OS — cascata Categoria→Grupo→Serviço ══════════════════ */

  group('OSForm — cascata Categoria → Grupo → Serviço', () {
    testWidgets('escolher Categoria estreita os Grupos elegíveis', (
      tester,
    ) async {
      await _pumpOSForm(
        tester,
        _osOverrides(
          ordens: FakeOrdens(seed: [fakeOS('a')]),
          servicos: _catalogoCascata(),
        ),
      );

      // Sem filtro: todos os grupos do catálogo aparecem no dropdown de Grupo.
      await _inspecionarDropdown(
        tester,
        const ValueKey('os-grupo-'),
        () {
          expect(find.text('Plano'), findsWidgets);
          expect(find.text('Avulsos'), findsWidgets);
          expect(find.text('Sofá'), findsWidgets);
          expect(find.text('Colchão'), findsWidgets);
        },
      );

      // Escolhe a categoria Veicular.
      await _escolherNoDropdown(
        tester,
        const ValueKey('os-cat-'),
        'Veicular',
      );

      // Agora só os grupos de serviços Veicular sobram (Plano/Avulsos);
      // Sofá/Colchão (Residencial) somem.
      await _inspecionarDropdown(
        tester,
        const ValueKey('os-grupo-'),
        () {
          expect(find.text('Plano'), findsWidgets);
          expect(find.text('Avulsos'), findsWidgets);
          expect(find.text('Sofá'), findsNothing);
          expect(find.text('Colchão'), findsNothing);
        },
      );
    });

    testWidgets(
      'Categoria→Grupo estreita os Serviços; escolher Serviço preenche valor/snapshot',
      (tester) async {
        await _pumpOSForm(
          tester,
          _osOverrides(
            ordens: FakeOrdens(seed: [fakeOS('a')]),
            servicos: _catalogoCascata(),
          ),
        );

        await _escolherNoDropdown(
          tester,
          const ValueKey('os-cat-'),
          'Veicular',
        );
        await _escolherNoDropdown(
          tester,
          const ValueKey('os-grupo-'),
          'Plano',
        );

        // Só o serviço Veicular/Plano ('Lavagem Simples') sobra no dropdown de
        // Serviço; os demais (Enceramento/Higienizações) somem.
        await _inspecionarDropdown(
          tester,
          const ValueKey('os-servico-'),
          () {
            expect(find.text('Lavagem Simples'), findsWidgets);
            expect(find.text('Enceramento'), findsNothing);
            expect(find.text('Higienização Sofá'), findsNothing);
            expect(find.text('Higienização Colchão'), findsNothing);
          },
        );

        // Escolhe o serviço → preenche o snapshot (nome) e o valor base.
        await _escolherNoDropdown(
          tester,
          const ValueKey('os-servico-'),
          'Lavagem Simples',
        );

        expect(find.text('Lavagem Simples'), findsWidgets); // dropdown + snapshot
        expect(find.text('100'), findsOneWidget); // valor base prefilled
      },
    );

    testWidgets('trocar a Categoria limpa um Serviço incompatível', (
      tester,
    ) async {
      await _pumpOSForm(
        tester,
        _osOverrides(
          ordens: FakeOrdens(seed: [fakeOS('a')]),
          servicos: _catalogoCascata(),
        ),
      );

      // Seleciona um serviço Residencial diretamente (sem filtro).
      await _escolherNoDropdown(
        tester,
        const ValueKey('os-servico-'),
        'Higienização Sofá',
      );
      expect(find.text('200'), findsOneWidget); // valor do serviço escolhido

      // Troca a categoria para Veicular → o serviço Residencial não pertence
      // mais e é limpo (o snapshot editável do nome permanece — free-text —,
      // mas 'Higienização Sofá' sai da LISTA de opções do dropdown de Serviço).
      // A key da Categoria embute a categoria atual (o serviço escolhido
      // auto-preencheu o filtro), então casa-se pelo prefixo `os-cat-`.
      await _escolherNoDropdownPor(
        tester,
        _dropdownComPrefixo('os-cat-'),
        'Veicular',
      );
      // Com o dropdown de Serviço aberto, 'Higienização Sofá' não pode aparecer
      // como OPÇÃO (Text no menu). O campo snapshot que ainda o retém é um
      // EditableText — por isso o finder ignora EditableText.
      await _inspecionarDropdown(
        tester,
        const ValueKey('os-servico-'),
        () => expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data == 'Higienização Sofá',
          ),
          findsNothing,
        ),
      );
    });
  });

  /* ══════════════════════ 2. OS — validação + submit ══════════════════════ */

  group('OSForm — validação e criação', () {
    testWidgets('submeter vazio mostra erros por-campo e não cria', (
      tester,
    ) async {
      final ordens = FakeOrdens(seed: [fakeOS('a')]);
      await _pumpOSForm(
        tester,
        _osOverrides(ordens: ordens, servicos: _catalogoCascata()),
      );

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Selecione um cliente'), findsOneWidget);
      expect(find.text('Data é obrigatória'), findsOneWidget);
      expect(find.text('Informe o valor'), findsOneWidget);
      expect(ordens.createCount, 0);
    });

    testWidgets('tudo válido → create com payload (servico/valor/status)', (
      tester,
    ) async {
      final ordens = FakeOrdens(seed: [fakeOS('a')]);
      final clientes = FakeClientes(
        seed: [fakeCliente(id: 'c1', nome: 'Carlos', sobrenome: 'Silva')],
      );
      await _pumpOSForm(
        tester,
        _osOverrides(
          ordens: ordens,
          servicos: _catalogoCascata(),
          clientes: clientes,
        ),
      );

      // Cliente: busca no servidor (debounce) → seleciona.
      await tester.enterText(_osFieldAt(tester, 0), 'Car');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Carlos Silva').last);
      await tester.pumpAndSettle();

      // Serviço (prefila o valor base = 100). Sem categoria/grupo o dropdown já
      // lista todos os serviços.
      await _escolherNoDropdown(
        tester,
        const ValueKey('os-servico-'),
        'Lavagem Simples',
      );

      // Data: abre o date picker e confirma (hoje).
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(ordens.createCount, 1);
      final payload = ordens.lastCreate!;
      expect(payload['cliente'], 'c1');
      expect(payload['servico'], 's1');
      expect(payload['tipo_servico_nome'], 'Lavagem Simples');
      expect(payload['valor_servico'], 100);
      // Sem profissional → status Agendada e profissional nulo.
      expect(payload['profissional'], isNull);
      expect(payload['status'], OSStatus.agendada.wire);
    });
  });

  /* ══════════════════════ 3. Clientes — ViaCEP autofill ══════════════════════ */

  group('ClienteForm — autofill por CEP (ViaCEP, mock sem rede)', () {
    testWidgets('CEP válido preenche rua/bairro/cidade/UF', (tester) async {
      // Captura a requisição para asserção FORA do callback: um `expect` que
      // falhe dentro do MockClient viraria exceção engolida pelo `catch` do
      // form (autofill abortaria em silêncio, mascarando o teste).
      Uri? reqUrl;
      final mock = MockClient((req) async {
        reqUrl = req.url;
        return http.Response(
          jsonEncode({
            'logradouro': 'Praça da Sé',
            'bairro': 'Sé',
            'localidade': 'São Paulo',
            'uf': 'SP',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        await _pumpClienteForm(tester);
        await tester.enterText(_clienteFieldAt(3), '01001000');
        await tester.pumpAndSettle();

        // Valores escopados aos campos (EditableText): "São Paulo" também
        // aparece como sugestão de cidade fora do campo.
        // Valor de cada campo preenchido, casando pelo controller do próprio
        // EditableText (o texto "São Paulo" também aparece como sugestão fora
        // do campo, então um find.text global seria ambíguo).
        Finder fieldValue(String s) => find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == s,
        );
        expect(fieldValue('Praça da Sé'), findsOneWidget); // rua
        expect(fieldValue('Sé'), findsOneWidget); // bairro
        expect(fieldValue('São Paulo'), findsOneWidget); // cidade
        expect(fieldValue('SP'), findsOneWidget); // UF
      }, () => mock);

      // A consulta bateu no ViaCEP com o CEP informado.
      expect(reqUrl?.host, 'viacep.com.br');
      expect(reqUrl.toString(), contains('01001000'));
    });

    testWidgets('CEP inexistente (erro:true) avisa sem quebrar o form', (
      tester,
    ) async {
      final mock = MockClient(
        (req) async => http.Response(jsonEncode({'erro': true}), 200),
      );

      await http.runWithClient(() async {
        await _pumpClienteForm(tester);
        await tester.enterText(_clienteFieldAt(3), '00000000');
        await tester.pumpAndSettle();

        expect(find.text('CEP não encontrado.'), findsOneWidget);
        expect(find.byType(ClienteForm), findsOneWidget); // form intacto
      }, () => mock);
    });

    testWidgets('CEP incompleto não dispara consulta nem avisa', (
      tester,
    ) async {
      var chamou = false;
      final mock = MockClient((req) async {
        chamou = true;
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await _pumpClienteForm(tester);
        await tester.enterText(_clienteFieldAt(3), '123'); // < 8 dígitos
        await tester.pumpAndSettle();

        expect(chamou, isFalse);
        expect(find.text('CEP não encontrado.'), findsNothing);
        expect(find.byType(ClienteForm), findsOneWidget);
      }, () => mock);
    });
  });

  /* ══════════════════════ 4. Clientes — validação de campos ══════════════════════ */

  group('ClienteForm — validação de obrigatórios', () {
    testWidgets('telefone vazio → "Telefone é obrigatório"', (tester) async {
      final repo = FakeClientes();
      await _pumpClienteForm(tester, repo: repo);

      // Preenche nome + bairro; deixa o telefone vazio.
      await tester.enterText(_clienteFieldAt(0), 'Carlos Silva');
      await tester.enterText(_clienteFieldAt(6), 'Centro');
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Telefone é obrigatório'), findsOneWidget);
      expect(repo.createCount, 0);
    });

    testWidgets('telefone com poucos dígitos → "Telefone incompleto…"', (
      tester,
    ) async {
      final repo = FakeClientes();
      await _pumpClienteForm(tester, repo: repo);

      await tester.enterText(_clienteFieldAt(0), 'Carlos Silva');
      await tester.enterText(_clienteFieldAt(6), 'Centro');
      await tester.enterText(_clienteFieldAt(1), '85999'); // < 10 dígitos
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(
        find.text('Telefone incompleto — informe DDD + número'),
        findsOneWidget,
      );
      expect(repo.createCount, 0);
    });

    testWidgets('e-mail malformado → "E-mail inválido"', (tester) async {
      final repo = FakeClientes();
      await _pumpClienteForm(tester, repo: repo);

      // Obrigatórios válidos + e-mail inválido.
      await tester.enterText(_clienteFieldAt(0), 'Carlos Silva');
      await tester.enterText(_clienteFieldAt(1), '85999998888');
      await tester.enterText(_clienteFieldAt(6), 'Centro');
      await tester.enterText(_clienteFieldAt(2), 'nao-e-email');
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('E-mail inválido'), findsOneWidget);
      expect(repo.createCount, 0);
    });
  });
}

/// Índice dos `TextField` do [OSForm] (0 = busca de cliente, 1 = snapshot,
/// 2 = valor, 3 = observações).
Finder _osFieldAt(WidgetTester tester, int i) => find
    .descendant(of: find.byType(OSForm), matching: find.byType(TextField))
    .at(i);
