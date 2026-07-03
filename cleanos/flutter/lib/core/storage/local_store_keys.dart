/// local_store_keys.dart — Nomes CANÔNICOS do armazenamento local sensível.
///
/// Ponto único de verdade das chaves/prefixos usados no device (secure storage
/// e sistema de arquivos), para que a purga LGPD do logout (`AuthService`) e os
/// produtores dessas chaves (fila de upload, buffer de checklist, diretório de
/// evidências) nunca divirjam. Auditoria A-01/A-05: dados de execução e fotos
/// de evidência NÃO podem sobreviver ao logout.
library;

/// Subdiretório app-private (em documents) onde a execução copia as fotos de
/// evidência antes do upload (ver `evidenceDirProvider` / `enqueueFoto`).
const String kEvidenceDirName = 'cleanos_evidencias';

/// Prefixo das filas de upload persistidas por OS (`UploadQueue`).
const String kUploadQueueKeyPrefix = 'cleanos_upload_queue_';

/// Prefixo dos buffers offline de checklist por OS (`OSExecucaoController`).
const String kChecklistBufKeyPrefix = 'cleanos_checklist_exec_';

/// Prefixos varridos pela purga LGPD do logout (dados de execução por OS).
/// O token de auth (`cleanos_pb_auth`) NÃO entra aqui — ele é limpo pelo
/// próprio `authStore.clear()`.
const List<String> kLgpdPurgeKeyPrefixes = [
  kUploadQueueKeyPrefix,
  kChecklistBufKeyPrefix,
];
