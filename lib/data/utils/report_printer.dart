import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:saber/data/prefs.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/material.dart' as m;

class ReportPrinter {
  static Future<void> printReport(
    Map<String, dynamic> reportData, {
    DateTime? generatedAt,
    Map<String, String?>? brandingData,
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

    if (clinicLogoUrl != null && clinicLogoUrl.isNotEmpty) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          m.NetworkImage(clinicLogoUrl),
        );
        if (palette.vibrantColor != null) {
          primaryColor = PdfColor.fromInt(
            palette.vibrantColor!.color.toARGB32(),
          );
        } else if (palette.dominantColor != null) {
          primaryColor = PdfColor.fromInt(
            palette.dominantColor!.color.toARGB32(),
          );
        }

        if (palette.lightVibrantColor != null) {
          secondaryColor = PdfColor.fromInt(
            palette.lightVibrantColor!.color.toARGB32(),
          );
        } else if (palette.lightMutedColor != null) {
          secondaryColor = PdfColor.fromInt(
            palette.lightMutedColor!.color.toARGB32(),
          );
        } else {
          secondaryColor = PdfColor(
            primaryColor.red,
            primaryColor.green,
            primaryColor.blue,
            0.1,
          );
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
            pw.SizedBox(height: 20),

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
              'PAST HISTORY',
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

    return printReport(dummyData, brandingData: brandingData);
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

  static List<pw.Widget> _buildMedicationSection(
    List medications,
    PdfColor primaryColor,
    PdfColor secondaryColor,
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
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: pw.BoxDecoration(color: secondaryColor),
        rowDecoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: primaryColor, width: 1.0),
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
