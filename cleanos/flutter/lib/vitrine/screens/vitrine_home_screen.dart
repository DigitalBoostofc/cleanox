/// Vitrine pública — autoagendamento Cleanox (sem conta).
///
/// Fluxo: 0 home · 1 serviços · 2 data/hora · 3 dados · 4 revisar · 5 ok
///         6 como funciona
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';
import '../vitrine_booking.dart';
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
  String? _error;
  VitrineAgendarResult? _ok;
  String? _categoriaFilter; // residencial | veicular
  String? _familiaFilter; // sofa | colchao | …
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

  void _toggleServico(VitrineServico servico) {
    setState(() {
      if (_selected.contains(servico.id)) {
        _selected.remove(servico.id);
      } else {
        _selected.add(servico.id);
      }
      // Alterar serviços/duração invalida slot antigo.
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

  Future<void> _submit() async {
    if (_slot == null || _dia == null || _picked.isEmpty) return;
    final err = validarDadosVitrine(
      nome: _nome.text,
      whatsapp: _whatsapp.text,
      cep: _cep.text,
      rua: _rua.text,
      numero: _numero.text,
      bairro: _bairro.text,
      cidade: _cidade.text,
      estado: _estado,
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
    });
    try {
      final payload = montarPayloadAgendamento(
        slotToken: _slot!.token,
        nome: _nome.text,
        whatsapp: _whatsapp.text,
        cep: _cep.text,
        rua: _rua.text,
        numero: _numero.text,
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
        numero: _numero.text,
        bairro: _bairro.text,
        cidade: _cidade.text,
        estado: _estado,
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
              Expanded(
                child: VitrineContentFrame(
                  maxWidth: _step == 0 ? 1180 : 760,
                  child: _body(),
                ),
              ),
              if (_step == 1)
                VitrineStickyBar(
                  totalLabel: _total > 0
                      ? '${_picked.length} item${_picked.length == 1 ? '' : 's'} selecionado${_picked.length == 1 ? '' : 's'}'
                      : '${_picked.length} item${_picked.length == 1 ? '' : 's'} selecionado${_picked.length == 1 ? '' : 's'}',
                  totalValue: _total > 0
                      ? 'Valor estimado ${formatCurrency(_total)}'
                      : ' ',
                  buttonLabel: 'Continuar',
                  onPressed: _picked.isEmpty ? null : () => _go(2),
                )
              else if (_step == 2)
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
                  totalLabel: 'Valor estimado',
                  totalValue: formatCurrency(_total),
                  buttonLabel: 'Confirmar agendamento',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
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

  // ─── Home ─────────────────────────────────────────────────────────────────

  Widget _home() {
    final destaques = _catalog.where((s) => s.vitrineDestaque).take(8).toList();
    final pkgs = <VitrineServico>[
      ...destaques,
      ..._catalog.where((s) => !s.vitrineDestaque),
    ].take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const VitrineGreeting(),
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
          showCta: _config.heroCtaAtivo,
          onCta: () => _go(1),
          imageUrl: _midiaUrl('hero') ?? _midiaUrl('capa'),
        ),
        const SizedBox(height: 22),
        const Text(
          'O que você procura?',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 12),
        VitrineMacroChoice(
          residencialImageUrl:
              _midiaUrl('categoria_residencial') ?? _midiaUrl('categoria_sofa'),
          automotivaImageUrl:
              _midiaUrl('categoria_auto') ?? _midiaUrl('automovel'),
          onResidencial: () {
            setState(() {
              _categoriaFilter = 'residencial';
              _familiaFilter = null;
            });
            _go(1);
          },
          onAutomotiva: () {
            setState(() {
              _categoriaFilter = 'veicular';
              _familiaFilter = null;
            });
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
              onPressed: () {
                setState(() {
                  _categoriaFilter = null;
                  _familiaFilter = null;
                });
                _go(1);
              },
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
        VitrineCatalogoPersonalizavel(
          servicos: pkgs,
          bootstrap: _bootstrap,
          selectedIds: _selected,
          onToggle: (servico) {
            _toggleServico(servico);
            _go(1);
          },
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

  // ─── Serviços ─────────────────────────────────────────────────────────────

  Widget _servicos() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        VitrineCatalogoPersonalizavel(
          servicos: _catalog,
          bootstrap: _bootstrap,
          selectedIds: _selected,
          onToggle: _toggleServico,
          initialCategoria: _categoriaFilter,
          initialGroup: _familiaFilter,
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
          formatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        VitrineField(
          label: 'CEP',
          controller: _cep,
          keyboard: TextInputType.number,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          onChanged: (_) => setState(() {}),
        ),
        VitrineField(
          label: 'Rua',
          controller: _rua,
          onChanged: (_) => setState(() {}),
        ),
        Row(
          children: [
            Expanded(
              child: VitrineField(
                label: 'Número',
                controller: _numero,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: VitrineField(
                label: 'Complemento (opcional)',
                controller: _complemento,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
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
    final endereco =
        '${_rua.text.trim()}, ${_numero.text.trim()}'
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
                  'Serviço adicional',
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
            'Serviços adicionais',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ClxBrand.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Opcionais combinados com o que você selecionou',
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
