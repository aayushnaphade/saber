import 'package:flutter/material.dart' as m;
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/prefs.dart';

class ReportPrinter {
  static Future<void> printReport(
    Map<String, dynamic> reportData, {
    DateTime? generatedAt,
    Map<String, String?>? brandingData,
    Patient? patient,
  }) async {
    final pdf = pw.Document();

    final clinicName = brandingData?['clinicName'] ?? stows.clinicName.value;
    final clinicAddress =
        brandingData?['clinicAddress'] ?? stows.clinicAddress.value;
    final clinicPhone = brandingData?['clinicPhone'] ?? stows.clinicPhone.value;
    final clinicWebsite =
        brandingData?['clinicWebsite'] ?? stows.clinicWebsite.value;
    final clinicLogoUrl =
        brandingData?['clinicLogoUrl'] ?? stows.clinicLogoUrl.value;

    final doctorName =
        brandingData?['doctorName'] ?? stows.userDisplayName.value;
    final qualification =
        brandingData?['qualification'] ?? stows.userQualification.value;
    final regNo = brandingData?['regNo'] ?? stows.userRegistrationNumber.value;
    final signatureUrl =
        brandingData?['signatureUrl'] ?? stows.userSignatureUrl.value;

    // Load images if available
    pw.ImageProvider? logoImage;
    if (clinicLogoUrl != null && clinicLogoUrl.isNotEmpty) {
      try {
        logoImage = await networkImage(clinicLogoUrl);
      } catch (e) {
        // ignore
      }
    }

    pw.ImageProvider? signatureImage;
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        signatureImage = await networkImage(signatureUrl);
      } catch (e) {
        // ignore
      }
    }

    // Load Fonts for Unicode support (Essential for Hindi/Arabic/Hebrew)
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final devanagariFont = await PdfGoogleFonts.notoSansDevanagariRegular();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
      fontFallback: [devanagariFont],
    );

    // Dynamic Branding Colors
    PdfColor primaryColor = PdfColors.blue900;
    PdfColor secondaryColor = PdfColors.blueGrey50;
    PdfColor tableHeaderColor = PdfColors.teal900; // Default distinct color

    if (clinicLogoUrl != null && clinicLogoUrl.isNotEmpty) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          m.NetworkImage(clinicLogoUrl),
        );
        if (palette.vibrantColor != null) {
          primaryColor = PdfColor.fromInt(palette.vibrantColor!.color.value);
        } else if (palette.dominantColor != null) {
          primaryColor = PdfColor.fromInt(palette.dominantColor!.color.value);
        }

        if (palette.lightVibrantColor != null) {
          secondaryColor = PdfColor.fromInt(
            palette.lightVibrantColor!.color.value,
          );
        } else if (palette.mutedColor != null) {
          secondaryColor = PdfColor.fromInt(palette.mutedColor!.color.value);
        }

        // Select a distinct color for the table (Darker/Different variance)
        if (palette.darkVibrantColor != null) {
          tableHeaderColor = PdfColor.fromInt(
            palette.darkVibrantColor!.color.value,
          );
        } else if (palette.darkMutedColor != null) {
          tableHeaderColor = PdfColor.fromInt(
            palette.darkMutedColor!.color.value,
          );
        } else {
          // Fallback if no dark variant: darken the primary
          tableHeaderColor = primaryColor;
        }
      } catch (e) {
        // ignore
      }
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: theme,
      buildBackground: (pw.Context context) {
        if (logoImage == null) return pw.SizedBox();
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.05, // Subtle watermark
              child: pw.Image(logoImage, width: 500, height: 500),
            ),
          ),
        );
      },
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return [
            // CLINIC HEADER (Only on first page for medical professionalism)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 70,
                    height: 70,
                    margin: const pw.EdgeInsets.only(right: 20),
                    child: pw.Image(logoImage),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        clinicName.isNotEmpty ? clinicName : 'Clinical Report',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (clinicAddress.isNotEmpty)
                        pw.Text(
                          clinicAddress,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (clinicPhone.isNotEmpty)
                        pw.Text(
                          'Phone: $clinicPhone',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (clinicWebsite.isNotEmpty)
                        pw.Text(
                          clinicWebsite,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Dr. $doctorName',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (qualification.isNotEmpty)
                      pw.Text(
                        qualification,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (regNo.isNotEmpty)
                      pw.Text(
                        'Reg No: $regNo',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300, height: 30),

            // REPORT TITLE
            pw.Center(
              child: pw.Text(
                'CLINICAL ASSESSMENT REPORT',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // PATIENT INFORMATION SECTION
            if (patient != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'Patient Name: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              pw.TextSpan(
                                text: patient.fullName,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        if (patient.age != null || patient.gender != null)
                          pw.Text(
                            '${patient.gender ?? ''}${patient.gender != null && patient.age != null ? ', ' : ''}${patient.age != null ? '${patient.age} yrs' : ''}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (patient.phoneNumber != null)
                          pw.Text(
                            'Phone: ${patient.phoneNumber}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        pw.Text(
                          (patient.registrationNumber != null &&
                                  patient.registrationNumber!.isNotEmpty)
                              ? 'Reg No: ${patient.registrationNumber}'
                              : (reportData['registration_number'] != null &&
                                      reportData['registration_number']
                                          .toString()
                                          .isNotEmpty)
                                  ? 'Reg No: ${reportData['registration_number']}'
                                  : 'Reg No: Not defined',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // DYNAMIC SECTIONS (using spread operator to allow splitting across pages)
            ..._buildSection(
              'DIAGNOSIS',
              reportData['provided_diagnosis'],
              primaryColor,
            ),
            ..._buildSection(
              'CHIEF COMPLAINTS / SYMPTOMS',
              reportData['current_symptoms'],
              primaryColor,
            ),

            if (reportData['mental_status_examination'] != null)
              ..._buildMseSection(
                reportData['mental_status_examination'],
                primaryColor,
              ),

            ..._buildSection(
              'PAST MEDICAL & PSYCHIATRIC HISTORY',
              reportData['past_history'],
              primaryColor,
            ),
            ..._buildSection(
              'FAMILY HISTORY',
              reportData['family_history'],
              primaryColor,
            ),
            ..._buildSection(
              'PREMORBID PERSONALITY',
              reportData['premorbid_personality'],
              primaryColor,
            ),

            if (reportData['medications'] != null &&
                (reportData['medications'] as List).isNotEmpty)
              ..._buildMedicationSection(
                reportData['medications'],
                primaryColor,
                secondaryColor,
                tableHeaderColor,
              ),

            pw.Spacer(),

            // SIGNATURE FOOTER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Date: ${DateFormat('dd MMM yyyy, h:mm a').format(generatedAt ?? DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (signatureImage != null)
                      pw.Container(
                        width: 120,
                        height: 40,
                        child: pw.Image(signatureImage),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Digital Signature',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Dr. $doctorName',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<void> printDemoReport([
    Map<String, String?>? brandingData,
  ]) async {
    final Map<String, dynamic> dummyData = {
      'provided_diagnosis':
          'Generalized Anxiety Disorder (GAD) with mild depressive symptoms. The patient exhibits persistent worry and physical tension.',
      'current_symptoms':
          'Difficulty sleeping, restlessness, palpitations when stressed, and occasional muscle tension. Symptoms have been present for over 6 months.',
      'mental_status_examination': {
        'appearance': 'Neat and well-groomed',
        'behavior': 'Cooperative, slightly restless',
        'mood_and_affect': 'Anxious mood, restricted affect',
        'thought_process': 'Linear and logical',
        'perception': 'No hallucinations reported',
        'insight': 'Good insight into the condition',
      },
      'past_history':
          'No significant psychiatric history. Medical history includes managed hypertension since 2018.',
      'family_history':
          'Paternal uncle had history of depression. Parents are healthy.',
      'premorbid_personality':
          'Introverted, conscientious, tends to be a perfectionist in work environments.',
      'medications': [
        {
          'name': 'Escitalopram 10mg',
          'frequency': '1-0-0',
          'duration': '1 month',
          'remarks': 'Take after breakfast',
        },
        {
          'name': 'Etizolam 0.25mg',
          'frequency': '0-0-1',
          'duration': '10 days',
          'remarks': 'SOS for sleep',
        },
      ],
    };

    final mockPatient = Patient(
      id: 'demo-patient-123',
      createdAt: DateTime.now(),
      fullName: 'John Doe',
      age: 45,
      gender: 'Male',
      status: PatientStatus.active,
      doctorId: 'demo-doctor',
      phoneNumber: '+91 98765 43210',
    );

    return printReport(
      dummyData,
      brandingData: brandingData,
      patient: mockPatient,
    );
  }

  static List<pw.Widget> _buildSection(
    String title,
    dynamic content,
    PdfColor primaryColor,
  ) {
    final text = (content?.toString() ?? '').trim();
    if (text.isEmpty || text == 'Not mentioned') return [];

    return [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(text, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
      pw.SizedBox(height: 16), // Bottom padding for section
    ];
  }

  static List<pw.Widget> _buildMseSection(dynamic mse, PdfColor primaryColor) {
    if (mse is! Map) {
      return _buildSection('MENTAL STATUS EXAMINATION', mse, primaryColor);
    }

    final List<pw.Widget> children = [];
    mse.forEach((key, value) {
      if (value != null &&
          value.toString().isNotEmpty &&
          value.toString() != 'Not mentioned') {
        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text:
                        '${key.toString().replaceAll('_', ' ').toUpperCase()}: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.TextSpan(
                    text: value.toString(),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    if (children.isEmpty) return [];

    return [
      pw.Text(
        'MENTAL STATUS EXAMINATION',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
      pw.SizedBox(height: 6),
      ...children,
      pw.SizedBox(height: 16),
    ];
  }

  static PdfColor _lighten(PdfColor color, [double amount = 0.9]) {
    return PdfColor(
      color.red + (1 - color.red) * amount,
      color.green + (1 - color.green) * amount,
      color.blue + (1 - color.blue) * amount,
    );
  }

  static List<pw.Widget> _buildMedicationSection(
    List medications,
    PdfColor primaryColor,
    PdfColor secondaryColor,
    PdfColor tableHeaderColor,
  ) {
    return [
      pw.Text(
        'TREATMENT PLAN / MEDICATIONS',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: tableHeaderColor, // Dark Text
        ),
        headerDecoration: pw.BoxDecoration(
          color: _lighten(tableHeaderColor, 0.9), // Solid Light Background
        ),
        rowDecoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: tableHeaderColor, width: 0.5),
          ),
        ),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headers: ['Medication', 'Frequency', 'Duration', 'Remarks'],
        data: medications
            .map(
              (m) => [
                m['name'] ?? '',
                m['frequency'] ?? '',
                m['duration'] ?? '',
                m['remarks'] ?? '',
              ],
            )
            .toList(),
      ),
      pw.SizedBox(height: 16),
    ];
  }
}
