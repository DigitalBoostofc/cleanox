/// Vitrine pública — UI alinhada aos mockups mobile Cleanox (sem conta).
///
/// Fluxo: 0 home · 1 serviços · 2 contato · 3 orçamento+bumps · 4 agenda · 5 ok
///         6 como funciona
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';
import '../widgets/vitrine_ui.dart';

class VitrineHomeScreen extends StatefulWidget {
  const VitrineHomeScreen({super.key});

  @override
  State<VitrineHomeScreen> createState() => _VitrineHomeScreenState();
}

class _VitrineHomeScreenState extends State<VitrineHomeScreen> {
  /// 0 home · 1 serviços · 2 dados · 3 orçamento · 4 agenda · 5 sucesso · 6 como
  int _step = 0;
  late Future<List<VitrineServico>> _catalogFuture;
  final _selected = <String>{};
  final _selectedBumps = <String>{};
  List<VitrineServico> _catalog = const [];
  List<VitrineOrderBump> _bumps = const [];
  VitrineConfig _config = const VitrineConfig();
  Map<String, String> _midia = const {};
  List<String> _cidades = const [];
  String _estado = '';
  bool _loadingBumps = false;

  final _nome = TextEditingController();
  final _whatsapp = TextEditingController();
  final _endereco = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _obs = TextEditingController();
  final _honeypot = TextEditingController();

  DateTime? _dia;
  List<VitrineSlot> _slots = const [];
  VitrineSlot? _slot;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;
  VitrineAgendarResult? _ok;
  String? _groupFilter;

  @override
  void initState() {
    super.initState();
    _catalogFuture = vitrineApiProvider.listServicos();
    vitrineApiProvider.bootstrap().then((b) {
      if (!mounted) return;
      setState(() {
        _config = b.config;
        _midia = b.midiaByChave;
        _cidades = b.cidades;
        _estado = b.estado;
        // Pré-seleciona cidade se só houver uma, ou se o campo estiver vazio.
        if (_cidade.text.trim().isEmpty && b.cidades.length == 1) {
          _cidade.text = b.cidades.first;
        }
      });
    }).catchError((_) {
      return vitrineApiProvider.getConfig().then((c) {
        if (mounted) setState(() => _config = c);
      });
    });
  }

  String? _midiaUrl(String chave) {
    final u = _midia[chave.toLowerCase()];
    if (u == null || u.isEmpty) return null;
    return u;
  }

  @override
  void dispose() {
    _nome.dispose();
    _whatsapp.dispose();
    _endereco.dispose();
    _bairro.dispose();
    _cidade.dispose();
    _obs.dispose();
    _honeypot.dispose();
    super.dispose();
  }

  List<VitrineServico> get _picked =>
      _catalog.where((s) => _selected.contains(s.id)).toList();

  List<VitrineOrderBump> get _pickedBumps =>
      _bumps.where((b) => _selectedBumps.contains(b.id)).toList();

  double get _subtotalServicos =>
      _picked.fold<double>(0, (s, x) => s + x.valorBase);

  double get _totalBumps =>
      _pickedBumps.fold<double>(0, (s, x) => s + x.precoPromo);

  double get _total => _subtotalServicos + _totalBumps;

  int get _duracaoMin {
    final sum = _picked.fold<int>(
      0,
      (s, x) => s + (x.tempoMedioMin > 0 ? x.tempoMedioMin : 60),
    );
    var extra = 0;
    for (final b in _pickedBumps) {
      VitrineServico? s;
      for (final c in _catalog) {
        if (c.id == b.servicoOferta) {
          s = c;
          break;
        }
      }
      extra += s != null && s.tempoMedioMin > 0 ? s.tempoMedioMin : 30;
    }
    final t = sum + extra;
    return t > 0 ? t : 60;
  }

  String get _primaryId {
    if (_picked.isEmpty) return '';
    final sorted = [..._picked]
      ..sort((a, b) => b.valorBase.compareTo(a.valorBase));
    return sorted.first.id;
  }

  void _go(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    if (step == 3) _loadBumps();
  }

  Future<void> _loadBumps() async {
    if (_picked.isEmpty) {
      setState(() {
        _bumps = const [];
        _selectedBumps.clear();
      });
      return;
    }
    setState(() => _loadingBumps = true);
    try {
      final list = await vitrineApiProvider.orderBumps(
        _picked.map((s) => s.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _bumps = list;
        _selectedBumps.removeWhere((id) => !list.any((b) => b.id == id));
        _loadingBumps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bumps = const [];
        _loadingBumps = false;
      });
    }
  }

  Future<void> _loadSlots(DateTime day) async {
    setState(() {
      _loadingSlots = true;
      _slots = const [];
      _slot = null;
      _error = null;
    });
    try {
      final list = await vitrineApiProvider.slots(
        servicoId: _primaryId,
        dataYmd: _ymd(day),
        duracaoMin: _duracaoMin,
      );
      if (!mounted) return;
      setState(() {
        _slots = list;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _error = '$e';
      });
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_slot == null || _dia == null || _picked.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await vitrineApiProvider.agendar({
        'slot_token': _slot!.token,
        'nome': _nome.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'telefone': _whatsapp.text.trim(),
        'endereco': _endereco.text.trim(),
        'bairro': _bairro.text.trim().isNotEmpty
            ? _bairro.text.trim()
            : _endereco.text.trim(),
        'cidade': _cidade.text.trim(),
        'observacoes': _obs.text.trim(),
        'website': _honeypot.text,
        'itens': [
          for (final s in _picked)
            {'id': s.id, 'nome': s.nome, 'valor': s.valorBase},
          for (final b in _pickedBumps)
            {
              'id': b.servicoOferta,
              'nome': b.titulo,
              'valor': b.precoPromo,
              'order_bump_id': b.id,
            },
        ],
      });
      if (!mounted) return;
      setState(() {
        _ok = res;
        _submitting = false;
        _step = 5;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$e';
      });
    }
  }

  bool get _dadosOk =>
      _nome.text.trim().isNotEmpty &&
      _whatsapp.text.replaceAll(RegExp(r'\D'), '').length >= 10 &&
      _endereco.text.trim().isNotEmpty &&
      (_cidades.isEmpty || _cidade.text.trim().isNotEmpty);

  int get _navIndex {
    if (_step == 0) return 0;
    if (_step == 6) return 2;
    if (_step >= 1 && _step <= 4) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitrineUi.bg,
      body: FutureBuilder<List<VitrineServico>>(
        future: _catalogFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Não foi possível carregar os serviços.\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        _catalogFuture = vitrineApiProvider.listServicos();
                      }),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
            );
          }
          _catalog = snap.data ?? const [];

          if (_step == 5 && _ok != null) {
            return _SuccessBody(
              result: _ok!,
              onHome: () => setState(() {
                _ok = null;
                _selected.clear();
                _selectedBumps.clear();
                _step = 0;
              }),
            );
          }

          return Column(
            children: [
              if (_step == 0 || _step == 6)
                VitrineLightTopBar(whatsapp: _config.whatsappExibido)
              else if (_step >= 1 && _step <= 4)
                VitrineNavyHeader(
                  stepLabel: switch (_step) {
                    1 => '1 · Serviços',
                    2 => '2 · Contato',
                    3 => '3 · Orçamento',
                    4 => '4 · Agendar',
                    _ => '',
                  },
                  onBack: () => _go(_step == 1 ? 0 : _step - 1),
                ),
              if (_error != null)
                Material(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _error = null),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: _body()),
              if (_step == 1)
                VitrineStickyBar(
                  totalLabel:
                      '${_picked.length} item${_picked.length == 1 ? '' : 's'} selecionado${_picked.length == 1 ? '' : 's'}',
                  totalValue: 'TOTAL ${formatCurrency(_total)}',
                  buttonLabel: 'Continuar',
                  onPressed: _picked.isEmpty ? null : () => _go(2),
                )
              else if (_step == 2)
                VitrineStickyBar(
                  buttonLabel: 'Ver orçamento',
                  onPressed: _dadosOk ? () => _go(3) : null,
                )
              else if (_step == 3)
                VitrineStickyBar(
                  totalLabel: 'Total agora',
                  totalValue: formatCurrency(_total),
                  buttonLabel: 'Escolher data e horário',
                  onPressed: () => _go(4),
                )
              else if (_step == 4)
                VitrineStickyBar(
                  buttonLabel: 'Confirmar agendamento',
                  loading: _submitting,
                  onPressed: _slot != null ? _submit : null,
                )
              else if (_step == 0 || _step == 6)
                VitrineBottomNav(
                  index: _navIndex,
                  onTap: (i) {
                    if (i == 0) _go(0);
                    if (i == 1) _go(1);
                    if (i == 2) _go(6);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _home();
      case 1:
        return _servicos();
      case 2:
        return _dados();
      case 3:
        return _orcamento();
      case 4:
        return _agenda();
      case 6:
        return _comoFunciona();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Home (mockup C1) ─────────────────────────────────────────────────────

  Widget _home() {
    final destaques =
        _catalog.where((s) => s.vitrineDestaque).take(8).toList();
    final pkgs = destaques.isNotEmpty ? destaques : _catalog.take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Olá 👋',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          kAppTagline,
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        VitrineHeroCard(
          title: _config.heroTitulo,
          subtitle: _config.heroSubtitulo,
          cta: _config.heroCta,
          onCta: () => _go(1),
          imageUrl: _midiaUrl('hero') ?? _midiaUrl('capa'),
        ),
        const SizedBox(height: 22),
        const Text(
          'O que higienizamos',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 12),
        VitrineCategoryGrid(
          items: [
            VitrineCatItem(
              icon: Icons.weekend_outlined,
              label: 'Sofá',
              filter: 'sofa',
              imageUrl: _midiaUrl('categoria_sofa') ?? _midiaUrl('sofa'),
            ),
            VitrineCatItem(
              icon: Icons.bed_outlined,
              label: 'Colchão',
              filter: 'colchao',
              imageUrl: _midiaUrl('categoria_colchao') ?? _midiaUrl('colchao'),
            ),
            VitrineCatItem(
              icon: Icons.chair_outlined,
              label: 'Poltrona',
              filter: 'poltrona',
              imageUrl:
                  _midiaUrl('categoria_poltrona') ?? _midiaUrl('poltrona'),
            ),
            VitrineCatItem(
              icon: Icons.layers_outlined,
              label: 'Tapete',
              filter: 'tapete',
              imageUrl: _midiaUrl('categoria_tapete') ?? _midiaUrl('tapete'),
            ),
            VitrineCatItem(
              icon: Icons.directions_car_outlined,
              label: 'Automóvel',
              filter: 'auto',
              imageUrl: _midiaUrl('categoria_auto') ?? _midiaUrl('automovel'),
            ),
            VitrineCatItem(
              icon: Icons.auto_awesome,
              label: 'Impermeab.',
              filter: 'imper',
              imageUrl:
                  _midiaUrl('categoria_imper') ?? _midiaUrl('impermeabilizacao'),
            ),
            VitrineCatItem(
              icon: Icons.event_seat_outlined,
              label: 'Cadeira',
              filter: 'cadeira',
              imageUrl:
                  _midiaUrl('categoria_cadeira') ?? _midiaUrl('cadeira'),
            ),
            const VitrineCatItem(
              icon: Icons.add,
              label: 'Mais',
            ),
          ],
          onTap: (f) {
            setState(() => _groupFilter = f);
            _go(1);
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pacotes em destaque',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ClxBrand.navy,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _go(1),
              child: const Text(
                'Ver todos',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w600,
                  color: ClxBrand.cyan,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pkgs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = pkgs[i];
              return Container(
                width: 148,
                padding: const EdgeInsets.all(14),
                decoration: VitrineUi.cardDeco(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ClxBrand.navy,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'a partir de',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 11,
                        color: ClxBrand.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ClxBrand.cyan.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(VitrineUi.rPill),
                      ),
                      child: Text(
                        formatCurrency(s.valorBase),
                        style: const TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ClxBrand.primary2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_config.cidadesTexto.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Atendemos: ${_config.cidadesTexto}',
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              color: ClxBrand.muted,
            ),
          ),
        ],
        if (_config.rodapeMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _config.rodapeMsg,
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              color: ClxBrand.muted,
            ),
          ),
        ],
      ],
    );
  }

  // ─── Serviços (mockup C2) ─────────────────────────────────────────────────

  Widget _servicos() {
    var list = List<VitrineServico>.from(_catalog);
    if (_groupFilter != null && _groupFilter!.isNotEmpty) {
      final f = _groupFilter!.toLowerCase();
      final filtered = list.where((s) {
        final g = s.grupo.toLowerCase();
        final n = s.nome.toLowerCase();
        final c = s.categoria.toLowerCase();
        return g.contains(f) || n.contains(f) || c.contains(f);
      }).toList();
      if (filtered.isNotEmpty) list = filtered;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'O que precisa higienizar?',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Selecione um ou mais itens para orçar',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            color: ClxBrand.muted,
          ),
        ),
        if (_groupFilter != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              label: Text('Filtro: $_groupFilter · limpar'),
              onPressed: () => setState(() => _groupFilter = null),
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (final s in list)
          VitrineServiceRow(
            nome: s.nome,
            descricao: s.descricao,
            preco: formatCurrency(s.valorBase),
            selected: _selected.contains(s.id),
            onTap: () => setState(() {
              if (_selected.contains(s.id)) {
                _selected.remove(s.id);
              } else {
                _selected.add(s.id);
              }
            }),
          ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nenhum serviço disponível no momento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ClxBrand.muted),
            ),
          ),
      ],
    );
  }

  // ─── Contato (mockup C3) ──────────────────────────────────────────────────

  Widget _dados() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Para onde vamos?',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Só para confirmar o atendimento — sem criar conta',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            color: ClxBrand.muted,
          ),
        ),
        const SizedBox(height: 16),
        VitrineField(
          label: 'Nome completo',
          controller: _nome,
          onChanged: (_) => setState(() {}),
        ),
        VitrineField(
          label: 'WhatsApp',
          controller: _whatsapp,
          keyboard: TextInputType.phone,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        VitrineField(
          label: 'Endereço do serviço',
          controller: _endereco,
          onChanged: (_) => setState(() {}),
        ),
        VitrineField(
          label: 'Bairro',
          controller: _bairro,
          onChanged: (_) => setState(() {}),
        ),
        if (_cidades.isNotEmpty) ...[
          const Text(
            'Cidade / região',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D4F63),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _cidades.contains(_cidade.text.trim())
                ? _cidade.text.trim()
                : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rMd),
                borderSide: const BorderSide(color: VitrineUi.line, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rMd),
                borderSide: const BorderSide(color: VitrineUi.line, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rMd),
                borderSide: const BorderSide(color: ClxBrand.cyan, width: 1.5),
              ),
            ),
            hint: Text(
              _estado.isEmpty ? 'Selecione a cidade' : 'Cidade — $_estado',
              style: const TextStyle(fontFamily: kFontFamily, fontSize: 14),
            ),
            items: [
              for (final c in _cidades)
                DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(fontFamily: kFontFamily)),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cidade.text = v);
            },
          ),
          const SizedBox(height: 14),
        ] else
          VitrineField(
            label: 'Cidade',
            controller: _cidade,
            onChanged: (_) => setState(() {}),
          ),
        VitrineField(
          label: 'Observações (opcional)',
          controller: _obs,
          maxLines: 3,
        ),
        Opacity(
          opacity: 0,
          child: SizedBox(height: 0, child: TextField(controller: _honeypot)),
        ),
        const Text(
          'Não pedimos senha. Usamos o WhatsApp só para confirmar o horário. '
          'Seus dados ficam com a Cleanox — o profissional não vê telefone.',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 12,
            color: ClxBrand.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Orçamento + bumps (mockup C4) ────────────────────────────────────────

  Widget _orcamento() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Seu orçamento',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Base + ofertas de acordo com o que você marcou',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            color: ClxBrand.muted,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VitrineUi.rLg),
            border: Border.all(color: VitrineUi.line),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ClxBrand.navy, ClxBrand.accent2],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total estimado',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      formatCurrency(_total),
                      style: const TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              for (final s in _picked)
                _sumRow(s.nome, s.descricao, formatCurrency(s.valorBase)),
              for (final b in _pickedBumps)
                _sumRow(
                  '+ ${b.titulo}',
                  'Oferta · order bump',
                  formatCurrency(b.precoPromo),
                ),
              _sumRow(
                'Cliente',
                '${_nome.text.trim()} · ${_bairro.text.trim().isEmpty ? _endereco.text.trim() : _bairro.text.trim()}',
                'OK',
                mutedValue: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingBumps)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_bumps.isNotEmpty) ...[
          const Text(
            'Aproveite no seu orçamento',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ClxBrand.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ofertas montadas de acordo com o carrinho',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              color: ClxBrand.muted,
            ),
          ),
          const SizedBox(height: 10),
          for (final b in _bumps) _bumpCard(b),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ClxBrand.cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(VitrineUi.rMd),
            border: Border.all(color: ClxBrand.cyan.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ClxBrand.cyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pagamento no local\nDébito, crédito ou Pix na maquininha Cleanox. Sem link online.',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 12,
                    color: VitrineUi.ink2,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sumRow(
    String title,
    String sub,
    String value, {
    bool mutedValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VitrineUi.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: ClxBrand.navy,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: const TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 11,
                      color: ClxBrand.muted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: mutedValue ? ClxBrand.muted : ClxBrand.cyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bumpCard(VitrineOrderBump b) {
    final on = _selectedBumps.contains(b.id);
    final foto = b.fotoUrl.isNotEmpty
        ? b.fotoUrl
        : (_midiaUrl('bump_${b.id}') ??
            _midiaUrl('bump_${b.servicoOferta}') ??
            '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on
            ? ClxBrand.cyan.withValues(alpha: 0.06)
            : const Color(0xFFF0FBFC),
        borderRadius: BorderRadius.circular(VitrineUi.rMd),
        child: InkWell(
          onTap: () => setState(() {
            if (on) {
              _selectedBumps.remove(b.id);
            } else {
              _selectedBumps.add(b.id);
            }
          }),
          borderRadius: BorderRadius.circular(VitrineUi.rMd),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VitrineUi.rMd),
              border: Border.all(
                color: ClxBrand.cyan,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (foto.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      foto,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.badge.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius:
                                BorderRadius.circular(VitrineUi.rPill),
                          ),
                          child: Text(
                            b.badge,
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text(
                        b.titulo,
                        style: const TextStyle(
                          fontFamily: kFontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: ClxBrand.navy,
                        ),
                      ),
                      if (b.descricao.isNotEmpty)
                        Text(
                          b.descricao,
                          style: const TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 11,
                            color: ClxBrand.muted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (b.precoCheio > b.precoPromo)
                            Text(
                              formatCurrency(b.precoCheio),
                              style: const TextStyle(
                                fontFamily: kFontFamily,
                                decoration: TextDecoration.lineThrough,
                                color: ClxBrand.muted,
                                fontSize: 12,
                              ),
                            ),
                          if (b.precoCheio > b.precoPromo)
                            const SizedBox(width: 8),
                          Text(
                            formatCurrency(b.precoPromo),
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              fontWeight: FontWeight.w800,
                              color: ClxBrand.primary2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFF059669) : ClxBrand.cyan,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    on ? Icons.check : Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Agenda (mockup C5) ───────────────────────────────────────────────────

  Widget _agenda() {
    final now = DateTime.now();
    final dias = List.generate(
      14,
      (i) => DateTime(now.year, now.month, now.day + 1 + i),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Escolha o dia e o horário',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dias.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = dias[i];
              final sel = _dia != null &&
                  _dia!.year == d.year &&
                  _dia!.month == d.month &&
                  _dia!.day == d.day;
              return ChoiceChip(
                label: Text(
                  DateFormat('EEE dd/MM', 'pt_BR').format(d),
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: sel ? Colors.white : ClxBrand.navy,
                  ),
                ),
                selected: sel,
                selectedColor: ClxBrand.navy,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: sel ? ClxBrand.navy : VitrineUi.line,
                ),
                onSelected: (_) {
                  setState(() => _dia = d);
                  _loadSlots(d);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingSlots)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_dia == null)
          const Text(
            'Selecione um dia acima.',
            style: TextStyle(color: ClxBrand.muted),
          )
        else if (_slots.isEmpty)
          const Text(
            'Nenhum horário livre neste dia. Tente outra data.',
            style: TextStyle(color: ClxBrand.muted),
          )
        else ...[
          const Text(
            'Horários',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: ClxBrand.navy,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _slots)
                ChoiceChip(
                  label: Text(
                    s.hora,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontWeight: FontWeight.w600,
                      color: _slot?.hora == s.hora
                          ? Colors.white
                          : VitrineUi.ink2,
                    ),
                  ),
                  selected: _slot?.hora == s.hora,
                  selectedColor: ClxBrand.navy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _slot?.hora == s.hora
                        ? ClxBrand.navy
                        : VitrineUi.line,
                  ),
                  onSelected: (_) => setState(() => _slot = s),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          decoration: VitrineUi.cardDeco(),
          child: Column(
            children: [
              _mini('Serviços', _picked.map((s) => s.nome).join(' + ')),
              if (_pickedBumps.isNotEmpty)
                _mini(
                  'Ofertas',
                  _pickedBumps.map((b) => b.titulo).join(' + '),
                ),
              if (_dia != null && _slot != null)
                _mini(
                  'Quando',
                  '${DateFormat('dd/MM').format(_dia!)} · ${_slot!.hora}',
                ),
              _mini('Total', formatCurrency(_total), highlight: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mini(String k, String v, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VitrineUi.line)),
      ),
      child: Row(
        children: [
          Text(
            k,
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 13,
              color: VitrineUi.ink2,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? ClxBrand.cyan : ClxBrand.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Como funciona ────────────────────────────────────────────────────────

  Widget _comoFunciona() {
    final text = _config.comoFunciona.isNotEmpty
        ? _config.comoFunciona
        : '1) Selecione os serviços\n'
            '2) Informe contato e endereço\n'
            '3) Veja o orçamento e ofertas\n'
            '4) Escolha data e horário\n'
            '5) Confirmamos no WhatsApp';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Como funciona',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: VitrineUi.cardDeco(radius: VitrineUi.rLg),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 14,
              height: 1.55,
              color: VitrineUi.ink2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => _go(1),
            style: FilledButton.styleFrom(
              backgroundColor: ClxBrand.cyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VitrineUi.rPill),
              ),
            ),
            child: const Text('Montar orçamento'),
          ),
        ),
      ],
    );
  }
}

// ─── Sucesso (mockup C6) ────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.result, required this.onHome});
  final VitrineAgendarResult result;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 36,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Agendamento recebido!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ClxBrand.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                color: ClxBrand.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              decoration: VitrineUi.cardDeco(radius: VitrineUi.rLg),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _kv('Protocolo', result.osRef),
                  _kv('Serviço', result.servico),
                  _kv(
                    'Data',
                    () {
                      try {
                        return DateFormat('dd/MM/yyyy')
                            .format(DateTime.parse(result.data));
                      } catch (_) {
                        return result.data;
                      }
                    }(),
                  ),
                  _kv('Horário', result.hora),
                  if (result.valor > 0)
                    _kv('Total', formatCurrency(result.valor)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClxBrand.navy,
                  side: const BorderSide(color: VitrineUi.line, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VitrineUi.rPill),
                  ),
                ),
                child: const Text(
                  'Voltar ao início',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                k,
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 13,
                  color: ClxBrand.muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w700,
                  color: ClxBrand.navy,
                ),
              ),
            ),
          ],
        ),
      );
}
