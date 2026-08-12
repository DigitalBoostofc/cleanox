import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VitrineServico catálogo personalizável', () {
    test('interpreta layout, copy e modo de preço do backend', () {
      final servico = VitrineServico.fromJson({
        'id': 'svc1',
        'nome': 'Sofá 3 lugares',
        'descricao': 'Descrição padrão',
        'grupo': 'sofa',
        'valor_base': 180,
        'vitrine_layout': 'antes_depois',
        'vitrine_titulo': 'Sofá renovado',
        'vitrine_descricao': 'Extração e acabamento.',
        'vitrine_badge': 'Mais escolhido',
        'vitrine_cta': 'Quero este cuidado',
        'vitrine_preco_modo': 'sob_avaliacao',
        'vitrine_ordem': 7,
      });

      expect(servico.layout, VitrineServicoLayout.antesDepois);
      expect(servico.tituloComercial, 'Sofá renovado');
      expect(servico.descricaoComercial, 'Extração e acabamento.');
      expect(servico.vitrineBadge, 'Mais escolhido');
      expect(servico.ctaComercial, 'Quero este cuidado');
      expect(servico.precoModo, VitrinePrecoModo.sobAvaliacao);
      expect(servico.vitrineOrdem, 7);
    });

    test('campos antigos recebem fallback sem perder nome e descrição', () {
      final servico = VitrineServico.fromJson({
        'id': 'old',
        'nome': 'Colchão casal',
        'descricao': 'Limpeza dos dois lados',
        'valor_base': 120,
      });

      expect(servico.layout, VitrineServicoLayout.fotografico);
      expect(servico.tituloComercial, 'Colchão casal');
      expect(servico.descricaoComercial, 'Limpeza dos dois lados');
      expect(servico.ctaComercial, 'Adicionar');
      expect(servico.precoModo, VitrinePrecoModo.aPartirDe);
    });
  });

  group('Vitrine mídia por serviço', () {
    test('agrupa capa e galeria preservando ponto focal', () {
      final bootstrap = VitrineBootstrap(
        config: const VitrineConfig(),
        midia: [
          VitrineMidia.fromJson({
            'id': 'cover',
            'servico': 'svc1',
            'papel': 'capa',
            'url': 'https://cdn/capa.webp',
            'foco_x': 25,
            'foco_y': 70,
          }),
          VitrineMidia.fromJson({
            'id': 'gallery',
            'servico': 'svc1',
            'papel': 'galeria',
            'url': 'https://cdn/galeria.webp',
          }),
          VitrineMidia.fromJson({
            'id': 'other',
            'servico': 'svc2',
            'papel': 'capa',
            'url': 'https://cdn/outra.webp',
          }),
        ],
      );

      expect(bootstrap.capaDoServico('svc1')?.id, 'cover');
      expect(bootstrap.midiaDoServico('svc1').map((m) => m.id), [
        'cover',
        'gallery',
      ]);
      expect(bootstrap.capaDoServico('svc1')?.alignmentX, -0.5);
      expect(bootstrap.capaDoServico('svc1')?.alignmentY, 0.4);
    });
  });

  test('admin serializa apenas configuração comercial editável', () {
    final servico = VitrineAdminServico.fromJson({
      'id': 'svc1',
      'nome': 'Sofá',
      'grupo': 'sofa',
      'valor_base': 180,
      'ativo': true,
      'vitrine': true,
      'vitrine_destaque': true,
      'vitrine_layout': 'destaque',
      'vitrine_titulo': 'Sofá premium',
      'vitrine_descricao': 'Descrição',
      'vitrine_badge': 'Popular',
      'vitrine_cta': 'Adicionar',
      'vitrine_preco_modo': 'valor',
      'vitrine_ordem': 3,
    });

    expect(servico.toPatchJson(), {
      'vitrine': true,
      'vitrine_destaque': true,
      'vitrine_layout': 'destaque',
      'vitrine_titulo': 'Sofá premium',
      'vitrine_descricao': 'Descrição',
      'vitrine_badge': 'Popular',
      'vitrine_cta': 'Adicionar',
      'vitrine_preco_modo': 'valor',
      'vitrine_ordem': 3,
    });
  });
}
