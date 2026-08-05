/// Teste de superfície de erro no create de usuário (mensagem legível).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

/// Espelha a lógica de [UsuarioForm._formatSaveError] (pura) para unit test.
String formatUsuarioSaveError(Object e, {required bool isEdit}) {
  if (e is ClientException) {
    final data = e.response;
    final msg = (data['message'] as String?)?.trim() ?? '';
    final details = data['data'];
    if (details is Map && details.isNotEmpty) {
      final parts = <String>[];
      details.forEach((k, v) {
        if (v is Map && v['message'] != null) {
          parts.add('${v['message']}');
        } else if (v != null) {
          parts.add('$k: $v');
        }
      });
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    if (msg.isNotEmpty &&
        msg != 'Failed to create record.' &&
        msg != 'Failed to update record.') {
      return msg;
    }
    if (!isEdit) {
      return 'Não foi possível criar o usuário. '
          'Confira e-mail (único), senha (mín. 4) e se você é admin/gerente.';
    }
    return 'Não foi possível salvar as alterações.';
  }
  return isEdit
      ? 'Não foi possível salvar as alterações.'
      : 'Não foi possível criar o usuário.';
}

void main() {
  test('PB genérico create → mensagem acionável', () {
    final e = ClientException(
      url: Uri.parse('https://x/api/collections/users/records'),
      statusCode: 400,
      response: const {
        'data': <String, dynamic>{},
        'message': 'Failed to create record.',
      },
    );
    final m = formatUsuarioSaveError(e, isEdit: false);
    expect(m, contains('e-mail'));
    expect(m, contains('senha'));
    expect(m, isNot(equals('Não foi possível criar o usuário.')));
  });

  test('campo password com message → usa a do PB', () {
    final e = ClientException(
      url: Uri.parse('https://x/api/collections/users/records'),
      statusCode: 400,
      response: const {
        'data': {
          'password': {'code': 'validation_min_text_constraint', 'message': 'Must be at least 8 character(s)'},
        },
        'message': 'Failed to create record.',
      },
    );
    expect(
      formatUsuarioSaveError(e, isEdit: false),
      contains('at least 8'),
    );
  });
}
