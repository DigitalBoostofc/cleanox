/// prof_providers.dart — Providers Riverpod da camada de dados do PROFISSIONAL.
///
/// Injeta as impls PB das interfaces congeladas do core (evidências, whatsapp,
/// tracking) SEM tocar no core.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/repositories/evidencias_repository.dart';
import '../../core/repositories/repo_types.dart';
import '../../core/repositories/whatsapp_repository.dart';
import '../../core/storage/local_store_keys.dart';
import 'pb_evidencias_repository.dart';
import 'pb_tracking_repository.dart';
import 'pb_whatsapp_repository.dart';

/// Secure storage compartilhado (fila de upload etc.). Override em teste.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Diretório app-private ESTÁVEL onde a execução copia as fotos antes de
/// enfileirar (o cache do image_picker é volátil — o SO pode limpá-lo após um
/// kill, quebrando o retry). Override em teste (o plugin não existe na VM).
final evidenceDirProvider = FutureProvider<Directory>((ref) async {
  final base = await getApplicationDocumentsDirectory();
  // Nome canônico compartilhado com a purga LGPD do logout (A-01).
  final dir = Directory('${base.path}/$kEvidenceDirName');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
});

/// Id do profissional autenticado (conveniência; null se deslogado).
final currentProfIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider)?.id,
);

/// Repositório de evidências (impl PB sobre `os_evidencias`).
final evidenciasRepositoryProvider = Provider<EvidenciasRepository>(
  (ref) => PbEvidenciasRepository(ref.watch(pocketBaseProvider)),
);

/// Repositório de rotas WhatsApp (a-caminho / relatório).
final whatsappRepositoryProvider = Provider<WhatsAppRepository>(
  (ref) => PbWhatsAppRepository(ref.watch(pocketBaseProvider)),
);

/// Repositório de tracking/push (doc 09).
///
/// Sempre a impl real: Em deslocamento + Cheguei + avisos 5min/1min dependem
/// de `/posicao` e `/cheguei`. A flag [Env.trackingEnabled] só existia como
/// gate antigo; o backend já está em produção.
final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => PbTrackingRepository(ref.watch(pocketBaseProvider)),
);

/// Realtime da coleção `ordens_servico` (SSE). A tela de serviços dedupe
/// fetch×realtime por id. Fica em StreamProvider.autoDispose (cancela a SSE ao
/// sair da superfície).
final ordensRealtimeProvider = StreamProvider.autoDispose<OrdemServicoEvent>((
  ref,
) {
  return ref.watch(ordensRepositoryProvider).subscribe();
});
