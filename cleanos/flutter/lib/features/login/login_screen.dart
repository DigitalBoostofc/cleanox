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
import '../../core/design/theme_fintech.dart';

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
    final isFintechClean = ref.watch(isFintechCleanProvider);
    // Web mobile (< 600dp): mesmo visual fintech do APK.
    // - isNarrowWebProvider: setado pelo builder do MaterialApp (app.dart)
    // - fallback: isWeb + largura (testes e paths sem o builder)
    final isNarrow = ref.watch(isNarrowWebProvider) ||
        (ref.watch(isWebPlatformProvider) &&
            MediaQuery.sizeOf(context).width < ClxLayout.narrowBreakpoint);
    final isFintech = isFintechClean || isNarrow;

    // Narrow web precisa do ThemeData fintech que o APK recebe via MaterialApp.
    // (isFintechClean=true ou builder do app já pode ter o tema — reaplicar é ok.)
    if (isNarrow && !isFintechClean) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Theme(
        data: dark ? buildFintechDarkTheme() : buildFintechLightTheme(),
        child: Builder(builder: (ctx) => _buildScaffold(ctx, isFintech: true)),
      );
    }
    return _buildScaffold(context, isFintech: isFintech);
  }

  Widget _buildScaffold(BuildContext context, {required bool isFintech}) {
    final clx = context.clx;
    if (isFintech) {
      return Scaffold(
        backgroundColor: clx.bg2,
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: ClxFadeSlide(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        clx.accent,
                        Color.lerp(clx.accent, clx.primary, 0.45)!,
                        clx.primary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CleanoxLogo(
                          height: 66,
                          variant: CleanoxLogoVariant.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          kAppTagline,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: clx.bg2,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildFintech(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Canvas cinza + card branco flutuante (paridade com casco desktop).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0B0C) : const Color(0xFFE6EAEE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ClxSpace.x6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildClassic(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Layout web desktop: card elevado no canvas (marca verde + branco).
  Widget _buildClassic(BuildContext context) {
    final clx = context.clx;
    return ClxScaleFade(
      beginScale: 0.9,
      duration: ClxMotion.emphasizedDuration,
      child: Container(
        decoration: BoxDecoration(
          color: clx.bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: ClxPulse(
                  minScale: 0.96,
                  maxScale: 1.06,
                  child: CleanoxLogo(
                    height: 96,
                    variant: CleanoxLogoVariant.primary,
                  ),
                ),
              ),
              const SizedBox(height: ClxSpace.x3),
              ClxFadeSlide(
                delay: const Duration(milliseconds: 60),
                child: Text(
                  kAppTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: clx.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: ClxSpace.x2),
              ClxFadeSlide(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Entre para continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: clx.ink3),
                ),
              ),
              const SizedBox(height: ClxSpace.x6),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: ClxSpace.x4),
              ],
              ClxFadeSlide(
                delay: const Duration(milliseconds: 140),
                child: _emailField(),
              ),
              const SizedBox(height: ClxSpace.x4),
              ClxFadeSlide(
                delay: const Duration(milliseconds: 180),
                child: _passwordField(),
              ),
              const SizedBox(height: ClxSpace.x6),
              ClxFadeSlide(
                delay: const Duration(milliseconds: 220),
                child: ClxPressScale(
                  onTap: _loading ? null : _submit,
                  child: ClxButton(
                    label: 'Entrar',
                    loading: _loading,
                    expand: true,
                    onPressed: _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Layout Easypay: form no sheet inferior (logo/hero fica no scaffold).
  Widget _buildFintech(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bem-vindo de volta',
            style: tt.titleLarge?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entre para continuar',
            style: tt.bodyMedium?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x5),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: ClxSpace.x4),
          ],
          ClxFadeSlide(
            delay: const Duration(milliseconds: 40),
            child: _emailField(),
          ),
          const SizedBox(height: ClxSpace.x4),
          ClxFadeSlide(
            delay: const Duration(milliseconds: 80),
            child: _passwordField(),
          ),
          const SizedBox(height: ClxSpace.x6),
          ClxFadeSlide(
            delay: const Duration(milliseconds: 120),
            child: ClxPressScale(
              onTap: _loading ? null : _submit,
              child: ClxButton(
                label: 'Entrar',
                loading: _loading,
                expand: true,
                onPressed: _submit,
              ),
            ),
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
