/// os_status_rules_test.dart — F-234: a guarda de consistência status ×
/// profissional, isolada da UI.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/ordens/os_status_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('statusAposEdicao', () {
    test('sem profissional → agendada, mesmo quando o registro está VELHO', () {
      // O caso do F-234: o registro em mãos diz "agendada/sem prof" porque não
      // acompanhou a atribuição feita no detalhe; o BANCO está em `atribuida`.
      // A regra tem que mandar `agendada` EXPLÍCITO mesmo assim — é isso que
      // impede o `atribuida` do banco de sobreviver ao lado de profissional="".
      expect(
        statusAposEdicao(atual: OSStatus.agendada, temProfissional: false),
        OSStatus.agendada,
        reason: 'null aqui deixaria o status fora do payload e o lixo passaria',
      );
    });

    test('sem profissional → agendada (atribuida e em_andamento)', () {
      for (final atual in [OSStatus.atribuida, OSStatus.emAndamento]) {
        expect(
          statusAposEdicao(atual: atual, temProfissional: false),
          OSStatus.agendada,
          reason: '$atual exige profissional; sem ele só pode ser agendada',
        );
      }
    });

    test('com profissional: agendada → atribuida', () {
      expect(
        statusAposEdicao(atual: OSStatus.agendada, temProfissional: true),
        OSStatus.atribuida,
      );
    });

    test('com profissional: não rebaixa quem já está adiante', () {
      // Editar o valor de uma OS em andamento não pode jogá-la para atribuida.
      expect(
        statusAposEdicao(atual: OSStatus.emAndamento, temProfissional: true),
        isNull,
      );
      expect(
        statusAposEdicao(atual: OSStatus.atribuida, temProfissional: true),
        isNull,
      );
    });

    test('OS finalizada: a edição nunca mexe no status', () {
      for (final atual in [OSStatus.concluida, OSStatus.cancelada]) {
        for (final temProf in [true, false]) {
          expect(
            statusAposEdicao(atual: atual, temProfissional: temProf),
            isNull,
            reason: '$atual não pode ser reaberta por uma edição de form',
          );
        }
      }
    });
  });

  group('invariante do domínio', () {
    test(
      'nenhuma combinação produz um status que exige profissional sem um',
      () {
        for (final atual in OSStatus.all) {
          final novo = statusAposEdicao(atual: atual, temProfissional: false);
          final resultante = novo ?? atual;
          // Sem profissional submetido, o status resultante NUNCA pode exigir um
          // — exceto nas finalizadas, que a edição não toca (e que sempre
          // tiveram profissional).
          if (!statusFinalizado(atual)) {
            expect(
              statusExigeProfissional(resultante),
              isFalse,
              reason:
                  'atual=$atual sem profissional resultaria em $resultante — '
                  'estado impossível (F-234)',
            );
          }
        }
      },
    );
  });
}
