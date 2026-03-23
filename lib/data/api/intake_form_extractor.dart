import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';

/// Service for extracting psychiatric intake form data from photos using Gemini Vision API
class IntakeFormExtractor {
  static final log = Logger('IntakeFormExtractor');

  // Service Account Credentials (same as ReportGenerator)
  static final _serviceAccountJson = jsonDecode(
    dotenv.env['GOOGLE_SERVICE_ACCOUNT_JSON']!,
  );

  static const _projectId = 'synapseai-production';
  static const _location = 'asia-south1';
  static const _modelId =
      'gemini-3-flash-preview'; // Using flash model for speed

  static const _systemPrompt = '''
**Role:**
You are an AI Medical Data Entry Assistant specializing in digitizing psychiatric intake forms.

**Task:**
Extract ALL information from the provided psychiatric intake form photos (front and back pages) and return it as a structured JSON object.

**Input:**
- Two photos: Front page and Back page of a psychiatric intake form
- Form contains checkboxes, text fields, and clinical observations
- May contain handwriting, checkmarks, and clinical abbreviations

**Output Requirements:**
Return a single valid JSON object with the following structure. Do NOT include markdown formatting.

**JSON Schema:**
{
  "registration_number": "string or null",
  "residence": "string or null",
  "duration_of_illness": "string or null",
  "referred_by": "string or null",
  "precipitating_factor": "string or null",
  
  "anxiety_worry": boolean,
  "panic": boolean,
  "restless": boolean,
  "palpitations_tremors": boolean,
  "phobia": boolean,
  "obsessions": boolean,
  "compulsions": boolean,
  "hypochondriacal": boolean,
  "fits_hyst_epileptic": boolean,
  "possession_state": boolean,
  
  "somatic_headache": boolean,
  "somatic_bodyache": boolean,
  "somatic_abdominal": boolean,
  "somatic_other": "string or null",
  
  "substance_use": "use/abuse/dependence or null",
  "alcohol_drugs": boolean,
  "tobacco_smoking": boolean,
  
  "decreased_libido": boolean,
  "increased_libido": boolean,
  "erectile_dysfunction": boolean,
  "premature_ejaculation": boolean,
  "retarded_ejaculation": boolean,
  "worry_masturbation_ne": boolean,
  "sexual_dysfunction_other": "string or null",
  
  "ideas_del_persecution": boolean,
  "ideas_del_reference": boolean,
  "other_delusions": boolean,
  "first_rank_symptoms": boolean,
  "hallucinations_auditory": boolean,
  "hallucinations_visual": boolean,
  "incoherence": boolean,
  "muttering_to_self": boolean,
  "inappropriate_smiling": boolean,
  "inappropriate_weeping": boolean,
  "abusing": boolean,
  "violence": boolean,
  "withdrawal_inertia": boolean,
  
  "irritable_elated": boolean,
  "grandiose": boolean,
  "overtalkative": boolean,
  "flight_of_ideas": boolean,
  "overactive_pma": boolean,
  "extravagant": boolean,
  
  "sad_intermittent": boolean,
  "sad_persistent": boolean,
  "anhedonia_inertia": boolean,
  "diurnal_change": boolean,
  "weight_loss": boolean,
  "weight_gain": boolean,
  "insomnia_type": "I/M/T/To or null",
  "hypersomnia": boolean,
  "pmr_pma": boolean,
  "fatigue": boolean,
  "worthlessness_guilt": boolean,
  "decreased_thinking_concentration": boolean,
  "indecisive": boolean,
  "suicidal_thoughts": boolean,
  "suicidal_plans": boolean,
  "suicidal_attempts": boolean,
  
  "disorientation_time": boolean,
  "disorientation_place": boolean,
  "disorientation_person": boolean,
  "forgetfulness": "mild/mod/severe or null",
  "aphasia_apraxia_agnosia": boolean,
  "decreased_intelligence": boolean,
  "perseveration": boolean,
  "losing_path": boolean,
  "disinhibition": boolean,
  "incontinence_urine": boolean,
  "incontinence_stools": boolean,
  "emotional_lability": boolean,
  
  "medical_illnesses": "string or null",
  "stresses": "string or null",
  "ongoing_treatment": "string or null",
  "other_symptoms": "string or null",
  "clinical_notes": "string or null",
  "provisional_diagnosis": "string or null"
}

**Extraction Rules:**
1. For checkboxes: Return `true` if checked/marked, `false` if unchecked/blank
2. For text fields: Return the exact text written, or `null` if empty
3. For dropdown fields (substance_use, insomnia_type, forgetfulness): Return the selected option or `null`
4. If text is illegible or unclear, return `null` for that field
5. Preserve medical abbreviations and terminology exactly as written
6. If a checkbox is ambiguous (unclear if checked), default to `false`

**Critical:** 
- Return ONLY the JSON object, no additional text
- Ensure all boolean fields are present (default to false if unclear)
- All string fields should be null if empty/not mentioned
''';

  /// Extract intake form data from two photos (front and back)
  static Future<Map<String, dynamic>> extractFromPhotos({
    required Uint8List frontPhoto,
    required Uint8List backPhoto,
  }) async {
    try {
      log.info('IntakeFormExtractor: Starting extraction from photos');
      log.info('Front photo size: ${frontPhoto.length} bytes');
      log.info('Back photo size: ${backPhoto.length} bytes');

      if (frontPhoto.isEmpty || backPhoto.isEmpty) {
        throw Exception('IntakeFormExtractor: Photo bytes are empty');
      }

      log.info('Authenticating with Google Cloud...');

      // Fix for private key formatting
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

      const parent =
          'projects/$_projectId/locations/$_location/publishers/google/models/$_modelId';

      log.info('Sending request to Vertex AI ($parent)...');

      // Create parts with both photos
      final parts = <GoogleCloudAiplatformV1Part>[
        GoogleCloudAiplatformV1Part(
          text: 'Extract all data from this psychiatric intake form:',
        ),
        GoogleCloudAiplatformV1Part(text: 'Front page:'),
        GoogleCloudAiplatformV1Part(
          inlineData: GoogleCloudAiplatformV1Blob(
            mimeType: 'image/png',
            data: base64Encode(frontPhoto),
          ),
        ),
        GoogleCloudAiplatformV1Part(text: 'Back page:'),
        GoogleCloudAiplatformV1Part(
          inlineData: GoogleCloudAiplatformV1Blob(
            mimeType: 'image/png',
            data: base64Encode(backPhoto),
          ),
        ),
      ];

      final request = GoogleCloudAiplatformV1GenerateContentRequest(
        systemInstruction: GoogleCloudAiplatformV1Content(
          parts: [GoogleCloudAiplatformV1Part(text: _systemPrompt)],
        ),
        contents: [GoogleCloudAiplatformV1Content(role: 'user', parts: parts)],
        generationConfig: GoogleCloudAiplatformV1GenerationConfig(
          temperature: 0.1, // Low temperature for precise extraction
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

      GoogleCloudAiplatformV1GenerateContentResponse? response;
      int maxRetries = 3;
      int attempt = 0;

      while (true) {
        try {
          response = await api.projects.locations.publishers.models
              .generateContent(request, parent);
          break; // Success
        } catch (e) {
          final isQuotaError = e.toString().contains('429') ||
              e.toString().contains('503') ||
              e.toString().contains('Resource has been exhausted');
          
          if (isQuotaError) {
            attempt++;
            if (attempt > maxRetries) {
              log.severe('Vertex AI Quota exceeded and max retries reached.', e);
              throw Exception(
                  'Vertex AI is currently overloaded (Quota Exceeded). Please try again in a few moments.');
            }
            final delayMs = (1000 * (1 << attempt)) + Random().nextInt(1000);
            log.warning(
                'Vertex AI Error (Quota/Unavailable). Retrying in ${delayMs}ms (Attempt $attempt of $maxRetries)...');
            await Future.delayed(Duration(milliseconds: delayMs));
          } else {
            rethrow;
          }
        }
      }

      log.info('Received response from Vertex AI');

      client.close();

      // Check for prompt feedback
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

        if (candidate.finishReason != 'STOP') {
          log.warning(
            'IntakeFormExtractor: Candidate finish reason: ${candidate.finishReason}',
          );
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

          log.info('Extraction successful, parsing JSON...');
          try {
            final extractedData =
                jsonDecode(responseText) as Map<String, dynamic>;
            log.info(
              'Successfully extracted ${extractedData.keys.length} fields',
            );
            return extractedData;
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
      log.severe('Error extracting intake form data', e);
      rethrow;
    }
  }
}
