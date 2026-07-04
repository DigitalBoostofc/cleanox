/// login_screen.dart — Porte de `Login.tsx`. Único ponto de entrada das duas
/// superfícies. `authWithPassword('users')` → o go_router roteia por papel.
///
/// Único arquivo do reskin "Fintech Clean" (doc 12, Onda 2) que PRECISA de
/// bifurcação estrutural via `isFintechCleanProvider`: ao contrário das telas
/// do profissional, esta é a MESMA rota para Web (`AppSurface.painel`) e APK
/// — layout clássico (card elevado) preservado 1:1 para a Web, layout novo
/// (sem card, logo + campos + CTA no polegar) só quando `isFintechClean`.
/// Lógica de auth/estado é 100% compartilhada entre as duas ramificações.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design/app_surface_provider.dart';
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

  /// Limpa a mensagem de erro assim que o usuário volta a digitar (espelha o
  /// `onChange` do `Login.tsx`, que zera o erro a cada tecla).
  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

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
    final isFintech = ref.watch(isFintechCleanProvider);
    return Scaffold(
      backgroundColor: clx.bg2,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x6),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isFintech ? 340 : 400),
              child: isFintech ? _buildFintech(context) : _buildClassic(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Layout clássico (`ClxCard` elevado) — inalterado, ainda usado pela Web
  /// (`AppSurface.painel`) e por quem monta esta tela sem `isFintechClean`.
  Widget _buildClassic(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
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
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: clx.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
            Text(
              'Entre para continuar',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: clx.ink3),
            ),
            const SizedBox(height: ClxSpace.x6),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: ClxSpace.x4),
            ],
            _emailField(),
            const SizedBox(height: ClxSpace.x4),
            _passwordField(),
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
    );
  }

  /// Layout "Fintech Clean" (Opção B, doc 12, tela 1): sem card — logo +
  /// campos + CTA pill direto sobre o fundo, bloco centralizado na tela (a
  /// mesma posição que já coloca o CTA na zona natural do polegar).
  Widget _buildFintech(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: clx.primary,
                borderRadius: ClxRadii.rXl,
              ),
              child: Icon(
                Icons.cleaning_services_rounded,
                color: clx.onPrimary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: ClxSpace.x4),
          Text(
            'CleanOS',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(
              color: clx.ink,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          Text(
            'Entre para continuar',
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x8),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: ClxSpace.x4),
          ],
          _emailField(),
          const SizedBox(height: ClxSpace.x5),
          _passwordField(),
          const SizedBox(height: ClxSpace.x6),
          ClxButton(
            label: 'Entrar',
            loading: _loading,
            expand: true,
            onPressed: _submit,
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Esqueceu a senha? Fale com o administrador.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: clx.ink3),
          ),
        ],
      ),
    );
  }

  Widget _emailField() => TextFormField(
    controller: _emailCtrl,
    keyboardType: TextInputType.emailAddress,
    autofillHints: const [AutofillHints.email],
    textInputAction: TextInputAction.next,
    autofocus: true,
    enabled: !_loading,
    onChanged: (_) => _clearError(),
    decoration: const InputDecoration(
      labelText: 'E-mail',
      hintText: 'seuemail@cleanox.com',
      prefixIcon: Icon(Icons.mail_outline_rounded),
    ),
    validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Informe o e-mail.' : null,
  );

  Widget _passwordField() => TextFormField(
    controller: _passCtrl,
    obscureText: _obscure,
    autofillHints: const [AutofillHints.password],
    textInputAction: TextInputAction.done,
    enabled: !_loading,
    onChanged: (_) => _clearError(),
    onFieldSubmitted: (_) => _submit(),
    decoration: InputDecoration(
      labelText: 'Senha',
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
    validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha.' : null,
  );
}
