import 'package:flutter/material.dart';
import 'package:saber/data/supabase/supabase_team_service.dart';
import 'package:saber/data/api/error_handler.dart';

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
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  enabled: !isSaving,
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isSaving,
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
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
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields correctly (Password min 6 chars)')),
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(
            onPressed: _fetchTeam,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _team.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No staff members found', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddStaffDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Staff Member'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _team.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final member = _team[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(member.fullName[0].toUpperCase()),
                      ),
                      title: Text(member.fullName),
                      subtitle: Text('${member.email}\nJoined ${member.createdAt.toString().split(' ')[0]}'),
                      trailing: Chip(
                        label: Text(member.role.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        backgroundColor: member.role == 'pharmacist' 
                          ? Colors.green.shade50 
                          : Colors.indigo.shade50,
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }
}
