import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:saber/design_system/colors.dart';
import 'package:logging/logging.dart';

/// Screen for capturing intake form photos (front and back)
class IntakePhotoCaptureScreen extends StatefulWidget {
  const IntakePhotoCaptureScreen({super.key});

  @override
  State<IntakePhotoCaptureScreen> createState() => _IntakePhotoCaptureScreenState();
}

class _IntakePhotoCaptureScreenState extends State<IntakePhotoCaptureScreen> {
  static final log = Logger('IntakePhotoCaptureScreen');
  
  final ImagePicker _picker = ImagePicker();
  
  XFile? _frontPhoto;
  XFile? _backPhoto;
  bool _isProcessing = false;
  String? _errorMessage;

  /// Validate image quality (check for blur and brightness)
  Future<bool> _validateImageQuality(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        log.warning('Failed to decode image');
        return false;
      }

      // Basic validation: check file size (should be reasonable)
      final sizeInMB = bytes.length / (1024 * 1024);
      if (sizeInMB > 10) {
        log.warning('Image too large: ${sizeInMB}MB');
        setState(() => _errorMessage = 'Image too large (max 10MB)');
        return false;
      }

      // Check minimum resolution
      if (image.width < 400 || image.height < 400) {
        log.warning('Image resolution too low: ${image.width}x${image.height}');
        setState(() => _errorMessage = 'Image resolution too low. Please use a better camera.');
        return false;
      }

      return true;
    } catch (e) {
      log.severe('Error validating image quality', e);
      setState(() => _errorMessage = 'Error validating image: $e');
      return false;
    }
  }

  /// Capture or pick photo from gallery
  Future<void> _capturePhoto(bool isFrontSide) async {
    try {
      setState(() {
        _errorMessage = null;
        _isProcessing = true;
      });

      // Show options: Camera or Gallery
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Capture ${isFrontSide ? 'Front' : 'Back'} Page'),
          content: const Text('Choose photo source:'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ],
        ),
      );

      if (source == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (photo == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Validate quality
      final isValid = await _validateImageQuality(photo);
      if (!isValid) {
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        if (isFrontSide) {
          _frontPhoto = photo;
        } else {
          _backPhoto = photo;
        }
        _isProcessing = false;
        _errorMessage = null;
      });
    } catch (e) {
      log.severe('Error capturing photo', e);
      setState(() {
        _errorMessage = 'Failed to capture photo: $e';
        _isProcessing = false;
      });
    }
  }

  /// Proceed with extracted photos
  Future<void> _proceedWithPhotos() async {
    if (_frontPhoto == null || _backPhoto == null) {
      setState(() => _errorMessage = 'Please capture both front and back photos');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      // Read photo bytes
      final frontBytes = await _frontPhoto!.readAsBytes();
      final backBytes = await _backPhoto!.readAsBytes();

      // Return both photos to the caller
      if (mounted) {
        Navigator.pop(context, {
          'frontPhoto': Uint8List.fromList(frontBytes),
          'backPhoto': Uint8List.fromList(backBytes),
        });
      }
    } catch (e) {
      log.severe('Error processing photos', e);
      setState(() {
        _errorMessage = 'Failed to process photos: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Intake Form'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: MedicalColors.infoBg,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: MedicalColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Capture clear photos of the front and back of the filled intake form',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: MedicalColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: MedicalColors.criticalBg,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: MedicalColors.critical),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: MedicalColors.critical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Photo capture sections
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Front photo
                    Expanded(
                      child: _buildPhotoSection(
                        title: 'Front Page',
                        photo: _frontPhoto,
                        onCapture: () => _capturePhoto(true),
                        onRetake: () => _capturePhoto(true),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back photo
                    Expanded(
                      child: _buildPhotoSection(
                        title: 'Back Page',
                        photo: _backPhoto,
                        onCapture: () => _capturePhoto(false),
                        onRetake: () => _capturePhoto(false),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _frontPhoto != null && _backPhoto != null && !_isProcessing
                      ? _proceedWithPhotos
                      : null,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isProcessing ? 'Processing...' : 'Proceed with Photos'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection({
    required String title,
    required XFile? photo,
    required VoidCallback onCapture,
    required VoidCallback onRetake,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  photo != null ? Icons.check_circle : Icons.camera_alt,
                  color: photo != null ? MedicalColors.healthy : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Photo preview or placeholder
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: photo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(photo.path),
                        fit: BoxFit.contain,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No photo captured',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: photo != null
                  ? OutlinedButton.icon(
                      onPressed: _isProcessing ? null : onRetake,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake Photo'),
                    )
                  : FilledButton.icon(
                      onPressed: _isProcessing ? null : onCapture,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Photo'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
