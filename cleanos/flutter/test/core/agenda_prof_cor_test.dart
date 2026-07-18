import 'package:cleanos/core/agenda/agenda_prof_cor.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHexCorAgenda / hexCorAgenda', () {
    test('parse #RRGGBB', () {
      expect(parseHexCorAgenda('#2563EB'), const Color(0xFF2563EB));
      expect(parseHexCorAgenda('16a34a'), const Color(0xFF16A34A));
      expect(parseHexCorAgenda('#abc'), const Color(0xFFAABBCC));
      expect(parseHexCorAgenda(''), isNull);
      expect(parseHexCorAgenda(null), isNull);
      expect(parseHexCorAgenda('zz'), isNull);
    });

    test('round-trip', () {
      const c = Color(0xFF2563EB);
      expect(parseHexCorAgenda(hexCorAgenda(c)), c);
    });
  });

  group('corAgendaProfissional', () {
    test('usa cor gravada', () {
      final u = User(
        id: 'p1',
        name: 'João Pedro',
        role: Role.profissional,
        corAgenda: '#2563EB',
      );
      expect(corAgendaProfissional(u), const Color(0xFF2563EB));
    });

    test('sem cor: paleta estável por id', () {
      final a = corAgendaProfissional(
        const User(id: 'aaa', name: 'A', role: Role.profissional),
      );
      final b = corAgendaProfissional(
        const User(id: 'aaa', name: 'A', role: Role.profissional),
      );
      final c = corAgendaProfissional(
        const User(id: 'bbb', name: 'B', role: Role.profissional),
      );
      expect(a, b);
      // ids diferentes tendem a cores diferentes (não é garantia formal)
      expect(kAgendaPaletaDefault.contains(a), isTrue);
      expect(kAgendaPaletaDefault.contains(c), isTrue);
    });

    test('null → cinza', () {
      expect(corAgendaProfissional(null), kAgendaCorSemProf);
    });
  });

  group('regras de status na agenda', () {
    OrdemServico os({
      required OSStatus status,
      User? prof,
    }) {
      return OrdemServico(
        id: 'o1',
        status: status,
        dataHora: '2026-07-18T12:00:00.000Z',
        profissional: prof?.id,
        expand: prof == null
            ? null
            : OSExpand(profissional: prof),
      );
    }

    final prof = const User(
      id: 'p1',
      name: 'Hendrio',
      role: Role.profissional,
      corAgenda: '#16A34A',
      avatar: 'foto.jpg',
    );

    test('cancelada não é visível', () {
      expect(agendaVisivel(os(status: OSStatus.cancelada, prof: prof)), isFalse);
      expect(agendaVisivel(os(status: OSStatus.atribuida, prof: prof)), isTrue);
    });

    test('avatar só em atribuída / em andamento', () {
      expect(agendaMostraAvatar(os(status: OSStatus.agendada, prof: prof)), isFalse);
      expect(agendaMostraAvatar(os(status: OSStatus.atribuida, prof: prof)), isTrue);
      expect(
        agendaMostraAvatar(os(status: OSStatus.emAndamento, prof: prof)),
        isTrue,
      );
      expect(agendaMostraAvatar(os(status: OSStatus.concluida, prof: prof)), isFalse);
    });

    test('check só em concluída', () {
      expect(
        agendaMostraCheckConcluida(os(status: OSStatus.concluida, prof: prof)),
        isTrue,
      );
      expect(
        agendaMostraCheckConcluida(os(status: OSStatus.atribuida, prof: prof)),
        isFalse,
      );
    });

    test('cor da OS vem do profissional', () {
      final o = os(status: OSStatus.atribuida, prof: prof);
      expect(corAgendaOs(o), const Color(0xFF16A34A));
    });

    test('agendada sem prof → cinza', () {
      final o = os(status: OSStatus.agendada);
      expect(corAgendaOs(o), kAgendaCorSemProf);
    });
  });
}
