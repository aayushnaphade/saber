import 'package:flutter/material.dart';
import 'package:saber/data/supabase/supabase_vitals_service.dart';
import 'package:saber/data/api/error_handler.dart';

class VitalsDialog extends StatefulWidget {
  final String patientId;
  final String patientName;
  final bool isNewPatient;

  const VitalsDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.isNewPatient,
  });

  @override
  State<VitalsDialog> createState() => _VitalsDialogState();
}

class _VitalsDialogState extends State<VitalsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _weightController = TextEditingController();
  
  var _isLoading = false;

  @override
  void dispose() {
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
      // Save Vitals
      // Even if empty, we might want to record that a session started? 
      // But typically we only save if there's data. 
      // The user requirement says "track the changes over time", so we should save what is entered.
      
      if (_systolicController.text.isNotEmpty ||
          _diastolicController.text.isNotEmpty ||
          _pulseController.text.isNotEmpty ||
          _weightController.text.isNotEmpty) {
        
        await SupabaseVitalsService.saveVitals(
          patientId: widget.patientId,
          systolic: int.tryParse(_systolicController.text.trim()),
          diastolic: int.tryParse(_diastolicController.text.trim()),
          heartRate: int.tryParse(_pulseController.text.trim()),
          weight: double.tryParse(_weightController.text.trim()),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    // Fee logic display
    // New Patient: 1000, Follow-up: 700
    final fee = widget.isNewPatient ? 1000 : 700;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vitals for ${widget.patientName}'),
          const SizedBox(height: 4),
           Text(
            'Consultation Fee: ₹$fee',
             style: Theme.of(context).textTheme.labelLarge?.copyWith(
               color: Colors.green,
               fontWeight: FontWeight.bold,
             ),
           ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                   Expanded(
                    child: TextFormField(
                      controller: _systolicController,
                      decoration: const InputDecoration(
                        labelText: 'Systolic BP',
                        suffixText: 'mmHg',
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(), // Allow skip? Or Cancel? 
          // If this is part of the flow, Cancel might cancel the whole queuing process.
          // Let's assume Cancel cancels the action.
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
              : const Text('Save & Continue'),
        ),
      ],
    );
  }
}
