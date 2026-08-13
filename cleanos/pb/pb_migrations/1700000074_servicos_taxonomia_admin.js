/// <reference path="../pb_data/types.d.ts" />
/**
 * Taxonomia editável de serviços: Categoria → Grupo → Subgrupo.
 * Coleção `servicos_taxonomia` (cofre admin/gerente).
 * `servicos.categoria` / `grupo` viram texto livre (slug da taxonomia).
 */
migrate(
  (app) => {
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    function tryFind(nameOrId) {
      try {
        return app.findCollectionByNameOrId(nameOrId);
      } catch (_) {
        return null;
      }
    }

    // ── servicos: categoria/grupo como texto (permite novos slugs) ──────────
    const servicos = app.findCollectionByNameOrId('servicos');
    let mudou = false;

    function toText(name, max) {
      const f = servicos.fields.getByName(name);
      if (!f) return;
      if (f.type === 'text') return;
      const id = f.id;
      servicos.fields.removeById(id);
      servicos.fields.add(
        new TextField({ id: id, name: name, required: false, max: max || 80 }),
      );
      mudou = true;
    }
    toText('categoria', 80);
    toText('grupo', 80);
    if (!servicos.fields.getByName('subgrupo')) {
      servicos.fields.add(
        new TextField({ name: 'subgrupo', required: false, max: 80 }),
      );
      mudou = true;
    }
    if (mudou) app.save(servicos);

    // ── coleção taxonomia ───────────────────────────────────────────────────
    if (!tryFind('servtaxonomia0001') && !tryFind('servicos_taxonomia')) {
      const c = new Collection({
        type: 'base',
        name: 'servicos_taxonomia',
        id: 'servtaxonomia0001',
      });
      c.fields.add(
        new SelectField({
          name: 'tipo',
          required: true,
          maxSelect: 1,
          values: ['categoria', 'grupo', 'subgrupo'],
        }),
      );
      c.fields.add(
        new TextField({ name: 'slug', required: true, max: 80 }),
      );
      c.fields.add(
        new TextField({ name: 'nome', required: true, max: 120 }),
      );
      // parent: id do nó pai (categoria←grupo, grupo←subgrupo). Vazio na categoria.
      c.fields.add(
        new TextField({ name: 'parent', required: false, max: 32 }),
      );
      c.fields.add(
        new NumberField({ name: 'ordem', required: false, min: 0 }),
      );
      c.fields.add(new BoolField({ name: 'ativo', required: false }));
      c.fields.add(
        new AutodateField({ name: 'created', onCreate: true, onUpdate: false }),
      );
      c.fields.add(
        new AutodateField({ name: 'updated', onCreate: true, onUpdate: true }),
      );
      c.listRule = COFRE;
      c.viewRule = COFRE;
      c.createRule = COFRE;
      c.updateRule = COFRE;
      c.deleteRule = COFRE;
      app.save(c);
    }

    // ── seed se vazio ───────────────────────────────────────────────────────
    try {
      const col = app.findCollectionByNameOrId('servicos_taxonomia');
      const existentes = app.findRecordsByFilter(
        'servicos_taxonomia',
        '',
        '',
        1,
        0,
      );
      if (existentes && existentes.length > 0) return;

      function add(tipo, slug, nome, parent, ordem) {
        const r = new Record(col);
        r.set('tipo', tipo);
        r.set('slug', slug);
        r.set('nome', nome);
        r.set('parent', parent || '');
        r.set('ordem', ordem || 0);
        r.set('ativo', true);
        app.save(r);
        return r.id;
      }

      const veicular = add('categoria', 'veicular', 'Veicular', '', 10);
      const residencial = add(
        'categoria',
        'residencial',
        'Residencial',
        '',
        20,
      );

      const gPlano = add('grupo', 'plano', 'Plano', veicular, 10);
      const gPromo = add('grupo', 'promocao', 'Promoção', veicular, 20);
      const gAdic = add('grupo', 'adicional', 'Adicional', veicular, 30);
      const gAvul = add('grupo', 'avulsos', 'Avulsos', veicular, 40);

      add('subgrupo', 'essencial', 'Essencial', gPlano, 10);
      add('subgrupo', 'completo', 'Completo', gPlano, 20);
      add('subgrupo', 'premium', 'Premium', gPlano, 30);

      add('subgrupo', 'completo_promo', 'Completo (promo)', gPromo, 10);
      add('subgrupo', 'premium_promo', 'Premium (promo)', gPromo, 20);

      add('subgrupo', 'muito_sujo', 'Veículo muito sujo', gAdic, 10);
      add('subgrupo', 'deslocamento', 'Taxa de deslocamento', gAdic, 20);
      add('subgrupo', 'outro_adicional', 'Outro adicional', gAdic, 30);

      add('subgrupo', 'bancos', 'Bancos', gAvul, 10);
      add('subgrupo', 'teto', 'Teto', gAvul, 20);
      add('subgrupo', 'cintos', 'Cintos', gAvul, 30);
      add('subgrupo', 'forros_porta', 'Forros de porta', gAvul, 40);
      add('subgrupo', 'painel', 'Painel / plásticos', gAvul, 50);
      add('subgrupo', 'carpete', 'Carpete / porta-malas / tapetes', gAvul, 60);
      add('subgrupo', 'outro_avulso', 'Outro avulso', gAvul, 70);

      const gSofa = add('grupo', 'sofa', 'Sofá', residencial, 10);
      const gColch = add('grupo', 'colchao', 'Colchão', residencial, 20);
      const gOut = add('grupo', 'outros', 'Outros', residencial, 30);

      add('subgrupo', 'sofa_2', '2 lugares', gSofa, 10);
      add('subgrupo', 'sofa_3', '3 lugares', gSofa, 20);
      add('subgrupo', 'sofa_4', '4 lugares', gSofa, 30);
      add('subgrupo', 'sofa_56', '5/6 lugares', gSofa, 40);
      add('subgrupo', 'sofa_retratil', 'Retrátil', gSofa, 50);
      add('subgrupo', 'sofa_outro', 'Outro sofá', gSofa, 60);

      add('subgrupo', 'solteiro', 'Solteiro', gColch, 10);
      add('subgrupo', 'casal', 'Casal', gColch, 20);
      add('subgrupo', 'queen', 'Queen', gColch, 30);
      add('subgrupo', 'king', 'King', gColch, 40);
      add('subgrupo', 'box_solteiro', 'Cama box solteiro', gColch, 50);
      add('subgrupo', 'box_casal', 'Cama box casal', gColch, 60);
      add('subgrupo', 'colchao_outro', 'Outro colchão/box', gColch, 70);

      add('subgrupo', 'poltrona', 'Poltrona', gOut, 10);
      add('subgrupo', 'cadeira', 'Cadeira', gOut, 20);
      add('subgrupo', 'puff', 'Puff', gOut, 30);
      add('subgrupo', 'tapete', 'Tapete', gOut, 40);
      add('subgrupo', 'resid_outro', 'Outro', gOut, 50);
    } catch (e) {
      console.log('seed servicos_taxonomia: ' + e);
    }
  },
  (app) => {
    try {
      const c = app.findCollectionByNameOrId('servicos_taxonomia');
      if (c) app.delete(c);
    } catch (_) {}
  },
);
