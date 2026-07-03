/// clientes_busca_test.dart — F-601: busca de Clientes com termo composto.
///
/// A busca de clientes é SERVER-SIDE (o controller passa `clienteSearchFilter`
/// como `filter` ao repositório, que repassa ao PocketBase — ver
/// `pb_clientes_repository.dart`). O bug: um termo com espaço ("QA Teste") que
/// atravessa a fronteira nome↔sobrenome retornava "Nenhum cliente encontrado",
/// enquanto "Silva" (1 palavra) achava o mesmo cliente.
///
/// Este teste prova a regressão em duas frentes, sem tocar a rede:
///  1) FILTRO GERADO — determinístico: o termo composto vira AND por token
///     (cada palavra casa em algum campo), não um único literal com a string
///     inteira (que era a causa raiz).
///  2) SEMÂNTICA ponta-a-ponta — um fake de `ClientesRepository` que APLICA o
///     filtro com as regras do PocketBase (`~` = contém, case-insensitive),
///     provando que o filtro ANTIGO falha e o NOVO acha "QA Teste Silva".
library;

import 'package:cleanos/core/models/cliente.dart';
import 'package:cleanos/core/repositories/clientes_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/painel_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Como o painel divide "QA Teste Silva": primeira palavra → nome, resto →
/// sobrenome. Assim o termo "QA Teste" NÃO cabe inteiro em nenhum campo isolado.
Cliente _cli({
  required String id,
  required String nome,
  String? sobrenome,
  String telefone = '',
  String bairro = '',
  String? cidade,
}) => Cliente(
  id: id,
  nome: nome,
  sobrenome: sobrenome,
  telefone: telefone,
  enderecoBairro: bairro,
  enderecoCidade: cidade,
);

/// Avalia um filtro no formato que `clienteSearchFilter` emite, com a semântica
/// do PocketBase: grupos `(a || b || ...)` unidos por ` && `; cada átomo
/// `campo ~ 'literal'` = "campo CONTÉM literal" (case-insensitive, como o `~`).
/// Suporta também o formato ANTIGO (sem parênteses, um único grupo) — assim o
/// mesmo avaliador prova o ciclo vermelho→verde.
bool _matchesPbFilter(Cliente c, String filter) {
  String field(String name) => switch (name) {
    'nome' => c.nome,
    'sobrenome' => c.sobrenome ?? '',
    'telefone' => c.telefone,
    'endereco_bairro' => c.enderecoBairro,
    'endereco_cidade' => c.enderecoCidade ?? '',
    _ => '',
  };
  bool atom(String raw) {
    final a = raw.trim();
    final i = a.indexOf(' ~ ');
    if (i < 0) throw ArgumentError('átomo inesperado: $a');
    final name = a.substring(0, i).trim();
    final rest = a.substring(i + 3).trim();
    final raw2 = rest.substring(rest.indexOf("'") + 1, rest.lastIndexOf("'"));
    // Inverso do pbStringLiteral: desfaz o escaping `\'` → `'` antes do contains,
    // senão um nome com apóstrofe (ex.: O'Brien) daria falso-negativo.
    final lit = raw2.replaceAll("\\'", "'");
    return field(name).toLowerCase().contains(lit.toLowerCase());
  }
  // AND por grupos, OR dentro do grupo.
  return filter.split(' && ').every((group) {
    final g = group.trim().replaceAll(RegExp(r'^\(|\)$'), '');
    return g.split(' || ').any(atom);
  });
}

/// Fake que APLICA o filtro server-side (diferente do `FakeClientes` de página
/// fixa): reproduz o que o PocketBase faria com a string de filtro.
class FilteringClientesRepo implements ClientesRepository {
  FilteringClientesRepo(this.all);
  final List<Cliente> all;

  @override
  Future<PageResult<Cliente>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome,sobrenome',
  }) async {
    final items = filter == null
        ? all
        : all.where((c) => _matchesPbFilter(c, filter)).toList();
    return PageResult<Cliente>(
      items: items,
      page: 1,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<Cliente> getOne(String id) async => all.firstWhere((c) => c.id == id);
  @override
  Future<Cliente> create(Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<Cliente> update(String id, Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<void> delete(String id) async {}
}

/// Reprodução do filtro ANTIGO (bugado): um único literal com o termo inteiro.
/// Usado só para provar que o bug existia (ciclo vermelho).
String? _filtroAntigo(String query) {
  final q = query.trim();
  if (q.isEmpty) return null;
  final lit = pbStringLiteral(q);
  return 'nome ~ $lit || sobrenome ~ $lit || telefone ~ $lit '
      '|| endereco_bairro ~ $lit || endereco_cidade ~ $lit';
}

void main() {
  group('clienteSearchFilter — filtro gerado (F-601)', () {
    test('termo composto vira AND por token (não um literal único)', () {
      final f = clienteSearchFilter('QA Teste')!;
      // Duas palavras → dois grupos unidos por &&.
      expect(f.contains(' && '), isTrue);
      // Cada palavra aparece como literal próprio…
      expect(f.contains("nome ~ 'QA'"), isTrue);
      expect(f.contains("sobrenome ~ 'Teste'"), isTrue);
      // …e NUNCA a string inteira com espaço (a causa raiz do bug).
      expect(f.contains("'QA Teste'"), isFalse);
    });

    test('termo de 1 palavra → grupo único, sem &&', () {
      final f = clienteSearchFilter('Silva')!;
      expect(f.contains("nome ~ 'Silva'"), isTrue);
      expect(f.contains(' && '), isFalse);
      expect(f.contains('||'), isTrue);
    });

    test('espaços extras/nas pontas não geram tokens vazios', () {
      final f = clienteSearchFilter('  QA   Teste  ')!;
      expect(f.contains("nome ~ 'QA'"), isTrue);
      expect(f.contains("nome ~ 'Teste'"), isTrue);
      expect(f.contains("~ ''"), isFalse);
    });

    test('vazio → null (lista tudo)', () {
      expect(clienteSearchFilter(''), isNull);
      expect(clienteSearchFilter('   '), isNull);
    });

    test('escapa aspas (anti-injeção) por token', () {
      final f = clienteSearchFilter("O'Brien")!;
      expect(f.contains(r"nome ~ 'O\'Brien'"), isTrue);
    });
  });

  group('busca server-side (fake aplica o filtro como o PocketBase)', () {
    // "QA Teste Silva" dividido: nome="QA", sobrenome="Teste Silva".
    // A string "QA Teste" NÃO cabe inteira em nenhum campo isolado.
    final repo = FilteringClientesRepo([
      _cli(id: 'qa', nome: 'QA', sobrenome: 'Teste Silva'),
      _cli(id: 'ana', nome: 'Ana', sobrenome: 'Souza'),
      _cli(id: 'ob', nome: "O'Brien"),
    ]);

    Future<List<String>> buscar(String termo) async {
      final res = await repo.list(filter: clienteSearchFilter(termo));
      return res.items.map((c) => c.id).toList();
    }

    test('1 palavra ("Silva") acha o cliente', () async {
      expect(await buscar('Silva'), ['qa']);
    });

    test('2 palavras ("QA Teste") acham "QA Teste Silva" (regressão F-601)', () async {
      expect(await buscar('QA Teste'), ['qa']);
    });

    test('termo que não casa não acha ninguém', () async {
      expect(await buscar('Zzz Inexistente'), isEmpty);
    });

    test('nome com apóstrofe ("O\'Brien") é encontrado (aspa escapada)', () async {
      // Prova que o filtro de produção lida com apóstrofe (binding seguro) e que
      // o avaliador do teste desfaz o escaping `\'` → `'` antes de casar.
      expect(await buscar("O'Brien"), ['ob']);
    });

    test('vermelho: o filtro ANTIGO NÃO achava o termo composto', () async {
      // Prova que o bug existia: com a montagem antiga, "QA Teste" some.
      final res = await repo.list(filter: _filtroAntigo('QA Teste'));
      expect(res.items, isEmpty);
      // …enquanto "Silva" (1 palavra) achava — exatamente o sintoma do F-601.
      final res1 = await repo.list(filter: _filtroAntigo('Silva'));
      expect(res1.items.map((c) => c.id), ['qa']);
    });
  });
}
