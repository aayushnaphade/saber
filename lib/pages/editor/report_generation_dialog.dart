import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:logger/logger.dart' as pretty;
import 'package:path/path.dart' as p;
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_prescription_service.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/utils/report_formatter.dart';
import 'package:saber/pages/editor/report_view.dart';

class ReportGenerationDialog extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final List<Uint8List> imageBytesList;
  final Patient? patient;
  final String? patientId;
  final String? patientName;
  final String? doctorName;
  final String? consultationId;
  final String filePath;
  final String rawNotes;
  final VoidCallback? onRegenerate;
  final VoidCallback? onVerify;
  final bool isReviewMode;
  final ClinicalReport? reportToReview;

  const ReportGenerationDialog({
    super.key,
    required this.reportData,
    required this.imageBytesList,
    this.patient,
    this.patientId,
    this.patientName,
    this.doctorName,
    this.consultationId,
    required this.filePath,
    required this.rawNotes,
    this.onRegenerate,
    this.onVerify,
    this.isReviewMode = false,
    this.reportToReview,
  });

  static final _log = Logger('ReportGenerationDialog');
  static final _prettyLog = pretty.Logger();

  @override
  Widget build(BuildContext context) {
    final reportViewKey = GlobalKey();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
                : [const Color(0xFFF5F7FA), const Color(0xFFE4EBF5)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait =
                MediaQuery.of(context).orientation == Orientation.portrait;

            return isPortrait
                ? Column(
                    children: [
                      Expanded(flex: 2, child: _buildImagePreview()),
                      const Divider(height: 1),
                      Expanded(
                        flex: 3,
                        child: _buildReportView(context, reportViewKey),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 1, child: _buildImagePreview()),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: _buildReportView(context, reportViewKey),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: imageBytesList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageBytesList[index],
              gaplessPlayback: true,
              cacheWidth: 1024,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportView(BuildContext context, GlobalKey reportViewKey) {
    return ReportView(
      key: reportViewKey,
      reportData: reportData,
      onRegenerate: onRegenerate,
      patient: patient,
      rawNotes: rawNotes,
      imageBytesList: imageBytesList,
      onVerify: () => _handleVerify(context),
    );
  }

  Future<void> _handleVerify(BuildContext context) async {
    if (isReviewMode && reportToReview != null) {
      final markdown = ReportFormatter.formatToMarkdown(
        reportData: reportData,
        patientId: patientId ?? '',
        patientName: patientName ?? 'Unknown',
        registrationNumber: patient?.registrationNumber ?? '',
      );

      await SupabaseReportService.updateReport(
        reportId: reportToReview!.id,
        structuredData: reportData,
        markdownContent: markdown,
        status: 'verified',
      );

      SessionManager().terminate();

      if (context.mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Close editor
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report verified successfully')),
        );
      }
      return;
    }

    // Logic for submitting a new report
    final sb = _generateMarkdown();
    final pId = patientId;
    debugPrint(
      'XXX_DEBUG: Attempting to save report. PatientId: $pId, isReviewMode: $isReviewMode',
    );

    if (pId != null) {
      try {
        await SupabaseReportService.createReport(
          patientId: pId,
          structuredData: reportData,
          markdownContent: sb.toString(),
          sourceDocumentPath: filePath,
        );

        // Prescription handling
        final medications = reportData['medications'];
        debugPrint('XXX_DEBUG: Report medications raw: $medications');
        if (medications != null) {
          debugPrint('XXX_DEBUG: Medications type: ${medications.runtimeType}');
        }

        if (medications is List && medications.isNotEmpty) {
          String? pName;
          try {
            final pData = await SupabasePatientService.getPatient(pId);
            pName = pData?.fullName;
          } catch (e) {
            debugPrint(
              'XXX_DEBUG: Failed to fetch patient name for prescription: $e',
            );
          }

          final medsList = medications.whereType<Map>().map((m) {
            final newMap = Map<String, dynamic>.from(m);
            if (newMap.containsKey('remarks')) {
              newMap['instructions'] = newMap['remarks'];
            }
            return newMap;
          }).toList();

          debugPrint(
            'XXX_DEBUG: Processing ${medsList.length} medications for prescription',
          );

          if (medsList.isNotEmpty) {
            try {
              await SupabasePrescriptionService.createPrescription(
                patientId: pId,
                consultationId: consultationId,
                medications: medsList,
                patientName: pName,
              );
              debugPrint(
                'XXX_DEBUG: Prescription creation called successfully',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prescription sent to pharmacy'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              debugPrint('XXX_DEBUG: Failed to create prescription: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to create prescription: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else {
            debugPrint('XXX_DEBUG: Medications list empty after filtering');
          }
        } else {
          debugPrint('XXX_DEBUG: No medications found in report data');
        }

        if (consultationId != null) {
          await SupabaseConsultationService.completeConsultation(
            consultationId!,
          );
        }
      } catch (e) {
        _log.severe('Failed to save report to DB', e);
      }
    } else {
      debugPrint('XXX_DEBUG: PatientId is null, skipping Supabase save');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot sync report: Missing Patient ID. Saved locally only.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Save locally
    final reportFileName =
        'clinical_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.md';
    // Use the directory of the session folder
    final absoluteSessionPath = p.isAbsolute(filePath)
        ? filePath
        : p.join(
            FileManager.documentsDirectory,
            filePath.startsWith('/') ? filePath.substring(1) : filePath,
          );
    final reportPath = p.join(p.dirname(absoluteSessionPath), reportFileName);

    if (await Directory(p.dirname(absoluteSessionPath)).exists()) {
      await FileManager.writeFile(
        reportPath,
        Uint8List.fromList(utf8.encode(sb.toString())),
        awaitWrite: true,
      );
    }

    if (context.mounted) {
      Navigator.pop(context);
      onVerify?.call();
    }
  }

  StringBuffer _generateMarkdown() {
    final sb = StringBuffer();
    sb.writeln('# 📋 Clinical Assessment Report');
    sb.writeln();
    sb.writeln('---');
    sb.writeln();
    if (patientName != null) sb.writeln('**👤 Patient:** $patientName');
    sb.writeln('**📅 Date:** ${DateFormat.yMMMd().format(DateTime.now())}');
    if (doctorName != null) sb.writeln('**👨‍⚕️ Doctor:** $doctorName');
    sb.writeln();
    sb.writeln('---');
    sb.writeln();

    sb.writeln('### 🕒 Current Symptoms (HPI)');
    sb.writeln(reportData['current_symptoms'] ?? 'Not mentioned');
    sb.writeln();

    sb.writeln('### 👤 Premorbid Personality');
    sb.writeln(reportData['premorbid_personality'] ?? 'Not mentioned');
    sb.writeln();

    sb.writeln('### 📜 Past History');
    sb.writeln(reportData['past_history'] ?? 'Not mentioned');
    sb.writeln();

    sb.writeln('### 👨‍👩‍👧‍👦 Family History');
    sb.writeln(reportData['family_history'] ?? 'Not mentioned');
    sb.writeln();

    sb.writeln('### 🏥 Mental Status Examination');
    final mse = reportData['mental_status_examination'];
    if (mse is Map) {
      mse.forEach((key, value) {
        final formattedKey = key.toString().replaceAll('_', ' ').toUpperCase();
        sb.writeln('- **$formattedKey:** $value');
      });
    } else if (mse is String) {
      sb.writeln(mse);
    } else {
      sb.writeln('*Not mentioned*');
    }
    sb.writeln();

    sb.writeln('### 🏁 Diagnosis');
    sb.writeln('**${reportData['provided_diagnosis'] ?? 'Not mentioned'}**');
    sb.writeln();

    sb.writeln('---');
    sb.writeln();
    sb.writeln('### 💊 Prescribed Medications');
    final meds = reportData['medications'] as List?;
    if (meds != null && meds.isNotEmpty) {
      sb.writeln('| Medication | Frequency | Duration | Remarks |');
      sb.writeln('| :--- | :--- | :--- | :--- |');
      for (final m in meds) {
        if (m is Map) {
          final name = m['name'] ?? 'N/A';
          final freq = m['frequency'] ?? 'N/A';
          final duration = m['duration'] ?? 'N/A';
          final remarks = m['remarks'] ?? '';
          sb.writeln('| **$name** | $freq | $duration | $remarks |');
        }
      }
    } else {
      sb.writeln('*None prescribed or not mentioned.*');
    }
    sb.writeln();
    sb.writeln('---');
    sb.writeln();
    sb.write(
      '> *This report was automatically generated by Synapse AI based on clinical notes.*',
    );
    return sb;
  }
}
