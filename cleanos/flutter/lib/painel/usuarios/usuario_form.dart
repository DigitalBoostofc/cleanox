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
import 'package:pocketbase/pocketbase.dart' show ClientException;

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/models/user.dart';
import '../../core/repositories/usuarios_repository.dart';
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
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _senha = TextEditingController();
  final TextEditingController _senhaConfirm = TextEditingController();

  Role _role = Role.profissional;
  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};
  List<int>? _avatarBytes;
  String? _avatarFilename;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.editing;
    if (u != null) {
      _nome.text = u.name.isNotEmpty ? u.name : (u.nome ?? '');
      _email.text = u.email;
      _whatsapp.text = u.whatsapp ?? '';
      _role = u.role;
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _whatsapp.dispose();
    _senha.dispose();
    _senhaConfirm.dispose();
    super.dispose();
  }

  bool _isSelf(String? myId) =>
      _isEdit && myId != null && widget.editing!.id == myId;

  Future<void> _pickAvatar() async {
    final file = await pickImageWithSource(context);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarFilename = file.name.isNotEmpty ? file.name : 'avatar.jpg';
    });
  }

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
      final avatar = (_avatarBytes != null && _avatarFilename != null)
          ? AvatarUpload(bytes: _avatarBytes!, filename: _avatarFilename!)
          : null;
      if (_isEdit) {
        await repo.update(
          widget.editing!.id,
          {
            'name': _nome.text.trim(),
            'role': _role.wire,
            'whatsapp': _whatsapp.text.trim(),
          },
          avatar: avatar,
        );
      } else {
        await repo.create(
          {
            'name': _nome.text.trim(),
            'email': _email.text.trim(),
            'role': _role.wire,
            'whatsapp': _whatsapp.text.trim(),
            'password': _senha.text,
            'passwordConfirm': _senhaConfirm.text,
            'emailVisibility': true,
          },
          avatar: avatar,
        );
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

  Future<void> _openResetSenha() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(ClxSpace.x4),
        shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _ResetSenhaDialog(target: widget.editing!),
        ),
      ),
    );
    if (ok == true && mounted) {
      showClxToast(context, 'Senha redefinida.', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final me = ref.watch(currentUserProvider);
    final myId = me?.id;
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink,
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
                // Foto (criar e editar) — desktop web e mobile.
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Foto do usuário',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: clx.ink2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: ClxSpace.x2),
                      GestureDetector(
                        onTap: _saving ? null : _pickAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            if (_avatarBytes != null)
                              UserAvatarBytes(
                                bytes: _avatarBytes,
                                radius: 44,
                                fallbackInitial: _nome.text.isNotEmpty
                                    ? _nome.text[0].toUpperCase()
                                    : 'U',
                              )
                            else if (widget.editing != null)
                              UserAvatar(user: widget.editing, radius: 44)
                            else
                              UserAvatarBytes(
                                bytes: null,
                                radius: 44,
                                fallbackInitial: _nome.text.isNotEmpty
                                    ? _nome.text[0].toUpperCase()
                                    : 'U',
                              ),
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: clx.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: clx.bg, width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: clx.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _saving ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(
                          _avatarBytes != null ||
                                  (widget.editing?.hasAvatar ?? false)
                              ? 'Trocar foto'
                              : 'Adicionar foto',
                        ),
                      ),
                      Text(
                        'JPG ou PNG · opcional',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: clx.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ClxSpace.x4),
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
                _field(
                  label: 'WhatsApp',
                  controller: _whatsapp,
                  hint: '(11) 99999-9999',
                  keyboardType: TextInputType.phone,
                  helper:
                      'Recebe o aviso de "Nova OS" com link para abrir o app. '
                      'Só é usado para o profissional.',
                ),
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
                if (_isEdit) _resetSenhaSection(clx, me?.role),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.warning),
              ),
            ),
        ],
      ),
    );
  }

  /// Redefinição de senha (só admin). O gerente vê uma nota; o admin vê o botão
  /// que abre o dialog — a redefinição é server-side (rota com privilégio
  /// elevado + reconfirmação da senha do próprio admin).
  Widget _resetSenhaSection(CleanoxColors clx, Role? myRole) {
    if (myRole != Role.admin) {
      return Container(
        padding: const EdgeInsets.all(ClxSpace.x3),
        decoration: BoxDecoration(
          color: clx.warningBg,
          borderRadius: ClxRadii.rMd,
          border: Border.all(color: clx.warning.withValues(alpha: 0.35)),
        ),
        child: Text(
          'Redefinir a senha de outra conta é exclusivo de administradores. '
          'Cada usuário também pode trocar a própria senha em Conta.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: clx.ink2, height: 1.5),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ClxButton(
        label: 'Redefinir senha',
        icon: Icons.lock_reset_rounded,
        variant: ClxButtonVariant.ghost,
        onPressed: _saving ? null : _openResetSenha,
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: clx.ink2,
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
    String? helper,
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
              helperText: helper,
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Traduz o erro da rota de redefinição para PT-BR. As mensagens do backend já
/// são amigáveis ("Senha do admin incorreta.", etc.), então passam direto.
String redefinirSenhaErro(Object err) {
  if (err is ClientException) {
    final msg = err.response['message'];
    if (msg is String && msg.trim().isNotEmpty) return msg;
    if (err.statusCode == 0) return 'Sem conexão. Verifique a internet.';
    if (err.statusCode == 403) {
      return 'Apenas administradores podem redefinir senhas.';
    }
  }
  return 'Não foi possível redefinir a senha.';
}

/// Dialog de redefinição de senha de OUTRA conta (admin). Três campos: nova
/// senha, confirmação e a senha do PRÓPRIO admin (reconfirmação). Resolve `true`
/// quando a rota confirma. Erros do servidor aparecem no banner.
class _ResetSenhaDialog extends ConsumerStatefulWidget {
  const _ResetSenhaDialog({required this.target});

  final User target;

  @override
  ConsumerState<_ResetSenhaDialog> createState() => _ResetSenhaDialogState();
}

class _ResetSenhaDialogState extends ConsumerState<_ResetSenhaDialog> {
  final TextEditingController _nova = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _adminSenha = TextEditingController();

  bool _saving = false;
  String? _error;
  final Map<String, String> _errs = {};

  @override
  void dispose() {
    _nova.dispose();
    _confirm.dispose();
    _adminSenha.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final errs = <String, String>{};
    if (_nova.text.length < 8) {
      errs['nova'] = 'Mínimo 8 caracteres';
    }
    if (_nova.text != _confirm.text) {
      errs['confirm'] = 'Senhas não coincidem';
    }
    if (_adminSenha.text.isEmpty) {
      errs['admin'] = 'Informe sua senha de admin';
    }
    return errs;
  }

  Future<void> _submit() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() {
        _errs
          ..clear()
          ..addAll(errs);
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _errs.clear();
    });
    try {
      await ref
          .read(usuariosRepositoryProvider)
          .redefinirSenha(
            userId: widget.target.id,
            novaSenha: _nova.text,
            adminSenha: _adminSenha.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = redefinirSenhaErro(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final nome = widget.target.name.isNotEmpty
        ? widget.target.name
        : (widget.target.nome ?? widget.target.email);
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
                  'Redefinir senha',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink,
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
                Text(
                  'Você está definindo uma nova senha para $nome. A sessão atual '
                  'dessa pessoa será encerrada — ela entra de novo com a senha nova.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: clx.ink2, height: 1.4),
                ),
                const SizedBox(height: ClxSpace.x4),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: ClxSpace.x4),
                ],
                _senhaField(
                  label: 'Nova senha',
                  controller: _nova,
                  errorKey: 'nova',
                  hint: 'Mínimo 8 caracteres',
                ),
                _senhaField(
                  label: 'Confirmar nova senha',
                  controller: _confirm,
                  errorKey: 'confirm',
                  hint: 'Repita a nova senha',
                ),
                _senhaField(
                  label: 'Sua senha de admin',
                  controller: _adminSenha,
                  errorKey: 'admin',
                  hint: 'Confirme com a sua senha',
                ),
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
                label: 'Redefinir',
                icon: Icons.lock_reset_rounded,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _senhaField({
    required String label,
    required TextEditingController controller,
    required String errorKey,
    String? hint,
  }) {
    final clx = context.clx;
    final err = _errs[errorKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: ClxSpace.x1),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextField(
            controller: controller,
            enabled: !_saving,
            obscureText: true,
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
