/// ponto_fisico.dart — Endereço de ponto físico da empresa (loja/galpão).
library;

import 'package:pocketbase/pocketbase.dart';

class PontoFisico {
  const PontoFisico({
    required this.id,
    required this.nome,
    this.enderecoCep = '',
    this.enderecoRua = '',
    this.enderecoNumero = '',
    this.enderecoComplemento = '',
    this.enderecoBairro = '',
    this.enderecoCidade = '',
    this.enderecoEstado = '',
    this.ativo = true,
    this.observacoes = '',
  });

  final String id;
  final String nome;
  final String enderecoCep;
  final String enderecoRua;
  final String enderecoNumero;
  final String enderecoComplemento;
  final String enderecoBairro;
  final String enderecoCidade;
  final String enderecoEstado;
  final bool ativo;
  final String observacoes;

  factory PontoFisico.fromRecord(RecordModel r) {
    final j = r.toJson();
    return PontoFisico(
      id: r.id,
      nome: '${j['nome'] ?? ''}'.trim(),
      enderecoCep: '${j['endereco_cep'] ?? ''}'.trim(),
      enderecoRua: '${j['endereco_rua'] ?? ''}'.trim(),
      enderecoNumero: '${j['endereco_numero'] ?? ''}'.trim(),
      enderecoComplemento: '${j['endereco_complemento'] ?? ''}'.trim(),
      enderecoBairro: '${j['endereco_bairro'] ?? ''}'.trim(),
      enderecoCidade: '${j['endereco_cidade'] ?? ''}'.trim(),
      enderecoEstado: '${j['endereco_estado'] ?? ''}'.trim().toUpperCase(),
      ativo: j['ativo'] != false,
      observacoes: '${j['observacoes'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toBody() => {
    'nome': nome.trim(),
    'endereco_cep': enderecoCep.trim(),
    'endereco_rua': enderecoRua.trim(),
    'endereco_numero': enderecoNumero.trim(),
    'endereco_complemento': enderecoComplemento.trim(),
    'endereco_bairro': enderecoBairro.trim(),
    'endereco_cidade': enderecoCidade.trim(),
    'endereco_estado': enderecoEstado.trim().toUpperCase(),
    'ativo': ativo,
    'observacoes': observacoes.trim(),
  };

  String get enderecoResumo {
    final parts = <String>[
      if (enderecoRua.isNotEmpty)
        enderecoNumero.isEmpty
            ? enderecoRua
            : '$enderecoRua, $enderecoNumero',
      if (enderecoBairro.isNotEmpty) enderecoBairro,
      if (enderecoCidade.isNotEmpty)
        enderecoEstado.isEmpty
            ? enderecoCidade
            : '$enderecoCidade-$enderecoEstado',
    ];
    return parts.isEmpty ? 'Sem endereço' : parts.join(' · ');
  }

  PontoFisico copyWith({
    String? nome,
    String? enderecoCep,
    String? enderecoRua,
    String? enderecoNumero,
    String? enderecoComplemento,
    String? enderecoBairro,
    String? enderecoCidade,
    String? enderecoEstado,
    bool? ativo,
    String? observacoes,
  }) => PontoFisico(
    id: id,
    nome: nome ?? this.nome,
    enderecoCep: enderecoCep ?? this.enderecoCep,
    enderecoRua: enderecoRua ?? this.enderecoRua,
    enderecoNumero: enderecoNumero ?? this.enderecoNumero,
    enderecoComplemento: enderecoComplemento ?? this.enderecoComplemento,
    enderecoBairro: enderecoBairro ?? this.enderecoBairro,
    enderecoCidade: enderecoCidade ?? this.enderecoCidade,
    enderecoEstado: enderecoEstado ?? this.enderecoEstado,
    ativo: ativo ?? this.ativo,
    observacoes: observacoes ?? this.observacoes,
  );
}
