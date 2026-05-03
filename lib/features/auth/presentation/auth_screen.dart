import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/google_logo.dart';
import '../../../shared/widgets/legal_consent_text.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({required this.initialMode, super.key});

  final String initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _statusBarColor = Color(0xFF82F126);
  static const _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: _statusBarColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  late bool _isSignup = widget.initialMode == 'signup';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyStatusBarStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyStatusBarStyle();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final value = next.value;
      if (value?.status == AuthStatus.authenticated && mounted) {
        if (value!.profile?.hasCompletedOnboarding == true) {
          context.go('/home');
        } else {
          context.go('/setup/intent');
        }
      }
    });
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: AppScreen(
        safeAreaBackgroundColor: _statusBarColor,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/onboarding'),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Image.asset(
                          'src/assets/logo-mark.png',
                          width: 96,
                          height: 96,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSignup ? 'Create your account' : 'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 24),
                        if (_isSignup)
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                            ),
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.length < 2) {
                                return 'Enter your full name';
                              }
                              if (trimmed.length > 80) {
                                return 'Name is too long';
                              }
                              return null;
                            },
                          ),
                        if (_isSignup) const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final email = value?.trim().toLowerCase() ?? '';
                            return RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+$',
                                ).hasMatch(email)
                                ? null
                                : 'Enter a valid email address';
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (!_isSignup && password.isNotEmpty) return null;
                            if (password.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!RegExp('[A-Z]').hasMatch(password)) {
                              return 'Use at least one uppercase letter';
                            }
                            if (!RegExp('[a-z]').hasMatch(password)) {
                              return 'Use at least one lowercase letter';
                            }
                            if (!RegExp('[0-9]').hasMatch(password)) {
                              return 'Use at least one number';
                            }
                            if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                              return 'Use at least one symbol';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        if (auth.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _formatAuthError(auth.error!),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: loading ? null : _submit,
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isSignup
                                      ? Icons.person_add_alt_1
                                      : Icons.login,
                                ),
                          label: Text(_isSignup ? 'Create account' : 'Log in'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: loading ? null : _signInWithGoogle,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GoogleLogo(size: 20),
                              SizedBox(width: 10),
                              Text('Continue with Google'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () => setState(() => _isSignup = !_isSignup),
                          child: Text(
                            _isSignup
                                ? 'Already have an account? Log in'
                                : 'New here? Create an account',
                          ),
                        ),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () => context.push('/forgot-password'),
                          child: const Text('Forgot password?'),
                        ),
                        const SizedBox(height: 8),
                        const LegalConsentText(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignup) {
      await controller.signUp(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      await controller.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  void _applyStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(_systemUiStyle);
  }

  String _formatAuthError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return 'Authentication failed. Please try again.';
  }
}
