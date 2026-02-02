import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:saber/data/prefs.dart';
import 'package:intl/intl.dart';

class ReportPrinter {
  static Future<void> printReport(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();

    final clinicName = stows.clinicName.value;
    final clinicAddress = stows.clinicAddress.value;
    final clinicPhone = stows.clinicPhone.value;
    final clinicWebsite = stows.clinicWebsite.value;
    final clinicLogoUrl = stows.clinicLogoUrl.value;

    final doctorName = stows.userDisplayName.value;
    final qualification = stows.userQualification.value;
    final regNo = stows.userRegistrationNumber.value;
    final signatureUrl = stows.userSignatureUrl.value;

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // HEADER
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
                          color: PdfColors.blue900,
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

            // TITLE
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

            // REPORT CONTENT
            _buildSection('DIAGNOSIS', reportData['provided_diagnosis']),
            _buildSection(
              'CHIEF COMPLAINTS / SYMPTOMS',
              reportData['current_symptoms'],
            ),

            if (reportData['mental_status_examination'] != null)
              _buildMseSection(reportData['mental_status_examination']),

            _buildSection('PAST HISTORY', reportData['past_history']),
            _buildSection('FAMILY HISTORY', reportData['family_history']),
            _buildSection(
              'PREMORBID PERSONALITY',
              reportData['premorbid_personality'],
            ),

            if (reportData['medications'] != null &&
                (reportData['medications'] as List).isNotEmpty)
              _buildMedicationSection(reportData['medications']),

            pw.Spacer(),

            // FOOTER / SIGNATURE
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
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

  static pw.Widget _buildSection(String title, dynamic content) {
    final text = (content?.toString() ?? '').trim();
    if (text.isEmpty || text == 'Not mentioned') return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMseSection(dynamic mse) {
    if (mse is! Map) return _buildSection('MENTAL STATUS EXAMINATION', mse);

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

    if (children.isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MENTAL STATUS EXAMINATION',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildMedicationSection(List medications) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TREATMENT PLAN / MEDICATIONS',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
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
        ],
      ),
    );
  }
}
