/// painel_providers.dart — Providers Riverpod da camada de dados do PAINEL.
///
/// Injeta as impls PB das interfaces congeladas do core (clientes/serviços/
/// usuários/evidências/whatsapp) SEM tocar no core. Consome o `pocketBaseProvider`
/// do core (mesmo padrão de `profissional/data/prof_providers.dart`). O repositório
/// de Ordens já é provido pelo core (`ordensRepositoryProvider`).
///
/// Providers "manuais" (sem codegen), como o core — são poucos e globais.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/repositories/clientes_repository.dart';
import '../../core/repositories/config_atuacao_repository.dart';
import '../../core/repositories/disponibilidade_repository.dart';
import '../../core/repositories/evidencias_repository.dart';
import '../../core/repositories/servicos_repository.dart';
import '../../core/repositories/usuarios_repository.dart';
import '../../core/repositories/whatsapp_repository.dart';
import 'pb_clientes_repository.dart';
import 'pb_config_atuacao_repository.dart';
import 'pb_disponibilidade_repository.dart';
import 'pb_painel_evidencias_repository.dart';
import 'pb_painel_whatsapp_repository.dart';
import 'pb_servicos_repository.dart';
import 'pb_usuarios_repository.dart';
import 'whatsapp_config_repository.dart';

/// 🔒 COFRE: CRUD de `clientes` (só o Painel injeta).
final clientesRepositoryProvider = Provider<ClientesRepository>(
  (ref) => PbClientesRepository(ref.watch(pocketBaseProvider)),
);

/// Catálogo de serviços (dropdown de Nova OS nesta onda).
final servicosRepositoryProvider = Provider<ServicosRepository>(
  (ref) => PbServicosRepository(ref.watch(pocketBaseProvider)),
);

/// Usuários (dropdown de profissionais em Nova OS / reatribuição).
final usuariosRepositoryProvider = Provider<UsuariosRepository>(
  (ref) => PbUsuariosRepository(ref.watch(pocketBaseProvider)),
);

/// Disponibilidade semanal por profissional (Agenda + editor de disponibilidade).
final disponibilidadeRepositoryProvider = Provider<DisponibilidadeRepository>(
  (ref) => PbDisponibilidadeRepository(ref.watch(pocketBaseProvider)),
);

/// Config de atuação (estado + cidades/bairros) — singleton admin/gerente.
final configAtuacaoRepositoryProvider = Provider<ConfigAtuacaoRepository>(
  (ref) => PbConfigAtuacaoRepository(ref.watch(pocketBaseProvider)),
);

/// Evidências (leitura) da execução — visão admin do laudo.
final painelEvidenciasRepositoryProvider = Provider<EvidenciasRepository>(
  (ref) => PbPainelEvidenciasRepository(ref.watch(pocketBaseProvider)),
);

/// Rotas de WhatsApp/UAZAPI do Painel (relatório ao cliente + status/connect/
/// disconnect da instância na seção WhatsApp admin).
final painelWhatsappRepositoryProvider = Provider<WhatsAppRepository>(
  (ref) => PbPainelWhatsAppRepository(ref.watch(pocketBaseProvider)),
);

/// Templates de mensagem automática (`/whatsapp/config`) — editor da seção
/// WhatsApp (admin). Contrato fora do core (congelado), por isso vive aqui.
final whatsappConfigRepositoryProvider = Provider<WhatsAppConfigRepository>(
  (ref) => PbWhatsAppConfigRepository(ref.watch(pocketBaseProvider)),
);
