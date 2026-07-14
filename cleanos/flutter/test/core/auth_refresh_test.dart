/// auth_refresh_test.dart — F-227: o refresh do app do profissional tem que
/// revalidar a SESSÃO, não só recarregar listas.
///
/// O `authStore` guarda o snapshot do user de quando o login aconteceu. Sem
/// `authRefresh()`, o admin muda a comissão do profissional e o app segue a
/// sessão inteira com a config antiga — só um F5 corrigia.
library;

import 'dart:convert';

import 'package:cleanos/core/auth/auth_service.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import '../profissional/fakes.dart';

/// JWT de mentira com `exp` no futuro — é só isso que `authStore.isValid` olha.
String _fakeToken() {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}'
      '.${seg({'id': 'p1', 'exp': exp ~/ 1000})}'
      '.assinatura';
}

Map<String, dynamic> _userJson({
  required String comissaoTipo,
  required num comissaoValor,
}) => {
  'id': 'p1',
  'collectionId': 'users',
  'collectionName': 'users',
  'email': 'lucas@cleanox.local',
  'name': 'Lucas Profissional',
  'role': 'profissional',
  'comissao_tipo': comissaoTipo,
  'comissao_valor': comissaoValor,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// PB logado como Lucas com a config ANTIGA (percentual 20%).
  /// O servidor, quando perguntado, responde com a config NOVA (fixo 50).
  (PocketBase, List<String>) pbLogado({int status = 200}) {
    final chamadas = <String>[];
    final pb = PocketBase(
      'http://127.0.0.1:9',
      httpClientFactory: () => MockClient((req) async {
        chamadas.add('${req.method} ${req.url.path}');
        if (status != 200) {
          return http.Response('{"message":"erro"}', status);
        }
        return http.Response(
          jsonEncode({
            'token': _fakeToken(),
            'record': _userJson(comissaoTipo: 'fixo', comissaoValor: 50),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    pb.authStore.save(
      _fakeToken(),
      RecordModel.fromJson(
        _userJson(comissaoTipo: 'percentual', comissaoValor: 20),
      ),
    );
    return (pb, chamadas);
  }

  AuthService svc(PocketBase pb) => AuthService(
    pb,
    storage: FakeSecureStorage({}),
    purgeEvidenceFiles: () async {},
    purgeImageDiskCache: () async {},
  );

  test('refresh() puxa a config de comissão atualizada do servidor', () async {
    final (pb, chamadas) = pbLogado();
    final auth = svc(pb);

    // Antes: o app opera com a config do login.
    expect(auth.currentUser!.comissaoTipo, ComissaoTipo.percentual);
    expect(auth.currentUser!.comissaoValor, 20);

    final user = await auth.refresh();

    expect(chamadas, contains('POST /api/collections/users/auth-refresh'));
    expect(user!.comissaoTipo, ComissaoTipo.fixo);
    expect(user.comissaoValor, 50);
    // E o authStore foi reescrito — currentUserProvider reemite daqui.
    expect(auth.currentUser!.comissaoTipo, ComissaoTipo.fixo);
    expect(auth.currentUser!.comissaoValor, 50);
  });

  test('deslogado: refresh() não chama a rede', () async {
    final (pb, chamadas) = pbLogado();
    pb.authStore.clear();

    expect(await svc(pb).refresh(), isNull);
    expect(chamadas, isEmpty);
  });

  test('401 (token morto) → desloga', () async {
    final (pb, _) = pbLogado(status: 401);
    final auth = svc(pb);

    expect(await auth.refresh(), isNull);
    expect(pb.authStore.isValid, isFalse);
  });

  test('falha de rede (500) → mantém a sessão do profissional em campo', () async {
    final (pb, _) = pbLogado(status: 500);
    final auth = svc(pb);

    final user = await auth.refresh();

    expect(pb.authStore.isValid, isTrue);
    expect(user, isNotNull, reason: 'não derruba o login por causa de sinal');
    expect(user!.comissaoValor, 20, reason: 'segue com o que tinha');
  });
}
