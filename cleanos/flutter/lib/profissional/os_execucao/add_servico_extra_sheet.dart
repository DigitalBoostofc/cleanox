/// add_servico_extra_sheet.dart — Bottom sheet: categoria → grupo → serviço.
///
/// Usado na execução do profissional para adicionar um serviço extra e anexar
/// o checklist padrão dele ao checklist da OS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/servico.dart';
import '../../painel/data/painel_providers.dart';
import '../../painel/servicos/servicos_labels.dart';

/// Abre o sheet e devolve o [ServicoPB] escolhido, ou null se cancelar.
Future<ServicoPB?> showAddServicoExtraSheet(BuildContext context) {
  return showModalBottomSheet<ServicoPB>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AddServicoExtraSheet(),
  );
}

class _AddServicoExtraSheet extends ConsumerStatefulWidget {
  const _AddServicoExtraSheet();

  @override
  ConsumerState<_AddServicoExtraSheet> createState() =>
      _AddServicoExtraSheetState();
}

class _AddServicoExtraSheetState extends ConsumerState<_AddServicoExtraSheet> {
  List<ServicoPB>? _servicos;
  String? _loadError;
  Categoria? _categoria;
  Grupo? _grupo;
  ServicoPB? _selecionado;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(servicosRepositoryProvider).listAtivos();
      if (!mounted) return;
      setState(() {
        _servicos = list;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Não foi possível carregar o catálogo.');
    }
  }

  List<Categoria> get _categorias {
    final s = _servicos;
    if (s == null) return const [];
    final set = <Categoria>{};
    for (final it in s) {
      if (it.categoria != null) set.add(it.categoria!);
    }
    return Categoria.values.where(set.contains).toList();
  }

  List<Grupo> get _grupos {
    final s = _servicos;
    if (s == null || _categoria == null) return const [];
    final set = <Grupo>{};
    for (final it in s) {
      if (it.categoria == _categoria && it.grupo != null) set.add(it.grupo!);
    }
    return Grupo.values.where(set.contains).toList();
  }

  List<ServicoPB> get _filtrados {
    final s = _servicos;
    if (s == null || _categoria == null || _grupo == null) return const [];
    final list = s
        .where((it) => it.categoria == _categoria && it.grupo == _grupo)
        .toList();
    list.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        ClxSpace.x4,
        ClxSpace.x3,
        ClxSpace.x4,
        ClxSpace.x4 + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: clx.line2,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          Text(
            'Adicionar serviço extra',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          Text(
            'Escolha categoria, grupo e o serviço. O checklist dele '
            'aparece em uma seção separada do serviço principal.',
            style: tt.bodySmall?.copyWith(color: clx.ink3, height: 1.35),
          ),
          const SizedBox(height: ClxSpace.x4),
          if (_loadError != null)
            ErrorBanner(message: _loadError!, onRetry: _load)
          else if (_servicos == null)
            const Padding(
              padding: EdgeInsets.all(ClxSpace.x6),
              child: Center(child: Spinner(size: 24)),
            )
          else if (_servicos!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(ClxSpace.x4),
              child: Text(
                'Nenhum serviço ativo no catálogo.',
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
              ),
            )
          else ...[
            _label(context, 'Categoria'),
            const SizedBox(height: ClxSpace.x1),
            DropdownButtonFormField<Categoria>(
              key: ValueKey('cat-${_categoria?.name ?? 'none'}'),
              initialValue: _categoria,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Selecione'),
              items: [
                for (final c in _categorias)
                  DropdownMenuItem(value: c, child: Text(categoriaLabel(c))),
              ],
              onChanged: (v) => setState(() {
                _categoria = v;
                _grupo = null;
                _selecionado = null;
              }),
            ),
            const SizedBox(height: ClxSpace.x3),
            _label(context, 'Grupo'),
            const SizedBox(height: ClxSpace.x1),
            DropdownButtonFormField<Grupo>(
              key: ValueKey(
                'grp-${_categoria?.name ?? 'x'}-${_grupo?.name ?? 'none'}',
              ),
              initialValue: _grupo,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Selecione'),
              items: [
                for (final g in _grupos)
                  DropdownMenuItem(value: g, child: Text(grupoLabel(g))),
              ],
              onChanged: _categoria == null
                  ? null
                  : (v) => setState(() {
                      _grupo = v;
                      _selecionado = null;
                    }),
            ),
            const SizedBox(height: ClxSpace.x3),
            _label(context, 'Serviço'),
            const SizedBox(height: ClxSpace.x1),
            DropdownButtonFormField<ServicoPB>(
              key: ValueKey(
                'svc-${_grupo?.name ?? 'x'}-${_selecionado?.id ?? 'none'}',
              ),
              initialValue: _selecionado,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Selecione'),
              items: [
                for (final s in _filtrados)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.valorBase > 0
                          ? '${s.nome} · ${formatCurrency(s.valorBase)}'
                          : s.nome,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _grupo == null
                  ? null
                  : (v) => setState(() => _selecionado = v),
            ),
            if (_selecionado != null) ...[
              const SizedBox(height: ClxSpace.x3),
              Container(
                padding: const EdgeInsets.all(ClxSpace.x3),
                decoration: BoxDecoration(
                  color: clx.bg2,
                  borderRadius: ClxRadii.rMd,
                  border: Border.all(color: clx.line),
                ),
                child: Text(
                  _selecionado!.checklistPadrao.isEmpty
                      ? 'Este serviço não tem checklist padrão — será '
                          'adicionado um item com o nome do serviço '
                          'em seção própria.'
                      : '${_selecionado!.checklistPadrao.length} item(ns) de '
                          'checklist em seção própria (“${_selecionado!.nome}”).',
                  style: tt.bodySmall?.copyWith(color: clx.ink2, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: ClxSpace.x4),
            Row(
              children: [
                Expanded(
                  child: ClxButton(
                    label: 'Cancelar',
                    variant: ClxButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: ClxSpace.x2),
                Expanded(
                  child: ClxButton(
                    label: 'Salvar',
                    icon: Icons.check_rounded,
                    onPressed: _selecionado == null
                        ? null
                        : () => Navigator.of(context).pop(_selecionado),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.clx.ink2,
      ),
    );
  }
}
