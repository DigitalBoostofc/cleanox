# SDK Dart `pocketbase` ^0.22 no CleanOS

Como o app `cleanos/flutter` fala com o backend. Padrões reais do repo — copie a
forma, não invente.

## Índice
- [Client + AuthStore](#client--authstore)
- [Login e refresh](#login-e-refresh)
- [Repository: o padrão](#repository-o-padrão)
- [Listagem paginada e `pb.filter`](#listagem-paginada-e-pbfilter)
- [Expand e anti-desvio](#expand-e-anti-desvio)
- [Realtime subscribe](#realtime-subscribe)
- [Arquivos protegidos (file token)](#arquivos-protegidos-file-token)
- [Upload multipart + idempotência](#upload-multipart--idempotência)
- [Rotas custom via `pb.send`](#rotas-custom-via-pbsend)
- [Erros: `ClientException`](#erros-clientexception)
- [Checklist ao mexer nas camadas de dados](#checklist-ao-mexer-nas-camadas-de-dados)

## Client + AuthStore

Um único `PocketBase` por app, criado em `core/pb/pb_client.dart`. O token vai
para **secure storage** (`flutter_secure_storage`) via `AsyncAuthStore` — nunca
`SharedPreferences` (anti-pattern de segurança). `PbClient.init()` roda **uma
vez** no boot porque a leitura inicial do token é assíncrona.

```dart
final authStore = AsyncAuthStore(
  initial: await secure.read(key: kAuthStorageKey),
  save:  (data) async => secure.write(key: kAuthStorageKey, value: data),
  clear: () async => secure.delete(key: kAuthStorageKey),
);
final pb = PocketBase(Env.pbUrl, authStore: authStore);
```

Regras: leitura/escrita do storage é **best-effort** (try/catch — falha de disco
não derruba a sessão em memória). `Env.pbUrl` vem do `core/env`, nunca hardcode.

## Login e refresh

Autenticação sempre na coleção `users` (papel decide a rota depois):

```dart
await pb.collection(Collections.users).authWithPassword(email, password);
```

Refresh proativo no boot; token inválido/expirado → limpa a sessão (redirect ao
login). Espelha o `authRefresh().catch(clear)` do web:

```dart
if (pb.authStore.isValid) {
  try { await pb.collection(Collections.users).authRefresh(); }
  catch (_) { pb.authStore.clear(); }
}
```

## Repository: o padrão

Features dependem de uma **interface** (`abstract class …Repository`), nunca da
impl PB; a impl (`Pb…Repository`) é injetada por Riverpod. A interface é a
fronteira congelada — não muda sem PR revisado no core. Toda impl mapeia
`RecordModel` → tipo de domínio (`OrdemServico.fromRecord`), nunca vaza
`RecordModel` para a UI.

```dart
abstract class OrdensRepository {
  Future<PageResult<OrdemServico>> list({int page, int perPage, String? filter, String sort, String? expand});
  Future<OrdemServico> getExec(String osId);
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch);
  Stream<OrdemServicoEvent> subscribe({String topic, String? filter});
}

class PbOrdensRepository implements OrdensRepository {
  PbOrdensRepository(this._pb);
  final PocketBase _pb;
  RecordService get _col => _pb.collection(Collections.ordensServico);
  // ...
}
```

Nomes de coleção e enums vêm **sempre** de `core/models/collections.dart`
(`Collections.ordensServico`, `OSStatus.emAndamento.wire`). Nunca escreva a
string `'ordens_servico'` solta.

## Listagem paginada e `pb.filter`

**Em lista de UI use `getList(page, perPage, …)` — nunca `getFullList`.**
`getFullList` só é aceitável para conjuntos pequenos e fechados (ex.: as
evidências de uma única OS). Devolva um `PageResult` SDK-agnóstico, não o
`ResultList` do pacote.

Monte filtros **sempre** com `pb.filter(expr, params)` — binding seguro
anti-injeção. Nunca interpole valores na string à mão.

```dart
final res = await _col.getList(
  page: 1, perPage: 200,
  filter: _pb.filter('profissional = {:prof} && data_hora >= {:ini}',
      {'prof': profId, 'ini': janela.start}),
  sort: 'data_hora',        // '-campo' = desc
  expand: kExecExpand,
);
return res.items.map(OrdemServico.fromRecord).toList();
```

Para filtros dinâmicos, componha os fragmentos numa lista e junte com `&& `,
alimentando um único mapa de params (ver `listDoProfissional`).

## Expand e anti-desvio

Leia relações expandidas por `record.expand`. **O expand da execução do
profissional é `'profissional,servico'` e NUNCA inclui `cliente`** (constante
`kExecExpand`). Pedir `expand=cliente` como profissional volta vazio de
propósito — o cofre é protegido no servidor; não tente contornar no cliente.

## Realtime subscribe

`subscribe(topic, cb, {filter, expand})` devolve uma `UnsubscribeFunc` que você
**precisa** chamar ao cancelar, senão vaza SSE. Cuidado com o *add-after-close*:
se o listener cancelar antes de o `subscribe` resolver, desfaça na hora. O padrão
robusto está em `PbOrdensRepository.subscribe` (flag `cancelled` + guarda
`controller.isClosed`). `topic` = `'*'` (toda a coleção) ou um id de OS.

```dart
UnsubscribeFunc? unsub;
final fn = await _col.subscribe('*', (e) {
  if (controller.isClosed) return;
  controller.add(OrdemServicoEvent(action: osEventActionFromWire(e.action),
      record: e.record == null ? null : OrdemServico.fromRecord(e.record!)));
}, filter: filter, expand: kExecExpand);
unsub = fn; // e em onCancel: await unsub?.call();
```

Nota: o backend bloqueia filtros realtime relacionais (`cliente.`/`@collection`)
para o profissional (`onRealtimeSubscribeRequest`). Não os envie.

## Arquivos protegidos (file token)

As fotos de `os_evidencias` são protegidas: a URL só serve o arquivo com um
**file token** de vida curta (~2 min), gerado **uma vez por load**:

```dart
final token = temFoto ? await _pb.files.getToken() : null;
final url = _pb.files.getUrl(rec, foto, token: token).toString();
```

Gere o token só se houver ao menos um arquivo, e reaproveite-o para todos os itens
do mesmo load (não um por foto). Ver `pb_evidencias_repository.dart`.

## Upload multipart + idempotência

Upload usa `files: [http.MultipartFile.fromBytes('foto', bytes, filename: …)]`
no `create`. Campos não-arquivo vão em `body`. Para tornar o retry seguro (rede
caiu depois do POST), envie um `idempotency_key` (uuid) no multipart — o backend
deduplica por `(os, idempotency_key)` e devolve o registro existente em vez de
duplicar:

```dart
final rec = await _col.create(
  body: {'os': osId, 'fase': input.fase.wire,
         if (key.isNotEmpty) 'idempotency_key': key},
  files: [http.MultipartFile.fromBytes('foto', input.bytes, filename: input.filename)],
  expand: 'enviado_por',
);
```

## Rotas custom via `pb.send`

Endpoints custom (`/api/cleanos/...`) são chamados com `pb.send(path, method,
body, query)`. O `Authorization` já vai automático pelo authStore.

```dart
await _pb.send<dynamic>('/api/cleanos/os/$osId/posicao',
    method: 'POST', body: {'lat': lat, 'lng': lng});
```

Rotas atrás de flag (tracking GPS) só são injetadas quando `Env.trackingEnabled`;
com a flag OFF o provider entrega um repositório stub do core.

## Erros: `ClientException`

O SDK lança `ClientException` com `statusCode` e `response` (mapa). Traduza com
`describeOSError` (`core/errors/os_error.dart`):

- `0` → offline (sem conexão)
- `403` → sem permissão — **trate graciosamente**, não esconda a ação; o servidor
  é a linha de defesa.
- `404` → não encontrado
- senão → use `response['message']`.

Rotas custom devolvem 409 com `{ error: "..." }` (ex.: WhatsApp desconectado);
`serverErrorMessage` (`profissional/data/server_error.dart`) prioriza esse
`error` e cai em `describeOSError` quando não há corpo útil.

## Checklist ao mexer nas camadas de dados

- [ ] Coleções/enums vêm de `collections.dart`? (sem string solta)
- [ ] Filtro montado com `pb.filter` + params? (nunca interpolação)
- [ ] Lista de UI usa `getList` paginado? (não `getFullList`)
- [ ] Nenhum `expand=cliente` / filtro relacional no fluxo do profissional?
- [ ] `subscribe` sempre pareado com `UnsubscribeFunc`?
- [ ] Só envia campos liberados no PATCH (ver `OSExecPatch` — espelha a denylist
      do backend; enviar campo travado gera 403 "sem mudar nada")?
- [ ] Erro tratado via `describeOSError`/`serverErrorMessage`, 403 gracioso?
- [ ] Arquivo protegido acessado com file token?
