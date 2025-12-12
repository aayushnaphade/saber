# SynapseAI Backend Structure Analysis

**Date:** December 11, 2025  
**Purpose:** Document current backend architecture and plan for medical features

---

## 🏗️ Current Backend Architecture

### 1. **Supabase Integration** (`lib/data/supabase/`)

#### `supabase_client.dart`
**Purpose:** Singleton Supabase client configuration

```dart
class SupabaseClientConfig {
  static const String supabaseUrl = 'https://hdrzwpsxljhcknmwstyq.supabase.co'
  static const String supabaseAnonKey = 'sb_publishable_R0EbhLSm11S0H_...'
  
  static Future<void> initialize() // Called in main.dart
  static SupabaseClient get instance // Global accessor
}

// Global shorthand
SupabaseClient get supabase => SupabaseClientConfig.instance;
```

**Features:**
- ✅ PKCE authentication flow
- ✅ Singleton pattern for app-wide access
- ✅ Async initialization

#### `supabase_auth_service.dart`
**Purpose:** Authentication operations wrapper

**Current Methods:**
```dart
class SupabaseAuthService {
  // Authentication
  static Future<AuthResponse> signInWithEmailPassword({email, password})
  static Future<AuthResponse> signUpWithEmailPassword({email, password, metadata})
  static Future<void> signInWithOtp({email})
  static Future<AuthResponse> verifyOtp({email, token, type})
  static Future<void> signOut()
  
  // Password Management
  static Future<void> resetPasswordForEmail(email)
  static Future<UserResponse> updatePassword(newPassword)
  
  // Session Management
  static Future<AuthResponse> refreshSession()
  static Future<bool> tryRestoreSession()
  
  // State
  static Stream<AuthState> get onAuthStateChange
  static Session? get currentSession
  static User? get currentUser
  static bool get isAuthenticated
  
  // Private helpers
  static Future<void> _saveSessionToPrefs(session)
  static Future<void> _clearSessionFromPrefs()
}
```

**Session Storage:**
- Uses `stows` (secure storage) to persist:
  - `supabaseUserId`
  - `supabaseAccessToken`
  - `supabaseRefreshToken`
  - `supabaseUserEmail`

---

### 2. **File Management System** (`lib/data/file_manager/`)

#### `file_manager.dart`
**Purpose:** Cross-platform file system operations

**Key Concepts:**
- **Root Directory:** `Documents/Saber/` (configurable via `customDataDir`)
- **File Format:** `.sbn2` (BSON) or `.sbn` (JSON, legacy)
- **Assets:** Stored as `{filename}.sbn2.{assetNumber}` (e.g., `note.sbn2.0`, `note.sbn2.1`)
- **Previews:** Stored as `{filename}.sbn2.p`

**Core Methods:**

```dart
class FileManager {
  // Initialization
  static Future<void> init({documentsDirectory, shouldWatchRootDirectory})
  
  // File Operations
  static Future<Uint8List?> readFile(filePath, {retries})
  static Future<void> writeFile(filePath, bytes, {awaitWrite, alsoUpload, lastModified})
  static Future<String> moveFile(fromPath, toPath, {replaceExistingFile, alsoMoveAssets})
  static Future<void> deleteFile(filePath, {alsoUpload, alsoDeleteAssets})
  
  // Directory Operations
  static Future<void> createFolder(folderPath)
  static Future<DirectoryChildren?> getChildrenOfDirectory(directory, {includeExtensions, includeAssets})
  static Future<List<String>> getAllFiles({includeExtensions, includeAssets})
  static Future<void> renameDirectory(directoryPath, newName)
  static Future<void> deleteDirectory(directoryPath, [recursive])
  
  // Import/Export
  static Future<void> exportFile(fileName, bytes, {isImage, context})
  static Future<String?> importFile(path, parentDir, {extension, awaitWrite})
  
  // Utilities
  static File getFile(filePath)
  static bool isDirectory(filePath)
  static bool doesFileExist(filePath)
  static DateTime lastModified(filePath)
  static Future<String> newFilePath([parentPath])
  static Future<String> suffixFilePathToMakeItUnique(filePath, {intendedExtension, currentPath})
  
  // Watch System
  static final fileWriteStream = StreamController<FileOperation>.broadcast()
  static void broadcastFileWrite(type, path)
}

// Data Classes
class DirectoryChildren {
  List<String> directories;
  List<String> files;
}

class FileOperation {
  FileOperationType type; // .write, .delete
  String filePath;
}
```

**File System Structure (Current):**
```
Documents/Saber/
├── mynote.sbn2              # Main note file
├── mynote.sbn2.0            # Image asset 0
├── mynote.sbn2.1            # Image asset 1
├── mynote.sbn2.p            # Preview thumbnail
├── folder/
│   └── subnote.sbn2
└── whiteboard.sbn2          # Reserved file
```

---

### 3. **Editor Core** (`lib/data/editor/`)

#### `editor_core_info.dart`
**Purpose:** Note data model and serialization

```dart
class EditorCoreInfo {
  String filePath;                    // Path to the .sbn2 file
  String get fileName;                // Just the filename
  
  // Canvas Properties
  AssetCache assetCache;              // Image asset manager
  int nextImageId;                    // Counter for new images
  Color? backgroundColor;
  CanvasBackgroundPattern backgroundPattern;
  int lineHeight;
  int lineThickness;
  
  // Content
  List<EditorPage> pages;             // Multiple pages per note
  int? initialPageIndex;              // Restore scroll position
  
  // State
  bool readOnly;
  bool readOnlyBecauseOfVersion;
  bool isEmpty / isNotEmpty;
  
  // Serialization
  static const sbnVersion = 19;       // File format version
  Future<void> loadFromFilePath()     // Load .sbn2 from disk
  Future<void> saveToFile({onlyIfNotEmpty})
  
  // Static
  static final empty;                 // Placeholder for new files
}
```

#### `editor_exporter.dart`
**Purpose:** Export notes to PDF/PNG

```dart
abstract class EditorExporter {
  // PDF Generation
  static Future<pw.Document> generatePdf(coreInfo, context)
  
  // Screenshot (for AI processing)
  static Future<Uint8List> screenshotPage({
    required EditorCoreInfo coreInfo,
    required int pageIndex,
    required ScreenshotController screenshotController,
    required BuildContext context,
  })
  
  // Internal
  static bool _shouldRasterizeStroke(stroke)  // Highlighter/Pencil need rasterization
}
```

**Screenshot Output:**
- Format: PNG (Uint8List)
- Resolution: Canvas native resolution
- Used for: PDF export, sharing, **AI processing** (our use case)

#### `page.dart`
**Purpose:** Individual page data

```dart
class EditorPage extends ChangeNotifier implements HasSize {
  List<Stroke> strokes;               // Pen/pencil strokes
  List<EditorImage> images;           // Embedded images
  Size size;                          // Page dimensions
  
  bool get isEmpty;
  void clear();
  void resize(Size newSize);
}
```

---

### 4. **Preferences & Storage** (`lib/data/prefs.dart`)

#### `Stows` (Settings Storage)
**Purpose:** Persistent app settings using `stow` package

**Authentication Data (SecureStow - Encrypted):**
```dart
// Legacy Nextcloud (deprecated but kept for migration)
final url = SecureStow('url', '');
final username = SecureStow('username', '');
final ncPassword = SecureStow('ncPassword', '');

// Supabase (Active)
final supabaseUserId = SecureStow('supabaseUserId', '');
final supabaseAccessToken = SecureStow('supabaseAccessToken', '');
final supabaseRefreshToken = SecureStow('supabaseRefreshToken', '');
final supabaseUserEmail = SecureStow('supabaseUserEmail', '');

// Encryption
final encPassword = SecureStow('encPassword', '');  // For end-to-end encryption
final key = SecureStow('key', '');
final iv = SecureStow('iv', '');
```

**User Data (PlainStow - Unencrypted):**
```dart
final pfp = PlainStow<Uint8List?>('pfp', null);  // Profile picture
final recentFiles = PlainStow('recentFiles', <String>[]);
final fileSyncAlreadyDeleted = PlainStow('fileSyncAlreadyDeleted', <String>{});
final fileSyncCorruptFiles = PlainStow('fileSyncCorruptFiles', <String>{});
```

**Login Check:**
```dart
bool get loggedIn => 
  supabaseUserId.value.isNotEmpty && 
  supabaseAccessToken.value.isNotEmpty;
```

---

### 5. **Routing** (`lib/data/routes.dart`)

**Current Routes:**
```dart
abstract class RoutePaths {
  static const home = '/home/:subpage';          // Main container
  static const browse = '/home/browse/*path';    // File browser
  static const editor = '/edit';                 // Note editor
  static const login = '/login';                 // Supabase login
}

abstract class HomeRoutes {
  static String browseFilePath(String path);     // /home/browse/folder/file
}
```

---

## 🎯 What We Need to Build for Medical Features

### Phase 1: Database Services (New)

Create `lib/data/supabase/supabase_patient_service.dart`:
```dart
class SupabasePatientService {
  // CRUD Operations
  static Future<List<Patient>> getAllPatients()
  static Future<Patient?> getPatient(String patientId)
  static Future<Patient> createPatient(PatientData data)
  static Future<void> updatePatient(String patientId, PatientData data)
  static Future<void> deletePatient(String patientId)
  
  // Search & Filter
  static Future<List<Patient>> searchPatients(String query)
  static Future<List<Patient>> getActivePatients()
}
```

Create `lib/data/supabase/supabase_document_service.dart`:
```dart
class SupabaseDocumentService {
  // Upload handwritten notes
  static Future<MedicalDocument> uploadDocument({
    required String patientId,
    required DocumentType type,
    required String localPath,
    required Uint8List screenshot,
  })
  
  // Download notes
  static Future<void> downloadDocument(String documentId, String localPath)
  
  // Sync status
  static Future<List<MedicalDocument>> getPendingUploads()
  static Future<void> markAsSynced(String documentId)
}
```

Create `lib/data/supabase/supabase_queue_service.dart`:
```dart
class SupabaseQueueService {
  // Patient Queue Management
  static Stream<List<PatientQueueItem>> watchQueue()
  static Future<void> addToQueue(PatientQueueData data)
  static Future<void> updateQueueStatus(String queueId, QueueStatus status)
  static Future<void> removeFromQueue(String queueId)
}
```

### Phase 2: Data Models (New)

Create `lib/data/models/patient.dart`:
```dart
class Patient {
  final String id;
  final String doctorId;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final String? phoneNumber;
  final String? email;
  final Map<String, dynamic>? medicalHistory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  
  factory Patient.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

Create `lib/data/models/medical_document.dart`:
```dart
enum DocumentType {
  examinationReport,
  prescription,
  sessionNote,
}

class MedicalDocument {
  final String id;
  final String patientId;
  final String doctorId;
  final DocumentType documentType;
  
  // File paths
  final String handwrittenFilePath;  // Supabase Storage URL
  final String screenshotPath;       // Supabase Storage URL
  final String? localPath;           // Local file system path
  
  // AI Processing
  final bool aiProcessed;
  final AIProcessingStatus aiProcessingStatus;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  
  factory MedicalDocument.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

enum AIProcessingStatus {
  pending,
  processing,
  completed,
  failed,
}
```

Create `lib/data/models/structured_record.dart`:
```dart
class StructuredMedicalRecord {
  final String id;
  final String documentId;
  final String patientId;
  
  // AI-extracted data
  final String? extractedText;       // Full OCR
  final Map<String, dynamic> structuredData;  // Parsed JSON
  final double? confidenceScore;     // 0-1
  
  // Doctor review
  final bool reviewedByDoctor;
  final Map<String, dynamic>? doctorCorrections;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  factory StructuredMedicalRecord.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### Phase 3: Enhanced File Manager (Modify Existing)

**New Methods to Add:**
```dart
class FileManager {
  // Patient-specific paths
  static String getPatientDirectory(String patientId) {
    return '/patients/$patientId/';
  }
  
  static String getDocumentDirectory(String patientId, DocumentType type) {
    final typeFolder = switch (type) {
      DocumentType.examinationReport => 'examination_reports',
      DocumentType.prescription => 'prescriptions',
      DocumentType.sessionNote => 'session_notes',
    };
    return '/patients/$patientId/$typeFolder/';
  }
  
  // Screenshot generation
  static Future<Uint8List> generateScreenshot(String filePath) async {
    final coreInfo = EditorCoreInfo(filePath: filePath);
    await coreInfo.loadFromFilePath();
    
    final screenshotController = ScreenshotController();
    return await EditorExporter.screenshotPage(
      coreInfo: coreInfo,
      pageIndex: 0,  // Can loop through all pages if needed
      screenshotController: screenshotController,
      context: context,  // Need to pass context
    );
  }
  
  // Metadata JSON
  static Future<void> saveMetadata(String filePath, Map<String, dynamic> metadata) {
    final metadataPath = '$filePath.metadata.json';
    return writeFile(metadataPath, utf8.encode(jsonEncode(metadata)));
  }
  
  static Future<Map<String, dynamic>?> loadMetadata(String filePath) async {
    final metadataPath = '$filePath.metadata.json';
    final bytes = await readFile(metadataPath);
    if (bytes == null) return null;
    return jsonDecode(utf8.decode(bytes));
  }
}
```

### Phase 4: Sync Service (New)

Create `lib/data/supabase/supabase_sync_service.dart`:
```dart
class SupabaseSyncService {
  static final uploadQueue = Queue<PendingUpload>();
  static final downloadQueue = Queue<PendingDownload>();
  
  // Upload Management
  static Future<void> enqueueUpload(PendingUpload upload)
  static Future<void> processUploadQueue()
  static Stream<UploadProgress> watchUploadProgress()
  
  // Download Management
  static Future<void> syncFromCloud()
  static Future<void> downloadDocument(String documentId)
  
  // Conflict Resolution
  static Future<ConflictResolution> handleConflict(LocalFile local, RemoteFile remote)
}

class PendingUpload {
  final String localPath;
  final String patientId;
  final DocumentType documentType;
  final DateTime queuedAt;
  UploadStatus status;
}

class UploadProgress {
  final String localPath;
  final double progress;  // 0.0 to 1.0
  final UploadStatus status;
}

enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
}
```

---

## 📐 File System Architecture Change

### Current Structure:
```
Documents/Saber/
├── mynote.sbn2
├── folder/
│   └── anothernote.sbn2
└── whiteboard.sbn2
```

### New Structure (Patient-Centric):
```
Documents/SynapseAI/
├── patients/
│   ├── {patient-uuid-1}/
│   │   ├── examination_reports/
│   │   │   ├── 2025-12-11_morning-checkup.sbn2
│   │   │   ├── 2025-12-11_morning-checkup.png
│   │   │   └── 2025-12-11_morning-checkup.metadata.json
│   │   ├── prescriptions/
│   │   │   ├── 2025-12-11_medications.sbn2
│   │   │   ├── 2025-12-11_medications.png
│   │   │   └── 2025-12-11_medications.metadata.json
│   │   └── session_notes/
│   │       ├── 2025-12-10_therapy-session.sbn2
│   │       ├── 2025-12-10_therapy-session.png
│   │       └── 2025-12-10_therapy-session.metadata.json
│   └── {patient-uuid-2}/
│       └── ...
└── temp/                           # For whiteboard/scratch notes
```

### Metadata JSON Structure:
```json
{
  "documentId": "uuid-from-supabase",
  "patientId": "patient-uuid",
  "patientName": "John Doe",
  "documentType": "examination_report",
  "createdAt": "2025-12-11T10:30:00Z",
  "lastSyncedAt": "2025-12-11T10:31:00Z",
  "aiProcessed": false,
  "localPath": "/patients/uuid/examination_reports/2025-12-11_morning-checkup.sbn2",
  "cloudPath": "patients/uuid/examination_reports/2025-12-11_morning-checkup.sbn2"
}
```

---

## 🔄 Data Flow for Document Creation

### Complete Workflow:
```
1. Doctor opens Patient Profile
   → Taps "New Examination Report"
   
2. App shows Document Type Selector
   → Doctor confirms type
   
3. Navigate to Editor
   → URL: /edit?patient_id={uuid}&type=examination_report
   → Editor loads with patient context in header
   
4. Doctor writes with stylus
   → Autosaves to local file every 10 seconds
   → Path: /patients/{uuid}/examination_reports/{timestamp}_untitled.sbn2
   
5. Doctor taps "Save & Process"
   → Show loading dialog
   
6. FileManager.generateScreenshot()
   → Create PNG from all pages
   → Save as {filename}.png
   
7. FileManager.saveMetadata()
   → Create {filename}.metadata.json
   
8. SupabaseSyncService.enqueueUpload()
   → Add to upload queue
   → If online: start upload immediately
   → If offline: queue for later
   
9. Upload Process (if online):
   a. Upload .sbn2 to Supabase Storage
   b. Upload .png to Supabase Storage
   c. Insert record into medical_documents table
   d. Trigger Edge Function for AI processing
   e. Update metadata.json with cloudPath and documentId
   
10. AI Processing (Async):
    a. Edge Function downloads .png
    b. Sends to OpenAI Vision API
    c. Parses response into structured JSON
    d. Inserts into structured_medical_records table
    d. Updates medical_documents.ai_processing_status = 'completed'
    
11. Push Notification (Optional):
    → "Document processed! Tap to review"
    
12. Doctor opens Review Page
    → Split screen: Original (left) | AI Extract (right)
    → Doctor corrects any mistakes
    → Saves corrections to structured_medical_records.doctor_corrections
```

---

## 🔐 Security Considerations

### Row Level Security (RLS) Policies

**Already Implemented:**
- ✅ Supabase Auth with PKCE
- ✅ Secure token storage (`SecureStow`)
- ✅ Session restoration

**To Implement:**
```sql
-- Doctors can only see their own patients
CREATE POLICY "Doctors can view their own patients"
  ON patients FOR SELECT
  USING (auth.uid() = doctor_id);

-- Doctors can only see documents for their patients
CREATE POLICY "Doctors can view their own documents"
  ON medical_documents FOR SELECT
  USING (
    doctor_id = auth.uid() OR
    patient_id IN (SELECT id FROM patients WHERE doctor_id = auth.uid())
  );
```

### Data Encryption

**Current:**
- ✅ Transport: TLS (Supabase default)
- ✅ At Rest: Supabase database encryption
- ✅ Credentials: SecureStow (platform keychain)

**To Consider:**
- Local file encryption (optional for extra security)
- End-to-end encryption for cloud files (like old Nextcloud)
- HIPAA-compliant logging

---

## 🚀 Implementation Priority

### Phase 1: Foundation (Week 1)
1. Create data models (`Patient`, `MedicalDocument`, `StructuredRecord`)
2. Create database services (`SupabasePatientService`, etc.)
3. Set up database schema in Supabase
4. Test CRUD operations with mock data

### Phase 2: File System (Week 2)
1. Modify `FileManager` to support patient directories
2. Implement screenshot generation helper
3. Implement metadata JSON helpers
4. Migrate existing files to new structure (if any)

### Phase 3: Editor Integration (Week 3)
1. Pass patient context to Editor via route params
2. Show patient info in Editor header
3. Implement "Save & Process" button
4. Hook up screenshot generation on save

### Phase 4: Sync (Week 4)
1. Implement upload queue
2. Implement Supabase Storage upload
3. Implement download sync
4. Handle offline/online transitions

### Phase 5: AI Pipeline (Week 5-6)
1. Create Supabase Edge Function
2. Integrate OpenAI Vision API
3. Implement processing status tracking
4. Build review UI

---

## 📝 Notes

### Strengths of Current Architecture
- ✅ Clean separation of concerns
- ✅ Robust local file management
- ✅ Stream-based file watching
- ✅ Secure authentication
- ✅ Screenshot export capability already exists

### Gaps to Fill
- ❌ No patient data model
- ❌ No cloud storage integration
- ❌ No queue management for uploads
- ❌ No conflict resolution
- ❌ Editor doesn't support patient context

### Key Dependencies
- `supabase_flutter`: ^2.x (already installed)
- `screenshot`: ^3.x (already used in exporter)
- OpenAI API or Anthropic API (for AI processing)
- Background task scheduling (for sync)

---

**End of Backend Structure Analysis**
