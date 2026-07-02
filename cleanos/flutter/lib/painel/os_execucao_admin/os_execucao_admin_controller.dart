/// os_execucao_admin_controller.dart — Estado/dados da EXECUÇÃO (visão admin).
///
/// Diferente do profissional, o admin/gerente PODE ver os dados do cliente
/// (expand `cliente`), então esta camada pede `profissional,servico,cliente`. É uma
/// visão de LEITURA: carrega a OS + evidências e monta o laudo. Consome só
/// interfaces congeladas (`OrdensRepository` do core + `EvidenciasRepository` da
/// camada do Painel). O envio do relatório usa a rota WhatsApp.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/os_execucao.dart';
import '../data/painel_providers.dart';

/// Expand da visão admin — inclui `cliente` (PII liberada ao Painel).
const String kAdminExecExpand = 'profissional,servico,cliente';

/// Payload da execução para a visão admin: a OS + as evidências carregadas.
class OSExecucaoAdminData {
  const OSExecucaoAdminData({required this.os, required this.evidencias});
  final OrdemServico os;
  final List<EvidenciaFoto> evidencias;
}

/// Carrega a OS (com cliente) + evidências. `family` por osId; `autoDispose`
/// libera ao sair da tela (um novo acesso refaz o fetch).
final osExecucaoAdminProvider = FutureProvider.autoDispose
    .family<OSExecucaoAdminData, String>((ref, osId) async {
      final os = await ref
          .watch(ordensRepositoryProvider)
          .getOne(osId, expand: kAdminExecExpand);
      // Evidências são um conjunto pequeno e fechado (só desta OS) → getFullList OK.
      final evidencias = await ref
          .watch(painelEvidenciasRepositoryProvider)
          .listDaOS(osId);
      return OSExecucaoAdminData(os: os, evidencias: evidencias);
    });
