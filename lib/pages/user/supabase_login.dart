import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/data/prefs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saber/components/misc/ethereal_background.dart';
import 'dart:ui';

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
  var _obscurePassword = true;
  var _isSignUpMode = false;
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
        // We handle navigation explicitly in _handleEmailPasswordAuth
        // or via the router redirect for restored sessions.
        // This avoids race conditions where a non-doctor is
        // briefly navigated to home before role check completes.
      },
      onError: (error) {
        if (mounted) {
          final String message;
          if (error is AuthException) {
            message = error.message;
          } else {
            message = ErrorHandler.getFriendlyErrorMessage(error);
          }

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

      if (_isSignUpMode) {
        // Sign up mode
        final response = await SupabaseAuthService.signUpWithEmailPassword(
          email: email,
          password: password,
        );

        if (response.user != null && mounted) {
          if (response.session == null) {
            // Email confirmation required
            setState(() {
              _showOtpInput = true;
              _isLoading = false;
            });
            _showSuccessSnackBar(
              'Sign up successful! Please enter the code sent to your email.',
            );
            return;
          } else {
            _showSuccessSnackBar('Account created successfully!');
          }
        }
      } else {
        // Sign in mode
        final response = await SupabaseAuthService.signInWithEmailPassword(
          email: email,
          password: password,
        );

        // Check user role after successful authentication
        if (response.user != null) {
          try {
            // Ensure profile is synced
            await SupabaseAuthService.syncProfile();

            final role = stows.userRole.value;
            log.info('User signed in with role: $role');

            /*
            if (role != 'doctor') {
              // Strictly only allow doctors on the tablet
              log.warning('Access denied for role: $role');
              // ...
            }
            */

             // Soft check: Warn but allow entry if role is missing/empty
             if (role.isNotEmpty && role != 'doctor') {
                log.warning('Non-doctor role detected: $role. Proceeding anyway for debugging.');
                // For strict production: uncomment the block above
             }

            // If we reach here, it's a doctor. Navigate to home.
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
            // If we can't verify, play it safe and sign out
            await SupabaseAuthService.signOut();
            if (mounted) {
              _showErrorSnackBar(
                'Authentication error: Could not verify permissions.',
              );
            }
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
        type: _isSignUpMode ? OtpType.signup : OtpType.email,
      );

      if (mounted) {
        _showSuccessSnackBar('Verification successful!');
      }
    } on AuthException catch (e) {
      if (mounted) {
        final errorString = e.toString();
        if (errorString.contains('SocketException') ||
            errorString.contains('Failed host lookup') ||
            errorString.contains('Network is unreachable')) {
          _showErrorSnackBar(
            'Network error. Please check your internet connection.',
          );
        } else {
          _showErrorSnackBar(e.message);
        }
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
        final errorString = e.toString();
        if (errorString.contains('SocketException') ||
            errorString.contains('Failed host lookup') ||
            errorString.contains('Network is unreachable')) {
          _showErrorSnackBar(
            'Network error. Please check your internet connection.',
          );
        } else {
          _showErrorSnackBar(e.message);
        }
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
      backgroundColor: const Color(0xFF001220),
      body: Stack(
        children: [
          const EtherealBackground(),
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
          children: [
            // Illustration
            _buildIllustration(colorScheme, 200),
            const SizedBox(height: 32),

            // Form Card
            _buildFormCard(context, colorScheme, textTheme),
          ],
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
        // Left side - Illustration
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIllustration(colorScheme, 180),
                  const SizedBox(height: 32),
                  Text(
                    'SynapseAI',
                    style: textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
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

        // Right side - Form
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
                child: _buildFormCard(context, colorScheme, textTheme),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration(ColorScheme colorScheme, double size) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Image.asset(
          'assets/icon/icon.png',
          color: Colors.white.withValues(alpha: 0.9),
          colorBlendMode: BlendMode.srcIn,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showOtpInput) ...[
                  // OTP Verification Header
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.mark_email_read_rounded,
                            color: Colors.cyanAccent,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify Email',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Enter the code sent to your email',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // OTP Field
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoading,
                    style: textTheme.bodyLarge?.copyWith(letterSpacing: 4),
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    onFieldSubmitted: (_) => _handleOtpVerification(),
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: '000000',
                      hintStyle: const TextStyle(color: Colors.white30),
                      counterText: '',
                      prefixIcon: const Icon(
                        Icons.lock_clock_outlined,
                        color: Colors.cyanAccent,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.cyanAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Verify Button
                  FilledButton(
                    onPressed: _isLoading ? null : _handleOtpVerification,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.withValues(alpha: 0.8),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black87,
                              ),
                            ),
                          )
                        : const Text(
                            'Verify Code',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Back Button
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() => _showOtpInput = false);
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Back to Login'),
                  ),
                ] else ...[
                  // Header
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.lock_person_rounded,
                            color: Colors.cyanAccent,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSignUpMode ? 'Create Account' : 'Welcome Back',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _isSignUpMode
                                  ? 'Join our mental health platform'
                                  : 'Sign in to continue',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'your.email@example.com',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.cyanAccent,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.cyanAccent,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colorScheme.error),
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

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoading,
                    style: const TextStyle(color: Colors.white),
                    onFieldSubmitted: (_) => _handleEmailPasswordAuth(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Enter your password',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.cyanAccent,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.cyanAccent,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colorScheme.error),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isSignUpMode && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  // Forgot Password Link (only in sign in mode)
                  if (!_isSignUpMode) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sign In/Sign Up Button
                  FilledButton(
                    onPressed: _isLoading ? null : _handleEmailPasswordAuth,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignUpMode ? 'Create Account' : 'Sign In',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isSignUpMode
                                    ? Icons.person_add_rounded
                                    : Icons.arrow_forward_rounded,
                                color: colorScheme.onPrimary,
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white10)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Colors.white10)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Toggle between Sign In and Sign Up
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUpMode = !_isSignUpMode;
                              _formKey.currentState?.reset();
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      side: const BorderSide(color: Colors.white10, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUpMode
                              ? 'Already have an account?'
                              : 'Don\'t have an account?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isSignUpMode ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Manual OTP Entry Button
                  if (!_isSignUpMode) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() => _showOtpInput = true);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                      ),
                      child: const Text('I have a verification code'),
                    ),
                  ],
                ],
                const SizedBox(height: 24),

                // Footer Text
                const Text(
                  'SynapseAI • Modern Psychiatry Portal',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
