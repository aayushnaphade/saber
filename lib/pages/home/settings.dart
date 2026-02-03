import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/settings/settings_button.dart';
import 'package:saber/components/settings/settings_dropdown.dart';
import 'package:saber/components/settings/settings_switch.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/adaptive_toggle_buttons.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/settings_subpages/app_settings_page.dart';
import 'package:saber/pages/home/settings_subpages/professional_profile_page.dart';
import 'package:stow/stow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<bool?> showResetDialog({
    required BuildContext context,
    required Stow pref,
    required String prefTitle,
  }) async {
    if (pref.value == pref.defaultValue) return null;
    return await showDialog(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.settings.reset.title),
        content: Text(prefTitle),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              pref.value = pref.defaultValue;
              Navigator.of(context).pop(true);
            },
            child: Text(t.settings.reset.button),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  var _isLoggingOut = false;
  var _isUpdatingPassword = false;
  var _isLoadingProfile = true;
  var _isSavingProfile = false;
  var _isUploadingImage = false;
  String? _avatarUrl;

  bool _profileExpanded = false;
  bool _aiReportsExpanded = false;
  bool _isEditingProfile = false;

  @override
  void initState() {
    stows.locale.addListener(onChanged);
    UpdateManager.status.addListener(onChanged);
    super.initState();
    _loadFromCache();
    _fetchProfile();
  }

  void _loadFromCache() {
    _nameController.text = stows.userDisplayName.value;
    _phoneController.text = stows.userPhone.value;
    _avatarUrl = stows.userAvatarUrl.value;

    if (_nameController.text.isNotEmpty || _avatarUrl != null) {
      _isLoadingProfile = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    stows.locale.removeListener(onChanged);
    UpdateManager.status.removeListener(onChanged);
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        final fullName = data['full_name'] as String? ?? '';
        final phoneNumber = data['phone_number'] as String? ?? '';
        final avatarUrl = data['avatar_url'] as String?;

        stows.userDisplayName.value = fullName;
        stows.userPhone.value = phoneNumber;
        stows.userAvatarUrl.value = avatarUrl;

        setState(() {
          _nameController.text = fullName;
          _phoneController.text = phoneNumber;
          _avatarUrl = avatarUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      stows.userDisplayName.value = _nameController.text.trim();
      stows.userPhone.value = _phoneController.text.trim();
      stows.userAvatarUrl.value = _avatarUrl;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _isUploadingImage = true);

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = file.extension ?? 'jpg';
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      if (mounted) {
        setState(() {
          _avatarUrl = imageUrl;
        });
        _saveProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if ((confirm ?? false) && mounted) {
      setState(() => _isLoggingOut = true);

      try {
        await SupabaseAuthService.signOut();
        if (mounted) {
          context.go(RoutePaths.login);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          setState(() => _isLoggingOut = false);
        }
      }
    }
  }

  Future<void> _handleChangePassword() async {
    final currentPasswordController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current password and new password below.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  if (value == currentPasswordController.text) {
                    return 'New password must be different from current';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if ((confirm ?? false) && mounted) {
      setState(() => _isUpdatingPassword = true);

      try {
        // First verify current password by attempting to sign in
        final user = supabase.auth.currentUser;
        if (user?.email == null) {
          throw Exception('User email not found');
        }

        // Verify current password
        await supabase.auth.signInWithPassword(
          email: user!.email!,
          password: currentPasswordController.text,
        );

        // If verification successful, update to new password
        await SupabaseAuthService.updatePassword(passwordController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = ErrorHandler.getFriendlyErrorMessage(e);

          // Check if it's an authentication error (wrong current password)
          if (e.toString().contains('Invalid login credentials') ||
              e.toString().contains('invalid_grant')) {
            errorMessage = 'Current password is incorrect';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUpdatingPassword = false);
        }
      }
    }
  }

  void onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surface,
                    colorScheme.surface.withOpacity(0.95),
                    colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ]
                : [
                    colorScheme.primaryContainer.withOpacity(0.1),
                    colorScheme.surface,
                    colorScheme.secondaryContainer.withOpacity(0.1),
                  ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: true,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              title: Text(
                t.home.titles.settings,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                ThemeSwitcher(
                  clipper: const ThemeSwitcherCircleClipper(),
                  builder: (context) {
                    final themeToggleKey = GlobalKey();
                    return ValueListenableBuilder(
                      valueListenable: stows.appTheme,
                      builder: (context, currentMode, _) {
                        IconData icon;
                        String tooltip;
                        if (currentMode == ThemeMode.light) {
                          icon = Icons.light_mode;
                          tooltip = 'Switch to Dark Mode';
                        } else if (currentMode == ThemeMode.dark) {
                          icon = Icons.dark_mode;
                          tooltip = 'Switch to System Mode';
                        } else {
                          icon = Icons.brightness_auto;
                          tooltip = 'Switch to Light Mode';
                        }

                        return IconButton(
                          key: themeToggleKey,
                          tooltip: tooltip,
                          icon: Icon(icon),
                          iconSize: 32, // Increased size for better visibility
                          onPressed: () {
                            final currentIndex = ThemeMode.values.indexOf(
                              currentMode,
                            );
                            final nextIndex =
                                (currentIndex + 1) % ThemeMode.values.length;
                            final nextMode = ThemeMode.values[nextIndex];

                            final availableThemes = AvailableThemes.of(context);
                            ThemeData nextTheme;
                            if (nextMode == ThemeMode.light) {
                              nextTheme = availableThemes.light;
                            } else if (nextMode == ThemeMode.dark) {
                              nextTheme = availableThemes.dark;
                            } else {
                              final brightness = MediaQuery.of(
                                context,
                              ).platformBrightness;
                              nextTheme = brightness == Brightness.dark
                                  ? availableThemes.dark
                                  : availableThemes.light;
                            }

                            final renderBox =
                                themeToggleKey.currentContext
                                        ?.findRenderObject()
                                    as RenderBox?;
                            final offset = renderBox?.localToGlobal(
                              renderBox.size.center(Offset.zero),
                            );

                            debugPrint(
                              'Theme toggle: nextMode=$nextMode, offset=$offset',
                            );
                            ThemeSwitcher.of(context).changeTheme(
                              theme: nextTheme,
                              offset: offset,
                              onAnimationFinish: () {
                                debugPrint('Theme transition finished');
                                stows.appTheme.value = nextMode;
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                if (UpdateManager.status.value != UpdateStatus.upToDate)
                  IconButton(
                    tooltip: t.home.tooltips.showUpdateDialog,
                    icon: const Icon(Icons.system_update),
                    onPressed: () {
                      UpdateManager.showUpdateDialog(
                        context,
                        userTriggered: true,
                      );
                    },
                  ),
                const SizedBox(width: 16),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        children: [
                          _buildProfileSection(colorScheme, isDark),
                          const SizedBox(height: 16),
                          _buildProfessionalSection(colorScheme, isDark),
                          if (stows.userRole.value == 'doctor') ...[
                            const SizedBox(height: 16),
                            _buildTeamSection(colorScheme, isDark),
                          ],
                          const SizedBox(height: 16),
                          // _buildAIReportsSection(colorScheme, isDark),
                          // const SizedBox(height: 16),
                          // _buildAppPreferencesSection(colorScheme, isDark),
                          // const SizedBox(height: 16),
                          _buildTroubleshootingSection(colorScheme, isDark),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(ColorScheme colorScheme, bool isDark) {
    final user = SupabaseAuthService.currentUser;
    final isLoggedIn = user != null;

    if (!isLoggedIn) {
      return _buildGlassCard(
        colorScheme: colorScheme,
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 64,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Not Logged In',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please sign in to access your profile',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.login),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingProfile) {
      return _buildGlassCard(
        colorScheme: colorScheme,
        isDark: isDark,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return _buildGlassCard(
      colorScheme: colorScheme,
      isDark: isDark,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _profileExpanded = !_profileExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? Icon(
                                Icons.person,
                                size: 32,
                                color: colorScheme.primary,
                              )
                            : null,
                      ),
                      if (_profileExpanded)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _isUploadingImage
                                  ? null
                                  : _pickAndUploadImage,
                              icon: _isUploadingImage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt, size: 16),
                              iconSize: 16,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'Your Profile',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _profileExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 16),

                  // Read-only or editable fields based on _isEditingProfile
                  if (!_isEditingProfile) ...[
                    // Read-only view
                    _buildReadOnlyField(
                      icon: Icons.badge_outlined,
                      label: 'Full Name',
                      value: _nameController.text.isNotEmpty
                          ? _nameController.text
                          : 'Not set',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      icon: Icons.phone_outlined,
                      label: 'Contact Number',
                      value: _phoneController.text.isNotEmpty
                          ? _phoneController.text
                          : 'Not set',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 24),

                    // Edit and Change Password buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              setState(() => _isEditingProfile = true);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isUpdatingPassword
                                ? null
                                : _handleChangePassword,
                            icon: _isUpdatingPassword
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_reset),
                            label: Text(
                              _isUpdatingPassword
                                  ? 'Updating...'
                                  : 'Change Password',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Edit mode with form fields
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'Dr. John Doe',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Contact Number',
                              hintText: '+91 98765 43210',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // Reset to original values
                                    _loadFromCache();
                                    setState(() => _isEditingProfile = false);
                                  },
                                  icon: const Icon(Icons.close),
                                  label: const Text('Cancel'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _isSavingProfile
                                      ? null
                                      : () async {
                                          await _saveProfile();
                                          if (mounted) {
                                            setState(
                                              () => _isEditingProfile = false,
                                            );
                                          }
                                        },
                                  icon: _isSavingProfile
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: Text(
                                    _isSavingProfile
                                        ? 'Saving...'
                                        : 'Save Changes',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _profileExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportsSection(ColorScheme colorScheme, bool isDark) {
    return _buildGlassCard(
      colorScheme: colorScheme,
      isDark: isDark,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _aiReportsExpanded = !_aiReportsExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI & Reports',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure AI-powered features',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _aiReportsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  SettingsDropdown<ReportGenerationModel>(
                    pref: stows.reportGenerationModel,
                    title: 'Report Quality',
                    subtitle: 'Speed vs quality trade-off',
                    icon: Icons.speed,
                    options: [
                      ToggleButtonsOption(
                        ReportGenerationModel.flash,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Fast'),
                          ],
                        ),
                      ),
                      ToggleButtonsOption(
                        ReportGenerationModel.pro,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.science,
                              size: 18,
                              color: colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Deep'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.primary.withOpacity(0.6),
                    ),
                    title: Text(
                      'More AI Features',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    subtitle: Text(
                      'Coming soon...',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _aiReportsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildAppPreferencesSection(ColorScheme colorScheme, bool isDark) {
    return _buildGlassCard(
      colorScheme: colorScheme,
      isDark: isDark,
      child: SettingsButton(
        title: 'Advanced Settings',
        subtitle: 'Editor, Writing, Performance & More',
        icon: Icons.settings_applications,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AppSettingsPage()),
          );
        },
      ),
    );
  }

  Widget _buildProfessionalSection(ColorScheme colorScheme, bool isDark) {
    return _buildGlassCard(
      colorScheme: colorScheme,
      isDark: isDark,
      child: SettingsButton(
        title: 'Professional & Clinic Details',
        subtitle: 'Personalize your reports and app header',
        icon: Icons.verified_user_outlined,
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => const ProfessionalProfilePage(),
                ),
              )
              .then((_) => _fetchProfile());
        },
      ),
    );
  }

  Widget _buildTeamSection(ColorScheme colorScheme, bool isDark) {
    return _buildGlassCard(
      colorScheme: colorScheme,
      isDark: isDark,
      child: SettingsButton(
        title: 'Team Management',
        subtitle: 'Manage your clinic team',
        icon: Icons.manage_accounts_outlined,
        onPressed: () {
          context.push('/home/team');
        },
      ),
    );
  }

  Widget _buildGlassCard({
    required ColorScheme colorScheme,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surfaceContainerHighest.withOpacity(0.7),
                  colorScheme.surfaceContainer.withOpacity(0.5),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  colorScheme.surfaceContainerHighest.withOpacity(0.6),
                ],
        ),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.2)
              : colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _buildReadOnlyField({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection(ColorScheme colorScheme, bool isDark) {
    return _buildGlassCard(
      colorScheme: colorScheme,
      isDark: isDark,
      child: InkWell(
        onTap: () => _showStylusTroubleshooting(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.gesture_rounded,
                  color: colorScheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.settings.prefLabels.stylusTroubleshooting,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solve unresponsiveness, lag, or jitters',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStylusTroubleshooting(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest.withOpacity(0.8),
                  ]
                : [
                    colorScheme.surface,
                    colorScheme.secondaryContainer.withOpacity(0.2),
                  ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t.settings.troubleshooting.stylus.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow these steps to restore precision',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildEnhancedTroubleItem(
                    context,
                    title: 'Magnetic Interference',
                    description: t.settings.troubleshooting.stylus.magneticCase,
                    icon: Icons.vibration_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedTroubleItem(
                    context,
                    title: 'Physical Obstruction',
                    description:
                        t.settings.troubleshooting.stylus.screenProtectors,
                    icon: Icons.layers_outlined,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedTroubleItem(
                    context,
                    title: 'Hardware Maintenance',
                    description: t.settings.troubleshooting.stylus.nib,
                    icon: Icons.edit_rounded,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'If problems persist, try restarting your tablet or re-pairing the stylus via the side magnetic strip.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTroubleItem(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? color.withOpacity(0.9) : color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
