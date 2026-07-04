/// app_surface_provider_test.dart — Sugar de superfície (doc 12 §1, Nível 2).
///
/// Default `AppSurface.painel` sem override (desvio documentado do plano
/// original — ver comentário em `app_surface_provider.dart`): protege os
/// testes existentes que nunca instalam este provider.
library;

import 'package:cleanos/app.dart';
import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default (sem override) é AppSurface.painel / isFintechClean=false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appSurfaceProvider), AppSurface.painel);
    expect(container.read(isFintechCleanProvider), isFalse);
  });

  test('override AppSurface.android → isFintechClean=true', () {
    final container = ProviderContainer(
      overrides: [appSurfaceProvider.overrideWithValue(AppSurface.android)],
    );
    addTearDown(container.dispose);

    expect(container.read(isFintechCleanProvider), isTrue);
  });

  test('override AppSurface.profissional → isFintechClean=true (decisão P-1)', () {
    final container = ProviderContainer(
      overrides: [
        appSurfaceProvider.overrideWithValue(AppSurface.profissional),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isFintechCleanProvider), isTrue);
  });
}
