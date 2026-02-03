import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_clinic_service.dart';
import 'package:saber/data/utils/report_printer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:signature/signature.dart';

class ProfessionalProfilePage extends StatefulWidget {
  const ProfessionalProfilePage({super.key});

  @override
  State<ProfessionalProfilePage> createState() =>
      _ProfessionalProfilePageState();
}

class _ProfessionalProfilePageState extends State<ProfessionalProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Doctor Controllers
  late final TextEditingController _qualificationController;
  late final TextEditingController _regNoController;

  // Clinic Controllers
  late final TextEditingController _clinicNameController;
  late final TextEditingController _clinicAddressController;
  late final TextEditingController _clinicPhoneController;
  late final TextEditingController _clinicWebsiteController;

  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUploadingSignature = false;

  String? _logoUrl;
  String? _signatureUrl;

  @override
  void initState() {
    super.initState();
    _qualificationController = TextEditingController(
      text: stows.userQualification.value,
    );
    _regNoController = TextEditingController(
      text: stows.userRegistrationNumber.value,
    );

    _clinicNameController = TextEditingController(text: stows.clinicName.value);
    _clinicAddressController = TextEditingController(
      text: stows.clinicAddress.value,
    );
    _clinicPhoneController = TextEditingController(
      text: stows.clinicPhone.value,
    );
    _clinicWebsiteController = TextEditingController(
      text: stows.clinicWebsite.value,
    );

    _logoUrl = stows.clinicLogoUrl.value;
    _signatureUrl = stows.userSignatureUrl.value;
  }

  @override
  void dispose() {
    _qualificationController.dispose();
    _regNoController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _clinicWebsiteController.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Save Profile Details
      await supabase
          .from('profiles')
          .update({
            'qualification': _qualificationController.text.trim(),
            'registration_number': _regNoController.text.trim(),
            'signature_url': _signatureUrl,
          })
          .eq('id', user.id);

      // 2. Save Clinic Details
      final clinicData = {
        'doctor_id': user.id,
        'name': _clinicNameController.text.trim(),
        'address': _clinicAddressController.text.trim(),
        'phone': _clinicPhoneController.text.trim(),
        'website': _clinicWebsiteController.text.trim(),
        'logo_url': _logoUrl,
      };

      if (stows.clinicId.value.isNotEmpty) {
        clinicData['id'] = stows.clinicId.value;
      }

      final savedClinic = await SupabaseClinicService.upsertClinicData(
        clinicData,
      );
      stows.clinicId.value = savedClinic.id;

      // 3. Update local stows
      stows.userQualification.value = _qualificationController.text.trim();
      stows.userRegistrationNumber.value = _regNoController.text.trim();
      stows.userSignatureUrl.value = _signatureUrl;

      stows.clinicName.value = _clinicNameController.text.trim();
      stows.clinicAddress.value = _clinicAddressController.text.trim();
      stows.clinicPhone.value = _clinicPhoneController.text.trim();
      stows.clinicWebsite.value = _clinicWebsiteController.text.trim();
      stows.clinicLogoUrl.value = _logoUrl;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Professional profile updated')),
        );
        Navigator.pop(context);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _isUploadingLogo = true);

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = file.extension ?? 'png';
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('clinic_assets')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final url = supabase.storage.from('clinic_assets').getPublicUrl(fileName);

      setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _showSignaturePad() async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500, // Restrict width to avoid full screen width
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Draw Your Signature',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white, // Ensure white background for drawing
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Signature(
                    controller: controller,
                    height: 240,
                    width: double.infinity, // Fill the container width
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      controller.clear();
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (controller.isNotEmpty) {
                        final bytes = await controller.toPngBytes();
                        if (bytes != null) {
                          if (context.mounted) Navigator.pop(context);
                          _uploadSignatureBytes(bytes);
                        }
                      }
                    },
                    child: const Text('Save Signature'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _uploadSignatureBytes(Uint8List bytes) async {
    setState(() => _isUploadingSignature = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage
          .from('signatures')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );

      final url = supabase.storage.from('signatures').getPublicUrl(fileName);

      setState(() => _signatureUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingSignature = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional & Clinic Profile'),
        actions: [
          IconButton(
            onPressed: () {
              ReportPrinter.printDemoReport({
                'clinicName': _clinicNameController.text.trim(),
                'clinicAddress': _clinicAddressController.text.trim(),
                'clinicPhone': _clinicPhoneController.text.trim(),
                'clinicWebsite': _clinicWebsiteController.text.trim(),
                'clinicLogoUrl': _logoUrl,
                'doctorName': stows.userDisplayName.value,
                'qualification': _qualificationController.text.trim(),
                'regNo': _regNoController.text.trim(),
                'signatureUrl': _signatureUrl,
              });
            },
            tooltip: 'View Demo Report',
            icon: const Icon(Icons.print_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: _isSaving ? null : _saveAll,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Doctor Information'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qualificationController,
                decoration: const InputDecoration(
                  labelText: 'Qualifications (e.g. MBBS, MD Psychiatry)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regNoController,
                decoration: const InputDecoration(
                  labelText: 'Registration Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.app_registration),
                ),
              ),
              const SizedBox(height: 24),
              _buildSignatureUploader(),

              const Divider(height: 48),

              _buildSectionTitle('Clinic Information'),
              const SizedBox(height: 16),
              _buildLogoUploader(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _clinicNameController,
                decoration: const InputDecoration(
                  labelText: 'Clinic / Hospital Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clinicAddressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clinicPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clinicWebsiteController,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),

              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Preview',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'See how your clinic details and signature appear on clinical reports.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ReportPrinter.printDemoReport({
                            'clinicName': _clinicNameController.text.trim(),
                            'clinicAddress': _clinicAddressController.text
                                .trim(),
                            'clinicPhone': _clinicPhoneController.text.trim(),
                            'clinicWebsite': _clinicWebsiteController.text
                                .trim(),
                            'clinicLogoUrl': _logoUrl,
                            'doctorName': stows.userDisplayName.value,
                            'qualification': _qualificationController.text
                                .trim(),
                            'regNo': _regNoController.text.trim(),
                            'signatureUrl': _signatureUrl,
                          });
                        },
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('View Demo Report'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Space for bottom bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildLogoUploader() {
    return Center(
      child: Column(
        children: [
          if (_logoUrl != null)
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(_logoUrl!),
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.none,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_business,
                size: 48,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isUploadingLogo ? null : _uploadLogo,
            icon: _isUploadingLogo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: const Text('Upload Clinic Logo'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Digital Signature',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              if (_signatureUrl != null)
                Container(
                  height: 80,
                  width: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(_signatureUrl!),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else
                Container(
                  height: 80,
                  width: 240,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.draw, size: 32, color: Colors.grey),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isUploadingSignature ? null : _showSignaturePad,
                icon: _isUploadingSignature
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit),
                label: const Text('Draw Signature'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
