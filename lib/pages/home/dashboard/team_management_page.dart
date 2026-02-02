import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/supabase/supabase_team_service.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/design_system/radius.dart';

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  List<StaffMember> _team = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeam();
  }

  Future<void> _fetchTeam() async {
    try {
      final team = await SupabaseTeamService.getTeamMembers();
      if (mounted) {
        setState(() {
          _team = team;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String selectedRole = 'receptionist';
    bool isSaving = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 500,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                        horizontal: AppSpacing.xl,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withBlue(
                              colorScheme.primary.blue + 30,
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Staff Member',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Create a new account for your team',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: [
                              _buildPremiumTextField(
                                context,
                                controller: nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                enabled: !isSaving,
                                validator: (v) => v?.isEmpty ?? true
                                    ? 'Name is required'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _buildPremiumTextField(
                                context,
                                controller: emailController,
                                label: 'Email Address',
                                icon: Icons.email_outlined,
                                enabled: !isSaving,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v?.isEmpty ?? true)
                                    return 'Email is required';
                                  if (!v!.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildPremiumTextField(
                                      context,
                                      controller: passwordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      enabled: !isSaving,
                                      obscureText: obscurePassword,
                                      helperText: 'Min. 6 chars',
                                      validator: (v) => (v?.length ?? 0) < 6
                                          ? 'Too short'
                                          : null,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setDialogState(
                                          () => obscurePassword =
                                              !obscurePassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: _buildPremiumTextField(
                                      context,
                                      controller: confirmPasswordController,
                                      label: 'Confirm',
                                      icon: Icons.lock_reset_rounded,
                                      enabled: !isSaving,
                                      obscureText: obscureConfirmPassword,
                                      validator: (v) {
                                        if (v != passwordController.text) {
                                          return 'Mismatch';
                                        }
                                        return null;
                                      },
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setDialogState(
                                          () => obscureConfirmPassword =
                                              !obscureConfirmPassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              DropdownButtonFormField<String>(
                                value: selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Team Role',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    borderSide: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? colorScheme.surfaceContainerHighest
                                            .withOpacity(0.3)
                                      : colorScheme.surfaceVariant.withOpacity(
                                          0.1,
                                        ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'receptionist',
                                    child: Text('Receptionist'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pharmacist',
                                    child: Text('Pharmacist'),
                                  ),
                                ],
                                onChanged: isSaving
                                    ? null
                                    : (v) => setDialogState(
                                        () => selectedRole = v!,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.xl,
                        right: AppSpacing.xl,
                        bottom: AppSpacing.xl,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }

                                      setDialogState(() => isSaving = true);
                                      try {
                                        await SupabaseTeamService.addStaffMember(
                                          fullName: nameController.text,
                                          email: emailController.text,
                                          password: passwordController.text,
                                          role: selectedRole,
                                        );
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          _fetchTeam();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Staff member added successfully',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() => isSaving = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ErrorHandler.getFriendlyErrorMessage(
                                                  e,
                                                ),
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor:
                                                  colorScheme.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? helperText,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : colorScheme.surfaceVariant.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.error.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  Future<void> _revokeStaffMember(StaffMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_update_warning_rounded,
                    color: colorScheme.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Revoke Access?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontSize: 15,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Are you sure you want to revoke access for ',
                      ),
                      TextSpan(
                        text: member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            '? They will no longer be able to log in to the system.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        child: const Text(
                          'Revoke Access',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await SupabaseTeamService.revokeStaffMember(member.id);
        if (mounted) {
          _fetchTeam();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member revoked successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              title: const Text(
                'Team Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
              pinned: true,
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Back',
              ),
              actions: [
                IconButton(
                  onPressed: _fetchTeam,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_team.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No staff members found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Add your first team member to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: _showAddStaffDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Staff Member'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final member = _team[index];
                    return _buildStaffCard(context, member, isDark);
                  }, childCount: _team.length),
                ),
              ),
            // Add padding at the bottom for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: !_isLoading && _team.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddStaffDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff'),
            )
          : null,
    );
  }

  Widget _buildStaffCard(
    BuildContext context,
    StaffMember member,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final roleColor = member.role == 'pharmacist'
        ? Colors.green
        : Colors.indigo;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: roleColor.withOpacity(0.1),
          foregroundColor: roleColor,
          child: Text(
            member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member.fullName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  member.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Joined ${member.createdAt.toString().split(' ')[0]}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withOpacity(0.2)),
              ),
              child: Text(
                member.role.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _revokeStaffMember(member),
              icon: Icon(
                Icons.delete_outline,
                color: colorScheme.error.withOpacity(0.7),
              ),
              tooltip: 'Revoke Access',
            ),
          ],
        ),
      ),
    );
  }
}
