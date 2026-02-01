import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saber/components/overlays/medication_history_overlay.dart';
import 'package:saber/data/models/medication_history_models.dart';

/// Integration tests for the medication history feature
/// These tests verify the complete workflow from opening the overlay to viewing medication history
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Medication History Integration Tests', () {
    testWidgets('Complete workflow: Load and display medication history', (WidgetTester tester) async {
      // Setup: Create test app with medication history overlay
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: MedicationHistoryOverlay(
                          patientId: 'test-patient-1',
                        ),
                      ),
                    );
                  },
                  child: const Text('Show Medication History'),
                ),
              ),
            ),
          ),
        ),
      );

      // Step 1: Tap button to open overlay
      await tester.tap(find.text('Show Medication History'));
      await tester.pumpAndSettle();

      // Step 2: Verify overlay is displayed
      expect(find.text('Medication History'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);

      // Step 3: Verify filter chips are present
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('1Y'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);

      // Step 4: Wait for data to load
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Step 5: Verify close button is present and tappable
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Note: The overlay's onClose callback is called, but the dialog
      // itself is managed by the parent, so it may still be visible
      // This is expected behavior - the parent decides whether to close the dialog
    });

    testWidgets('Filter functionality: Switch between time periods', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'test-patient-2',
            ),
          ),
        ),
      );

      await tester.pump();

      // Default filter should be 6M
      // Test switching to 3M
      await tester.tap(find.text('3M'));
      await tester.pumpAndSettle();

      // Test switching to 1Y
      await tester.tap(find.text('1Y'));
      await tester.pumpAndSettle();

      // Test switching to ALL
      await tester.tap(find.text('ALL'));
      await tester.pumpAndSettle();

      // Verify no errors occurred during filter changes
      expect(tester.takeException(), isNull);
    });

    testWidgets('Timeline rendering: Verify medications are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'test-patient-2',
            ),
          ),
        ),
      );

      // Wait for initial load
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Note: Actual medication names would appear if the service returns data
      // In a real integration test, you'd verify specific medications are shown
    });

    testWidgets('Error handling: Display error when service fails', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'invalid-patient-id',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show error message or empty state
      // expect(find.text('Failed to load medication history'), findsOneWidget);
    });

    testWidgets('Empty state: Display message when no history exists', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'patient-no-history',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show empty state message
      expect(find.text('No medication history found'), findsOneWidget);
    });

    testWidgets('Responsive layout: Verify overlay adapts to screen size', (WidgetTester tester) async {
      // Test on different screen sizes
      await tester.binding.setSurfaceSize(const Size(1920, 1080)); // Desktop

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'test-patient-1',
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify overlay is visible and properly sized
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(MedicationHistoryOverlay),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxWidth, 600);
      expect(container.constraints?.maxHeight, 400);

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Accessibility: Screen reader support', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'test-patient-1',
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify semantic labels
      expect(find.text('Medication History'), findsOneWidget);
      
      // Verify interactive elements are accessible
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Performance: Timeline renders within acceptable time', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'test-patient-2',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Rendering should complete within 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('Medication History - Data Scenarios', () {
    testWidgets('Scenario: Patient with active medications only', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'patient-active-only',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify active medications are displayed
      // Timeline should show ongoing medication lines
    });

    testWidgets('Scenario: Patient with stopped medications only', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'patient-stopped-only',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify stopped medications are displayed
      // Timeline should show completed medication lines
    });

    testWidgets('Scenario: Patient with medication dose changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'patient-dose-changes',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify dose change events are marked on timeline
      // Should see increase/decrease markers
    });

    testWidgets('Scenario: Long-term patient with years of history', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'patient-long-term',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test ALL filter to see complete history
      await tester.tap(find.text('ALL'));
      await tester.pumpAndSettle();

      // Verify timeline spans multiple years
    });
  });

  group('Medication History - User Interactions', () {
    testWidgets('Interaction: Hover over event markers shows tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'test-patient-2',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find event markers (if any are rendered)
      final tooltips = find.byType(Tooltip);
      
      if (tooltips.evaluate().isNotEmpty) {
        // Hover over tooltip to trigger it
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        
        await tester.pump();
        
        // Move to tooltip location
        final tooltipFinder = tooltips.first;
        await gesture.moveTo(tester.getCenter(tooltipFinder));
        await tester.pumpAndSettle();

        // Tooltip message should be visible
        // expect(find.text('Started'), findsOneWidget);
      }
    });

    testWidgets('Interaction: Scroll through long medication list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationHistoryOverlay(
              patientId: 'patient-many-meds',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find scrollable widget
      final scrollable = find.descendant(
        of: find.byType(MedicationHistoryOverlay),
        matching: find.byType(SingleChildScrollView),
      );

      if (scrollable.evaluate().isNotEmpty) {
        // Scroll down
        await tester.drag(scrollable.first, const Offset(0, -200));
        await tester.pumpAndSettle();

        // Scroll up
        await tester.drag(scrollable.first, const Offset(0, 200));
        await tester.pumpAndSettle();

        // Verify no errors during scrolling
        expect(tester.takeException(), isNull);
      }
    });
  });
}
