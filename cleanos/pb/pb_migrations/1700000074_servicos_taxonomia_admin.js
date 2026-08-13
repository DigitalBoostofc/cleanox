/// <reference path="../pb_data/types.d.ts" />
/**
 * Taxonomia editável: coleção `servicos_taxonomia`.
 * Converte `servicos.categoria` / `grupo` de select → text (remove + recria,
 * sem reutilizar o mesmo field id — PB não permite trocar type no lugar).
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

    // ── servicos: select → text (categoria / grupo) ─────────────────────────
    const servicos = app.findCollectionByNameOrId('servicos');
    let mudou = false;

    function selectToText(name, max) {
      const f = servicos.fields.getByName(name);
      if (!f) return;
      if (f.type === 'text') return;
      // Snapshot valores atuais antes de trocar o schema.
      let rows = [];
      try {
        rows = app.findRecordsByFilter('servicos', '', '', 500, 0) || [];
      } catch (_) {
        rows = [];
      }
      const keep = {};
      for (let i = 0; i < rows.length; i++) {
        keep[rows[i].id] = rows[i].getString(name) || '';
      }
      servicos.fields.removeById(f.id);
      servicos.fields.add(
        new TextField({ name: name, required: false, max: max || 80 }),
      );
      app.save(servicos);
      // Regrava valores
      for (const id of Object.keys(keep)) {
        try {
          const r = app.findRecordById('servicos', id);
          r.set(name, keep[id]);
          app.save(r);
        } catch (_) {}
      }
      mudou = true;
    }

    // Só converte se ainda for select (idempotente se já text).
    try {
      selectToText('categoria', 80);
    } catch (e) {
      console.log('categoria→text: ' + e);
    }
    // re-fetch collection after possible save
    const servicos2 = app.findCollectionByNameOrId('servicos');
    function selectToText2(name, max) {
      const f = servicos2.fields.getByName(name);
      if (!f) return;
      if (f.type === 'text') return;
      let rows = [];
      try {
        rows = app.findRecordsByFilter('servicos', '', '', 500, 0) || [];
      } catch (_) {
        rows = [];
      }
      const keep = {};
      for (let i = 0; i < rows.length; i++) {
        keep[rows[i].id] = rows[i].getString(name) || '';
      }
      servicos2.fields.removeById(f.id);
      servicos2.fields.add(
        new TextField({ name: name, required: false, max: max || 80 }),
      );
      app.save(servicos2);
      for (const id of Object.keys(keep)) {
        try {
          const r = app.findRecordById('servicos', id);
          r.set(name, keep[id]);
          app.save(r);
        } catch (_) {}
      }
    }
    try {
      selectToText2('grupo', 80);
    } catch (e) {
      console.log('grupo→text: ' + e);
    }

    const servicos3 = app.findCollectionByNameOrId('servicos');
    if (!servicos3.fields.getByName('subgrupo')) {
      servicos3.fields.add(
        new TextField({ name: 'subgrupo', required: false, max: 80 }),
      );
      app.save(servicos3);
    }

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
      c.fields.add(new TextField({ name: 'slug', required: true, max: 80 }));
      c.fields.add(new TextField({ name: 'nome', required: true, max: 120 }));
      c.fields.add(new TextField({ name: 'parent', required: false, max: 32 }));
      c.fields.add(new NumberField({ name: 'ordem', required: false, min: 0 }));
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
      const residencial = add('categoria', 'residencial', 'Residencial', '', 20);

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
