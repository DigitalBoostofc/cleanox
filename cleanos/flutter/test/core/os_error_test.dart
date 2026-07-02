/// Testes de describeOSError — porte de os/osStore.ts (0/403/404/genérico).
library;

import 'package:cleanos/core/errors/os_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('status 0 → offline', () {
    final e = describeOSError(ClientException(statusCode: 0));
    expect(e.isOffline, isTrue);
    expect(e.isPermission, isFalse);
    expect(e.isNotFound, isFalse);
  });

  test('status 403 → permissão', () {
    final e = describeOSError(ClientException(statusCode: 403));
    expect(e.isPermission, isTrue);
    expect(e.message, contains('permissão'));
  });

  test('status 404 → não encontrado', () {
    final e = describeOSError(ClientException(statusCode: 404));
    expect(e.isNotFound, isTrue);
  });

  test('usa response.message quando presente', () {
    final e = describeOSError(
      ClientException(statusCode: 400, response: {'message': 'Deu ruim X'}),
    );
    expect(e.message, 'Deu ruim X');
    expect(e.isPermission, isFalse);
  });

  test('status genérico sem message', () {
    final e = describeOSError(ClientException(statusCode: 500));
    expect(e.message, contains('500'));
  });

  test('erro não-PB vira mensagem genérica segura', () {
    final e = describeOSError(Exception('boom'));
    expect(e.isOffline, isFalse);
    expect(e.message, contains('boom'));
  });
}
