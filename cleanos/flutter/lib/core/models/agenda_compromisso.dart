/// Tarefa/compromisso interno do profissional na Agenda (não é OS).
library;

import 'package:pocketbase/pocketbase.dart';

enum RecorrenciaCompromisso {
  nenhuma,
  semanal,
  mensal;

  String get wire => name;

  String get label => switch (this) {
    RecorrenciaCompromisso.nenhuma => 'Não se repete',
    RecorrenciaCompromisso.semanal => 'Toda semana',
    RecorrenciaCompromisso.mensal => 'Todo mês',
  };

  static RecorrenciaCompromisso parse(String? raw) {
    final s = (raw ?? '').trim();
    for (final v in RecorrenciaCompromisso.values) {
      if (v.wire == s) return v;
    }
    return RecorrenciaCompromisso.nenhuma;
  }
}

enum StatusCompromisso {
  pendente,
  concluida;

  String get wire => name;

  String get label =>
      this == StatusCompromisso.concluida ? 'Concluída' : 'Pendente';

  static StatusCompromisso parse(String? raw) {
    final s = (raw ?? '').trim();
    return s == StatusCompromisso.concluida.wire
        ? StatusCompromisso.concluida
        : StatusCompromisso.pendente;
  }
}

class AgendaCompromisso {
  const AgendaCompromisso({
    required this.id,
    required this.titulo,
    this.descricao = '',
    this.profissionais = const [],
    required this.dataHora,
    this.duracaoMin = 60,
    this.recorrencia = RecorrenciaCompromisso.nenhuma,
    this.serieId = '',
    this.status = StatusCompromisso.pendente,
  });

  final String id;
  final String titulo;
  final String descricao;

  /// IDs dos profissionais na tarefa (1 ou mais).
  final List<String> profissionais;
  final String dataHora;
  final int duracaoMin;
  final RecorrenciaCompromisso recorrencia;
  final String serieId;
  final StatusCompromisso status;

  /// Primeiro da lista — compatível com o campo antigo de 1 profissional.
  String get profissional =>
      profissionais.isEmpty ? '' : profissionais.first;

  bool incluiProfissional(String id) {
    final t = id.trim();
    if (t.isEmpty) return false;
    return profissionais.contains(t);
  }

  bool get concluida => status == StatusCompromisso.concluida;

  factory AgendaCompromisso.fromRecord(RecordModel r) {
    final j = r.toJson();
    return AgendaCompromisso(
      id: r.id,
      titulo: '${j['titulo'] ?? ''}'.trim(),
      descricao: '${j['descricao'] ?? ''}'.trim(),
      profissionais: _ids(j['profissional']),
      dataHora: '${j['data_hora'] ?? ''}'.trim(),
      duracaoMin: _asInt(j['duracao_min'], 60),
      recorrencia: RecorrenciaCompromisso.parse('${j['recorrencia'] ?? ''}'),
      serieId: '${j['serie_id'] ?? ''}'.trim(),
      status: StatusCompromisso.parse('${j['status'] ?? ''}'),
    );
  }

  Map<String, dynamic> toBody() => {
    'titulo': titulo.trim(),
    'descricao': descricao.trim(),
    'profissional': profissionais,
    'data_hora': dataHora.trim(),
    'duracao_min': duracaoMin < 15 ? 15 : duracaoMin,
    'recorrencia': recorrencia.wire,
    'serie_id': serieId.trim(),
    'status': status.wire,
  };

  AgendaCompromisso copyWith({
    String? titulo,
    String? descricao,
    List<String>? profissionais,
    String? dataHora,
    int? duracaoMin,
    RecorrenciaCompromisso? recorrencia,
    String? serieId,
    StatusCompromisso? status,
  }) => AgendaCompromisso(
    id: id,
    titulo: titulo ?? this.titulo,
    descricao: descricao ?? this.descricao,
    profissionais: profissionais ?? this.profissionais,
    dataHora: dataHora ?? this.dataHora,
    duracaoMin: duracaoMin ?? this.duracaoMin,
    recorrencia: recorrencia ?? this.recorrencia,
    serieId: serieId ?? this.serieId,
    status: status ?? this.status,
  );

  static List<String> _ids(dynamic v) {
    if (v is List) {
      return [
        for (final x in v)
          if ('$x'.trim().isNotEmpty) '$x'.trim(),
      ];
    }
    final s = '$v'.trim();
    if (s.isEmpty || s == 'null') return const [];
    return [s];
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }
}

/// Datas UTC das ocorrências a criar (1 pontual, 12 semanais ou 6 mensais).
List<DateTime> ocorrenciasCompromisso({
  required DateTime inicioUtc,
  required RecorrenciaCompromisso recorrencia,
  int semanais = 12,
  int mensais = 6,
}) {
  switch (recorrencia) {
    case RecorrenciaCompromisso.nenhuma:
      return [inicioUtc];
    case RecorrenciaCompromisso.semanal:
      return [
        for (var i = 0; i < semanais; i++)
          inicioUtc.add(Duration(days: 7 * i)),
      ];
    case RecorrenciaCompromisso.mensal:
      return [
        for (var i = 0; i < mensais; i++) _addMonthsUtc(inicioUtc, i),
      ];
  }
}

DateTime _addMonthsUtc(DateTime utc, int months) {
  final y = utc.year;
  final m = utc.month + months;
  final year = y + (m - 1) ~/ 12;
  final month = ((m - 1) % 12) + 1;
  final last = DateTime.utc(year, month + 1, 0).day;
  final day = utc.day > last ? last : utc.day;
  return DateTime.utc(year, month, day, utc.hour, utc.minute, utc.second);
}
