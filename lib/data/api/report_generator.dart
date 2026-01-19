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
  static final _serviceAccountJson = jsonDecode(dotenv.env['GOOGLE_SERVICE_ACCOUNT_JSON']!);

  static const _projectId = 'synapseai-production';
  static const _location = 'asia-south1';
  static const _modelId = 'gemini-3-pro-preview';

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

  static const _exactExtractionSystemPrompt = '''
**Role:**
You are a Precision Clinical Data Extractor. Your job is to digitize handwritten psychiatric session notes into a JSON format.

**Core Directive:**
Segment the raw text into six specific clinical sections. Within those sections, you must preserve the **exact phrasing, abbreviations, and symbols** used by the doctor. Do not expand abbreviations (e.g., keep "c/o", do not change to "complains of"). Do not translate Hinglish terms (e.g., keep "Ghabrahat").

**Input Processing Rules:**
1.  **Verbatim Extraction:** Extract words exactly as written. If the doctor writes "Sad +", output "Sad +".
2.  **Symbol Handling:**
    * Convert arrow drawings to Unicode: Use `↑` for up-arrow/increase, `↓` for down-arrow/decrease.
    * Keep `+`, `-`, `Δ` (delta) exactly as shown.
3.  **Diagram Handling:** If a section contains a drawing (like a Family Tree/Genogram) and no text, replace the content with the tag: `[Diagram: Genogram]`.
4.  **Grouping Logic (The Bracket Rule):**
    * If multiple items are grouped by a bracket `}` or line to a single duration/cause (e.g., "Symptom A, Symptom B } 2 months"), **distribute the modifier** to each item to preserve the meaning.
    * *Example Conversion:* "Ghabrahat, ↓ sleep } 2 mths" → "Ghabrahat (2 mths), ↓ sleep (2 mths)"
5.  **Implicit Headers:** If the doctor omits a header (e.g., skips writing "MSE:") but strictly lists MSE observations (e.g., "Conscious, Orient"), automatically place that text into the `mental_status_examination` field.
6.  **Typo Correction:** Fix obvious OCR/handwriting slips (e.g., "5ad" → "Sad", "m0ths" → "mths"), but do **not** fix grammatical errors or clinical shorthand.

**JSON Output Structure:**
Return a single JSON object with these 6 keys. Values must be **Strings**.

* `current_symptoms`: (String) Content related to c/o, presenting complaints.
* `premorbid_personality`: (String) Content related to personality before illness.
* `past_history`: (String) Content related to PHx, past episodes.
* `family_history`: (String) Content related to FHx, family tree.
* `mental_status_examination`: (String) Content related to MSE, appearance, mood, affect.
* `provided_diagnosis`: (String) Content related to Imp, Δ, or diagnosis.

**Handling Missing Data:**
If a section is empty in the source notes, use the string `"Not mentioned"`.

**Example:**

*Input Note:*
"c/o: Ghabrahat, Low mood } 2 wks.
PHx: Nil.
MSE: Co-op. Mood-ok.
Imp: Anxiety"

*Output JSON:*
{
  "current_symptoms": "Ghabrahat (2 wks), Low mood (2 wks)",
  "premorbid_personality": "Not mentioned",
  "past_history": "Nil",
  "family_history": "Not mentioned",
  "mental_status_examination": "Co-op. Mood-ok.",
  "provided_diagnosis": "Anxiety"
}
''';

  static Future<Map<String, dynamic>> generateReport(List<Uint8List> imageBytesList) async {
    try {
      if (imageBytesList.isEmpty) {
        throw Exception('ReportGenerator: Captured image bytes are empty');
      }

      log.info('ReportGenerator: Generating report with model $_modelId in $_location');
      log.info('ReportGenerator: Processing ${imageBytesList.length} pages');
      log.info('Authenticating with Google Cloud...');
      
      // Fix for private key formatting issues when reading from .env
      final serviceAccount = Map<String, dynamic>.from(_serviceAccountJson);
      if (serviceAccount.containsKey('private_key')) {
        serviceAccount['private_key'] = (serviceAccount['private_key'] as String)
            .replaceAll(r'\n', '\n');
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = [AiplatformApi.cloudPlatformScope];
      
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final api = AiplatformApi(client);

      const parent = 'projects/$_projectId/locations/$_location/publishers/google/models/$_modelId';
      
      log.info('Sending request to Vertex AI ($parent)...');

      final systemPrompt = stows.exactExtraction.value
          ? _exactExtractionSystemPrompt
          : _defaultSystemPrompt;

      // Create parts for all pages
      final parts = <GoogleCloudAiplatformV1Part>[
        GoogleCloudAiplatformV1Part(text: 'Analyze these clinical notes (spanning ${imageBytesList.length} pages) and generate the report.'),
      ];

      for (var i = 0; i < imageBytesList.length; i++) {
        parts.add(GoogleCloudAiplatformV1Part(text: 'Page ${i + 1}:'));
        parts.add(GoogleCloudAiplatformV1Part(
          inlineData: GoogleCloudAiplatformV1Blob(
            mimeType: 'image/png',
            data: base64Encode(imageBytesList[i]),
          ),
        ));
      }

      final request = GoogleCloudAiplatformV1GenerateContentRequest(
        systemInstruction: GoogleCloudAiplatformV1Content(
          parts: [
            GoogleCloudAiplatformV1Part(text: systemPrompt),
          ],
        ),
        contents: [
          GoogleCloudAiplatformV1Content(
            role: 'user',
            parts: parts,
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
        } else {
          throw Exception('Vertex AI returned no content. Finish reason: ${candidate.finishReason}');
        }
      }
      
      throw Exception('No candidates returned from Vertex AI');

    } catch (e) {
      log.severe('Error generating report', e);
      rethrow;
    }
  }
}
