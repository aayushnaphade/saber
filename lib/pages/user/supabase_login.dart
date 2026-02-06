import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:saber/components/misc/flowing_gradient_background.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/pages/home/home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase authentication login page with Material 3 design
class SupabaseLoginPage extends StatefulWidget {
  const SupabaseLoginPage({super.key});

  @override
  State<SupabaseLoginPage> createState() => _SupabaseLoginPageState();
}

class _SupabaseLoginPageState extends State<SupabaseLoginPage> {
  final log = Logger('_SupabaseLoginPageState');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  var _isLoading = false;
  final _obscurePassword = true;
  var _showOtpInput = false;
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authStateSubscription = SupabaseAuthService.onAuthStateChange.listen(
      (AuthState data) {
        // Explicitly handle navigation only after role check
      },
      onError: (error) {
        if (mounted) {
          final String message = error is AuthException
              ? error.message
              : ErrorHandler.getFriendlyErrorMessage(error);
          _showErrorSnackBar(message);
        }
      },
    );
  }

  Future<void> _handleEmailPasswordAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    stows.userRole.value = '';

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await SupabaseAuthService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        try {
          await SupabaseAuthService.syncProfile();
          final role = stows.userRole.value;
          log.info('User signed in with role: $role');

          if (role.isNotEmpty && role != 'doctor') {
            log.warning(
              'Non-doctor role detected: $role. Proceeding anyway for debugging.',
            );
          }

          if (mounted) {
            _showSuccessSnackBar('Signed in successfully!');
            context.go(
              RoutePaths.home.replaceFirst(
                ':subpage',
                HomePage.dashboardSubpage,
              ),
            );
          }
        } catch (roleError) {
          log.warning('Could not verify user role', roleError);
          await SupabaseAuthService.signOut();
          if (mounted) {
            _showErrorSnackBar(
              'Authentication error: Could not verify permissions.',
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getFriendlyErrorMessage(e));
      }
    } catch (e) {
      log.severe('Authentication error', e);
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getFriendlyErrorMessage(e));
      }
    } finally {
      if (mounted && !_showOtpInput) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOtpVerification() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6 || otp.length > 8) {
      _showErrorSnackBar('Please enter a valid verification code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseAuthService.verifyOtp(
        email: _emailController.text.trim(),
        token: otp,
        type: OtpType.email,
      );

      if (mounted) {
        _showSuccessSnackBar('Verification successful!');
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      log.severe('OTP verification error', e);
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getFriendlyErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseAuthService.resetPasswordForEmail(email);
      if (mounted) {
        _showSuccessSnackBar(
          'Password reset email sent! Please check your inbox.',
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      log.severe('Password reset error', e);
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getFriendlyErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const FlowingGradientBackground(),
          SafeArea(
            child: isLandscape
                ? _buildLandscapeLayout(context, colorScheme, textTheme)
                : _buildPortraitLayout(context, colorScheme, textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildFormCard(context, colorScheme, textTheme, false)],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIllustration(colorScheme, 300, textColor: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Effortless Documentation\nfor Modern Psychiatry',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 48.0,
              vertical: 32.0,
            ),
            child: Center(
              child: SingleChildScrollView(
                child: _buildFormCard(context, colorScheme, textTheme, true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration(
    ColorScheme colorScheme,
    double size, {
    Color? textColor,
  }) {
    return Column(
      children: [
        SizedBox(
          width: size * 0.5,
          height: size * 0.5,
          child: Center(
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'synapseAI',
          style: TextStyle(
            color: textColor ?? const Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.15,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLandscape,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showOtpInput) ...[
              Text(
                'Verify Email',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _handleOtpVerification,
                child: const Text('Verify Code'),
              ),
              TextButton(
                onPressed: () => setState(() => _showOtpInput = false),
                child: const Text('Back to Login'),
              ),
            ] else ...[
              if (!isLandscape) ...[
                _buildIllustration(colorScheme, 150),
                const SizedBox(height: 16),
              ],
              Text(
                'Welcome Back, Doctor.',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF0D47A1),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF4FC3F7)],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleEmailPasswordAuth,
                    borderRadius: BorderRadius.circular(28),
                    child: const Center(
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _showOtpInput = true),
                child: const Text(
                  'I have a verification code',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
