import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/aiplatform/v1.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';

class ReportGenerator {
  static final log = Logger('ReportGenerator');

  // Service Account Credentials
  // IMPORTANT: In a production app, never hardcode credentials like this.
  // Use a backend proxy or secure storage.
  static final _serviceAccountJson = jsonDecode(
    dotenv.env['GOOGLE_SERVICE_ACCOUNT_JSON']!,
  );

  static const _projectId = 'synapseai-production';
  static const _location = 'asia-south1';

  /// Get the model ID based on user preference
  static String get _modelId {
    switch (stows.reportGenerationModel.value) {
      case ReportGenerationModel.flash:
        return 'gemini-3-flash-preview';
      case ReportGenerationModel.pro:
        return 'gemini-3-pro-preview';
    }
  }

  static const _defaultSystemPrompt = '''
**Role:**
You are an expert AI Medical Scribe specializing in Psychiatry. Your task is to convert unstructured session notes (which may contain abbreviations, symbols, and mixed English/Hindi terminology) into a structured Clinical Assessment Report in JSON format.

**Input Context:**
- The input will be text derived from handwritten clinical notes.
- Notes often use standard medical abbreviations (e.g., "c/o" for complains of, "h/o" for history of).
- Notes may use symbols (e.g., "↑" for increased, "↓" for decreased, "+" for positive, "∆" for diagnosis).
- Notes may contain colloquial terms (e.g., "Ghabrahat", "Bechaini"). Preserve these terms as they describe patient phenomenology.

**Output Requirements:**
You must output a single valid JSON object containing exactly these six keys. Do not include markdown formatting (like ```json) inside the response, just the raw JSON.

**JSON Schema Keys:**
1.  `current_symptoms`: (String) The "c/o" or History of Present Illness. Include duration if mentioned.
2.  `premorbid_personality`: (String) Information about the patient's nature before illness.
3.  `past_history`: (String) Previous episodes, medical history, or past treatments.
4.  `family_history`: (String) Descriptions of family mental health or the family tree/genogram details.
5.  `mental_status_examination`: (Object) Break this down into sub-fields based on the notes (e.g., "appearance", "mood", "affect", "thought", "perception", "insight").
6.  `provided_diagnosis`: (String) The diagnosis or impression (Imp/∆) written by the doctor.
7.  `medications`: (Array of Objects) List of prescribed medicines found in the notes (Rx/Adv). Each object must have:
    - `name` (String): Name of the medicine + dosage.
    - `frequency` (String): Frequency (e.g., "BD", "1-0-1").
    - `duration` (String): Duration if mentioned (e.g., "5 days", "1 month").
    - `remarks` (String): Any special instructions or administration notes (e.g., "after food", "empty stomach", "at night"). Look for text written below or next to the medication.
    If no medications are found, return empty array `[]`.

**Critical Rules:**
1.  **Missing Information:** If a specific section is not found in the notes, the value must be the string "Not mentioned". Do not hallucinate or infer missing data.
2.  **Abbreviations:** Expand standard clinical abbreviations for clarity (e.g., change "wks" to "weeks", "pt" to "patient") BUT keep the patient's subjective description (quotes) exact.
3.  **Symbols:** Convert symbols to text (e.g., "Sleep ↓" becomes "Sleep decreased/reduced").
4.  **Language:** If words like "Ghabrahat" or "Man udaas" are used, transliterate them exactly as written, followed by the English approximation in parentheses if obvious (e.g., "Ghabrahat (Anxiety)").

**Example Input:**
"C/o: Ghabrahat, ↓ sleep, Sad ↑ for 2 mths. Ppt fact: Death of friend. Past Hist: Similar complaint 3 yrs back following work stress. MSE: Consc, co-op. Mood-anx. Aff-restricted. Rx: T. Sertraline 50mg HS, T. Clonazepam 0.5mg SOS fro 5 days (ensure good sleep)."

**Example Output:**
{
  "current_symptoms": "Reports Ghabrahat, decreased sleep, and increased sadness for 2 months. Precipitating factor: Death of a friend.",
  "premorbid_personality": "Not mentioned",
  "past_history": "Similar complaint 3 years back, following stress at work. Remitted without treatment.",
  "family_history": "Not mentioned",
  "mental_status_examination": {
    "general_behavior": "Conscious, cooperative",
    "mood": "Anxious",
    "affect": "Restricted"
  },
  "provided_diagnosis": "Not mentioned",
  "medications": [
    {
      "name": "T. Sertraline 50mg",
      "frequency": "HS",
      "duration": "Not mentioned",
      "remarks": "Not mentioned"
    },
    {
      "name": "T. Clonazepam 0.5mg",
      "frequency": "SOS",
      "duration": "5 days",
      "remarks": "ensure good sleep"
    }
  ]
}
''';

  static Future<Map<String, dynamic>> generateReport(
    List<Uint8List> imageBytesList, {
    String? registrationNumber,
  }) async {
    try {
      if (imageBytesList.isEmpty) {
        throw Exception('ReportGenerator: Captured image bytes are empty');
      }

      log.info(
        'ReportGenerator: Generating report with model $_modelId in $_location',
      );
      log.info('ReportGenerator: Processing ${imageBytesList.length} pages');
      log.info('Authenticating with Google Cloud...');

      // Fix for private key formatting issues when reading from .env
      final serviceAccount = Map<String, dynamic>.from(_serviceAccountJson);
      if (serviceAccount.containsKey('private_key')) {
        serviceAccount['private_key'] =
            (serviceAccount['private_key'] as String).replaceAll(r'\n', '\n');
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(
        serviceAccount,
      );
      final scopes = [AiplatformApi.cloudPlatformScope];

      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final api = AiplatformApi(client);

      final parent =
          'projects/$_projectId/locations/$_location/publishers/google/models/$_modelId';

      log.info('Sending request to Vertex AI ($parent)...');

      final systemPrompt = _defaultSystemPrompt;

      // Create parts for all pages
      final parts = <GoogleCloudAiplatformV1Part>[
        GoogleCloudAiplatformV1Part(
          text:
              'Analyze these clinical notes (spanning ${imageBytesList.length} pages) and generate the report.',
        ),
      ];

      for (var i = 0; i < imageBytesList.length; i++) {
        final imageSize = imageBytesList[i].length;
        log.info(
          'Adding page ${i + 1} to request, image size: $imageSize bytes',
        );

        if (imageSize == 0) {
          log.warning('Page ${i + 1} has empty image bytes!');
          continue; // Skip empty images
        }

        parts.add(GoogleCloudAiplatformV1Part(text: 'Page ${i + 1}:'));
        parts.add(
          GoogleCloudAiplatformV1Part(
            inlineData: GoogleCloudAiplatformV1Blob(
              mimeType: 'image/png',
              data: base64Encode(imageBytesList[i]),
            ),
          ),
        );
      }

      // Ensure we have at least one valid image
      if (parts.length <= 1) {
        throw Exception('No valid images to process - all pages were empty');
      }

      log.info('Total parts in request: ${parts.length}');

      final request = GoogleCloudAiplatformV1GenerateContentRequest(
        systemInstruction: GoogleCloudAiplatformV1Content(
          parts: [GoogleCloudAiplatformV1Part(text: systemPrompt)],
        ),
        contents: [GoogleCloudAiplatformV1Content(role: 'user', parts: parts)],
        generationConfig: GoogleCloudAiplatformV1GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 8192,
          topP: 0.8,
          topK: 40,
        ),
        safetySettings: [
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_HATE_SPEECH',
            threshold: 'BLOCK_NONE',
          ),
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
            threshold: 'BLOCK_NONE',
          ),
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            threshold: 'BLOCK_NONE',
          ),
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_HARASSMENT',
            threshold: 'BLOCK_NONE',
          ),
        ],
      );

      final response = await api.projects.locations.publishers.models
          .generateContent(request, parent);

      log.info('Full Vertex AI Response: ${jsonEncode(response.toJson())}');

      client.close();

      // Check for prompt feedback (safety blocks, etc.)
      if (response.promptFeedback != null) {
        log.info(
          'Prompt feedback: ${jsonEncode(response.promptFeedback!.toJson())}',
        );
        if (response.promptFeedback!.blockReason != null) {
          throw Exception(
            'Request blocked by Vertex AI: ${response.promptFeedback!.blockReason}',
          );
        }
      }

      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final candidate = response.candidates!.first;

        log.info('Candidate finish reason: ${candidate.finishReason}');
        if (candidate.safetyRatings != null) {
          log.info(
            'Safety ratings: ${candidate.safetyRatings!.map((r) => '${r.category}: ${r.probability}').join(', ')}',
          );
        }

        if (candidate.finishReason != 'STOP') {
          log.warning(
            'ReportGenerator: Candidate finish reason: ${candidate.finishReason}',
          );
          // If finish reason indicates an issue, throw with more context
          if (candidate.finishReason == 'SAFETY' ||
              candidate.finishReason == 'OTHER') {
            throw Exception(
              'Vertex AI stopped generation. Reason: ${candidate.finishReason}',
            );
          }
        }

        if (candidate.content != null &&
            candidate.content!.parts != null &&
            candidate.content!.parts!.isNotEmpty) {
          String responseText = candidate.content!.parts!.first.text ?? '';

          // Clean up markdown code blocks
          responseText = responseText
              .replaceFirst(RegExp(r'^```json\s*'), '')
              .replaceFirst(RegExp(r'\s*```$'), '')
              .trim();

          log.info('Received response from Vertex AI');
          try {
            final data = jsonDecode(responseText) as Map<String, dynamic>;
            if (registrationNumber != null) {
              data['registration_number'] = registrationNumber;
            }
            return data;
          } catch (e) {
            log.severe('Failed to parse JSON response: $responseText');
            throw Exception('Failed to parse AI response');
          }
        } else {
          throw Exception(
            'Vertex AI returned no content. Finish reason: ${candidate.finishReason}',
          );
        }
      }

      throw Exception('No candidates returned from Vertex AI');
    } catch (e) {
      log.severe('Error generating report', e);
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection timed out')) {
        throw Exception(
          'Network error: Unable to reach Google services. Please check your internet connection or hospital firewall settings.',
        );
      }
      rethrow;
    }
  }
}
