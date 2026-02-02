import 'package:flutter/material.dart';
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
    String selectedRole = 'receptionist';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Staff Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    helperText: 'Must be at least 6 characters',
                  ),
                  obscureText: true,
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                    DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist')),
                  ],
                  onChanged: isSaving ? null : (v) => setDialogState(() => selectedRole = v!),
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving ? null : () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields correctly')),
                  );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Staff member added successfully')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
                    );
                  }
                }
              },
              child: isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
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
            SliverAppBar.large(
              title: const Text('Team Management'),
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
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
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people_outline, size: 64, color: colorScheme.outline),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final member = _team[index];
                      return _buildStaffCard(context, member, isDark);
                    },
                    childCount: _team.length,
                  ),
                ),
              ),
              // Add padding at the bottom for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
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

  Widget _buildStaffCard(BuildContext context, StaffMember member, bool isDark) {
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
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
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
                Icon(Icons.email_outlined, size: 14, color: colorScheme.onSurfaceVariant),
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
                Icon(Icons.calendar_today_outlined, size: 14, color: colorScheme.onSurfaceVariant),
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
        trailing: Container(
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
      ),
    );
  }
}
