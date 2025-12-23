import 'package:flutter/material.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';

class ScheduleAppointmentDialog extends StatefulWidget {
  const ScheduleAppointmentDialog({super.key});

  @override
  State<ScheduleAppointmentDialog> createState() =>
      _ScheduleAppointmentDialogState();
}

class _ScheduleAppointmentDialogState extends State<ScheduleAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  Patient? _selectedPatient;
  String _visitType = 'New Session'; // Default
  var _isLoading = false;
  List<Patient> _patients = [];
  var _isLoadingPatients = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final patients = await SupabasePatientService.getAllPatients();
      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoadingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patients: $e')),
        );
      }
    }
  }

  Future<void> _submit({DateTime? scheduledTime}) async {
    if (!_formKey.currentState!.validate() || _selectedPatient == null) return;

    setState(() => _isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      final time = scheduledTime ?? DateTime.now();

      // Create consultation
      await supabase.from('consultations').insert({
        'patient_id': _selectedPatient!.id,
        'doctor_id': currentUserId,
        'status': 'waiting',
        'created_at': time.toIso8601String(),
      });

      // Update patient visit type
      await supabase.from('patients').update({
        'visit_type': _visitType == 'New Session' ? 'New' : 'Follow-up',
      }).eq('id', _selectedPatient!.id);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scheduledTime == null
                  ? 'Patient added to queue'
                  : 'Appointment scheduled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final scheduledTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    _submit(scheduledTime: scheduledTime);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule Patient'),
      content: SizedBox(
        width: 400,
        child: _isLoadingPatients
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Patient>(
                      decoration: const InputDecoration(
                        labelText: 'Select Patient',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      value: _selectedPatient,
                      items: _patients.map((patient) {
                        return DropdownMenuItem(
                          value: patient,
                          child: Text(patient.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPatient = value);
                      },
                      validator: (value) =>
                          value == null ? 'Please select a patient' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Visit Type',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('New Session'),
                          selected: _visitType == 'New Session',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _visitType = 'New Session');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Follow Up'),
                          selected: _visitType == 'Follow Up',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _visitType = 'Follow Up');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _isLoading ? null : _pickDateTime,
          child: const Text('Schedule for Later'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : () => _submit(),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Start Session Now'),
        ),
      ],
    );
  }
}
