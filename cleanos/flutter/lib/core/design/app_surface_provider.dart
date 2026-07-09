/// app_surface_provider.dart — Propaga a `AppSurface` atual (Riverpod) pra
/// decisões estruturais que `ThemeData` não cobre (nav de 5 itens vs.
/// sidebar/rail, hero de saldo, etc. — ver doc 12 §1, Nível 2).
///
/// `CleanosApp.build()` instala o valor real via `ProviderScope` aninhado, a
/// partir do `surface` que já recebe como parâmetro de construtor.
///
/// Default `AppSurface.painel` (desvio do plano original, que propunha lançar
/// `UnimplementedError` quando não instalado): os 52 testes de widget já
/// existentes montam `PainelShell`/telas do Painel via `MaterialApp.router`
/// direto, sem passar por `CleanosApp` — um `throw` aqui quebraria todos eles.
/// Web/painel já é o comportamento atual, então o default preserva
/// exatamente o que os testes (e a Web) já esperam sem editar nenhum.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart' show AppSurface;

final appSurfaceProvider = Provider<AppSurface>((ref) => AppSurface.painel);

/// Sugar: true nos dois APKs (unificado e o legado profissional, decisão do
/// dono P-1); false na Web. Consumidores que só precisam de um booleano (ex.:
/// `PainelShell`) leem daqui em vez de importar `app.dart` diretamente — evita
/// um ciclo de import desnecessário com `core/router/app_router.dart`.
final isFintechCleanProvider = Provider<bool>(
  (ref) => ref.watch(appSurfaceProvider) != AppSurface.painel,
  // Obrigatório: `appSurfaceProvider` é sobrescrito num ProviderScope aninhado
  // (por `CleanosApp`/pelos testes); sem declarar a dependência, o Riverpod
  // lança "Tried to read Provider<bool> from a place where one of its
  // dependencies were overridden but the provider is not.".
  dependencies: [appSurfaceProvider],
);

/// Expõe se o app roda no browser. Sobreponível em testes para simular web.
final isWebPlatformProvider = Provider<bool>((ref) => kIsWeb);

/// true quando rodando no browser E a largura da janela < [ClxLayout.narrowBreakpoint].
///
/// Telas dentro de [PainelShell]: o shell sobrepõe este provider via
/// `ProviderScope` aninhado derivado do [LayoutBuilder] (sincronicamente,
/// sem atraso de frame). Telas fora do shell (ex.: [LoginScreen]): usam
/// [isWebPlatformProvider] + [MediaQuery] diretamente, pois o shell não está
/// na árvore quando o login é exibido.
///
/// Default [false]: desktop/tablet web, todos os paths de APK e testes
/// permanecem no layout clássico sem nenhuma sobrescrita necessária.
final isNarrowWebProvider = Provider<bool>((ref) => false);
