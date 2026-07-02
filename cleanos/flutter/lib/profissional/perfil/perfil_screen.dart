/// perfil_screen.dart — Aba "Perfil" (Slice B3).
///
/// Espelha `Perfil.tsx`: card do usuário (média de avaliação), resumo do dia
/// (agendados/concluídos), alterar senha, liberar localização (placeholder B4) e
/// sair. As estatísticas são secundárias — falham em silêncio sem travar a tela.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/env/env.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../data/prof_providers.dart';
import '../location/tracking_providers.dart';

/// Estatísticas do perfil (resumo do dia + média de avaliação).
class PerfilStats {
  const PerfilStats({
    required this.totalHoje,
    required this.concluidasHoje,
    this.media,
    this.totalAvaliadas = 0,
  });

  final int totalHoje;
  final int concluidasHoje;
  final double? media;
  final int totalAvaliadas;
}

final perfilStatsProvider = FutureProvider.autoDispose<PerfilStats>((
  ref,
) async {
  final id = ref.watch(currentProfIdProvider);
  if (id == null) return const PerfilStats(totalHoje: 0, concluidasHoje: 0);
  final repo = ref.watch(ordensRepositoryProvider);
  final bounds = getBrtDayBounds();

  final hoje = await repo.list(
    perPage: 100,
    filter:
        "profissional = '$id' && data_hora >= '${bounds.todayStart}' "
        "&& data_hora < '${bounds.tomorrowStart}'",
  );
  final avaliadas = await repo.list(
    perPage: 200,
    filter:
        "profissional = '$id' && status = 'concluida' && avaliacao_nota >= 1",
  );

  final concluidas = hoje.items
      .where((o) => o.status == OSStatus.concluida)
      .length;
  double? media;
  if (avaliadas.items.isNotEmpty) {
    final soma = avaliadas.items.fold<double>(
      0,
      (acc, o) => acc + (o.avaliacaoNota ?? 0),
    );
    media = soma / avaliadas.items.length;
  }
  return PerfilStats(
    totalHoje: hoje.totalItems,
    concluidasHoje: concluidas,
    media: media,
    totalAvaliadas: avaliadas.items.length,
  );
});

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(perfilStatsProvider);
    final rawName = user?.displayName ?? '—';
    final displayName = rawName != '—' ? rawName : 'Profissional';
    final avatarInitial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'P';

    return Column(
      children: [
        _Header(mode: ref.watch(themeModeControllerProvider), ref: ref),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(ClxSpace.x4),
            children: [
              // Card do usuário.
              ClxCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: clx.accent,
                      child: Text(
                        avatarInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    Text(
                      displayName,
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if ((user?.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user!.email,
                        style: TextStyle(color: clx.ink3, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: ClxSpace.x2),
                    ClxChip(label: 'Profissional', color: clx.primary),
                    statsAsync.maybeWhen(
                      data: (s) => s.media != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: ClxSpace.x3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sua avaliação: ',
                                    style: TextStyle(
                                      color: clx.ink2,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  StarRating(value: s.media!, size: 15),
                                  const SizedBox(width: ClxSpace.x1),
                                  Text(
                                    s.media!.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: clx.ink,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(top: ClxSpace.x2),
                              child: Text(
                                'Nenhuma avaliação ainda',
                                style: TextStyle(color: clx.ink3, fontSize: 13),
                              ),
                            ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ClxSpace.x3),

              // Resumo do dia.
              _ResumoDoDia(statsAsync: statsAsync),
              const SizedBox(height: ClxSpace.x3),

              // Alterar senha.
              const _AlterarSenhaCard(),
              const SizedBox(height: ClxSpace.x3),

              // Liberar localização (placeholder / B4).
              const _LiberarLocalizacaoTile(),
              const SizedBox(height: ClxSpace.x3),

              // Sair.
              ClxButton(
                label: 'Sair do sistema',
                variant: ClxButtonVariant.ghost,
                icon: Icons.logout_rounded,
                expand: true,
                onPressed: () => ref.read(authServiceProvider).logout(),
              ),
              const SizedBox(height: ClxSpace.x8),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mode, required this.ref});

  final ThemeMode mode;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x4,
        ClxSpace.x3,
        ClxSpace.x2,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        color: clx.bg,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Perfil',
              style: TextStyle(
                color: clx.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Alternar tema',
            icon: Icon(
              mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () =>
                ref.read(themeModeControllerProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

class _ResumoDoDia extends StatelessWidget {
  const _ResumoDoDia({required this.statsAsync});

  final AsyncValue<PerfilStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x4,
              ClxSpace.x3,
              ClxSpace.x4,
              ClxSpace.x2,
            ),
            child: Text(
              'RESUMO DE HOJE',
              style: TextStyle(
                color: clx.ink3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Divider(height: 1, color: clx.line),
          Padding(
            padding: const EdgeInsets.all(ClxSpace.x4),
            child: statsAsync.when(
              loading: () => const Center(child: Spinner(size: 20)),
              error: (_, __) => Text(
                'Não foi possível carregar o resumo.',
                style: TextStyle(color: clx.ink3, fontSize: 13),
              ),
              data: (s) => Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${s.totalHoje}',
                      label: 'Agendados',
                      color: clx.accent,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      value: '${s.concluidasHoje}',
                      label: 'Concluídos',
                      color: clx.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: clx.ink3,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LiberarLocalizacaoTile extends ConsumerStatefulWidget {
  const _LiberarLocalizacaoTile();

  @override
  ConsumerState<_LiberarLocalizacaoTile> createState() =>
      _LiberarLocalizacaoTileState();
}

class _LiberarLocalizacaoTileState
    extends ConsumerState<_LiberarLocalizacaoTile> {
  bool _busy = false;

  Future<void> _liberar() async {
    if (!Env.trackingEnabled) {
      showClxToast(
        context,
        'Localização em tempo real chega numa próxima atualização.',
        type: ToastType.info,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final perm = await ref
          .read(locationTrackingServiceProvider)
          .ensurePermission();
      if (!mounted) return;
      final ok = perm.name == 'always' || perm.name == 'whileInUse';
      showClxToast(
        context,
        ok
            ? 'Localização liberada. Obrigado!'
            : 'Permissão de localização negada.',
        type: ok ? ToastType.success : ToastType.warning,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      onTap: _busy ? null : _liberar,
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: clx.ink2),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liberar localização',
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  Env.trackingEnabled
                      ? 'Permite avisar o cliente quando você está a caminho.'
                      : 'Em breve: acompanhamento em tempo real a caminho da OS.',
                  style: TextStyle(color: clx.ink3, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (_busy)
            const Spinner(size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: clx.ink3),
        ],
      ),
    );
  }
}

class _AlterarSenhaCard extends ConsumerStatefulWidget {
  const _AlterarSenhaCard();

  @override
  ConsumerState<_AlterarSenhaCard> createState() => _AlterarSenhaCardState();
}

class _AlterarSenhaCardState extends ConsumerState<_AlterarSenhaCard> {
  bool _open = false;
  bool _saving = false;
  bool _success = false;
  String? _error;
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_old.text.isEmpty) return 'Informe a senha atual.';
    if (_new.text.length < 8) {
      return 'A nova senha deve ter ao menos 8 caracteres.';
    }
    if (_new.text != _confirm.text) return 'As senhas não coincidem.';
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(pocketBaseProvider)
          .collection(Collections.users)
          .update(
            user.id,
            body: {
              'oldPassword': _old.text,
              'password': _new.text,
              'passwordConfirm': _confirm.text,
            },
          );
      setState(() => _success = true);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      ref.read(authServiceProvider).logout();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível alterar a senha. Confira a senha atual.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              _open = !_open;
              _error = null;
            }),
            borderRadius: ClxRadii.rLg,
            child: Padding(
              padding: const EdgeInsets.all(ClxSpace.x4),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 20, color: clx.ink2),
                  const SizedBox(width: ClxSpace.x3),
                  Expanded(
                    child: Text(
                      'Alterar senha',
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: clx.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x4,
                0,
                ClxSpace.x4,
                ClxSpace.x4,
              ),
              child: _success
                  ? Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: clx.success),
                        const SizedBox(width: ClxSpace.x2),
                        Expanded(
                          child: Text(
                            'Senha alterada! Redirecionando para o login…',
                            style: TextStyle(
                              color: clx.success,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          ErrorBanner(message: _error!),
                          const SizedBox(height: ClxSpace.x3),
                        ],
                        _pwdField('Senha atual', _old),
                        const SizedBox(height: ClxSpace.x2),
                        _pwdField('Nova senha (mín. 8)', _new),
                        const SizedBox(height: ClxSpace.x2),
                        _pwdField('Confirmar nova senha', _confirm),
                        const SizedBox(height: ClxSpace.x3),
                        ClxButton(
                          label: 'Alterar senha',
                          variant: ClxButtonVariant.secondary,
                          expand: true,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _pwdField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      enabled: !_saving,
      decoration: InputDecoration(labelText: label),
    );
  }
}
