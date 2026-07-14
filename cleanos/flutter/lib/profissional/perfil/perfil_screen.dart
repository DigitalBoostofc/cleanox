/// perfil_screen.dart — Aba "Perfil" (Slice B3).
///
/// Espelha `Perfil.tsx`: card do usuário (média de avaliação), resumo do dia
/// (agendados/concluídos), alterar senha, liberar localização (placeholder B4) e
/// sair. As estatísticas são secundárias — falham em silêncio sem travar a tela.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/env/env.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/repositories/usuarios_repository.dart';
import '../../painel/data/painel_providers.dart';
import '../data/prof_filters.dart';
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

  // A-04: filtros via prof_filters (escaping pbStringLiteral, sem interpolação).
  final hoje = await repo.list(
    perPage: 100,
    filter: profOrdensHojeFilter(id, bounds),
  );
  // ⚠️ A-08: teto de 200 — acima disso a média passa a considerar só as 200 OS
  // avaliadas MAIS RECENTES (sort explícito abaixo, para o corte ser
  // determinístico e enviesado pro presente, não arbitrário). Paginar tudo ou
  // agregar server-side é over-engineering pro volume real (< ~50 OS/dia →
  // anos até um profissional passar de 200 avaliadas); se estourar, agregação
  // server-side é o caminho.
  final avaliadas = await repo.list(
    perPage: 200,
    sort: '-data_hora',
    filter: profAvaliadasFilter(id),
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

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  bool _uploadingPhoto = false;

  Future<void> _pickPhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _uploadingPhoto) return;
    final file = await pickImageWithSource(context);
    if (file == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      await ref.read(usuariosRepositoryProvider).update(
        user.id,
        <String, dynamic>{},
        avatar: AvatarUpload(
          bytes: bytes,
          filename: file.name.isNotEmpty ? file.name : 'avatar.jpg',
        ),
      );
      await ref.read(pocketBaseProvider).collection('users').authRefresh();
      if (mounted) {
        showClxToast(context, 'Foto atualizada.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível atualizar a foto.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(perfilStatsProvider);
    final rawName = user?.displayName ?? '—';
    final displayName = rawName != '—' ? rawName : 'Profissional';
    final mode = ref.watch(themeModeControllerProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ClxFadeSlide(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        clx.accent,
                        Color.lerp(clx.accent, clx.primary, 0.55)!,
                        clx.primary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: clx.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                      children: [
                        Row(
                          children: [
                            const Spacer(),
                            IconButton(
                              tooltip: 'Alternar tema',
                              icon: Icon(
                                mode == ThemeMode.dark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () => ref
                                  .read(themeModeControllerProvider.notifier)
                                  .toggle(),
                            ),
                          ],
                        ),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            if (_uploadingPhoto)
                              const SizedBox(
                                width: 96,
                                height: 96,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              UserAvatar(
                                user: user,
                                radius: 48,
                                onTap: _pickPhoto,
                              ),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _uploadingPhoto ? null : _pickPhoto,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((user?.email ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user!.email,
                            style: tt.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Profissional',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        statsAsync.maybeWhen(
                          data: (s) => s.media != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Avaliação: ',
                                        style: tt.bodyMedium?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                      StarRating(value: s.media!, size: 15),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.media!.toStringAsFixed(1),
                                        style: tt.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Nenhuma avaliação ainda',
                                    style: tt.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        TextButton.icon(
                          onPressed: _uploadingPhoto ? null : _pickPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: Colors.white,
                          ),
                          label: Text(
                            user?.hasAvatar == true
                                ? 'Trocar foto'
                                : 'Adicionar foto',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(ClxSpace.x4),
                child: Column(
                  children: [
                    ClxFadeSlide(
                      delay: const Duration(milliseconds: 50),
                      child: _ResumoDoDia(statsAsync: statsAsync),
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    ClxFadeSlide(
                      delay: const Duration(milliseconds: 90),
                      child: const _AlterarSenhaCard(),
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    ClxFadeSlide(
                      delay: const Duration(milliseconds: 120),
                      child: const _LiberarLocalizacaoTile(),
                    ),
                    const SizedBox(height: ClxSpace.x3),
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
          ),
        ),
      ],
    );
  }
}

class _ResumoDoDia extends StatelessWidget {
  const _ResumoDoDia({required this.statsAsync});

  final AsyncValue<PerfilStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
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
              style: tt.labelSmall?.copyWith(
                color: clx.ink3,
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
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
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
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: tt.displaySmall?.copyWith(
            color: color,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tt.labelMedium?.copyWith(color: clx.ink3),
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
    final tt = Theme.of(context).textTheme;
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
                  style: tt.titleSmall?.copyWith(color: clx.ink),
                ),
                Text(
                  Env.trackingEnabled
                      ? 'Permite avisar o cliente quando você está a caminho.'
                      : 'Em breve: acompanhamento em tempo real a caminho da OS.',
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
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
  // Erros por-campo (espelha `pwdFieldErrs` de Perfil.tsx).
  String? _oldErr;
  String? _newErr;
  String? _confirmErr;
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

  /// Valida campo a campo (espelha `validatePwd` de Perfil.tsx). Devolve `true`
  /// quando não há erros; caso contrário, preenche os erros por-campo.
  bool _validate() {
    String? oldErr;
    String? newErr;
    String? confirmErr;
    if (_old.text.isEmpty) oldErr = 'Informe a senha atual';
    if (_new.text.isEmpty) {
      newErr = 'Informe a nova senha';
    } else if (_new.text.length < 8) {
      newErr = 'Mínimo 8 caracteres';
    }
    if (_new.text != _confirm.text) confirmErr = 'As senhas não coincidem';
    setState(() {
      _oldErr = oldErr;
      _newErr = newErr;
      _confirmErr = confirmErr;
    });
    return oldErr == null && newErr == null && confirmErr == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
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
    } catch (err) {
      if (mounted) setState(() => _error = _pbPasswordError(err));
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
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: clx.ink),
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
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: clx.success),
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
                        _pwdField(
                          'Senha atual',
                          _old,
                          error: _oldErr,
                          onChanged: () {
                            if (_oldErr != null) {
                              setState(() => _oldErr = null);
                            }
                          },
                        ),
                        const SizedBox(height: ClxSpace.x2),
                        _pwdField(
                          'Nova senha',
                          _new,
                          error: _newErr,
                          hint: 'Mínimo 8 caracteres',
                          onChanged: () {
                            if (_newErr != null) {
                              setState(() => _newErr = null);
                            }
                          },
                        ),
                        const SizedBox(height: ClxSpace.x2),
                        _pwdField(
                          'Confirmar nova senha',
                          _confirm,
                          error: _confirmErr,
                          onChanged: () {
                            if (_confirmErr != null) {
                              setState(() => _confirmErr = null);
                            }
                          },
                        ),
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

  Widget _pwdField(
    String label,
    TextEditingController ctrl, {
    String? error,
    String? hint,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      enabled: !_saving,
      onChanged: onChanged == null ? null : (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
      ),
    );
  }

  /// Traduz o erro do PocketBase ao trocar a senha (espelha `pbPasswordError`
  /// de Perfil.tsx): distingue senha atual incorreta, nova senha inválida e
  /// confirmação divergente a partir do corpo 400.
  String _pbPasswordError(Object? err) {
    if (err is ClientException) {
      if (err.statusCode == 400) {
        final msg = (err.response['message'] as String? ?? '').toLowerCase();
        if (msg.contains('authenticate') || msg.contains('failed')) {
          return 'Senha atual incorreta.';
        }
        final data = err.response['data'];
        if (data is Map) {
          String? fieldMsg(String key) {
            final f = data[key];
            return f is Map ? f['message'] as String? : null;
          }
          if (fieldMsg('oldPassword') != null) return 'Senha atual incorreta.';
          final pwdMsg = fieldMsg('password');
          if (pwdMsg != null) return 'Nova senha inválida: $pwdMsg';
          if (fieldMsg('passwordConfirm') != null) {
            return 'As senhas não coincidem.';
          }
        }
        return 'Dados inválidos. Verifique o formulário.';
      }
      if (err.statusCode == 0) return 'Sem conexão com o servidor.';
    }
    return 'Ocorreu um erro inesperado.';
  }
}
