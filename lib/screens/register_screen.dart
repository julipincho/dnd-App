import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _avatarFile;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() {
        _avatarFile = File(picked.path);
      });
    } catch (e) {
      debugPrint('Error picking user avatar: $e');
    }
  }

  Future<void> _submit() async {
    final authProvider = context.read<AuthProvider>();

    if (!_formKey.currentState!.validate()) return;

    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _displayNameController.text.trim(),
      avatarFile: _avatarFile,
    );

    if (!mounted) return;

    if (success) {
      context.go('/');
    }
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
                constraints: const BoxConstraints(maxWidth: 460),
                child: StitchCodexPanel(
                  emphasized: true,
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const StitchBrandLockup(
                          title: Text(
                            'STITCH',
                            style: TextStyle(
                              color: StitchCodexPalette.textPrimary,
                              fontFamily: StitchTypography.display,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                            ),
                          ),
                          markSize: 44,
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: authProvider.isLoading ? null : _pickAvatar,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: StitchCodexPalette.bronze
                                        .withValues(alpha: 0.52),
                                  ),
                                  gradient: _avatarFile == null
                                      ? const LinearGradient(
                                          colors: [
                                            StitchCodexPalette.surfaceRaised,
                                            StitchCodexPalette.surface,
                                          ],
                                        )
                                      : null,
                                  image: _avatarFile != null
                                      ? DecorationImage(
                                          image: FileImage(_avatarFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _avatarFile == null
                                    ? const Icon(
                                        Icons.person_add_alt_1_outlined,
                                        color: StitchCodexPalette.bronze,
                                        size: 38,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: StitchCodexPalette.crimson,
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: StitchCodexPalette.surface,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_rounded,
                                    color: StitchCodexPalette.textPrimary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Create account',
                          style: TextStyle(
                            color: StitchCodexPalette.textPrimary,
                            fontFamily: StitchTypography.display,
                            fontSize: 27,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Register to keep your campaigns and characters linked to your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: StitchCodexPalette.textMuted,
                            fontFamily: StitchTypography.body,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _displayNameController,
                          textCapitalization: TextCapitalization.words,
                          style: stitchCodexFieldTextStyle,
                          cursorColor: StitchCodexPalette.bronze,
                          decoration: stitchCodexInputDecoration(
                            labelText: 'Username',
                            hintText: 'Your adventurer name',
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (name.isEmpty) return 'Enter your username';
                            if (name.length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                            final password = value ?? '';
                            if (password.isEmpty) return 'Enter a password';
                            if (password.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: stitchCodexFieldTextStyle,
                          cursorColor: StitchCodexPalette.bronze,
                          decoration: stitchCodexInputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: Icons.lock_reset_outlined,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: StitchCodexPalette.textMuted,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        if ((authProvider.errorMessage ?? '').isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            authProvider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: StitchCodexPalette.crimsonBright,
                              fontFamily: StitchTypography.body,
                              fontSize: 14,
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
                                : const Text('Create Account'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () {
                                  authProvider.clearError();
                                  context.go('/login');
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: StitchCodexPalette.textSecondary,
                            textStyle: const TextStyle(
                              fontFamily: StitchTypography.body,
                              fontSize: 15,
                            ),
                          ),
                          child: const Text('Already have an account? Sign in'),
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
