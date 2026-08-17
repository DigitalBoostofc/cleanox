/// Telas do admin da vitrine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/cleanox_logo.dart';
import '../../core/formatters/formatters.dart';
import '../widgets/vitrine_hero_catalogo.dart';
import '../widgets/vitrine_oferta_estilo.dart';
import '../vitrine_api.dart';
import 'vitrine_admin_auth.dart';
import 'vitrine_midia_repository.dart';
import 'vitrine_oferta_foco_editor.dart';
import 'vitrine_servico_editor.dart';

export 'vitrine_servico_editor.dart';

// ── Login ───────────────────────────────────────────────────────────────────

class VitrineAdminLoginScreen extends ConsumerStatefulWidget {
  const VitrineAdminLoginScreen({super.key});

  @override
  ConsumerState<VitrineAdminLoginScreen> createState() =>
      _VitrineAdminLoginScreenState();
}

class _VitrineAdminLoginScreenState
    extends ConsumerState<VitrineAdminLoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(vitrineAdminAuthProvider);
      final user = await auth.login(_email.text.trim(), _pass.text);
      if (!user.role.isPainel) {
        auth.logout();
        throw Exception(
          'Acesso restrito a admin e gerente. Contas de profissional não entram.',
        );
      }
      if (!mounted) return;
      context.go('/admin');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClxBrand.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0B1D34),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CleanoxLogo(
                    height: 40,
                    variant: CleanoxLogoVariant.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Admin da vitrine',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: ClxBrand.navy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Personalize o site de agendamento',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    color: ClxBrand.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: ClxBrand.cyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Acesso restrito a admin e gerente do CleanOS.\n'
                  'Contas de profissional são recusadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.4,
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

// ── Dashboard ───────────────────────────────────────────────────────────────

class VitrineAdminDashboardScreen extends ConsumerStatefulWidget {
  const VitrineAdminDashboardScreen({super.key});

  @override
  ConsumerState<VitrineAdminDashboardScreen> createState() =>
      _VitrineAdminDashboardScreenState();
}

class _VitrineAdminDashboardScreenState
    extends ConsumerState<VitrineAdminDashboardScreen> {
  late Future<List<VitrineAgendamentoResumo>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(vitrineAdminApiProvider).adminAgendamentos();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo da vitrine',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ClxBrand.navy,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Agendamentos vindos do site público (canal vitrine)',
                    style: TextStyle(color: ClxBrand.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton.tonal(
              onPressed: () {
                // Abre site público em nova aba (web).
                // ignore: discarded_futures
                launchUrl(Uri.parse('/'));
              },
              child: const Text('Ver site'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Text('Erro: ${snap.error}');
            }
            final items = snap.data ?? const <VitrineAgendamentoResumo>[];
            final total = items.fold<double>(0, (s, a) => s + a.valorServico);
            final ticket = items.isEmpty ? 0.0 : total / items.length;
            final ativos = items
                .where(
                  (a) => a.status != 'cancelada' && a.status != 'concluida',
                )
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 700;
                    final cards = [
                      _KpiCard(
                        label: 'Agendamentos',
                        value: '${items.length}',
                        hint: 'listados (canal vitrine)',
                      ),
                      _KpiCard(
                        label: 'Em aberto',
                        value: '$ativos',
                        hint: 'não cancelados/concluídos',
                      ),
                      _KpiCard(
                        label: 'Ticket médio',
                        value: formatCurrency(ticket),
                        hint: 'valor estimado OS',
                      ),
                      _KpiCard(
                        label: 'Volume',
                        value: formatCurrency(total),
                        hint: 'soma dos listados',
                      ),
                    ];
                    if (wide) {
                      return Row(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final card in cards)
                          SizedBox(width: double.infinity, child: card),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhum agendamento da vitrine ainda.'),
                    ),
                  )
                else
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Ref')),
                          DataColumn(label: Text('Cliente')),
                          DataColumn(label: Text('Serviços')),
                          DataColumn(label: Text('Quando')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: [
                          for (final a in items)
                            DataRow(
                              cells: [
                                DataCell(Text(a.osRef)),
                                DataCell(Text(a.nomeCurto)),
                                DataCell(Text(a.tipoServicoNome)),
                                DataCell(Text(a.dataHora)),
                                DataCell(Text(formatCurrency(a.valorServico))),
                                DataCell(Text(a.status)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 12,
                color: ClxBrand.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ClxBrand.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontSize: 11,
                color: ClxBrand.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Personalizar ────────────────────────────────────────────────────────────

class VitrineAdminPersonalizarScreen extends ConsumerStatefulWidget {
  const VitrineAdminPersonalizarScreen({super.key});

  @override
  ConsumerState<VitrineAdminPersonalizarScreen> createState() =>
      _VitrineAdminPersonalizarScreenState();
}

class _VitrineAdminPersonalizarScreenState
    extends ConsumerState<VitrineAdminPersonalizarScreen> {
  final _wa = TextEditingController();
  final _rodape = TextEditingController();
  final _cidades = TextEditingController();
  final _como = TextEditingController();
  final _capacidade = TextEditingController();
  final _horaIni = TextEditingController();
  final _horaFim = TextEditingController();
  final _passo = TextEditingController();
  final _antecedencia = TextEditingController();
  final _horizonte = TextEditingController();
  final _macroResidTitulo = TextEditingController();
  final _macroResidSub = TextEditingController();
  final _macroAutoTitulo = TextEditingController();
  final _macroAutoSub = TextEditingController();
  final _homeDestaquesTitulo = TextEditingController();
  final _homeDestaquesCta = TextEditingController();
  bool _homeDestaquesAtivo = true;
  VitrineHeroCatalogo _heroCatalogo = const VitrineHeroCatalogo();
  final _heroCatalogoTitulo = TextEditingController();
  final _heroCatalogoDestaque = TextEditingController();
  List<VitrineAdminServico> _estrelas = [];
  final _tagCtrls = <String, TextEditingController>{};
  final _capas = <String, VitrineMidiaItem>{};

  /// Hero saiu da home pública — mantidos só para não apagar no save.
  String _heroTitulo = '';
  String _heroSubtitulo = '';
  String _heroCta = 'Agendar agora';
  bool _heroCtaAtivo = false;

  bool _macroAutoPrimeiro = true;
  String _macroResidIcone = 'cleaning';
  String _macroAutoIcone = 'car';

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(vitrineAdminApiProvider).adminGetConfig();
      if (!mounted) return;
      _heroTitulo = c.heroTitulo;
      _heroSubtitulo = c.heroSubtitulo;
      _heroCta = c.heroCta;
      _heroCtaAtivo = c.heroCtaAtivo;
      _wa.text = c.whatsappExibido;
      _rodape.text = c.rodapeMsg;
      _cidades.text = c.cidadesTexto;
      _como.text = c.comoFunciona;
      _capacidade.text = '${c.capacidadeSimultanea}';
      _horaIni.text = c.horarioInicio;
      _horaFim.text = c.horarioFim;
      _passo.text = '${c.passoMin}';
      _antecedencia.text = '${c.antecedenciaMinutos}';
      _horizonte.text = '${c.horizonteDias}';
      _macroAutoPrimeiro = c.macroAutoPrimeiro;
      _macroResidTitulo.text = c.macroResidTitulo;
      _macroResidSub.text = c.macroResidSubtitulo;
      _macroResidIcone = c.macroResidIcone.trim().isEmpty
          ? 'cleaning'
          : c.macroResidIcone;
      _macroAutoTitulo.text = c.macroAutoTitulo;
      _macroAutoSub.text = c.macroAutoSubtitulo;
      _macroAutoIcone =
          c.macroAutoIcone.trim().isEmpty ? 'car' : c.macroAutoIcone;
      _homeDestaquesTitulo.text = c.homeDestaquesTitulo;
      _homeDestaquesCta.text = c.homeDestaquesCta;
      _homeDestaquesAtivo = c.homeDestaquesAtivo;
      _heroCatalogo = c.heroCatalogo;
      _heroCatalogoTitulo.text = c.heroCatalogo.titulo;
      _heroCatalogoDestaque.text = c.heroCatalogo.destaque;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(vitrineAdminApiProvider)
          .adminSaveConfig(
            VitrineConfig(
              heroTitulo: _heroTitulo,
              heroSubtitulo: _heroSubtitulo,
              heroCta: _heroCta,
              heroCtaAtivo: _heroCtaAtivo,
              whatsappExibido: _wa.text.trim(),
              rodapeMsg: _rodape.text.trim(),
              cidadesTexto: _cidades.text.trim(),
              comoFunciona: _como.text.trim(),
              capacidadeSimultanea: int.tryParse(_capacidade.text.trim()) ?? 0,
              horarioInicio: _horaIni.text.trim(),
              horarioFim: _horaFim.text.trim(),
              passoMin: int.tryParse(_passo.text.trim()) ?? 30,
              antecedenciaMinutos:
                  int.tryParse(_antecedencia.text.trim()) ?? 60,
              horizonteDias: int.tryParse(_horizonte.text.trim()) ?? 14,
              macroAutoPrimeiro: _macroAutoPrimeiro,
              macroResidTitulo: _macroResidTitulo.text.trim().isEmpty
                  ? 'Higienização residencial'
                  : _macroResidTitulo.text.trim(),
              macroResidSubtitulo: _macroResidSub.text.trim(),
              macroResidIcone: _macroResidIcone,
              macroAutoTitulo: _macroAutoTitulo.text.trim().isEmpty
                  ? 'Estética automotiva'
                  : _macroAutoTitulo.text.trim(),
              macroAutoSubtitulo: _macroAutoSub.text.trim(),
              macroAutoIcone: _macroAutoIcone,
              homeDestaquesTitulo: _homeDestaquesTitulo.text.trim().isEmpty
                  ? 'Ofertas em destaque'
                  : _homeDestaquesTitulo.text.trim(),
              homeDestaquesCta: _homeDestaquesCta.text.trim().isEmpty
                  ? 'Ver todos'
                  : _homeDestaquesCta.text.trim(),
              homeDestaquesAtivo: _homeDestaquesAtivo,
              heroCatalogo: _heroCatalogo.copyWith(
                titulo: _heroCatalogoTitulo.text.trim().isEmpty
                    ? VitrineHeroCatalogo.defaultTitulo
                    : _heroCatalogoTitulo.text.trim(),
                destaque: _heroCatalogoDestaque.text.trim(),
              ),
            ),
          );
      for (final s in _estrelas) {
        final tag = _tagCtrls[s.id]?.text.trim() ?? '';
        final capa = _capas[s.id];
        if (capa != null) {
          final estilo = VitrineOfertaEstilo.parse(
            '${capa.focoX}',
            '${capa.focoY}',
            capa.legenda,
          ).copyWith(badge: tag);
          final saved = await VitrineMidiaRepository(
            ref.read(vitrineAdminPbProvider),
          ).update(
            capa.id,
            focoX: estilo.x,
            focoY: estilo.y,
            legenda: estilo.writeInto(capa.legenda),
          );
          _capas[s.id] = saved;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuração salva')));
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    _wa.dispose();
    _rodape.dispose();
    _cidades.dispose();
    _como.dispose();
    _capacidade.dispose();
    _horaIni.dispose();
    _horaFim.dispose();
    _passo.dispose();
    _antecedencia.dispose();
    _horizonte.dispose();
    _macroResidTitulo.dispose();
    _macroResidSub.dispose();
    _macroAutoTitulo.dispose();
    _macroAutoSub.dispose();
    _homeDestaquesTitulo.dispose();
    _homeDestaquesCta.dispose();
    _heroCatalogoTitulo.dispose();
    _heroCatalogoDestaque.dispose();
    for (final c in _tagCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }


  _ConteudoSecao? _secao;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_secao != null) {
      return _editorDaSecao(_secao!);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Conteúdo do site',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Toque numa seção para editar. Cada uma aparece num lugar do agendar.',
          style: TextStyle(fontSize: 13, color: ClxBrand.muted),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        const SizedBox(height: 16),
        _tileSecao(
          secao: _ConteudoSecao.home,
          icon: Icons.grid_view_rounded,
          titulo: 'Início do site',
          resumo: 'Os dois cards: estética automotiva e higienização residencial.',
        ),
        _tileSecao(
          secao: _ConteudoSecao.hero,
          icon: Icons.directions_car_outlined,
          titulo: 'Cabeçalho do carro',
          resumo: 'Texto do navy e onde ele fica. Arraste no preview.',
        ),
        _tileSecao(
          secao: _ConteudoSecao.ofertas,
          icon: Icons.local_offer_outlined,
          titulo: 'Ofertas em destaque',
          resumo: 'Título da faixa e botão Ver todas. Os cards vêm da estrela em Serviços.',
        ),
        _tileSecao(
          secao: _ConteudoSecao.horarios,
          icon: Icons.schedule_rounded,
          titulo: 'Horários do agendamento',
          resumo: 'Janela de preferência que o cliente escolhe no site.',
        ),
        _tileSecao(
          secao: _ConteudoSecao.contato,
          icon: Icons.chat_outlined,
          titulo: 'Contato e rodapé',
          resumo: 'WhatsApp, cidades atendidas e mensagem de baixo.',
        ),
        _tileSecao(
          secao: _ConteudoSecao.como,
          icon: Icons.help_outline_rounded,
          titulo: 'Como funciona',
          resumo: 'Texto explicativo do site.',
        ),
      ],
    );
  }

  Widget _tileSecao({
    required _ConteudoSecao secao,
    required IconData icon,
    required String titulo,
    required String resumo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('vitrine-conteudo-secao-${secao.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => _secao = secao);
            if (secao == _ConteudoSecao.ofertas) {
              _carregarEstrelas();
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1D34),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: ClxBrand.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resumo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ClxBrand.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: ClxBrand.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editorDaSecao(_ConteudoSecao secao) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('vitrine-conteudo-voltar'),
              onPressed: () => setState(() => _secao = null),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                switch (secao) {
                  _ConteudoSecao.home => 'Início do site',
                  _ConteudoSecao.hero => 'Cabeçalho do carro',
                  _ConteudoSecao.ofertas => 'Ofertas em destaque',
                  _ConteudoSecao.horarios => 'Horários do agendamento',
                  _ConteudoSecao.contato => 'Contato e rodapé',
                  _ConteudoSecao.como => 'Como funciona',
                },
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ClxBrand.navy,
                ),
              ),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: switch (secao) {
              _ConteudoSecao.home => _formHome(),
              _ConteudoSecao.hero => _formHero(),
              _ConteudoSecao.ofertas => _formOfertas(),
              _ConteudoSecao.horarios => _formHorarios(),
              _ConteudoSecao.contato => _formContato(),
              _ConteudoSecao.como => _formComo(),
            },
          ),
        ),
      ],
    );
  }

  Widget _formHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Os dois cards da primeira tela. Fotos de cada serviço ficam em Serviços → Editar.',
          style: TextStyle(fontSize: 12, color: ClxBrand.muted),
        ),
        SwitchListTile(
          key: const Key('vitrine-macro-auto-primeiro'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Estética automotiva primeiro'),
          subtitle: Text(
            _macroAutoPrimeiro
                ? 'Ordem: automotiva → residencial'
                : 'Ordem: residencial → automotiva',
          ),
          value: _macroAutoPrimeiro,
          onChanged: (v) => setState(() => _macroAutoPrimeiro = v),
        ),
        TextField(
          controller: _macroAutoTitulo,
          decoration: const InputDecoration(
            labelText: 'Título — Estética automotiva',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _macroAutoSub,
          decoration: const InputDecoration(
            labelText: 'Subtítulo — Estética automotiva',
          ),
        ),
        const SizedBox(height: 12),
        _dropdownIcone(
          key: 'macro-auto-ico-$_macroAutoIcone',
          value: _macroAutoIcone,
          label: 'Ícone — Estética automotiva',
          onChanged: (v) => setState(() => _macroAutoIcone = v),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _macroResidTitulo,
          decoration: const InputDecoration(
            labelText: 'Título — Higienização residencial',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _macroResidSub,
          decoration: const InputDecoration(
            labelText: 'Subtítulo — Higienização residencial',
          ),
        ),
        const SizedBox(height: 12),
        _dropdownIcone(
          key: 'macro-resid-ico-$_macroResidIcone',
          value: _macroResidIcone,
          label: 'Ícone — Higienização residencial',
          onChanged: (v) => setState(() => _macroResidIcone = v),
        ),
      ],
    );
  }

  Future<void> _carregarEstrelas() async {
    try {
      final all = await ref.read(vitrineAdminApiProvider).adminListServicos();
      if (!mounted) return;
      final starred = all.where((s) => s.vitrineDestaque).toList()
        ..sort((a, b) => a.vitrineOrdem.compareTo(b.vitrineOrdem));
      final repo = VitrineMidiaRepository(ref.read(vitrineAdminPbProvider));
      final capas = <String, VitrineMidiaItem>{};
      for (final s in starred) {
        try {
          final midias = await repo.listByServico(s.id);
          VitrineMidiaItem? capa;
          for (final m in midias) {
            if ((m.displayUrl ?? '').isEmpty) continue;
            if (m.papel == 'capa') {
              capa = m;
              break;
            }
            capa ??= m;
          }
          if (capa != null) capas[s.id] = capa;
        } catch (_) {}
      }
      if (!mounted) return;
      for (final old in _tagCtrls.values) {
        old.dispose();
      }
      _tagCtrls
        ..clear()
        ..addEntries(
          starred.map((s) {
            final capa = capas[s.id];
            final fromCard = capa == null
                ? ''
                : VitrineOfertaEstilo.parse(
                    '${capa.focoX}',
                    '${capa.focoY}',
                    capa.legenda,
                  ).badge;
            return MapEntry(
              s.id,
              TextEditingController(
                text: fromCard.trim().isEmpty ? s.vitrineBadge : fromCard,
              ),
            );
          }),
        );
      setState(() {
        _estrelas = starred;
        _capas
          ..clear()
          ..addAll(capas);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Widget _formHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Esse é o bloco navy da estética automotiva. Arraste o texto para o lugar.',
          style: TextStyle(fontSize: 13, color: ClxBrand.muted),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: ClxBrand.navy,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: VitrineHeroCatalogoStage(
                hero: _heroCatalogo.copyWith(
                  titulo: _heroCatalogoTitulo.text.trim().isEmpty
                      ? VitrineHeroCatalogo.defaultTitulo
                      : _heroCatalogoTitulo.text.trim(),
                  destaque: _heroCatalogoDestaque.text.trim(),
                ),
                height: 150,
                fontSize: 20,
                editable: true,
                onMoved: (o) => setState(() {
                  _heroCatalogo = _heroCatalogo.copyWith(x: o.dx, y: o.dy);
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _heroCatalogoTitulo,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Texto',
            hintText: 'O que vamos fazer no seu carro hoje?',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _heroCatalogoDestaque,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Palavra em ciano',
            hintText: 'carro',
          ),
        ),
      ],
    );
  }

  Widget _formOfertas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('vitrine-ofertas-ativo'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar faixa no site'),
          subtitle: Text(
            _homeDestaquesAtivo
                ? 'Ligado: aparece na estética automotiva'
                : 'Desligado: some do site',
          ),
          value: _homeDestaquesAtivo,
          onChanged: (v) => setState(() => _homeDestaquesAtivo = v),
        ),
        const Text(
          'Entra na faixa quem tiver estrela em Vitrine → Serviços. '
          'A tag abaixo é o selo do card (ex.: MAIS VENDIDO).',
          style: TextStyle(fontSize: 12, color: ClxBrand.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('vitrine-home-destaques-titulo'),
          controller: _homeDestaquesTitulo,
          decoration: const InputDecoration(labelText: 'Título da faixa'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('vitrine-home-destaques-cta'),
          controller: _homeDestaquesCta,
          decoration: const InputDecoration(
            labelText: 'Texto do botão (ex.: Ver todas)',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tags dos cards',
          style: TextStyle(fontWeight: FontWeight.w800, color: ClxBrand.navy),
        ),
        const SizedBox(height: 8),
        if (_estrelas.isEmpty)
          const Text(
            'Nenhum serviço com estrela. Vá em Vitrine → Serviços e marque a estrela.',
            style: TextStyle(fontSize: 13, color: ClxBrand.muted),
          )
        else
          for (final s in _estrelas) ...[
            Text(
              s.vitrineTitulo.trim().isEmpty ? s.nome : s.vitrineTitulo,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              key: Key('vitrine-oferta-tag-${s.id}'),
              controller: _tagCtrls[s.id],
              decoration: const InputDecoration(
                labelText: 'Tag do card',
                hintText: 'MAIS VENDIDO',
              ),
            ),
            if (_capas[s.id] != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: Key('vitrine-oferta-foco-${s.id}'),
                onPressed: () async {
                  final midia = _capas[s.id];
                  if (midia == null) return;
                  final saved = await showVitrineOfertaFocoEditor(
                    context,
                    repo: VitrineMidiaRepository(
                      ref.read(vitrineAdminPbProvider),
                    ),
                    midia: midia,
                    titulo: s.vitrineTitulo.trim().isEmpty
                        ? s.nome
                        : s.vitrineTitulo,
                    preco: formatCurrency(s.valorBase),
                    badge: s.vitrineBadge,
                  );
                  if (saved != null && mounted) {
                    setState(() => _capas[s.id] = saved);
                  }
                },
                icon: const Icon(Icons.crop_free_rounded, size: 18),
                label: const Text('Editar card'),
              ),
            ],
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  Widget _formHorarios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'O cliente escolhe data e hora de preferência. Não reserva vaga: '
          'a OS cai em Em agendamento e a equipe confirma depois.',
          style: TextStyle(fontSize: 12, color: ClxBrand.muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _horaIni,
                decoration: const InputDecoration(labelText: 'Horário início'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _horaFim,
                decoration: const InputDecoration(labelText: 'Horário fim'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _passo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Passo (min)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _antecedencia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Antecedência (min)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _horizonte,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Horizonte de dias'),
        ),
      ],
    );
  }

  Widget _formContato() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _wa,
          decoration: const InputDecoration(labelText: 'WhatsApp exibido'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cidades,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Cidades atendidas',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rodape,
          decoration: const InputDecoration(labelText: 'Mensagem do rodapé'),
        ),
      ],
    );
  }

  Widget _formComo() {
    return TextField(
      controller: _como,
      maxLines: 8,
      decoration: const InputDecoration(
        labelText: 'Como funciona',
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _dropdownIcone({
    required String key,
    required String value,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey(key),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: 'car', child: Text('Carro')),
        DropdownMenuItem(value: 'garage', child: Text('Garagem')),
        DropdownMenuItem(value: 'spray', child: Text('Spray / escova')),
        DropdownMenuItem(value: 'home', child: Text('Casa')),
        DropdownMenuItem(value: 'cleaning', child: Text('Limpeza')),
        DropdownMenuItem(value: 'sofa', child: Text('Sofá')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

enum _ConteudoSecao { home, hero, ofertas, horarios, contato, como }

// ── Serviços ────────────────────────────────────────────────────────────────

class VitrineAdminServicosScreen extends ConsumerStatefulWidget {
  const VitrineAdminServicosScreen({super.key});

  @override
  ConsumerState<VitrineAdminServicosScreen> createState() =>
      _VitrineAdminServicosScreenState();
}

class _VitrineAdminServicosScreenState
    extends ConsumerState<VitrineAdminServicosScreen> {
  /// Lista local: toggle/estrela/drag atualizam in-place (scroll não zera).
  List<VitrineAdminServico>? _items;
  Object? _error;
  bool _loading = true;
  /// Lock lógico sem rebuild de UI (evita LinearProgress/snackbar mexerem o scroll).
  bool _reorderBusy = false;
  final _scrollController = ScrollController();
  final _togglingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _scrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

  void _keepScroll([double? offset]) {
    final o = offset ?? _scrollOffset;
    void jump() {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = o.clamp(0.0, max);
      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    }

    // Restaura no próximo frame e no seguinte (layout do reorder pode atrasar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  Future<void> _load() async {
    final offset = _scrollOffset;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(vitrineAdminApiProvider).adminListServicos();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      _keepScroll(offset);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      _keepScroll(offset);
    }
  }

  void _replaceLocal(VitrineAdminServico updated) {
    final list = _items;
    if (list == null) return;
    final offset = _scrollOffset;
    setState(() {
      _items = [
        for (final s in list)
          if (s.id == updated.id) updated else s,
      ];
    });
    _keepScroll(offset);
  }

  List<VitrineAdminServico> _ofMacro(String macro) {
    final items = _items ?? const <VitrineAdminServico>[];
    final filtered = [
      for (final s in items)
        if (s.macroCategoria == macro) s,
    ];
    // Ordem canônica: só vitrine_ordem (empate estável por id, não por nome —
    // evita “pulo” visual se vários ainda estão em 0).
    filtered.sort((a, b) {
      final o = a.vitrineOrdem.compareTo(b.vitrineOrdem);
      if (o != 0) return o;
      return a.id.compareTo(b.id);
    });
    return filtered;
  }

  Future<void> _toggle(
    VitrineAdminServico s, {
    bool? vitrine,
    bool? destaque,
  }) async {
    if (_togglingIds.contains(s.id) || _reorderBusy) return;
    final next = s.copyWith(
      vitrine: vitrine ?? s.vitrine,
      vitrineDestaque: destaque ?? s.vitrineDestaque,
    );
    _replaceLocal(next);
    final offset = _scrollOffset;
    setState(() => _togglingIds.add(s.id));
    _keepScroll(offset);
    try {
      await ref.read(vitrineAdminApiProvider).adminPatchServico(
            s.id,
            vitrine: vitrine,
            vitrineDestaque: destaque,
          );
    } catch (e) {
      if (!mounted) return;
      _replaceLocal(s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Não foi possível atualizar: $e'),
        ),
      );
    } finally {
      if (mounted) {
        final o = _scrollOffset;
        setState(() => _togglingIds.remove(s.id));
        _keepScroll(o);
      }
    }
  }

  /// Reordena na categoria e grava `vitrine_ordem` sem resetar o scroll.
  Future<void> _onReorderMacro(
    String macro,
    int oldIndex,
    int newIndex,
  ) async {
    if (_reorderBusy) return;
    final before = _ofMacro(macro);
    if (before.isEmpty) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= before.length || oldIndex == target) return;

    final offset = _scrollOffset;
    final moved = [...before];
    final item = moved.removeAt(oldIndex);
    moved.insert(target, item);

    final snapshot = _items == null ? null : [..._items!];
    final byId = {
      for (final s in (_items ?? const <VitrineAdminServico>[])) s.id: s,
    };
    final updatedMoved = <VitrineAdminServico>[
      for (var i = 0; i < moved.length; i++)
        moved[i].copyWith(vitrineOrdem: i),
    ];
    for (final s in updatedMoved) {
      byId[s.id] = s;
    }

    _reorderBusy = true;
    // Um único setState: lista nova, sem barra de progresso nem snack de sucesso.
    setState(() {
      _items = byId.values.toList();
    });
    _keepScroll(offset);

    try {
      final api = ref.read(vitrineAdminApiProvider);
      final futures = <Future<void>>[];
      for (final s in updatedMoved) {
        final prev = before.firstWhere((e) => e.id == s.id);
        if (prev.vitrineOrdem != s.vitrineOrdem) {
          futures.add(
            api.adminPatchServico(s.id, vitrineOrdem: s.vitrineOrdem),
          );
        }
      }
      await Future.wait(futures);
      // Sucesso silencioso — snackbar/progress deslocavam o layout e o scroll.
    } catch (e) {
      if (!mounted) return;
      if (snapshot != null) {
        setState(() => _items = snapshot);
        _keepScroll(offset);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Não foi possível salvar a ordem: $e'),
        ),
      );
    } finally {
      _reorderBusy = false;
      if (mounted) _keepScroll(offset);
    }
  }

  Future<void> _openEditor(VitrineAdminServico servico) async {
    final api = ref.read(vitrineAdminApiProvider);
    final midiaRepo = VitrineMidiaRepository(ref.read(vitrineAdminPbProvider));
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => VitrineServicoEditorDialog(
        servico: servico,
        midiaRepo: midiaRepo,
        onSave: (draft) => api.adminPatchServico(
          servico.id,
          vitrine: draft['vitrine'] == true,
          vitrineDestaque: draft['vitrine_destaque'] == true,
          layout: VitrineServicoLayout.parse(draft['vitrine_layout']),
          vitrineTitulo: '${draft['vitrine_titulo'] ?? ''}',
          vitrineDescricao: '${draft['vitrine_descricao'] ?? ''}',
          vitrineBadge: '${draft['vitrine_badge'] ?? ''}',
          vitrineCta: '${draft['vitrine_cta'] ?? ''}',
          precoModo: VitrinePrecoModo.parse(draft['vitrine_preco_modo']),
          vitrineOrdem: (draft['vitrine_ordem'] as num?)?.toInt() ?? 0,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erro: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    final veicular = _ofMacro('veicular');
    final residencial = _ofMacro('residencial');
    final outros = _ofMacro('outros');
    return ListView(
      key: const PageStorageKey<String>('vitrine-admin-servicos-list'),
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Serviços na vitrine',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ClxBrand.navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Arraste pelo ícone ☰ para definir a ordem de cada categoria. '
          'Essa ordem é a que aparece no site ao clicar em Estética automotiva '
          'ou Higienização residencial. '
          'Use o personalizar para capa/antes/depois e demais campos.',
          style: TextStyle(color: ClxBrand.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _section(
          key: const ValueKey('vitrine-admin-sec-veicular'),
          macro: 'veicular',
          title: 'Estética automotiva',
          subtitle: 'Serviços veiculares',
          items: veicular,
          emptyHint: 'Nenhum serviço veicular cadastrado.',
        ),
        const SizedBox(height: 20),
        _section(
          key: const ValueKey('vitrine-admin-sec-residencial'),
          macro: 'residencial',
          title: 'Higienização residencial',
          subtitle: 'Sofá, colchão, poltrona, tapete e afins',
          items: residencial,
          emptyHint: 'Nenhum serviço residencial cadastrado.',
        ),
        if (outros.isNotEmpty) ...[
          const SizedBox(height: 20),
          _section(
            key: const ValueKey('vitrine-admin-sec-outros'),
            macro: 'outros',
            title: 'Outros / sem categoria',
            subtitle: 'Defina categoria no cadastro do serviço',
            items: outros,
            emptyHint: '',
          ),
        ],
      ],
    );
  }

  Widget _section({
    required Key key,
    required String macro,
    required String title,
    required String subtitle,
    required List<VitrineAdminServico> items,
    required String emptyHint,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: ClxBrand.navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$subtitle · ${items.length} serviço${items.length == 1 ? '' : 's'} · arraste para reordenar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty && emptyHint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              emptyHint,
              style: const TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
          )
        else
          ReorderableListView.builder(
            key: PageStorageKey<String>('vitrine-admin-reorder-$macro'),
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: _reorderBusy
                ? (_, __) {}
                : (oldIndex, newIndex) =>
                    _onReorderMacro(macro, oldIndex, newIndex),
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final s = items[index];
              return _servicoTile(
                s,
                index: index,
                key: ValueKey('vitrine-admin-servico-${s.id}'),
              );
            },
          ),
      ],
    );
  }

  Widget _servicoTile(
    VitrineAdminServico s, {
    required int index,
    required Key key,
  }) {
    final busy = _togglingIds.contains(s.id);
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          children: [
            Switch(
              value: s.vitrine,
              onChanged: busy || _reorderBusy
                  ? null
                  : (value) => _toggle(s, vitrine: value),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.vitrineTitulo.isEmpty ? s.nome : s.vitrineTitulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${s.grupo.isEmpty ? '—' : s.grupo} · '
                    '${formatCurrency(s.valorBase)} · '
                    '${_adminLayoutLabel(s.layout)}'
                    '${s.vitrineDestaque ? ' · destaque' : ''}'
                    ' · #${s.vitrineOrdem}',
                    style: const TextStyle(
                      color: ClxBrand.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Destaque na home',
              icon: Icon(
                s.vitrineDestaque ? Icons.star : Icons.star_border,
                color: s.vitrineDestaque ? ClxBrand.cyan : ClxBrand.muted,
              ),
              onPressed: busy || _reorderBusy
                  ? null
                  : () => _toggle(s, destaque: !s.vitrineDestaque),
            ),
            IconButton(
              tooltip: 'Personalizar serviço',
              icon: const Icon(Icons.tune),
              onPressed: busy || _reorderBusy ? null : () => _openEditor(s),
            ),
            ReorderableDragStartListener(
              index: index,
              enabled: !_reorderBusy,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Icon(
                  Icons.drag_handle,
                  key: ValueKey('vitrine-admin-drag-${s.id}'),
                  color: ClxBrand.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _adminLayoutLabel(VitrineServicoLayout layout) => switch (layout) {
  VitrineServicoLayout.destaque => 'Destaque amplo',
  VitrineServicoLayout.fotografico => 'Card fotográfico',
  VitrineServicoLayout.antesDepois => 'Antes/depois',
  VitrineServicoLayout.compacto => 'Compacto',
};

// ── Order bumps ─────────────────────────────────────────────────────────────

class VitrineAdminBumpsScreen extends ConsumerStatefulWidget {
  const VitrineAdminBumpsScreen({super.key});

  @override
  ConsumerState<VitrineAdminBumpsScreen> createState() =>
      _VitrineAdminBumpsScreenState();
}

class _VitrineAdminBumpsScreenState
    extends ConsumerState<VitrineAdminBumpsScreen> {
  late Future<List<VitrineOrderBump>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(vitrineAdminApiProvider).adminListBumps();
  }

  Future<void> _openEditor([VitrineOrderBump? existing]) async {
    final api = ref.read(vitrineAdminApiProvider);
    final servicos = await api.adminListServicos();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BumpEditorDialog(
        existing: existing,
        servicos: servicos,
        onSave: (body) async {
          await api.adminSaveBump(body, id: existing?.id);
        },
      ),
    );
    if (ok == true && mounted) setState(_reload);
  }

  Future<void> _delete(VitrineOrderBump b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir bump?'),
        content: Text(b.titulo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(vitrineAdminApiProvider).adminDeleteBump(b.id);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erro: ${snap.error}'));
        }
        final items = snap.data ?? const <VitrineOrderBump>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order bumps',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ClxBrand.navy,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo bump'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Faixa da home do veículo: marque a estrela e o badge em Serviços. '
              'Abaixo: order bumps da tela Revisar (não é a faixa).',
              style: TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ofertas exclusivas na tela Revisar. Defina quando aparecer '
              '(serviço X, ou X e Y) e o preço promocional do serviço ofertado. '
              'Esse valor só vale se o lead aceitar o bump — não entra no catálogo.',
              style: TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma oferta. Crie: se o cliente escolher o serviço A, '
                    'ofereça B com desconto na revisão.',
                  ),
                ),
              ),
            for (final b in items)
              Card(
                child: ListTile(
                  title: Text(
                    b.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${_bumpRuleLabel(b)} · '
                    '${formatCurrency(b.precoPromo)}'
                    '${b.precoCheio > b.precoPromo ? ' (de ${formatCurrency(b.precoCheio)})' : ''}'
                    '${b.ativo ? '' : ' · PAUSADO'}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(b),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _bumpRuleLabel(VitrineOrderBump b) {
  final vals = b.gatilhoValores.join(', ');
  return switch (b.gatilhoTipo) {
    'todos_servicos' => 'Se tiver TODOS os serviços: $vals',
    'qualquer_servico' => 'Se tiver QUALQUER serviço: $vals',
    'todos_grupos' => 'Se tiver TODOS os grupos: $vals',
    _ => 'Se tiver QUALQUER grupo: $vals',
  };
}

class _BumpEditorDialog extends StatefulWidget {
  const _BumpEditorDialog({
    required this.existing,
    required this.servicos,
    required this.onSave,
  });

  final VitrineOrderBump? existing;
  final List<VitrineAdminServico> servicos;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  @override
  State<_BumpEditorDialog> createState() => _BumpEditorDialogState();
}

class _BumpEditorDialogState extends State<_BumpEditorDialog> {
  late final TextEditingController _titulo;
  late final TextEditingController _desc;
  late final TextEditingController _badge;
  late final TextEditingController _cheio;
  late final TextEditingController _promo;
  late final TextEditingController _desconto;
  late final TextEditingController _grupos;
  late final TextEditingController _prio;
  String _tipo = 'qualquer_servico';
  String? _servicoOferta;
  final Set<String> _gatilhoServicos = {};
  final Set<String> _excluir = {};
  bool _ativo = true;
  bool _saving = false;
  String? _error;

  bool get _isServicoRule =>
      _tipo == 'qualquer_servico' || _tipo == 'todos_servicos';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _desc = TextEditingController(text: e?.descricao ?? '');
    _badge = TextEditingController(text: e?.badge ?? '');
    _cheio = TextEditingController(
      text: e != null && e.precoCheio > 0 ? _fmt(e.precoCheio) : '',
    );
    _promo = TextEditingController(
      text: e != null ? _fmt(e.precoPromo) : '',
    );
    _desconto = TextEditingController(
      text: e != null && e.precoCheio > 0 && e.precoPromo < e.precoCheio
          ? _fmt(((1 - e.precoPromo / e.precoCheio) * 100))
          : '',
    );
    _tipo = e?.gatilhoTipo ?? 'qualquer_servico';
    if (_tipo == 'qualquer_grupo' || _tipo == 'todos_grupos') {
      _grupos = TextEditingController(text: e?.gatilhoValores.join(', ') ?? '');
    } else {
      _grupos = TextEditingController();
      _gatilhoServicos.addAll(e?.gatilhoValores ?? const []);
    }
    _excluir.addAll(e?.excluirSe ?? const []);
    _prio = TextEditingController(text: '${e?.prioridade ?? 10}');
    _servicoOferta = e?.servicoOferta;
    _ativo = e?.ativo ?? true;
    if ((_servicoOferta ?? '').isNotEmpty && _cheio.text.isEmpty) {
      _syncCheioFromOferta();
    }
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(2);
  }

  double _parse(String t) =>
      double.tryParse(t.trim().replaceAll(',', '.')) ?? 0;

  String _nomeOferta(String? id) {
    if (id == null || id.isEmpty) return 'Oferta';
    for (final s in widget.servicos) {
      if (s.id == id) return s.nome;
    }
    return 'Oferta';
  }

  void _syncCheioFromOferta() {
    final id = _servicoOferta;
    if (id == null) return;
    for (final s in widget.servicos) {
      if (s.id == id && s.valorBase > 0) {
        _cheio.text = _fmt(s.valorBase);
        _recalcFromDesconto();
        break;
      }
    }
  }

  void _recalcFromDesconto() {
    final cheio = _parse(_cheio.text);
    final pct = _parse(_desconto.text);
    if (cheio <= 0 || pct <= 0) return;
    final promo = (cheio * (1 - pct / 100)).clamp(0, cheio);
    _promo.text = _fmt(promo.toDouble());
    if (_badge.text.trim().isEmpty ||
        RegExp(r'^[−\-]?\d+%?$').hasMatch(_badge.text.trim())) {
      _badge.text = '−${pct.round()}%';
    }
  }

  void _recalcFromPromo() {
    final cheio = _parse(_cheio.text);
    final promo = _parse(_promo.text);
    if (cheio <= 0 || promo <= 0 || promo >= cheio) return;
    final pct = ((1 - promo / cheio) * 100);
    _desconto.text = _fmt(pct);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    _badge.dispose();
    _cheio.dispose();
    _promo.dispose();
    _desconto.dispose();
    _grupos.dispose();
    _prio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_servicoOferta == null || _servicoOferta!.isEmpty) {
      setState(() => _error = 'Escolha o serviço da oferta');
      return;
    }
    final List<String> vals;
    if (_isServicoRule) {
      vals = _gatilhoServicos.toList();
      if (vals.isEmpty) {
        setState(() => _error = 'Marque ao menos um serviço gatilho');
        return;
      }
    } else {
      vals = _grupos.text
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (vals.isEmpty) {
        setState(() => _error = 'Informe ao menos um grupo gatilho');
        return;
      }
    }
    final promo = _parse(_promo.text);
    if (promo <= 0) {
      setState(() => _error = 'Informe o preço promo (ou % de desconto)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'titulo': _titulo.text.trim().isEmpty
            ? _nomeOferta(_servicoOferta)
            : _titulo.text.trim(),
        'descricao': _desc.text.trim(),
        'badge': _badge.text.trim(),
        'servico_oferta': _servicoOferta,
        'preco_cheio': _parse(_cheio.text),
        'preco_promo': promo,
        'gatilho_tipo': _tipo,
        'gatilho_valores': vals,
        'excluir_se': _excluir.toList(),
        'prioridade': int.tryParse(_prio.text) ?? 10,
        'ativo': _ativo,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nova oferta (order bump)' : 'Editar oferta'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '1) Serviço em oferta (preço exclusivo na revisão)',
                style: TextStyle(fontWeight: FontWeight.w700, color: ClxBrand.navy),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _servicoOferta,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Serviço ofertado',
                ),
                items: [
                  for (final s in widget.servicos)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.nome} · ${formatCurrency(s.valorBase)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _servicoOferta = v;
                  _syncCheioFromOferta();
                  if (_titulo.text.trim().isEmpty) {
                    _titulo.text = _nomeOferta(v);
                  }
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cheio,
                      decoration: const InputDecoration(
                        labelText: 'Preço cheio',
                        helperText: 'De',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        _recalcFromDesconto();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _desconto,
                      decoration: const InputDecoration(
                        labelText: '% desconto',
                        helperText: 'Gera preço promo',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        _recalcFromDesconto();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _promo,
                      decoration: const InputDecoration(
                        labelText: 'Preço promo',
                        helperText: 'Só no bump',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        _recalcFromPromo();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título na tela'),
              ),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
              TextField(
                controller: _badge,
                decoration: const InputDecoration(
                  labelText: 'Badge (ex.: −30%)',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '2) Quando mostrar (combinações E / OU)',
                style: TextStyle(fontWeight: FontWeight.w700, color: ClxBrand.navy),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Regra'),
                items: const [
                  DropdownMenuItem(
                    value: 'qualquer_servico',
                    child: Text('Se tiver QUALQUER destes serviços (OU)'),
                  ),
                  DropdownMenuItem(
                    value: 'todos_servicos',
                    child: Text('Se tiver TODOS estes serviços (E)'),
                  ),
                  DropdownMenuItem(
                    value: 'qualquer_grupo',
                    child: Text('Se tiver QUALQUER destes grupos (OU)'),
                  ),
                  DropdownMenuItem(
                    value: 'todos_grupos',
                    child: Text('Se tiver TODOS estes grupos (E)'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _tipo = v ?? _tipo;
                }),
              ),
              const SizedBox(height: 8),
              if (_isServicoRule) ...[
                Text(
                  _tipo == 'todos_servicos'
                      ? 'Marque os serviços que precisam estar TODOS no carrinho:'
                      : 'Marque os serviços que disparam a oferta (basta 1):',
                  style: const TextStyle(fontSize: 12, color: ClxBrand.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in widget.servicos)
                      FilterChip(
                        label: Text(s.nome, style: const TextStyle(fontSize: 12)),
                        selected: _gatilhoServicos.contains(s.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _gatilhoServicos.add(s.id);
                          } else {
                            _gatilhoServicos.remove(s.id);
                          }
                        }),
                      ),
                  ],
                ),
              ] else
                TextField(
                  controller: _grupos,
                  decoration: InputDecoration(
                    labelText: _tipo == 'todos_grupos'
                        ? 'Grupos (todos) — ex.: sofa, colchao'
                        : 'Grupos (qualquer) — ex.: sofa, colchao',
                    helperText: 'Use o campo Grupo do cadastro de Serviços',
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Não mostrar se o carrinho já tiver (opcional):',
                style: TextStyle(fontSize: 12, color: ClxBrand.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in widget.servicos)
                    FilterChip(
                      label: Text(s.nome, style: const TextStyle(fontSize: 11)),
                      selected: _excluir.contains(s.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _excluir.add(s.id);
                        } else {
                          _excluir.remove(s.id);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _prio,
                decoration: const InputDecoration(
                  labelText: 'Prioridade (maior aparece primeiro)',
                ),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text(
                  'Oferta exclusiva: preço promo só vale se aceitar o bump',
                ),
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '…' : 'Salvar'),
        ),
      ],
    );
  }
}

