/// Telas do admin da vitrine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/cleanox_logo.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';
import 'vitrine_admin_auth.dart';
import 'vitrine_midia_repository.dart';

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
                .where((a) =>
                    a.status != 'cancelada' && a.status != 'concluida')
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
  final _titulo = TextEditingController();
  final _sub = TextEditingController();
  final _cta = TextEditingController();
  final _wa = TextEditingController();
  final _rodape = TextEditingController();
  final _cidades = TextEditingController();
  final _como = TextEditingController();
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
      _titulo.text = c.heroTitulo;
      _sub.text = c.heroSubtitulo;
      _cta.text = c.heroCta;
      _wa.text = c.whatsappExibido;
      _rodape.text = c.rodapeMsg;
      _cidades.text = c.cidadesTexto;
      _como.text = c.comoFunciona;
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
      await ref.read(vitrineAdminApiProvider).adminSaveConfig(
            VitrineConfig(
              heroTitulo: _titulo.text.trim(),
              heroSubtitulo: _sub.text.trim(),
              heroCta: _cta.text.trim(),
              whatsappExibido: _wa.text.trim(),
              rodapeMsg: _rodape.text.trim(),
              cidadesTexto: _cidades.text.trim(),
              comoFunciona: _como.text.trim(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuração salva')),
      );
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
    _titulo.dispose();
    _sub.dispose();
    _cta.dispose();
    _wa.dispose();
    _rodape.dispose();
    _cidades.dispose();
    _como.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Personalizar site',
                style: TextStyle(
                  fontSize: 20,
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
          color: const Color(0xFFF0FBFC),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Dica de mídia: em Mídia/fotos use as chaves hero (capa), '
              'categoria_sofa, categoria_colchao, categoria_poltrona, '
              'categoria_tapete, categoria_auto, categoria_cadeira. '
              'Order bumps usam a foto do próprio bump ou chave bump_<id>.',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 12,
                color: ClxBrand.navy,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título do hero'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sub,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Subtítulo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cta,
                  decoration: const InputDecoration(labelText: 'Texto do botão'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wa,
                  decoration:
                      const InputDecoration(labelText: 'WhatsApp exibido'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cidades,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Cidades atendidas (texto livre)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rodape,
                  decoration: const InputDecoration(labelText: 'Mensagem rodapé'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _como,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Como funciona'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Serviços ────────────────────────────────────────────────────────────────

class VitrineAdminServicosScreen extends ConsumerStatefulWidget {
  const VitrineAdminServicosScreen({super.key});

  @override
  ConsumerState<VitrineAdminServicosScreen> createState() =>
      _VitrineAdminServicosScreenState();
}

class _VitrineAdminServicosScreenState
    extends ConsumerState<VitrineAdminServicosScreen> {
  late Future<List<VitrineAdminServico>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(vitrineAdminApiProvider).adminListServicos();
  }

  Future<void> _toggle(
    VitrineAdminServico s, {
    bool? vitrine,
    bool? destaque,
  }) async {
    await ref.read(vitrineAdminApiProvider).adminPatchServico(
          s.id,
          vitrine: vitrine,
          vitrineDestaque: destaque,
        );
    if (!mounted) return;
    setState(_reload);
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
        final items = snap.data ?? const <VitrineAdminServico>[];
        return ListView(
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
              'Marque o que aparece no site de agendamento e o que é destaque na home.',
              style: TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final s in items)
              Card(
                child: SwitchListTile(
                  title: Text(s.nome,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${s.grupo.isEmpty ? '—' : s.grupo} · ${formatCurrency(s.valorBase)}'
                    '${s.vitrineDestaque ? ' · destaque' : ''}',
                  ),
                  value: s.vitrine,
                  onChanged: (v) => _toggle(s, vitrine: v),
                  secondary: IconButton(
                    tooltip: 'Destaque na home',
                    icon: Icon(
                      s.vitrineDestaque ? Icons.star : Icons.star_border,
                      color: s.vitrineDestaque ? ClxBrand.cyan : ClxBrand.muted,
                    ),
                    onPressed: () =>
                        _toggle(s, destaque: !s.vitrineDestaque),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
              'Ofertas que aparecem no orçamento conforme o que o cliente marcou.',
              style: TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum order bump cadastrado.'),
                ),
              ),
            for (final b in items)
              Card(
                child: ListTile(
                  title: Text(b.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${b.gatilhoTipo}: ${b.gatilhoValores.join(", ")} · '
                    '${formatCurrency(b.precoPromo)}'
                    '${b.ativo ? "" : " · PAUSADO"}',
                  ),
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
  late final TextEditingController _gatilho;
  late final TextEditingController _prio;
  String _tipo = 'qualquer_grupo';
  String? _servicoOferta;
  bool _ativo = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _desc = TextEditingController(text: e?.descricao ?? '');
    _badge = TextEditingController(text: e?.badge ?? '');
    _cheio = TextEditingController(
      text: e != null && e.precoCheio > 0 ? '${e.precoCheio}' : '',
    );
    _promo = TextEditingController(
      text: e != null ? '${e.precoPromo}' : '',
    );
    _gatilho = TextEditingController(
      text: e?.gatilhoValores.join(', ') ?? '',
    );
    _prio = TextEditingController(text: '${e?.prioridade ?? 10}');
    _tipo = e?.gatilhoTipo ?? 'qualquer_grupo';
    _servicoOferta = e?.servicoOferta;
    _ativo = e?.ativo ?? true;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    _badge.dispose();
    _cheio.dispose();
    _promo.dispose();
    _gatilho.dispose();
    _prio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_servicoOferta == null || _servicoOferta!.isEmpty) {
      setState(() => _error = 'Escolha o serviço da oferta');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final vals = _gatilho.text
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.onSave({
        'titulo': _titulo.text.trim(),
        'descricao': _desc.text.trim(),
        'badge': _badge.text.trim(),
        'servico_oferta': _servicoOferta,
        'preco_cheio': double.tryParse(_cheio.text.replaceAll(',', '.')) ?? 0,
        'preco_promo': double.tryParse(_promo.text.replaceAll(',', '.')) ?? 0,
        'gatilho_tipo': _tipo,
        'gatilho_valores': vals,
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
      title: Text(widget.existing == null ? 'Novo order bump' : 'Editar bump'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: _badge,
                decoration:
                    const InputDecoration(labelText: 'Badge (ex.: −39%)'),
              ),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _servicoOferta,
                decoration:
                    const InputDecoration(labelText: 'Serviço ofertado'),
                items: [
                  for (final s in widget.servicos)
                    DropdownMenuItem(value: s.id, child: Text(s.nome)),
                ],
                onChanged: (v) => setState(() => _servicoOferta = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cheio,
                      decoration:
                          const InputDecoration(labelText: 'Preço cheio'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _promo,
                      decoration:
                          const InputDecoration(labelText: 'Preço promo'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de gatilho'),
                items: const [
                  DropdownMenuItem(
                    value: 'qualquer_grupo',
                    child: Text('Se tiver grupo…'),
                  ),
                  DropdownMenuItem(
                    value: 'qualquer_servico',
                    child: Text('Se tiver serviço id…'),
                  ),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              TextField(
                controller: _gatilho,
                decoration: InputDecoration(
                  labelText: _tipo == 'qualquer_grupo'
                      ? 'Grupos (ex.: sofa, colchao)'
                      : 'IDs de serviço (separados por vírgula)',
                ),
              ),
              TextField(
                controller: _prio,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
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

// ── Mídia ───────────────────────────────────────────────────────────────────

class VitrineAdminMidiaScreen extends ConsumerStatefulWidget {
  const VitrineAdminMidiaScreen({super.key});

  @override
  ConsumerState<VitrineAdminMidiaScreen> createState() =>
      _VitrineAdminMidiaScreenState();
}

class _VitrineAdminMidiaScreenState
    extends ConsumerState<VitrineAdminMidiaScreen> {
  late Future<List<VitrineMidiaItem>> _future;

  VitrineMidiaRepository get _repo =>
      VitrineMidiaRepository(ref.read(vitrineAdminPbProvider));

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.list();
  }

  Future<void> _openEditor([VitrineMidiaItem? existing]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MidiaEditorDialog(
        existing: existing,
        onSave: ({
          required chave,
          required titulo,
          required urlExterna,
          required ordem,
          required ativo,
          fileBytes,
          filename,
        }) async {
          if (existing == null) {
            await _repo.create(
              chave: chave,
              titulo: titulo,
              urlExterna: urlExterna,
              ordem: ordem,
              ativo: ativo,
              fileBytes: fileBytes,
              filename: filename,
            );
          } else {
            await _repo.update(
              existing.id,
              chave: chave,
              titulo: titulo,
              urlExterna: urlExterna,
              ordem: ordem,
              ativo: ativo,
              fileBytes: fileBytes,
              filename: filename,
            );
          }
        },
      ),
    );
    if (ok == true && mounted) setState(_reload);
  }

  Future<void> _delete(VitrineMidiaItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir mídia?'),
        content: Text(m.chave),
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
    await _repo.delete(m.id);
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
        final items = snap.data ?? const <VitrineMidiaItem>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mídia / fotos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ClxBrand.navy,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Nova mídia'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Fotos do hero, categorias e order bumps. Use chave estável '
              '(ex.: hero, categoria_sofa, bump_cadeira).',
              style: TextStyle(color: ClxBrand.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma mídia ainda. Toque em “Nova mídia” para enviar '
                    'uma foto ou colar uma URL externa.',
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final m in items)
                    SizedBox(
                      width: 220,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: m.displayUrl != null
                                  ? Image.network(
                                      m.displayUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                        color: Color(0xFFE2E8F0),
                                        child: Icon(Icons.broken_image),
                                      ),
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFFE8F4F6),
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: ClxBrand.cyan,
                                        size: 36,
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.chave,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ClxBrand.navy,
                                    ),
                                  ),
                                  if (m.titulo.isNotEmpty)
                                    Text(
                                      m.titulo,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: ClxBrand.muted,
                                      ),
                                    ),
                                  Text(
                                    m.ativo ? 'Ativo' : 'Pausado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: m.ativo
                                          ? const Color(0xFF059669)
                                          : ClxBrand.muted,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _openEditor(m),
                                      ),
                                      IconButton(
                                        tooltip: 'Excluir',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _delete(m),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _MidiaEditorDialog extends StatefulWidget {
  const _MidiaEditorDialog({
    required this.existing,
    required this.onSave,
  });

  final VitrineMidiaItem? existing;
  final Future<void> Function({
    required String chave,
    required String titulo,
    required String urlExterna,
    required int ordem,
    required bool ativo,
    List<int>? fileBytes,
    String? filename,
  }) onSave;

  @override
  State<_MidiaEditorDialog> createState() => _MidiaEditorDialogState();
}

class _MidiaEditorDialogState extends State<_MidiaEditorDialog> {
  late final TextEditingController _chave;
  late final TextEditingController _titulo;
  late final TextEditingController _url;
  late final TextEditingController _ordem;
  bool _ativo = true;
  bool _saving = false;
  String? _error;
  List<int>? _bytes;
  String? _filename;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _chave = TextEditingController(text: e?.chave ?? 'hero');
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _url = TextEditingController(text: e?.urlExterna ?? '');
    _ordem = TextEditingController(text: '${e?.ordem ?? 0}');
    _ativo = e?.ativo ?? true;
  }

  @override
  void dispose() {
    _chave.dispose();
    _titulo.dispose();
    _url.dispose();
    _ordem.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _bytes = bytes;
      _filename = x.name;
    });
  }

  Future<void> _save() async {
    if (_chave.text.trim().isEmpty) {
      setState(() => _error = 'Chave obrigatória');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        chave: _chave.text.trim(),
        titulo: _titulo.text.trim(),
        urlExterna: _url.text.trim(),
        ordem: int.tryParse(_ordem.text) ?? 0,
        ativo: _ativo,
        fileBytes: _bytes,
        filename: _filename,
      );
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
      title: Text(widget.existing == null ? 'Nova mídia' : 'Editar mídia'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _chave,
                decoration: const InputDecoration(
                  labelText: 'Chave',
                  hintText: 'hero, categoria_sofa…',
                ),
              ),
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'URL externa (opcional)',
                ),
              ),
              TextField(
                controller: _ordem,
                decoration: const InputDecoration(labelText: 'Ordem'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.upload),
                    label: Text(
                      _filename ?? 'Escolher foto',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_bytes != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${(_bytes!.length / 1024).toStringAsFixed(0)} KB',
                      style: const TextStyle(fontSize: 12, color: ClxBrand.muted),
                    ),
                  ],
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo na vitrine'),
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
