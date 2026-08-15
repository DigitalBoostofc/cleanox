/// Vitrine pública — autoagendamento Cleanox (sem conta).
///
/// Fluxo: 0 home (guiado cat→grupo→catálogo) · 1 serviços · 2 data/hora
///         · 3 dados · 4 revisar · 5 ok · 6 como funciona
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';
import '../vitrine_booking.dart';
import '../vitrine_porte.dart';
import '../widgets/vitrine_catalogo_personalizavel.dart';
import '../widgets/vitrine_ui.dart';

class VitrineHomeScreen extends StatefulWidget {
  const VitrineHomeScreen({super.key, this.api});

  /// Injetável em testes; produção usa [vitrineApiProvider].
  final VitrineApi? api;

  @override
  State<VitrineHomeScreen> createState() => _VitrineHomeScreenState();
}

class _VitrineHomeScreenState extends State<VitrineHomeScreen> {
  /// 0 home · 1 serviços · 2 agenda · 3 dados · 4 revisar · 5 sucesso · 6 como
  int _step = 0;
  late Future<List<VitrineServico>> _catalogFuture;
  final _selected = <String>{};
  final _selectedBumps = <String>{};
  List<VitrineServico> _catalog = const [];
  List<VitrineOrderBump> _bumps = const [];
  VitrineConfig _config = const VitrineConfig();
  VitrineBootstrap _bootstrap = const VitrineBootstrap(
    config: VitrineConfig(),
    midia: [],
  );
  Map<String, String> _midia = const {};
  List<String> _cidades = const [];
  String _estado = '';
  bool _loadingBumps = false;

  final _nome = TextEditingController();
  final _whatsapp = TextEditingController();
  final _cep = TextEditingController();
  final _rua = TextEditingController();
  final _numero = TextEditingController();
  final _complemento = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _obs = TextEditingController();
  final _honeypot = TextEditingController();

  DateTime? _dia;
  List<VitrineSlot> _slots = const [];
  VitrineSlot? _slot;
  bool _loadingSlots = false;
  bool _submitting = false;
  bool _cepLoading = false;
  String? _cepWarning;
  String? _error;
  VitrineAgendarResult? _ok;
  String? _categoriaFilter; // residencial | veicular (macro)
  String? _familiaFilter; // grupo: sofa | plano | …
  /// 0 categorias · 1 grupos · 2 catálogo filtrado
  int _homeBrowse = 0;
  String? _buscaFilter; // texto do “Buscar serviço”
  String? _idempotencyKey;
  int _duracaoNoSlot = 0;

  VitrineApi get _api => widget.api ?? vitrineApiProvider;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _api.listServicos();
    _api
        .bootstrap()
        .then((b) {
          if (!mounted) return;
          setState(() {
            _bootstrap = b;
            _config = b.config;
            _midia = b.midiaByChave;
            _cidades = b.cidades;
            _estado = b.estado;
            if (_cidade.text.trim().isEmpty && b.cidades.length == 1) {
              _cidade.text = b.cidades.first;
            }
            if (_estado.isEmpty && b.estado.isNotEmpty) {
              _estado = b.estado;
            }
          });
        })
        .catchError((_) {
          return _api.getConfig().then((c) {
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
    _cep.dispose();
    _rua.dispose();
    _numero.dispose();
    _complemento.dispose();
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

  void _invalidateSlot({bool clearDia = false}) {
    _slot = null;
    _slots = const [];
    _duracaoNoSlot = 0;
    if (clearDia) _dia = null;
  }

  void _go(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    if (step == 4) _loadBumps();
  }

  /// FAB Carrinho → sheet com itens + Continuar (ou aviso se vazio).
  Future<void> _openCarrinho() async {
    if (_picked.isEmpty) {
      setState(() {
        _error = 'Adicione ao menos um serviço ao carrinho.';
      });
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CarrinhoSheet(
          items: List<VitrineServico>.from(_picked),
          onRemove: (s) {
            setState(() {
              _selected.remove(s.id);
              _error = null;
            });
          },
          onContinuar: () {
            Navigator.of(ctx).pop();
            if (_picked.isNotEmpty) _go(2);
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  String? _macroOf(VitrineServico s) => vitrineMacroCategoriaOf(
        categoria: s.categoria,
        grupo: s.grupo,
        nome: s.nome,
      );

  bool _matchBusca(VitrineServico s) => vitrineMatchesBuscaNome(
        nome: s.nome,
        tituloComercial: s.tituloComercial,
        query: _buscaFilter ?? '',
      );

  List<VitrineServico> _sortedServicos(Iterable<VitrineServico> list) {
    final out = list.toList();
    out.sort((a, b) {
      final o = a.vitrineOrdem.compareTo(b.vitrineOrdem);
      if (o != 0) return o;
      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
    return out;
  }

  void _toggleServico(VitrineServico servico) {
    final vars = variantesPorteDoCard(servico, _catalog);
    if (vars != null) {
      final noCarrinho = vars.where((v) => _selected.contains(v.id)).toList();
      if (noCarrinho.isNotEmpty) {
        setState(() {
          for (final v in noCarrinho) {
            _selected.remove(v.id);
          }
          _invalidateSlot();
        });
        return;
      }
      _abrirPorte(servico, vars);
      return;
    }
    setState(() {
      if (_selected.contains(servico.id)) {
        _selected.remove(servico.id);
      } else {
        _selected.add(servico.id);
      }
      _invalidateSlot();
    });
  }

  Future<void> _abrirPorte(
    VitrineServico card,
    List<VitrineServico> vars,
  ) async {
    final escolhido = await showVitrinePorteSheet(
      context,
      titulo: card.tituloComercial,
      variantes: vars,
    );
    if (!mounted || escolhido == null) return;
    setState(() {
      _selected.add(escolhido.id);
      _invalidateSlot();
    });
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
      final list = await _api.orderBumps(_picked.map((s) => s.id).toList());
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
      _duracaoNoSlot = _duracaoMin;
    });
    try {
      final list = await _api.slots(
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

  String _newIdempotencyKey() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _applyPhoneMask(TextEditingController c, String raw) {
    final masked = maskPhoneBR(raw);
    if (masked == c.text) return;
    c.value = TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  void _applyCepMask(TextEditingController c, String raw) {
    final masked = maskCEP(raw);
    if (masked == c.text) return;
    c.value = TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  /// ViaCEP: completa rua/bairro/cidade/UF ao digitar 8 dígitos.
  Future<void> _handleCep(String raw) async {
    _applyCepMask(_cep, raw);
    if (_cepWarning != null) setState(() => _cepWarning = null);
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    setState(() => _cepLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://viacep.com.br/ws/$digits/json/'),
      );
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['erro'] == true) {
        setState(() => _cepWarning = 'CEP não encontrado.');
        return;
      }
      final logradouro = (data['logradouro'] as String?)?.trim() ?? '';
      final bairro = (data['bairro'] as String?)?.trim() ?? '';
      final cidade = (data['localidade'] as String?)?.trim() ?? '';
      final uf = (data['uf'] as String?)?.trim() ?? '';
      setState(() {
        if (logradouro.isNotEmpty) {
          // Mantém número se o usuário já digitou "Rua, 12".
          final atual = splitRuaNumero(_rua.text);
          _rua.text = atual.numero.isEmpty
              ? logradouro
              : '$logradouro, ${atual.numero}';
        }
        if (bairro.isNotEmpty) _bairro.text = bairro;
        if (cidade.isNotEmpty) {
          if (_cidades.isEmpty || _cidades.contains(cidade)) {
            _cidade.text = cidade;
          }
        }
        if (uf.isNotEmpty && _estado.isEmpty) {
          _estado = uf.toUpperCase();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _cepWarning = 'Não foi possível consultar o CEP.');
      }
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  ({String rua, String numero}) get _ruaNumero {
    final parts = splitRuaNumero(_rua.text);
    if (parts.numero.isNotEmpty) return parts;
    // Compat: se ainda houver valor no controller antigo de número.
    final n = _numero.text.trim();
    if (n.isNotEmpty) return (rua: parts.rua, numero: n);
    return parts;
  }

  Future<void> _submit() async {
    if (_slot == null || _dia == null || _picked.isEmpty) return;
    final addr = _ruaNumero;
    final err = validarDadosVitrine(
      nome: _nome.text,
      whatsapp: _whatsapp.text,
      cep: _cep.text,
      rua: _rua.text,
      numero: addr.numero,
      bairro: _bairro.text,
      cidade: _cidade.text,
      estado: _estado,
      ruaComNumero: true,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // Se a duração mudou desde a escolha do slot, exige nova escolha.
    if (_duracaoNoSlot > 0 && _duracaoNoSlot != _duracaoMin) {
      setState(() {
        _invalidateSlot();
        _error = 'A duração mudou. Escolha novamente data e horário.';
        _step = 2;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _idempotencyKey ??= _newIdempotencyKey();
      _numero.text = addr.numero;
    });
    try {
      final payload = montarPayloadAgendamento(
        slotToken: _slot!.token,
        nome: _nome.text,
        whatsapp: onlyDigitsPhone(_whatsapp.text),
        cep: _cep.text,
        rua: addr.rua,
        numero: addr.numero,
        bairro: _bairro.text,
        cidade: _cidade.text,
        estado: _estado,
        complemento: _complemento.text,
        observacoes: _obs.text,
        honeypot: _honeypot.text,
        idempotencyKey: _idempotencyKey!,
        itens: [
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
      );
      final res = await _api.agendar(payload);
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
      validarDadosVitrine(
        nome: _nome.text,
        whatsapp: _whatsapp.text,
        cep: _cep.text,
        rua: _rua.text,
        numero: _ruaNumero.numero,
        bairro: _bairro.text,
        cidade: _cidade.text,
        estado: _estado,
        ruaComNumero: true,
      ) ==
      null;

  int get _navIndex {
    if (_step == 0) return 0;
    if (_step == 6) return 2;
    if (_step >= 1 && _step <= 4) return 1;
    return 0;
  }

  String get _stepLabel => VitrineStepX.fromIndex(_step).headerLabel;

  int get _horizonte {
    final h = _config.horizonteDias;
    return h > 0 ? h : 14;
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
                        _catalogFuture = _api.listServicos();
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
                _invalidateSlot(clearDia: true);
                _idempotencyKey = null;
                _step = 0;
                _homeBrowse = 0;
                _categoriaFilter = null;
                _familiaFilter = null;
                _buscaFilter = null;
              }),
            );
          }

          return Column(
            children: [
              if (_step == 0 || _step == 6)
                VitrineLightTopBar(whatsapp: _config.whatsappExibido)
              else if (_step >= 1 && _step <= 4)
                VitrineLightStepHeader(
                  stepLabel: _stepLabel,
                  onBack: () {
                    if (_step == 1 || _step == 2) {
                      _go(0);
                    } else {
                      _go(_step - 1);
                    }
                  },
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
              Expanded(
                child: VitrineContentFrame(
                  maxWidth: VitrineUi.contentMaxWidth,
                  child: _body(),
                ),
              ),
              // Ao adicionar no catálogo: NÃO sticky — só badge no carrinho.
              if (_step == 2)
                VitrineStickyBar(
                  buttonLabel: 'Continuar',
                  onPressed: _slot != null ? () => _go(3) : null,
                )
              else if (_step == 3)
                VitrineStickyBar(
                  buttonLabel: 'Revisar e confirmar',
                  onPressed: _dadosOk ? () => _go(4) : null,
                )
              else if (_step == 4)
                VitrineStickyBar(
                  totalLabel: 'Resumo',
                  totalCaption: 'Valor estimado',
                  totalValue: formatCurrency(_total),
                  buttonLabel: 'Confirmar agendamento',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                )
              else if (_step == 6 ||
                  _step == 1 ||
                  (_step == 0 &&
                      (_homeBrowse >= 2 || _picked.isNotEmpty)))
                VitrineBottomNav(
                  index: _navIndex,
                  cartCount: _picked.length,
                  onTap: (i) {
                    if (i == 0) {
                      setState(() {
                        _step = 0;
                        _homeBrowse = 0;
                        _error = null;
                      });
                    }
                    if (i == 1) _openCarrinho();
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
        return _agenda();
      case 3:
        return _dados();
      case 4:
        return _revisar();
      case 6:
        return _comoFunciona();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Home (fluxo guiado) ─────────────────────────────────────────────────

  String _labelGrupo(String slug) => vitrineLabelGrupo(slug);

  String _macroTitle(String macro) {
    if (macro == 'veicular') {
      final t = _config.macroAutoTitulo.trim();
      return t.isEmpty ? 'Estética automotiva' : t;
    }
    if (macro == 'residencial') {
      final t = _config.macroResidTitulo.trim();
      return t.isEmpty ? 'Higienização residencial' : t;
    }
    return macro;
  }

  String _macroSubtitle(String macro) {
    if (macro == 'veicular') {
      final t = _config.macroAutoSubtitulo.trim();
      return t.isEmpty ? 'Bancos, teto, carpete e pacotes Cleanox' : t;
    }
    if (macro == 'residencial') {
      final t = _config.macroResidSubtitulo.trim();
      return t.isEmpty ? 'Sofá, colchão, poltrona, tapete e mais' : t;
    }
    return '';
  }

  VitrineChoiceGlyph _macroGlyph(String macro) {
    if (macro == 'veicular') {
      return vitrineMacroGlyph(_config.macroAutoIcone);
    }
    if (macro == 'residencial') {
      return vitrineMacroGlyph(_config.macroResidIcone);
    }
    return VitrineChoiceGlyph.clean;
  }

  VitrineChoiceGlyph _glyphGrupo(String slug) => vitrineGrupoGlyph(slug);

  List<VitrineServico> _servicosNoMacro(String macro) {
    return _sortedServicos(
      _catalog.where((s) => _macroOf(s) == macro),
    );
  }

  List<String> _gruposDoMacro(String macro) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in _servicosNoMacro(macro)) {
      final g = s.grupo.trim().toLowerCase();
      final key = g.isEmpty ? 'outros' : g;
      if (seen.add(key)) out.add(key);
    }
    out.sort();
    return ordenarGruposVitrine(macro, out);
  }

  List<VitrineServico> _servicosNoGrupo(String macro, String grupo) {
    final g = grupo.trim().toLowerCase();
    return catalogoAgrupadoPorPorte(
      _sortedServicos(
        _servicosNoMacro(macro).where((s) {
          final sg = s.grupo.trim().toLowerCase();
          final key = sg.isEmpty ? 'outros' : sg;
          return key == g;
        }),
      ),
    );
  }

  List<VitrineServico> _catalogoFiltradoGuiado() {
    final cat = (_categoriaFilter ?? '').trim().toLowerCase();
    final grupo = (_familiaFilter ?? '').trim().toLowerCase();
    return catalogoAgrupadoPorPorte(
      _sortedServicos(
        _catalog.where((s) {
          if (!_matchBusca(s)) return false;
          if (cat.isNotEmpty && _macroOf(s) != cat) return false;
          if (grupo.isNotEmpty &&
              !vitrineBuscaCruzaGrupo(_buscaFilter ?? '')) {
            final g = s.grupo.trim().toLowerCase();
            final key = g.isEmpty ? 'outros' : g;
            if (key != grupo) return false;
          }
          return true;
        }),
      ),
    );
  }

  void _pickCategoria(String macro) {
    setState(() {
      _categoriaFilter = macro;
      _familiaFilter = null;
      _buscaFilter = null;
      _homeBrowse = 1;
      _error = null;
    });
  }

  /// Troca para a outra macro (ex.: residencial ↔ veicular) e abre os grupos.
  void _switchCategoria(String macro) {
    _pickCategoria(macro);
  }

  /// Outra categoria disponível (para atalho no topo do catálogo).
  String? _outraMacroDisponivel(String atual) {
    final cur = atual.trim().toLowerCase();
    final candidatas = <String>[];
    if (_config.macroAutoPrimeiro) {
      candidatas.addAll(['veicular', 'residencial']);
    } else {
      candidatas.addAll(['residencial', 'veicular']);
    }
    for (final m in candidatas) {
      if (m == cur) continue;
      if (_servicosNoMacro(m).isNotEmpty) return m;
    }
    return null;
  }

  void _pickGrupo(String grupo) {
    setState(() {
      _familiaFilter = grupo;
      _buscaFilter = null;
      _homeBrowse = 2;
      _error = null;
    });
  }

  void _browseBack() {
    setState(() {
      if (_homeBrowse >= 2) {
        _homeBrowse = 1;
        _familiaFilter = null;
      } else if (_homeBrowse == 1) {
        _homeBrowse = 0;
        _categoriaFilter = null;
        _familiaFilter = null;
      }
      _buscaFilter = null;
      _error = null;
    });
  }

  Widget _home() {
    switch (_homeBrowse) {
      case 1:
        return _homeGrupos();
      case 2:
        return _homeCatalogoFiltrado();
      default:
        return _homeCategorias();
    }
  }

  Widget _homeCategorias() {
    final macros = <String>[];
    if (_config.macroAutoPrimeiro) {
      macros.addAll(['veicular', 'residencial']);
    } else {
      macros.addAll(['residencial', 'veicular']);
    }
    // Só mostra macro que tem serviço no catálogo.
    final available = [
      for (final m in macros)
        if (_servicosNoMacro(m).isNotEmpty) m,
    ];

    return LayoutBuilder(
      key: const Key('vitrine-home-browse-categorias'),
      builder: (context, constraints) {
        final maxW = min(_kChoiceMaxW, constraints.maxWidth);
        final cardSide = _choiceCardSide(constraints.maxWidth);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: _kChoiceHPad,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max(0, constraints.maxHeight - 32),
                maxWidth: maxW,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'O que você procura?',
                    key: Key('vitrine-home-oqvp'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: ClxBrand.navy,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escolha o tipo de serviço para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 14,
                      color: ClxBrand.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (available.isEmpty)
                    const Text(
                      'Nenhum serviço disponível no momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ClxBrand.muted),
                    )
                  else
                    _squareChoiceGrid(
                      key: const Key('vitrine-home-cat-row'),
                      cardSide: cardSide,
                      cards: [
                        for (final m in available)
                          _categoriaSquareCard(
                            key: Key('vitrine-home-cat-$m'),
                            title: _macroTitle(m),
                            subtitle: _macroSubtitle(m),
                            glyph: _macroGlyph(m),
                            onTap: () => _pickCategoria(m),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoriaSquareCard({
    required Key key,
    required String title,
    required String subtitle,
    required VitrineChoiceGlyph glyph,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140B1D34),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ClxBrand.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: VitrineChoiceIcon(
                    glyph: glyph,
                    size: 30,
                    color: ClxBrand.cyan,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: ClxBrand.navy,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 11,
                      height: 1.2,
                      color: ClxBrand.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mesmo tamanho da 1ª tela (2 colunas). Ímpar: última linha com 1 card no meio.
  static const double _kChoiceGap = 14;
  static const double _kChoiceMaxW = 520;
  static const double _kChoiceMaxSide = 168;
  static const double _kChoiceHPad = 24;

  double _choiceCardSide(double layoutWidth) {
    final maxW = min(_kChoiceMaxW, layoutWidth);
    final usable = maxW - _kChoiceHPad * 2;
    return min(_kChoiceMaxSide, (usable - _kChoiceGap) / 2);
  }

  /// Grade 2 colunas; se sobrar 1 card, centraliza na linha de baixo.
  Widget _squareChoiceGrid({
    required Key key,
    required double cardSide,
    required List<Widget> cards,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: _kChoiceGap));
      if (i + 1 < cards.length) {
        rows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: cardSide, height: cardSide, child: cards[i]),
              const SizedBox(width: _kChoiceGap),
              SizedBox(width: cardSide, height: cardSide, child: cards[i + 1]),
            ],
          ),
        );
      } else {
        // Ímpar: card sozinho centralizado (meio entre as duas colunas).
        rows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: cardSide, height: cardSide, child: cards[i]),
            ],
          ),
        );
      }
    }
    return Column(key: key, mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _browseBackButton({Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kChoiceHPad, 4, _kChoiceHPad, 0),
      child: Row(
        children: [
          TextButton.icon(
            key: const Key('vitrine-home-back'),
            onPressed: _browseBack,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              visualDensity: VisualDensity.compact,
              foregroundColor: ClxBrand.navy,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Voltar',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _switchCategoriaTrailing(String catAtual) {
    final outra = _outraMacroDisponivel(catAtual);
    if (outra == null) return const SizedBox.shrink();
    // Mesmo tamanho/peso; só o V de "Ver" em maiúscula.
    const style = TextStyle(
      fontFamily: kFontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      height: 1.1,
    );
    return TextButton(
      key: Key('vitrine-home-switch-cat-$outra'),
      onPressed: () => _switchCategoria(outra),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        visualDensity: VisualDensity.compact,
        foregroundColor: ClxBrand.cyan,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  const TextSpan(text: 'Ver '),
                  TextSpan(text: _macroTitle(outra)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }

  Widget _homeGrupos() {
    final cat = (_categoriaFilter ?? '').trim().toLowerCase();
    final grupos = _gruposDoMacro(cat);

    return LayoutBuilder(
      key: const Key('vitrine-home-browse-grupos'),
      builder: (context, constraints) {
        final maxW = min(_kChoiceMaxW, constraints.maxWidth);
        // Mesmo tamanho da 1ª tela (sempre fórmula de 2 colunas).
        final cardSide = _choiceCardSide(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixo no topo, logo abaixo da logo / top bar.
            _browseBackButton(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kChoiceHPad,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max(0, constraints.maxHeight - 72),
                      maxWidth: maxW,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _macroTitle(cat),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ClxBrand.cyan,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecione os itens que deseja limpar',
                          key: Key('vitrine-home-selecione-itens'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ClxBrand.navy,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Toque no grupo para ver as opções.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 14,
                            color: ClxBrand.muted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (grupos.isEmpty)
                          const Text(
                            'Nenhum grupo disponível nesta categoria.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ClxBrand.muted),
                          )
                        else
                          _squareChoiceGrid(
                            key: const Key('vitrine-home-grupo-row'),
                            cardSide: cardSide,
                            cards: [
                              for (final g in grupos)
                                _categoriaSquareCard(
                                  key: Key('vitrine-home-grupo-$g'),
                                  title: _labelGrupo(g),
                                  subtitle:
                                      '${_servicosNoGrupo(cat, g).length} opções',
                                  glyph: _glyphGrupo(g),
                                  onTap: () => _pickGrupo(g),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _homeCatalogoFiltrado() {
    final cat = (_categoriaFilter ?? '').trim().toLowerCase();
    final grupo = (_familiaFilter ?? '').trim().toLowerCase();
    final items = _catalogoFiltradoGuiado();

    return Column(
      key: const Key('vitrine-home-browse-catalogo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _browseBackButton(
          trailing: cat.isNotEmpty ? _switchCategoriaTrailing(cat) : null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _HomeCatalogHeader(
                initialQuery: _buscaFilter ?? '',
                onSearch: (q) {
                  setState(() {
                    _buscaFilter = q.trim().isEmpty ? null : q.trim();
                  });
                },
                onClearFilters: () {
                  setState(() => _buscaFilter = null);
                },
              ),
              if (cat.isNotEmpty && _gruposDoMacro(cat).isNotEmpty) ...[
                const SizedBox(height: 12),
                _HomeGrupoIconStrip(
                  key: const Key('vitrine-home-grupo-icon-strip'),
                  grupos: _gruposDoMacro(cat),
                  selected: grupo,
                  labelOf: _labelGrupo,
                  glyphOf: _glyphGrupo,
                  onSelect: (g) {
                    setState(() {
                      _familiaFilter = g;
                      _error = null;
                    });
                  },
                ),
              ],
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhum serviço encontrado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ClxBrand.muted),
                  ),
                )
              else
                VitrineCatalogoPersonalizavel(
                  key: ValueKey(
                    'vitrine-home-catgrid-$cat-$grupo-${_buscaFilter ?? ''}',
                  ),
                  servicos: items,
                  bootstrap: _bootstrap,
                  selectedIds: idsSelecaoComPorte(
                    exibidos: items,
                    catalogo: _catalog,
                    selecionados: _selected,
                  ),
                  showHeader: false,
                  showCategoryChips: false,
                  onToggle: _toggleServico,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Serviços ─────────────────────────────────────────────────────────────

  Widget _servicos() {
    final catKey = (_categoriaFilter ?? '').trim().toLowerCase();
    final famKey = (_familiaFilter ?? '').trim().toLowerCase();
    final buscaKey = (_buscaFilter ?? '').trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        VitrineCatalogoPersonalizavel(
          // Key força novo State quando o macro/busca muda — filtro não “gruda”.
          key: ValueKey('vitrine-catalogo-$catKey-$famKey-$buscaKey'),
          servicos: catalogoAgrupadoPorPorte(_catalog),
          bootstrap: _bootstrap,
          selectedIds: idsSelecaoComPorte(
            exibidos: catalogoAgrupadoPorPorte(_catalog),
            catalogo: _catalog,
            selecionados: _selected,
          ),
          onToggle: _toggleServico,
          initialCategoria: _categoriaFilter,
          initialGroup: _familiaFilter,
          initialQuery: _buscaFilter,
        ),
      ],
    );
  }

  // ─── Data e horário ───────────────────────────────────────────────────────

  Widget _agenda() {
    final now = DateTime.now();
    final dias = List.generate(
      _horizonte,
      (i) => DateTime(now.year, now.month, now.day + 1 + i),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Escolha data e horário',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Escolha a data e o horário de preferência. Nossa equipe confirma e entra em contato.',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            color: ClxBrand.muted,
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
              final sel =
                  _dia != null &&
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
                side: BorderSide(color: sel ? ClxBrand.navy : VitrineUi.line),
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
            'Nenhum horário nesta data. Tente outro dia.',
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
                  onSelected: (_) => setState(() {
                    _slot = s;
                    _duracaoNoSlot = _duracaoMin;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          decoration: VitrineUi.cardDeco(),
          child: Column(
            children: [
              _mini('Serviços selecionados', _picked.map((s) => s.nome).join(' + ')),
              if (_dia != null && _slot != null)
                _mini(
                  'Quando',
                  '${DateFormat('dd/MM').format(_dia!)} · ${_slot!.hora}',
                ),
              if (_total > 0)
                _mini(
                  'Valor estimado do serviço',
                  formatCurrency(_total),
                  highlight: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Dados e endereço ─────────────────────────────────────────────────────

  Widget _dados() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Seus dados e endereço',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Usamos só para o atendimento — sem criar conta. '
          'Telefone e endereço ficam no cofre da Cleanox.',
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
          hint: '(85) 99999-9999',
          onChanged: (v) {
            _applyPhoneMask(_whatsapp, v);
            setState(() {});
          },
        ),
        VitrineField(
          label: 'CEP',
          controller: _cep,
          keyboard: TextInputType.number,
          hint: '00000-000',
          onChanged: (v) {
            _handleCep(v);
            setState(() {});
          },
        ),
        if (_cepLoading || _cepWarning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                if (_cepLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_cepLoading) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _cepLoading
                        ? 'Buscando endereço…'
                        : (_cepWarning ?? ''),
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      color: _cepWarning != null
                          ? Colors.orange.shade800
                          : ClxBrand.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        VitrineField(
          label: 'Rua e número',
          controller: _rua,
          hint: 'Ex.: Rua das Flores, 123',
          onChanged: (_) => setState(() {}),
        ),
        VitrineField(
          label: 'Complemento (opcional)',
          controller: _complemento,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
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
                  child: Text(
                    c,
                    style: const TextStyle(fontFamily: kFontFamily),
                  ),
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
        if (_estado.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Estado: $_estado',
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 12,
                color: ClxBrand.muted,
              ),
            ),
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

  // ─── Revisar e confirmar ──────────────────────────────────────────────────

  Widget _revisar() {
    final addr = _ruaNumero;
    final endereco =
        '${addr.rua}, ${addr.numero}'
        '${_complemento.text.trim().isEmpty ? '' : ' · ${_complemento.text.trim()}'}\n'
        '${_bairro.text.trim()} · ${_cidade.text.trim()}'
        '${_estado.isEmpty ? '' : '-$_estado'}\n'
        'CEP ${_cep.text.trim()}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Resumo do agendamento',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Confira os serviços, o horário e o endereço antes de confirmar.',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 13,
            color: ClxBrand.muted,
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingBumps)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_bumps.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(VitrineUi.rMd),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oferta exclusiva nesta etapa',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ClxBrand.navy,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Preço especial só se você adicionar agora — não aparece no catálogo.',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 12,
                    color: ClxBrand.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final b in _bumps) _bumpCard(b),
          const SizedBox(height: 16),
        ],
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
                      'Valor estimado do serviço',
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
                _sumRow(s.nome, 'Serviço selecionado', formatCurrency(s.valorBase)),
              for (final b in _pickedBumps)
                _sumRow(
                  '+ ${b.titulo}',
                  'Oferta exclusiva',
                  formatCurrency(b.precoPromo),
                ),
              if (_dia != null && _slot != null)
                _sumRow(
                  'Data e horário',
                  '${DateFormat('dd/MM/yyyy').format(_dia!)} · ${_slot!.hora}',
                  'OK',
                  mutedValue: true,
                ),
              _sumRow(
                'Nome',
                _nome.text.trim(),
                'OK',
                mutedValue: true,
              ),
              _sumRow(
                'WhatsApp',
                mascaraWhatsapp(_whatsapp.text),
                'OK',
                mutedValue: true,
              ),
              _sumRow(
                'Endereço',
                endereco,
                'OK',
                mutedValue: true,
              ),
            ],
          ),
        ),
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
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.white,
                ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            // Adicional muda duração → invalida slot.
            _invalidateSlot();
          }),
          borderRadius: BorderRadius.circular(VitrineUi.rMd),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VitrineUi.rMd),
              border: Border.all(color: ClxBrand.cyan, width: 1.5),
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
                            borderRadius: BorderRadius.circular(
                              VitrineUi.rPill,
                            ),
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
        : kComoFuncionaDefault;
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
            child: const Text('Agendar agora'),
          ),
        ),
      ],
    );
  }
}

// ─── Sucesso ────────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.result, required this.onHome});
  final VitrineAgendarResult result;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final local =
        [
          if (result.bairro.isNotEmpty) result.bairro,
          if (result.cidade.isNotEmpty) result.cidade,
        ].join(' · ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
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
              'Agendamento confirmado!',
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
              result.mensagem.isNotEmpty
                  ? result.mensagem
                  : 'A Cleanox vai atribuir a equipe. Pagamento só no local.',
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
                  _kv('Referência', result.osRef),
                  _kv('Serviços', result.servico),
                  _kv('Data', () {
                    try {
                      return DateFormat(
                        'dd/MM/yyyy',
                      ).format(DateTime.parse(result.data));
                    } catch (_) {
                      return result.data;
                    }
                  }()),
                  _kv('Horário', result.hora),
                  if (local.isNotEmpty) _kv('Local', local),
                  if (result.valor > 0)
                    _kv('Valor estimado', formatCurrency(result.valor)),
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
          width: 110,
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

/// Sheet do carrinho: lista itens + Continuar (sem sticky bar no catálogo).
class _CarrinhoSheet extends StatefulWidget {
  const _CarrinhoSheet({
    required this.items,
    required this.onRemove,
    required this.onContinuar,
  });

  final List<VitrineServico> items;
  final ValueChanged<VitrineServico> onRemove;
  final VoidCallback onContinuar;

  @override
  State<_CarrinhoSheet> createState() => _CarrinhoSheetState();
}

class _CarrinhoSheetState extends State<_CarrinhoSheet> {
  late List<VitrineServico> _items;

  @override
  void initState() {
    super.initState();
    _items = List<VitrineServico>.from(widget.items);
  }

  double get _total =>
      _items.fold<double>(0, (s, x) => s + x.valorBase);

  void _remove(VitrineServico s) {
    setState(() {
      _items.removeWhere((x) => x.id == s.id);
    });
    widget.onRemove(s);
    if (_items.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560),
          child: Material(
            key: const Key('vitrine-carrinho-sheet'),
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Seu carrinho',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ClxBrand.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('vitrine-carrinho-close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = _items[i];
                      final nome = s.tituloComercial.trim().isNotEmpty
                          ? s.tituloComercial
                          : s.nome;
                      return Container(
                        key: Key('vitrine-carrinho-item-${s.id}'),
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nome,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: ClxBrand.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatCurrency(s.valorBase),
                                    style: const TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: ClxBrand.cyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: Key('vitrine-carrinho-remove-${s.id}'),
                              tooltip: 'Remover',
                              onPressed: () => _remove(s),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: ClxBrand.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_items.length} item${_items.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontFamily: kFontFamily,
                                fontSize: 13,
                                color: ClxBrand.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(_total),
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ClxBrand.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('vitrine-carrinho-continuar'),
                        onPressed:
                            _items.isEmpty ? null : widget.onContinuar,
                        style: FilledButton.styleFrom(
                          backgroundColor: ClxBrand.cyan,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha horizontal rolável (arrastar) com ícones dos grupos da categoria.
class _HomeGrupoIconStrip extends StatefulWidget {
  const _HomeGrupoIconStrip({
    super.key,
    required this.grupos,
    required this.selected,
    required this.labelOf,
    required this.glyphOf,
    required this.onSelect,
  });

  final List<String> grupos;
  final String selected;
  final String Function(String slug) labelOf;
  final VitrineChoiceGlyph Function(String slug) glyphOf;
  final ValueChanged<String> onSelect;

  @override
  State<_HomeGrupoIconStrip> createState() => _HomeGrupoIconStripState();
}

class _HomeGrupoIconStripState extends State<_HomeGrupoIconStrip> {
  final _scroll = ScrollController();
  var _maisDir = false;
  var _maisEsq = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant _HomeGrupoIconStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grupos.length != widget.grupos.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final dir = p.maxScrollExtent - p.pixels > 6;
    final esq = p.pixels > 6;
    if (dir != _maisDir || esq != _maisEsq) {
      setState(() {
        _maisDir = dir;
        _maisEsq = esq;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Stack(
        children: [
          ListView.separated(
            key: const Key('vitrine-home-grupo-icons-scroll'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: widget.grupos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = widget.grupos[i];
              final on = g == widget.selected.trim().toLowerCase();
              return _GrupoIconChip(
                key: Key('vitrine-home-grupo-icon-$g'),
                label: widget.labelOf(g),
                glyph: widget.glyphOf(g),
                selected: on,
                onTap: () => widget.onSelect(g),
              );
            },
          ),
          if (_maisEsq)
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: VitrineFaixaOverflowHint(
                key: Key('vitrine-home-grupo-seta-esq'),
                paraEsquerda: true,
              ),
            ),
          if (_maisDir)
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: VitrineFaixaOverflowHint(
                key: Key('vitrine-home-grupo-seta-dir'),
              ),
            ),
        ],
      ),
    );
  }
}

class _GrupoIconChip extends StatelessWidget {
  const _GrupoIconChip({
    super.key,
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final VitrineChoiceGlyph glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Paleta marca: selecionado = fundo cyan + glifo branco;
    // idle = fundo cyan 12% + glifo cyan (nunca branco em fundo claro).
    final bg = selected ? ClxBrand.cyan : ClxBrand.cyan.withValues(alpha: 0.12);
    final fg = selected ? Colors.white : ClxBrand.cyan;
    final border = selected ? ClxBrand.cyan : ClxBrand.cyan.withValues(alpha: 0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
        width: 84,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 1.5),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: ClxBrand.cyan.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x0F0B1D34),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                ),
                child: VitrineChoiceIcon(glyph: glyph, size: 24, color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                vitrineLabelGrupoDuasLinhas(label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? ClxBrand.cyan : ClxBrand.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card navy da home: busca + chips de categoria atualizam a própria home.
class _HomeCatalogHeader extends StatefulWidget {
  const _HomeCatalogHeader({
    required this.onSearch,
    required this.onClearFilters,
    this.initialQuery = '',
  });

  final ValueChanged<String> onSearch;
  final VoidCallback onClearFilters;
  final String initialQuery;

  @override
  State<_HomeCatalogHeader> createState() => _HomeCatalogHeaderState();
}

class _HomeCatalogHeaderState extends State<_HomeCatalogHeader> {
  late final TextEditingController _busca;

  @override
  void initState() {
    super.initState();
    _busca = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _HomeCatalogHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        _busca.text != widget.initialQuery) {
      _busca.value = TextEditingValue(
        text: widget.initialQuery,
        selection: TextSelection.collapsed(offset: widget.initialQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _emit([String? raw]) {
    widget.onSearch((raw ?? _busca.text).trim());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: ClxBrand.navy,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const Key('vitrine-home-catalog-header'),
              onTap: () {
                _busca.clear();
                setState(() {});
                widget.onClearFilters();
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SERVIÇOS CLEANOX',
                      style: TextStyle(
                        color: ClxBrand.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Todos os serviços',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('vitrine-home-busca'),
              controller: _busca,
              textInputAction: TextInputAction.search,
              onSubmitted: _emit,
              onChanged: (v) {
                setState(() {});
                // Filtra na própria home ao digitar.
                _emit(v);
              },
              style: const TextStyle(color: ClxBrand.navy),
              decoration: InputDecoration(
                hintText: 'Buscar serviço',
                helperText: 'Busca palavras do nome do serviço',
                helperStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: ClxBrand.cyan),
                suffixIcon: _busca.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _busca.clear();
                          setState(() {});
                          _emit('');
                        },
                        icon: const Icon(Icons.close, color: ClxBrand.muted),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


