/// conta_screen.dart — "Minha Conta" do Painel (espelha `Conta.tsx`).
///
/// Dados do próprio usuário (via `currentUserProvider`) + trocar senha com
/// validação, loading e sucesso/erro. A troca de senha usa o `pocketBaseProvider`
/// exposto pelo core (mesmo caminho do `perfil_screen.dart` do profissional) —
/// consome o singleton, não edita o core. Após o sucesso, desloga (a sessão
/// antiga é invalidada pela troca de senha).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/collections.dart';

/// Rótulo do papel (espelha `ROLE_LABELS`).
String _roleLabel(Role? role) => switch (role) {
  Role.admin => 'Admin',
  Role.gerente => 'Gerente',
  Role.profissional => 'Profissional',
  null => '—',
};

/// Traduz o erro da troca de senha para PT-BR (espelha `pbPasswordError`).
String _passwordError(Object err) {
  if (err is ClientException) {
    if (err.statusCode == 400) {
      final data = err.response['data'];
      if (data is Map) {
        if (data['oldPassword'] != null) return 'Senha atual incorreta.';
        final pwd = data['password'];
        if (pwd is Map && pwd['message'] != null) {
          return 'Nova senha inválida: ${pwd['message']}';
        }
        if (data['passwordConfirm'] != null) return 'As senhas não coincidem.';
      }
      return 'Dados inválidos. Verifique o formulário.';
    }
    if (err.statusCode == 0) return 'Sem conexão com o servidor.';
  }
  return 'Ocorreu um erro inesperado.';
}

class ContaScreen extends ConsumerWidget {
  const ContaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x6),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DadosCard(
                  nome: user?.displayName ?? '—',
                  email: user?.email ?? '—',
                  role: role,
                ),
                const SizedBox(height: ClxSpace.x5),
                const _AlterarSenhaCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DadosCard extends StatelessWidget {
  const _DadosCard({
    required this.nome,
    required this.email,
    required this.role,
  });

  final String nome;
  final String email;
  final Role? role;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 18, color: clx.ink2),
              const SizedBox(width: ClxSpace.x2),
              Text(
                'Minha conta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x4),
          _DetailRow(
            label: 'Nome',
            child: Text(nome, style: _valStyle(context, clx)),
          ),
          Divider(height: ClxSpace.x5, color: clx.line),
          _DetailRow(
            label: 'E-mail',
            child: Text(email, style: _valStyle(context, clx)),
          ),
          Divider(height: ClxSpace.x5, color: clx.line),
          _DetailRow(
            label: 'Papel',
            child: ClxChip(label: _roleLabel(role), color: clx.accent),
          ),
        ],
      ),
    );
  }

  TextStyle? _valStyle(BuildContext context, CleanoxColors clx) =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: clx.ink,
        fontWeight: FontWeight.w600,
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3)),
        ),
        const SizedBox(width: ClxSpace.x3),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ],
    );
  }
}

class _AlterarSenhaCard extends ConsumerStatefulWidget {
  const _AlterarSenhaCard();

  @override
  ConsumerState<_AlterarSenhaCard> createState() => _AlterarSenhaCardState();
}

class _AlterarSenhaCardState extends ConsumerState<_AlterarSenhaCard> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _success = false;
  String? _error;
  final Map<String, String> _fieldErrs = {};

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final errs = <String, String>{};
    if (_old.text.isEmpty) errs['old'] = 'Informe a senha atual';
    if (_new.text.isEmpty) {
      errs['new'] = 'Informe a nova senha';
    } else if (_new.text.length < 8) {
      errs['new'] = 'Mínimo 8 caracteres';
    }
    if (_new.text != _confirm.text) {
      errs['confirm'] = 'As senhas não coincidem';
    }
    setState(() {
      _fieldErrs
        ..clear()
        ..addAll(errs);
    });
    return errs.isEmpty;
  }

  void _clearField(String key) {
    if (_fieldErrs.containsKey(key)) setState(() => _fieldErrs.remove(key));
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
      if (!mounted) return;
      setState(() => _success = true);
      _old.clear();
      _new.clear();
      _confirm.clear();
      await Future<void>.delayed(const Duration(milliseconds: 2400));
      ref.read(authServiceProvider).logout();
    } catch (e) {
      if (mounted) setState(() => _error = _passwordError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: clx.ink2),
              const SizedBox(width: ClxSpace.x2),
              Text(
                'Alterar senha',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x4),
          if (_success)
            _SuccessBanner()
          else ...[
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: ClxSpace.x4),
            ],
            _PwdField(
              label: 'Senha atual',
              controller: _old,
              error: _fieldErrs['old'],
              autofillHint: AutofillHints.password,
              enabled: !_saving,
              onChanged: (_) => _clearField('old'),
            ),
            const SizedBox(height: ClxSpace.x3),
            _PwdField(
              label: 'Nova senha',
              hint: 'Ao menos 8 caracteres',
              controller: _new,
              error: _fieldErrs['new'],
              autofillHint: AutofillHints.newPassword,
              enabled: !_saving,
              onChanged: (_) => _clearField('new'),
            ),
            const SizedBox(height: ClxSpace.x3),
            _PwdField(
              label: 'Confirmar nova senha',
              hint: 'Repita a nova senha',
              controller: _confirm,
              error: _fieldErrs['confirm'],
              autofillHint: AutofillHints.newPassword,
              enabled: !_saving,
              onChanged: (_) => _clearField('confirm'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: ClxSpace.x5),
            ClxButton(
              label: 'Alterar senha',
              icon: Icons.check_rounded,
              expand: true,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x4),
      decoration: BoxDecoration(
        color: clx.successBg,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: clx.success, size: 22),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Text(
              'Senha alterada com sucesso! Você será redirecionado para o login…',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: clx.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de senha com rótulo, dica e erro por campo.
class _PwdField extends StatelessWidget {
  const _PwdField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.hint,
    this.error,
    this.autofillHint,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool enabled;
  final String? error;
  final String? autofillHint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: clx.ink2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ClxSpace.x1),
        TextField(
          controller: controller,
          obscureText: true,
          enabled: enabled,
          autofillHints: autofillHint == null ? null : [autofillHint!],
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(hintText: hint, errorText: error),
        ),
      ],
    );
  }
}
