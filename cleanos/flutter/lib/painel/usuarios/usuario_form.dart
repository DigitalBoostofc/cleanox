/// usuario_form.dart — Formulário de criar/editar Usuário (coleção auth `users`).
///
/// Espelha o modal de `Usuarios.tsx`: nome, e-mail + senha (só na CRIAÇÃO), papel
/// (admin/gerente/profissional). Regras de segurança espelhadas do React:
///   • ao EDITAR, e-mail/senha não mudam aqui (senha → Admin UI do PocketBase);
///   • ninguém altera o PRÓPRIO papel (o dropdown fica travado);
///   • senha mínima 8 + confirmação na criação.
/// O servidor continua sendo a linha de defesa — a UI só antecipa a validação.
///
/// Grava via `UsuariosRepository` (core). Resolve `true` quando salvou.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/user.dart';
import '../data/painel_providers.dart';

String roleLabel(Role r) => switch (r) {
  Role.admin => 'Admin',
  Role.gerente => 'Gerente',
  Role.profissional => 'Profissional',
};

String roleDescription(Role r) => switch (r) {
  Role.admin => 'Admin — acesso total ao painel',
  Role.gerente => 'Gerente — acesso total exceto marcar repasse',
  Role.profissional => 'Profissional — acessa o app do profissional',
};

/// Abre o formulário de usuário. [editing] nulo = criar. Resolve `true` se salvou.
Future<bool?> showUsuarioForm(BuildContext context, {User? editing}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(ClxSpace.x4),
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: UsuarioForm(editing: editing),
      ),
    ),
  );
}

class UsuarioForm extends ConsumerStatefulWidget {
  const UsuarioForm({super.key, this.editing});

  final User? editing;

  @override
  ConsumerState<UsuarioForm> createState() => _UsuarioFormState();
}

class _UsuarioFormState extends ConsumerState<UsuarioForm> {
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _senha = TextEditingController();
  final TextEditingController _senhaConfirm = TextEditingController();

  Role _role = Role.profissional;
  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.editing;
    if (u != null) {
      _nome.text = u.name.isNotEmpty ? u.name : (u.nome ?? '');
      _email.text = u.email;
      _role = u.role;
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _senhaConfirm.dispose();
    super.dispose();
  }

  bool _isSelf(String? myId) =>
      _isEdit && myId != null && widget.editing!.id == myId;

  Map<String, String> _validate() {
    final errs = <String, String>{};
    if (_nome.text.trim().isEmpty) errs['nome'] = 'Nome é obrigatório';
    if (!_isEdit) {
      final email = _email.text.trim();
      if (email.isEmpty) {
        errs['email'] = 'E-mail é obrigatório';
      } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        errs['email'] = 'E-mail inválido';
      }
      if (_senha.text.isEmpty) {
        errs['senha'] = 'Senha é obrigatória';
      } else if (_senha.text.length < 8) {
        errs['senha'] = 'Mínimo 8 caracteres';
      }
      if (_senha.text != _senhaConfirm.text) {
        errs['senhaConfirm'] = 'Senhas não coincidem';
      }
    }
    return errs;
  }

  Future<void> _save() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() {
        _errs
          ..clear()
          ..addAll(errs);
      });
      return;
    }
    // Impede rebaixar o próprio papel (paridade com o React).
    final myId = ref.read(currentUserProvider)?.id;
    if (_isSelf(myId) && _role != widget.editing!.role) {
      setState(
        () => _saveError =
            'Não é possível alterar o próprio papel. Peça a outro administrador.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _errs.clear();
    });
    try {
      final repo = ref.read(usuariosRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.editing!.id, {
          'name': _nome.text.trim(),
          'role': _role.wire,
        });
      } else {
        await repo.create({
          'name': _nome.text.trim(),
          'email': _email.text.trim(),
          'role': _role.wire,
          'password': _senha.text,
          'passwordConfirm': _senhaConfirm.text,
          'emailVisibility': true,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _isEdit
              ? 'Não foi possível salvar as alterações.'
              : 'Não foi possível criar o usuário.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final myId = ref.watch(currentUserProvider)?.id;
    final self = _isSelf(myId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClxSpace.x5,
            ClxSpace.x4,
            ClxSpace.x3,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? 'Editar usuário' : 'Novo usuário',
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                color: clx.ink3,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saveError != null) ...[
                  ErrorBanner(message: _saveError!),
                  const SizedBox(height: ClxSpace.x4),
                ],
                _field(
                  label: 'Nome',
                  required: true,
                  controller: _nome,
                  errorKey: 'nome',
                  hint: 'Pedro Santos',
                  textCapitalization: TextCapitalization.words,
                ),
                if (!_isEdit)
                  _field(
                    label: 'E-mail',
                    required: true,
                    controller: _email,
                    errorKey: 'email',
                    hint: 'pedro@empresa.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                _roleField(clx, self),
                if (!_isEdit) ...[
                  _field(
                    label: 'Senha',
                    required: true,
                    controller: _senha,
                    errorKey: 'senha',
                    hint: 'Mínimo 8 caracteres',
                    obscure: true,
                  ),
                  _field(
                    label: 'Confirmar senha',
                    required: true,
                    controller: _senhaConfirm,
                    errorKey: 'senhaConfirm',
                    hint: 'Repita a senha',
                    obscure: true,
                  ),
                ],
                if (_isEdit) _resetSenhaNote(clx),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: clx.line),
        Padding(
          padding: const EdgeInsets.all(ClxSpace.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClxButton(
                label: 'Cancelar',
                variant: ClxButtonVariant.ghost,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: ClxSpace.x3),
              ClxButton(
                label: 'Salvar',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roleField(CleanoxColors clx, bool self) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Papel', required: true),
          DropdownButtonFormField<Role>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final r in Role.values)
                DropdownMenuItem(
                  value: r,
                  child: Text(
                    roleDescription(r),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (_saving || self)
                ? null
                : (v) => setState(() => _role = v ?? Role.profissional),
          ),
          if (self)
            Padding(
              padding: const EdgeInsets.only(top: ClxSpace.x1),
              child: Text(
                'Não é possível alterar o próprio papel.',
                style: TextStyle(color: clx.warning, fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resetSenhaNote(CleanoxColors clx) {
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.warningBg,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Para redefinir a senha deste usuário, use o Admin UI do PocketBase (/_/). '
        'Apenas o próprio usuário pode trocar a própria senha pelo painel.',
        style: TextStyle(color: clx.ink2, fontSize: 12.5, height: 1.5),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x1),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(
            color: clx.ink2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          children: [
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: clx.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    bool required = false,
    String? errorKey,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
  }) {
    final err = errorKey == null ? null : _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextField(
            controller: controller,
            enabled: !_saving,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            obscureText: obscure,
            onChanged: (_) {
              if (err != null) setState(() => _errs.remove(errorKey));
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              errorText: err,
            ),
          ),
        ],
      ),
    );
  }
}
