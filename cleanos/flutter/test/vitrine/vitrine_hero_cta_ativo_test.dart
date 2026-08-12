import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hero_cta_ativo parse', () {
    expect(VitrineConfig.fromJson({}).heroCtaAtivo, isTrue);
    expect(VitrineConfig.fromJson({'hero_cta_ativo': false}).heroCtaAtivo, isFalse);
    expect(VitrineConfig.fromJson({'hero_cta_ativo': true}).heroCtaAtivo, isTrue);
    expect(VitrineConfig.fromJson({'hero_cta_ativo': 'false'}).heroCtaAtivo, isFalse);
    expect(VitrineConfig.fromJson({'hero_cta_ativo': 0}).heroCtaAtivo, isFalse);
    final j = const VitrineConfig(heroCtaAtivo: false).toJson();
    expect(j['hero_cta_ativo'], isFalse);
  });
}
