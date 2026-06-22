import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authProvider = context.read<AuthProvider>();

    if (!_formKey.currentState!.validate()) return;

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) return;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      body: StitchCodexBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: StitchCodexPanel(
                  emphasized: true,
                  padding: const EdgeInsets.all(28),
                  accent: StitchCodexPalette.bronze,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const StitchBrandMark(size: 68),
                        const SizedBox(height: 18),
                        const Text(
                          'RETURN TO STITCH',
                          style: TextStyle(
                            color: StitchCodexPalette.bronze,
                            fontFamily: StitchTypography.data,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            color: StitchCodexPalette.textPrimary,
                            fontFamily: StitchTypography.display,
                            fontSize: 27,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to continue your campaigns and characters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: StitchCodexPalette.textMuted,
                            fontFamily: StitchTypography.body,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: stitchCodexFieldTextStyle,
                          cursorColor: StitchCodexPalette.bronze,
                          decoration: stitchCodexInputDecoration(
                            labelText: 'Email',
                            hintText: 'adventurer@example.com',
                            prefixIcon: Icons.mail_outline,
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Enter your email';
                            if (!email.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: stitchCodexFieldTextStyle,
                          cursorColor: StitchCodexPalette.bronze,
                          decoration: stitchCodexInputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: StitchCodexPalette.textMuted,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Enter your password';
                            }
                            return null;
                          },
                        ),
                        if ((authProvider.errorMessage ?? '').isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: StitchCodexPalette.crimson
                                  .withValues(alpha: 0.10),
                              border: Border.all(
                                color: StitchCodexPalette.crimson
                                    .withValues(alpha: 0.40),
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              authProvider.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: StitchCodexPalette.crimsonBright,
                                fontFamily: StitchTypography.body,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: authProvider.isLoading ? null : _submit,
                            style: stitchCodexPrimaryButtonStyle(),
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: StitchCodexPalette.textPrimary,
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () {
                                  authProvider.clearError();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            "Don't have an account? Register",
                            style: TextStyle(
                              color: StitchCodexPalette.textSecondary,
                              fontFamily: StitchTypography.body,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
