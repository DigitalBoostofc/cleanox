/// agenda_prof_cor.dart — Cor da agenda por PROFISSIONAL (não por status).
///
/// Regras de produto (dono, 2026-07-18):
/// - cor do bloco/bolinha = profissional (campo `users.cor_agenda` ou paleta);
/// - `cancelada` NÃO aparece na agenda;
/// - `agendada` sem foto (ainda não tem profissional útil);
/// - `atribuida` / `em_andamento` → foto do profissional;
/// - `concluida` → marcação de concluído (check), sem foto.
library;

import 'package:flutter/material.dart';

import '../models/collections.dart';
import '../models/ordem_servico.dart';
import '../models/user.dart';

/// Cinza neutro: OS agendada sem profissional (ou cor inválida).
const Color kAgendaCorSemProf = Color(0xFF94A3B8);

/// Paleta estável quando o profissional ainda não escolheu cor.
const List<Color> kAgendaPaletaDefault = [
  Color(0xFF2563EB), // azul
  Color(0xFF16A34A), // verde
  Color(0xFFD97706), // âmbar
  Color(0xFF7C3AED), // violeta
  Color(0xFFDB2777), // rosa
  Color(0xFF0891B2), // ciano
  Color(0xFFEA580C), // laranja
  Color(0xFF4F46E5), // índigo
];

/// Swatches do seletor no form de usuário (inclui as duas cores do dono).
const List<Color> kAgendaCoresEscolha = [
  Color(0xFF2563EB), // Azul — João Pedro
  Color(0xFF16A34A), // Verde — Hendrio Piter
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFFEA580C),
  Color(0xFF4F46E5),
  Color(0xFF0F766E),
  Color(0xFFB45309),
];

/// Parse `#RGB` / `#RRGGBB` (case-insensitive). Null se vazio/inválido.
Color? parseHexCorAgenda(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }
  if (s.length != 6) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

/// Serializa cor para gravar em `users.cor_agenda`.
String hexCorAgenda(Color c) {
  final r = (c.r * 255.0).round().clamp(0, 255);
  final g = (c.g * 255.0).round().clamp(0, 255);
  final b = (c.b * 255.0).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Cor de agenda de um [User] profissional.
Color corAgendaProfissional(User? user) {
  if (user == null) return kAgendaCorSemProf;
  final chosen = parseHexCorAgenda(user.corAgenda);
  if (chosen != null) return chosen;
  if (user.id.isEmpty) return kAgendaCorSemProf;
  // Hash estável do id → índice da paleta (mesmo sem cor gravada).
  var h = 0;
  for (final cu in user.id.codeUnits) {
    h = (h * 31 + cu) & 0x7fffffff;
  }
  return kAgendaPaletaDefault[h % kAgendaPaletaDefault.length];
}

/// Cor do bloco/bolinha da OS na agenda.
Color corAgendaOs(OrdemServico os) {
  final prof = os.expand?.profissional;
  if (prof != null && prof.displayName != '—') {
    return corAgendaProfissional(prof);
  }
  // Sem expand: tenta só o id (sem cor custom → paleta por id).
  final pid = os.profissional;
  if (pid != null && pid.isNotEmpty) {
    return corAgendaProfissional(User(id: pid, name: '', role: Role.profissional));
  }
  return kAgendaCorSemProf;
}

/// Fundo suave do bloco (mesmo tom da cor do profissional).
Color corAgendaBg(Color cor) => cor.withValues(alpha: 0.14);

/// Cancelada some da agenda.
bool agendaVisivel(OrdemServico os) => os.status != OSStatus.cancelada;

/// Foto só em atribuída / em andamento (não em agendada nem concluída).
bool agendaMostraAvatar(OrdemServico os) {
  return os.status == OSStatus.atribuida || os.status == OSStatus.emAndamento;
}

/// Marcação de “concluído” no bloco/bolinha.
bool agendaMostraCheckConcluida(OrdemServico os) =>
    os.status == OSStatus.concluida;
