import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/supabase/document_sync_service.dart';

void main() {
  group('DocumentSyncService Path Correction', () {
    const patientId = 'test-patient-id';

    test('Should keep path unchanged for normal session files', () {
      const relativePath = 'session_notes/session_1/session_1_notes.sbn2';
      final result = DocumentSyncService.getCorrectedLocalPath(
        relativePath,
        patientId,
      );

      expect(result, '/patients/$patientId/$relativePath');
    });

    test('Should correct path when session folder and filename mismatch', () {
      // Scenario: file says session 1, but it's in session 5 folder
      const relativePath = 'session_notes/session_5/session_1_notes.sbn2';

      final result = DocumentSyncService.getCorrectedLocalPath(
        relativePath,
        patientId,
      );

      // Expected: saved to session_1 folder
      const expectedPath =
          '/patients/$patientId/session_notes/session_1/session_1_notes.sbn2';
      expect(result, expectedPath);
    });

    test('Should correct path for .sbn files too', () {
      const relativePath = 'session_notes/session_10/session_3_notes.sbn';

      final result = DocumentSyncService.getCorrectedLocalPath(
        relativePath,
        patientId,
      );

      const expectedPath =
          '/patients/$patientId/session_notes/session_3/session_3_notes.sbn';
      expect(result, expectedPath);
    });

    test('Should ignore non-session files', () {
      const relativePath = 'other_docs/lab_results.pdf';
      final result = DocumentSyncService.getCorrectedLocalPath(
        relativePath,
        patientId,
      );

      expect(result, '/patients/$patientId/$relativePath');
    });

    test('Should ignore session files with matching numbers', () {
      const relativePath = 'session_notes/session_99/session_99_notes.sbn2';
      final result = DocumentSyncService.getCorrectedLocalPath(
        relativePath,
        patientId,
      );

      expect(result, '/patients/$patientId/$relativePath');
    });

    test('Should handle malformed paths gracefully', () {
      const relativePath = 'session_notes/session_invalid/session_1_notes.sbn2';
      final result = DocumentSyncService.getCorrectedLocalPath(
        relativePath,
        patientId,
      );

      // Should not crash, just return original if parsing fails
      expect(result, '/patients/$patientId/$relativePath');
    });
  });
}
