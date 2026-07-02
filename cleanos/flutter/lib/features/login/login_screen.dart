/// login_screen.dart — Porte de `Login.tsx`. Único ponto de entrada das duas
/// superfícies. `authWithPassword('users')` → o go_router roteia por papel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design/design.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .login(_emailCtrl.text.trim(), _passCtrl.text);
      // Sucesso: o refreshListenable do go_router redireciona por papel.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ocorreu um erro inesperado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Scaffold(
      backgroundColor: clx.bg2,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ClxCard(
              elevated: true,
              padding: const EdgeInsets.all(ClxSpace.x6),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CleanOS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: clx.accent,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x2),
                    Text(
                      'Entre para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: clx.ink3, fontSize: 14),
                    ),
                    const SizedBox(height: ClxSpace.x6),
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: ClxSpace.x4),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'seuemail@cleanox.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o e-mail.'
                          : null,
                    ),
                    const SizedBox(height: ClxSpace.x4),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      enabled: !_loading,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                    ),
                    const SizedBox(height: ClxSpace.x6),
                    ClxButton(
                      label: 'Entrar',
                      loading: _loading,
                      expand: true,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
