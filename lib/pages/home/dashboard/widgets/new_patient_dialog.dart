import 'package:flutter/material.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_vitals_service.dart';

class NewPatientDialog extends StatefulWidget {
  const NewPatientDialog({super.key});

  @override
  State<NewPatientDialog> createState() => _NewPatientDialogState();
}

class _NewPatientDialogState extends State<NewPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  // Vitals Controllers
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _weightController = TextEditingController();
  
  String? _selectedGender;
  var _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final patient = await SupabasePatientService.createPatient(
        fullName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _selectedGender,
        phoneNumber: _phoneController.text.trim(),
      );

      // Save Vitals if any provided
      if (_systolicController.text.isNotEmpty ||
          _diastolicController.text.isNotEmpty ||
          _pulseController.text.isNotEmpty ||
          _weightController.text.isNotEmpty) {
        await SupabaseVitalsService.saveVitals(
          patientId: patient.id,
          systolic: int.tryParse(_systolicController.text.trim()),
          diastolic: int.tryParse(_diastolicController.text.trim()),
          heartRate: int.tryParse(_pulseController.text.trim()),
          weight: double.tryParse(_weightController.text.trim()),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient registered successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register patient: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register New Patient'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter patient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedGender = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Vitals (Optional)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Row(
                children: [
                   Expanded(
                    child: TextFormField(
                      controller: _systolicController,
                      decoration: const InputDecoration(
                        labelText: 'Systolic BP',
                        suffixText: 'mmHg',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _diastolicController,
                      decoration: const InputDecoration(
                        labelText: 'Diastolic BP',
                        suffixText: 'mmHg',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pulseController,
                      decoration: const InputDecoration(
                        labelText: 'Pulse',
                        prefixIcon: Icon(Icons.favorite_outline),
                        suffixText: 'bpm',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                        suffixText: 'kg',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
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
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Register'),
        ),
      ],
    );
  }
}
