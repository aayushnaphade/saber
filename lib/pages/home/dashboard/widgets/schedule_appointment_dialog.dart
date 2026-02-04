import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/pages/home/dashboard/widgets/vitals_dialog.dart';

class ScheduleAppointmentDialog extends StatefulWidget {
  const ScheduleAppointmentDialog({super.key});

  @override
  State<ScheduleAppointmentDialog> createState() =>
      _ScheduleAppointmentDialogState();
}

class _ScheduleAppointmentDialogState extends State<ScheduleAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  Patient? _selectedPatient;
  var _visitType = 'New Session'; // Default
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
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _submit({DateTime? scheduledTime}) async {
    if (!_formKey.currentState!.validate() || _selectedPatient == null) return;

    if (scheduledTime == null) {
      // Collect vitals for immediate sessions (queue)
      final vitalsResult = await showDialog(
        context: context,
        builder: (context) => VitalsDialog(
          patientId: _selectedPatient!.id,
          patientName: _selectedPatient!.fullName,
          isNewPatient: _visitType == 'New Session',
        ),
      );

      // If user cancelled vitals, do we stop?
      // Assuming yes, to ensure vitals are taken.
      // But VitalsDialog might return null if cancelled.
      // Let's assume user must save to proceed, or if they cancel, we abort queueing.
      // However, VitalsDialog action is "Save & Continue" which pops(true).
      // "Cancel" pops(null).
      if (vitalsResult != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      final time = scheduledTime ?? DateTime.now();

      // Check for conflicts if scheduling
      if (scheduledTime != null) {
        final conflicts = await SupabaseDashboardService.checkTimeSlotConflicts(
          time,
        );
        if (conflicts.isNotEmpty && mounted) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Scheduling Conflict'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The following appointments overlap with this time slot:',
                  ),
                  const SizedBox(height: 12),
                  ...conflicts.map(
                    (conflict) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${conflict.patientName} at ${DateFormat('h:mm a').format(conflict.time)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Do you want to schedule anyway?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Schedule Anyway'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      // Get max queue order
      final maxOrderResponse = await supabase
          .from('consultations')
          .select('queue_order')
          .eq('doctor_id', currentUserId)
          .or('status.eq.waiting,status.eq.in_progress')
          .order('queue_order', ascending: false)
          .limit(1)
          .maybeSingle();

      final nextQueueOrder =
          (maxOrderResponse?['queue_order'] as int? ?? 0) + 1;

      // Create consultation
      await supabase.from('consultations').insert({
        'patient_id': _selectedPatient!.id,
        'doctor_id': currentUserId,
        'status': 'waiting',
        'scheduled_time': time.toUtc().toIso8601String(),
        'appointment_type': scheduledTime != null ? 'scheduled' : 'walk-in',
        'queue_order': nextQueueOrder,
      });

      // Update patient visit type
      await supabase
          .from('patients')
          .update({
            'visit_type': _visitType == 'New Session' ? 'New' : 'Follow-up',
          })
          .eq('id', _selectedPatient!.id);

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
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
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
                      initialValue: _selectedPatient,
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
                    const Text(
                      'Visit Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
