import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/aiplatform/v1.dart';
import 'package:logging/logging.dart';

class ReportGenerator {
  static final log = Logger('ReportGenerator');

  // Service Account Credentials
  // IMPORTANT: In a production app, never hardcode credentials like this.
  // Use a backend proxy or secure storage.
  static const _serviceAccountJson = {
    "type": "service_account",
    "project_id": "synapseai-production",
    "private_key_id": "REPLACE_WITH_PRIVATE_KEY_ID",
    "private_key": "REPLACE_WITH_PRIVATE_KEY",
    "client_email": "gemini-backend-user@synapseai-production.iam.gserviceaccount.com",
    "client_id": "REPLACE_WITH_CLIENT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/gemini-backend-user%40synapseai-production.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  static const String _projectId = 'synapseai-production';
  static const String _location = 'asia-south1';
  static const String _modelId = 'gemini-3-pro-preview';

  static const String _systemPrompt = '''
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
6.  `provided_diagnosis`: (String) The diagnosis or impression (Imp/∆) written by the doctor. Also include any medications, prescriptions (Rx), or treatment plans mentioned.

**Critical Rules:**
1.  **Missing Information:** If a specific section is not found in the notes, the value must be the string "Not mentioned". Do not hallucinate or infer missing data.
2.  **Abbreviations:** Expand standard clinical abbreviations for clarity (e.g., change "wks" to "weeks", "pt" to "patient") BUT keep the patient's subjective description (quotes) exact.
3.  **Symbols:** Convert symbols to text (e.g., "Sleep ↓" becomes "Sleep decreased/reduced").
4.  **Language:** If words like "Ghabrahat" or "Man udaas" are used, transliterate them exactly as written, followed by the English approximation in parentheses if obvious (e.g., "Ghabrahat (Anxiety)").

**Example Input:**
"C/o: Ghabrahat, ↓ sleep, Sad ↑ for 2 mths. Ppt fact: Death of friend. Past Hist: Similar complaint 3 yrs back following work stress. MSE: Consc, co-op. Mood-anx. Aff-restricted."

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
  "provided_diagnosis": "Not mentioned"
}
''';

  static Future<Map<String, dynamic>> generateReport(Uint8List imageBytes) async {
    try {
      if (imageBytes.isEmpty) {
        throw Exception('ReportGenerator: Captured image bytes are empty');
      }

      log.info('ReportGenerator: Generating report with model $_modelId in $_location');
      log.info('ReportGenerator: Image size: ${imageBytes.length} bytes');
      log.info('Authenticating with Google Cloud...');
      
      final accountCredentials = ServiceAccountCredentials.fromJson(_serviceAccountJson);
      final scopes = [AiplatformApi.cloudPlatformScope];
      
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final api = AiplatformApi(client);

      final parent = 'projects/$_projectId/locations/$_location/publishers/google/models/$_modelId';
      
      log.info('Sending request to Vertex AI ($parent)...');

      final request = GoogleCloudAiplatformV1GenerateContentRequest(
        systemInstruction: GoogleCloudAiplatformV1Content(
          parts: [
            GoogleCloudAiplatformV1Part(text: _systemPrompt),
          ],
        ),
        contents: [
          GoogleCloudAiplatformV1Content(
            role: 'user',
            parts: [
              GoogleCloudAiplatformV1Part(text: "Analyze this clinical note and generate the report."),
              GoogleCloudAiplatformV1Part(
                inlineData: GoogleCloudAiplatformV1Blob(
                  mimeType: 'image/png',
                  data: base64Encode(imageBytes),
                ),
              ),
            ],
          ),
        ],
        generationConfig: GoogleCloudAiplatformV1GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 2048,
          topP: 0.8,
          topK: 40,
        ),
        safetySettings: [
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_HATE_SPEECH',
            threshold: 'BLOCK_ONLY_HIGH',
          ),
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
            threshold: 'BLOCK_ONLY_HIGH',
          ),
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            threshold: 'BLOCK_ONLY_HIGH',
          ),
          GoogleCloudAiplatformV1SafetySetting(
            category: 'HARM_CATEGORY_HARASSMENT',
            threshold: 'BLOCK_ONLY_HIGH',
          ),
        ],
      );

      final response = await api.projects.locations.publishers.models.generateContent(
        request,
        parent,
      );

      log.info('Full Vertex AI Response: ${jsonEncode(response.toJson())}');

      client.close();

      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final candidate = response.candidates!.first;
        
        if (candidate.finishReason != 'STOP') {
          log.warning('ReportGenerator: Candidate finish reason: ${candidate.finishReason}');
        }

        if (candidate.content != null && candidate.content!.parts != null && candidate.content!.parts!.isNotEmpty) {
          String responseText = candidate.content!.parts!.first.text ?? '';
          
          // Clean up markdown code blocks
          responseText = responseText.replaceFirst(RegExp(r'^```json\s*'), '').replaceFirst(RegExp(r'\s*```$'), '').trim();
          
          log.info('Received response from Vertex AI');
          try {
            return jsonDecode(responseText) as Map<String, dynamic>;
          } catch (e) {
            log.severe('Failed to parse JSON response: $responseText');
            throw Exception('Failed to parse AI response');
          }
        }
      }
      
      throw Exception('No content generated from Vertex AI');

    } catch (e) {
      log.severe('Error generating report', e);
      rethrow;
    }
  }
}
