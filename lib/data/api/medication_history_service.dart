import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/api/report_generator.dart';
import 'package:saber/data/models/medication_history_models.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/aiplatform/v1.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MedicationHistoryService {
  static final _log = Logger('MedicationHistoryService');

  /// Fetches all prescriptions for a patient and analyzes the history
  static Future<PatientMedicationHistory> getMedicationHistory(String patientId) async {
    try {
      _log.info('Fetching prescription history for patient: $patientId');
      
      final response = await supabase
          .from('prescriptions')
          .select('id, created_at, content, consultation_id')
          .eq('patient_id', patientId)
          .order('created_at', ascending: true);

      if (response == null || (response as List).isEmpty) {
        return PatientMedicationHistory(patientId: patientId, lifespans: []);
      }

      final List prescriptions = response as List;
      _log.info('Found ${prescriptions.length} prescriptions. Analyzing transitions...');

      // Map from medication name to its lifespan
      final Map<String, List<MedicationEvent>> lifespansMap = {};

      for (int i = 0; i < prescriptions.length; i++) {
        final current = prescriptions[i];
        final prev = i > 0 ? prescriptions[i - 1] : null;
        
        final currentDate = DateTime.parse(current['created_at']);
        final currentMeds = current['content']['medications'] as List? ?? [];
        final prevMeds = prev != null ? (prev['content']['medications'] as List? ?? []) : [];

        // If it's the first prescription, all meds are "STARTED"
        if (prev == null) {
          for (final med in currentMeds) {
            final name = _getMedName(med);
            _addEvent(lifespansMap, name, MedicationEvent(
              date: currentDate,
              type: MedicationEventType.started,
              dose: med['name'], // name field in prescription usually contains dosage
              frequency: med['frequency'],
              remarks: med['remarks'],
              consultationId: current['consultation_id'],
            ));
          }
        } else {
          // Identify transitions using AI
          final transitions = await _analyzeTransitionsAI(prevMeds, currentMeds);
          
          for (final transition in transitions) {
            final name = transition['name'];
            _addEvent(lifespansMap, name, MedicationEvent(
              date: currentDate,
              type: _mapTransitionType(transition['type']),
              dose: transition['current_dose'],
              frequency: transition['current_frequency'],
              remarks: transition['remarks'],
              consultationId: current['consultation_id'],
            ));
          }
          
          // Detect STOPPED meds: Any med in prev that's not in current AND not mentioned in AI transitions as STOPPED
          // Actually, we'll let AI handle the comparison entirely to be safe.
        }
      }

      final lifespans = lifespansMap.entries.map((e) => MedicationLifespan(
        name: e.key,
        events: e.value,
      )).toList();

      return PatientMedicationHistory(patientId: patientId, lifespans: lifespans);
    } catch (e) {
      _log.severe('Failed to get medication history', e);
      rethrow;
    }
  }

  static String _getMedName(dynamic med) {
    // In our system, 'name' often includes dosage (e.g., "Tab Sertraline 50mg").
    // For the timeline, we ideally want just "Sertraline".
    // We'll trust the AI analysis to group these correctly.
    return med['name']?.toString() ?? 'Unknown';
  }

  static void _addEvent(Map<String, List<MedicationEvent>> map, String name, MedicationEvent event) {
    if (!map.containsKey(name)) {
      map[name] = [];
    }
    map[name]!.add(event);
  }

  static MedicationEventType _mapTransitionType(String? type) {
    switch (type?.toLowerCase()) {
      case 'started': return MedicationEventType.started;
      case 'increased': return MedicationEventType.increased;
      case 'decreased': return MedicationEventType.decreased;
      case 'stopped': return MedicationEventType.stopped;
      case 'continued': return MedicationEventType.continued;
      default: return MedicationEventType.continued;
    }
  }

  /// Uses Gemini to compare two lists of medications and find changes
  static Future<List<Map<String, dynamic>>> _analyzeTransitionsAI(List prevMeds, List currentMeds) async {
    try {
      if (prevMeds.isEmpty && currentMeds.isEmpty) return [];

      final prompt = '''
Compare two lists of psychiatric medications from a patient's consecutive prescriptions and identify the transitions for each medication.

**Previous Medications:**
${jsonEncode(prevMeds)}

**Current Medications:**
${jsonEncode(currentMeds)}

**Rules:**
1. Identify if a medication was:
   - "STARTED": Not in previous, but in current.
   - "INCREASED": Dose or frequency increased in current compared to previous.
   - "DECREASED": Dose or frequency decreased in current compared to previous.
   - "STOPPED": In previous, but missing in current.
   - "CONTINUED": In both with same dose/frequency.
2. Group medications by their base name (e.g., "Sertraline") even if dosage changed.
3. Output a valid JSON list of objects. Each object must have:
   - "name": Base name of the medicine.
   - "type": "STARTED", "INCREASED", "DECREASED", "STOPPED", or "CONTINUED".
   - "previous_dose": Dose from previous (if applicable).
   - "current_dose": Dose from current (if applicable).
   - "current_frequency": Frequency from current.
   - "remarks": Remarks from current.

Output ONLY the JSON list.
''';

      // Reusing logic from ReportGenerator to call Vertex AI
      // For simplicity in this implementation, I'll invoke the same API directly here
      // though in a real app we might want to share the client logic.
      
      final serviceAccountJson = jsonDecode(dotenv.env['GOOGLE_SERVICE_ACCOUNT_JSON']!);
      final serviceAccount = Map<String, dynamic>.from(serviceAccountJson);
      if (serviceAccount.containsKey('private_key')) {
        serviceAccount['private_key'] = (serviceAccount['private_key'] as String).replaceAll(r'\n', '\n');
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = [AiplatformApi.cloudPlatformScope];
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final api = AiplatformApi(client);

      const projectId = 'synapseai-production';
      const location = 'asia-south1';
      const modelId = 'gemini-1.5-flash-preview'; // Flash is fast and good for this
      final parent = 'projects/$projectId/locations/$location/publishers/google/models/$modelId';

      final request = GoogleCloudAiplatformV1GenerateContentRequest(
        contents: [
          GoogleCloudAiplatformV1Content(
            role: 'user',
            parts: [GoogleCloudAiplatformV1Part(text: prompt)],
          ),
        ],
        generationConfig: GoogleCloudAiplatformV1GenerationConfig(
          temperature: 0.1, // Low temperature for deterministic output
          maxOutputTokens: 2048,
        ),
      );

      final response = await api.projects.locations.publishers.models.generateContent(request, parent);
      client.close();

      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final part = response.candidates!.first.content?.parts?.first;
        if (part != null && part.text != null) {
          String text = part.text!.trim();
          // Clean markdown blocks
          text = text.replaceFirst(RegExp(r'^```json\s*'), '').replaceFirst(RegExp(r'\s*```$'), '').trim();
          return (jsonDecode(text) as List).cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      _log.severe('AI analysis failed', e);
      // Fallback: simple name-based comparison if AI fails
      return _fallbackComparison(prevMeds, currentMeds);
    }
  }

  static List<Map<String, dynamic>> _fallbackComparison(List prevMeds, List currentMeds) {
    final List<Map<String, dynamic>> results = [];
    final prevNames = prevMeds.map((m) => m['name']?.toString()).toSet();
    final currentNames = currentMeds.map((m) => m['name']?.toString()).toSet();

    for (final med in currentMeds) {
      final name = med['name']?.toString();
      if (!prevNames.contains(name)) {
        results.add({'name': name, 'type': 'STARTED', 'current_dose': med['name'], 'current_frequency': med['frequency']});
      } else {
        results.add({'name': name, 'type': 'CONTINUED', 'current_dose': med['name'], 'current_frequency': med['frequency']});
      }
    }

    for (final med in prevMeds) {
      final name = med['name']?.toString();
      if (!currentNames.contains(name)) {
        results.add({'name': name, 'type': 'STOPPED'});
      }
    }

    return results;
  }
}
