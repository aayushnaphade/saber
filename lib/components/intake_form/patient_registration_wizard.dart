import 'package:flutter/material.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_vitals_service.dart';
import 'package:saber/data/models/patient.dart';

class DoctorPatientRegistrationWizard extends StatefulWidget {
  const DoctorPatientRegistrationWizard({super.key});

  @override
  State<DoctorPatientRegistrationWizard> createState() =>
      _DoctorPatientRegistrationWizardState();
}

class _DoctorPatientRegistrationWizardState
    extends State<DoctorPatientRegistrationWizard> {
  int _currentStep = 0;
  final _demographicsFormKey = GlobalKey<FormState>();
  final _vitalsFormKey = GlobalKey<FormState>();

  // Demographic controllers
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _phoneController = TextEditingController();

  // Vitals controllers
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _weightController = TextEditingController();

  var _isLoading = false;
  Patient? _createdPatient;

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _phoneController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handlePatientCreation() async {
    if (!_demographicsFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final patient = await SupabasePatientService.createPatient(
        fullName: _fullNameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _genderController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      setState(() {
        _createdPatient = patient;
        _currentStep = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVitalsSelection() async {
    if (_createdPatient == null) return;

    setState(() => _isLoading = true);

    try {
      // Save Vitals if any field is filled
      if (_systolicController.text.isNotEmpty ||
          _diastolicController.text.isNotEmpty ||
          _pulseController.text.isNotEmpty ||
          _weightController.text.isNotEmpty) {
        await SupabaseVitalsService.saveVitals(
          patientId: _createdPatient!.id,
          systolic: int.tryParse(_systolicController.text.trim()),
          diastolic: int.tryParse(_diastolicController.text.trim()),
          heartRate: int.tryParse(_pulseController.text.trim()),
          weight: double.tryParse(_weightController.text.trim()),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(_createdPatient);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _currentStep == 0
                        ? Icons.person_add_alt_1_outlined
                        : Icons.monitor_heart_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStep == 0
                          ? 'Patient Registration'
                          : 'Quick Vitals Check',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentStep == 0
                          ? 'Step 1 of 2'
                          : 'Step 2 of 2 (Optional)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Content
            if (_currentStep == 0)
              _buildDemographicsForm()
            else
              _buildVitalsForm(),

            const SizedBox(height: 32),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentStep == 1)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.pop(context, _createdPatient),
                    child: const Text('Skip Vitals'),
                  ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : (_currentStep == 0
                            ? _handlePatientCreation
                            : _handleVitalsSelection),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep == 0 ? 'Next' : 'Complete Registration',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemographicsForm() {
    return Form(
      key: _demographicsFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Name is required' : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _genderController,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsForm() {
    return Form(
      key: _vitalsFormKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _systolicController,
                  decoration: const InputDecoration(
                    labelText: 'BP (Systolic)',
                    suffixText: 'mmHg',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _diastolicController,
                  decoration: const InputDecoration(
                    labelText: 'BP (Diastolic)',
                    suffixText: 'mmHg',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pulseController,
                  decoration: const InputDecoration(
                    labelText: 'Pulse',
                    prefixIcon: Icon(Icons.favorite_outline),
                    suffixText: 'bpm',
                    border: OutlineInputBorder(),
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
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
