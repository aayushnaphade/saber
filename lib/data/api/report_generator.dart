import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
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
You are an expert AI Medical Scribe specializing in Psychiatry. Your task is to extract and structure clinical data from handwritten session notes into a Clinical Assessment Report JSON.

**Multimodal Instructions:**
- **Spatial Anchoring**: Clinical notes are typically written chronologically from top to bottom. If multiple pages are provided, process them in the sequence provided (Page 1, Page 2, etc.).
- **Handwriting Recognition**: Aggressively parse handwritten symbols and shorthands. Some text may be blurred or slanted; use the surrounding clinical context to infer the most likely medical meaning. If a word is truly illegible, mark it as "[illegible]" within the relative field.

**Input Context:**
- Notes use standard abbreviations (e.g., "c/o" for complaints of, "h/o" for history of, "Rx/Adv" for medications).
- Symbols are common (e.g., "↑" for increased, "↓" for decreased, "+" for positive, "∆" for diagnosis, "⊘" for absent).
- Language: Mixed English and transliterated Hindi (e.g., "Ghabrahat" for anxiety, "Mun udaas" for low mood).

**Output Requirements:**
You must output a structured Clinical Assessment Report based on the provided schema.

**Section-Specific Logic:**
1.  `current_symptoms`: Extract the "c/o" or History of Present Illness. Include durations (e.g., "2 wks").
2.  `mental_status_examination`: map findings to "appearance", "behavior", "speech", "mood", "affect", "thought_process", "thought_content", "perception", "cognition", "insight", "judgment". 
3.  `medications`: 
    - Look for "Rx", "Adv", or lists at the bottom.
    - Expand frequencies: "BD" -> "twice daily", "TDS" -> "thrice daily", "HS" -> "at bedtime", "SOS" -> "as needed".
    - Durations: "x 5 d" -> "5 days", "1/52" -> "1 week", "1/12" -> "1 month".

**Critical Rules:**
1.  **Strict Accuracy**: Do not hallucinate. If a section is missing, return "Not mentioned".
2.  **Terminology**: Transliterate Hindi terms exactly (e.g., "Ghabrahat") and add the English meaning in parentheses.
3.  **Expansion**: Convert symbols to text (e.g., "Sleep ↓" becomes "Sleep decreased").

**Example Output:**
```json
{
  "current_symptoms": "Reports Ghabrahat, decreased sleep, and increased sadness for 2 months. Precipitating factor: Death of a friend.",
  "premorbid_personality": "Not mentioned",
  "past_history": "Similar complaint 3 years back, following stress at work. Remitted without treatment.",
  "family_history": "Not mentioned",
  "mental_status_examination": {
    "appearance": "Conscious",
    "behavior": "cooperative",
    "speech": "Not mentioned",
    "mood": "Anxious",
    "affect": "Restricted",
    "thought_process": "Not mentioned",
    "thought_content": "Not mentioned",
    "perception": "Not mentioned",
    "cognition": "Not mentioned",
    "insight": "Not mentioned",
    "judgment": "Not mentioned"
  },
  "provided_diagnosis": "Not mentioned",
  "medications": [
    {
      "name": "T. Sertraline",
      "dosage": "50mg",
      "frequency": "HS",
      "duration": "Not mentioned",
      "remarks": "Not mentioned"
    }
  ]
}
```
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
      const scopes = [AiplatformApi.cloudPlatformScope];

      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final api = AiplatformApi(client);

      final parent =
          'projects/$_projectId/locations/$_location/publishers/google/models/$_modelId';

      log.info('Sending request to Vertex AI ($parent)...');

      String systemPrompt = _defaultSystemPrompt;
      try {
        final medsJson = await rootBundle.loadString(
          'assets/data/psychiatric_medications.json',
        );
        final medsList = (jsonDecode(medsJson) as List).cast<String>();
        systemPrompt +=
            '\n4.  **Medication Spelling**: When extracting medications, strictly match the spelling against the following known psychiatric medications: ${medsList.join(', ')}. Correct any misspellings found in the handwritten notes to match this list. If it isn\'t on the list, extract it exactly as written.';
      } catch (e) {
        log.warning('Could not load medication dictionary for prompt: $e');
      }
      final parts = <GoogleCloudAiplatformV1Part>[];

      for (var i = 0; i < imageBytesList.length; i++) {
        final imageSize = imageBytesList[i].length;
        if (imageSize == 0) continue;

        // Label page for spatial/contextual reasoning
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

      // 2. Add instruction part LAST
      parts.add(
        GoogleCloudAiplatformV1Part(
          text:
              'Analyze these clinical notes (spanning ${imageBytesList.length} pages) and generate the report based on the provided system instructions and schema.',
        ),
      );

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
          temperature: 0.2, // Lower temperature for factual extraction
          maxOutputTokens: 8192,
          topP: 0.95, // Recommended for OCR/Handwriting
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
            'Safety ratings: ${candidate.safetyRatings!.map((r) => "${r.category}: ${r.probability}").join(', ')}',
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
          e.toString().contains('Connection timed out') ||
          e.toString().contains('connection abort')) {
        throw Exception(
          'Network error: The connection was interrupted. This often happens with large notes or poor internet. Please try again with fewer pages or a stronger connection.',
        );
      }
      rethrow;
    }
  }
}
