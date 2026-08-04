/// os_atividade.dart — Feed interno da OS (comentários + log de alterações).
///
/// Coleção `os_atividade` — só admin/gerente. Profissional não lê (regras PB).
library;

import 'package:pocketbase/pocketbase.dart';

import 'user.dart';

/// Tipo de entrada no feed.
enum OsAtividadeTipo {
  comentario,
  alteracao,
  sistema;

  static OsAtividadeTipo fromWire(String? raw) {
    switch (raw) {
      case 'comentario':
        return OsAtividadeTipo.comentario;
      case 'alteracao':
        return OsAtividadeTipo.alteracao;
      case 'sistema':
        return OsAtividadeTipo.sistema;
      default:
        return OsAtividadeTipo.sistema;
    }
  }

  String get wire => name;

  String get label => switch (this) {
        OsAtividadeTipo.comentario => 'Comentário',
        OsAtividadeTipo.alteracao => 'Alteração',
        OsAtividadeTipo.sistema => 'Sistema',
      };
}

class OsAtividade {
  const OsAtividade({
    required this.id,
    required this.os,
    required this.tipo,
    this.autor,
    this.autorUser,
    required this.texto,
    this.campo,
    this.valorAntes,
    this.valorDepois,
    this.mentions = const [],
    this.created,
    this.updated,
  });

  final String id;
  final String os;
  final OsAtividadeTipo tipo;
  final String? autor;
  final User? autorUser;
  final String texto;
  final String? campo;
  final String? valorAntes;
  final String? valorDepois;
  final List<String> mentions;
  final String? created;
  final String? updated;

  factory OsAtividade.fromRecord(RecordModel record) {
    final j = Map<String, dynamic>.from(record.toJson());

    String relStr(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is Map) return (v['id'] ?? '').toString();
      return v.toString();
    }

    List<String> relList(dynamic v) {
      if (v == null) return const [];
      if (v is List) {
        return v.map(relStr).where((s) => s.isNotEmpty).toList();
      }
      final s = relStr(v);
      return s.isEmpty ? const [] : [s];
    }

    User? autorUser;
    try {
      // SDK 0.22: expand via get('expand.campo') ou mapa expand no toJson.
      RecordModel? exp;
      try {
        exp = record.get<RecordModel?>('expand.autor', null);
      } catch (_) {
        exp = null;
      }
      if (exp == null) {
        final expandMap = record.get<Map<String, dynamic>?>('expand', null);
        final raw = expandMap?['autor'];
        if (raw is RecordModel) {
          exp = raw;
        } else if (raw is Map<String, dynamic>) {
          exp = RecordModel(raw);
        }
      }
      if (exp != null) autorUser = User.fromRecord(exp);
    } catch (_) {}

    final autorId = relStr(j['autor']);
    final campo = (j['campo'] as String?)?.trim();
    final va = (j['valor_antes'] as String?)?.trim();
    final vd = (j['valor_depois'] as String?)?.trim();

    return OsAtividade(
      id: record.id,
      os: relStr(j['os']),
      tipo: OsAtividadeTipo.fromWire(j['tipo'] as String?),
      autor: autorId.isEmpty ? null : autorId,
      autorUser: autorUser,
      texto: (j['texto'] as String?) ?? '',
      campo: (campo == null || campo.isEmpty) ? null : campo,
      valorAntes: (va == null || va.isEmpty) ? null : va,
      valorDepois: (vd == null || vd.isEmpty) ? null : vd,
      mentions: relList(j['mentions']),
      created: j['created'] as String?,
      updated: j['updated'] as String?,
    );
  }

  String get autorNome {
    final u = autorUser;
    if (u != null) return u.displayName;
    return 'Sistema';
  }
}

class NotificacaoInApp {
  const NotificacaoInApp({
    required this.id,
    required this.destinatario,
    required this.tipo,
    required this.titulo,
    this.corpo,
    this.os,
    this.atividade,
    this.lida = false,
    this.created,
    this.updated,
  });

  final String id;
  final String destinatario;
  final String tipo;
  final String titulo;
  final String? corpo;
  final String? os;
  final String? atividade;
  final bool lida;
  final String? created;
  final String? updated;

  factory NotificacaoInApp.fromRecord(RecordModel record) {
    final j = Map<String, dynamic>.from(record.toJson());

    String? relOpt(dynamic v) {
      if (v == null || v == '') return null;
      if (v is String) return v.isEmpty ? null : v;
      if (v is Map) {
        final id = (v['id'] ?? '').toString();
        return id.isEmpty ? null : id;
      }
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return NotificacaoInApp(
      id: record.id,
      destinatario: relOpt(j['destinatario']) ?? '',
      tipo: (j['tipo'] as String?) ?? 'mencao_os',
      titulo: (j['titulo'] as String?) ?? '',
      corpo: (j['corpo'] as String?)?.trim().isEmpty == true
          ? null
          : j['corpo'] as String?,
      os: relOpt(j['os']),
      atividade: relOpt(j['atividade']),
      lida: j['lida'] == true,
      created: j['created'] as String?,
      updated: j['updated'] as String?,
    );
  }
}
