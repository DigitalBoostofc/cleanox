/// evidence_purge.dart — Fachada da purga do diretório de evidências (A-01).
///
/// Seleciona a implementação por plataforma: IO (Android/iOS/desktop) apaga o
/// diretório real; web é no-op. O `AuthService` importa daqui — nunca a impl
/// direta — para o core continuar compilando nas duas superfícies.
library;

export 'evidence_purge_stub.dart'
    if (dart.library.io) 'evidence_purge_io.dart';
