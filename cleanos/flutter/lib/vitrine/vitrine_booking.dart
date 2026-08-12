/// Helpers puros do funil de autoagendamento da Vitrine (testáveis sem UI).
library;

/// Etapas do funil público (mobile-first).
/// 0 home · 1 serviços · 2 data/hora · 3 dados · 4 revisar · 5 ok · 6 como
enum VitrineStep {
  home,
  servicos,
  agenda,
  dados,
  revisar,
  sucesso,
  comoFunciona,
}

extension VitrineStepX on VitrineStep {
  int get index => switch (this) {
    VitrineStep.home => 0,
    VitrineStep.servicos => 1,
    VitrineStep.agenda => 2,
    VitrineStep.dados => 3,
    VitrineStep.revisar => 4,
    VitrineStep.sucesso => 5,
    VitrineStep.comoFunciona => 6,
  };

  static VitrineStep fromIndex(int i) => switch (i) {
    1 => VitrineStep.servicos,
    2 => VitrineStep.agenda,
    3 => VitrineStep.dados,
    4 => VitrineStep.revisar,
    5 => VitrineStep.sucesso,
    6 => VitrineStep.comoFunciona,
    _ => VitrineStep.home,
  };

  String get headerLabel => switch (this) {
    VitrineStep.servicos => '1 · Serviços',
    VitrineStep.agenda => '2 · Data e horário',
    VitrineStep.dados => '3 · Seus dados',
    VitrineStep.revisar => '4 · Revisar',
    _ => '',
  };
}

/// Ordem canônica do funil de agendamento (sem home/como/sucesso).
const kVitrineFunilOrdem = <VitrineStep>[
  VitrineStep.servicos,
  VitrineStep.agenda,
  VitrineStep.dados,
  VitrineStep.revisar,
];

String mascaraWhatsapp(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 4) return '****';
  if (d.length <= 8) {
    return '${d.substring(0, 2)}****${d.substring(d.length - 2)}';
  }
  return '${d.substring(0, 2)}*****${d.substring(d.length - 4)}';
}

bool cepBrValido(String cep) {
  final d = cep.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^\d{8}$').hasMatch(d);
}

bool telefoneBrValido(String tel) {
  final d = tel.replaceAll(RegExp(r'\D'), '');
  return d.length >= 10 && d.length <= 13;
}

/// Validação client-side espelhando o backend (campos estruturados).
String? validarDadosVitrine({
  required String nome,
  required String whatsapp,
  required String cep,
  required String rua,
  required String numero,
  required String bairro,
  required String cidade,
  String estado = '',
}) {
  if (nome.trim().isEmpty) return 'Informe o nome completo';
  if (!telefoneBrValido(whatsapp)) return 'Informe um WhatsApp válido';
  if (!cepBrValido(cep)) return 'Informe um CEP válido';
  if (rua.trim().isEmpty) return 'Informe a rua';
  if (numero.trim().isEmpty) return 'Informe o número';
  if (bairro.trim().isEmpty) return 'Informe o bairro';
  if (cidade.trim().isEmpty) return 'Informe a cidade';
  return null;
}

/// Payload canônico enviado a POST /vitrine/agendar.
Map<String, dynamic> montarPayloadAgendamento({
  required String slotToken,
  required String nome,
  required String whatsapp,
  required String cep,
  required String rua,
  required String numero,
  required String bairro,
  required String cidade,
  required String estado,
  required String complemento,
  required String observacoes,
  required String honeypot,
  required String idempotencyKey,
  required List<Map<String, dynamic>> itens,
}) {
  return {
    'slot_token': slotToken,
    'nome': nome.trim(),
    'whatsapp': whatsapp.trim(),
    'telefone': whatsapp.trim(),
    'cep': cep.replaceAll(RegExp(r'\D'), ''),
    'rua': rua.trim(),
    'numero': numero.trim(),
    'complemento': complemento.trim(),
    'bairro': bairro.trim(),
    'cidade': cidade.trim(),
    'estado': estado.trim().toUpperCase(),
    'observacoes': observacoes.trim(),
    'website': honeypot,
    'idempotency_key': idempotencyKey,
    'itens': itens,
  };
}

/// Texto default de "como funciona" (sem linguagem de orçamento).
const kComoFuncionaDefault =
    '1) Selecione os serviços\n'
    '2) Escolha data e horário\n'
    '3) Informe contato e endereço\n'
    '4) Revise e confirme\n'
    '5) OS criada — a Cleanox atribui a equipe';

bool contemLinguagemOrcamento(String text) {
  final t = text.toLowerCase();
  return t.contains('orçamento') || t.contains('orcamento');
}
