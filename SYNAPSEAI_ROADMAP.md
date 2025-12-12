# SynapseAI - Medical Documentation Platform Roadmap

**Last Updated:** December 11, 2025  
**Project Status:** Foundation Phase - UI Development  
**Original Base:** Saber (Open-source note-taking app)

---

## 🎯 Vision

Transform a note-taking app into an intelligent medical documentation platform where doctors can handwrite patient notes, prescriptions, and examination reports on a tablet. AI processes the handwriting to create structured digital records while maintaining the original handwritten documents.

---

## 📊 Current State (As of Dec 11, 2025)

### ✅ Completed Features

1. **Authentication System**
   - Supabase Auth integration (Email/Password + OTP)
   - 8-digit OTP verification support
   - Session management with auto-restore
   - Logout functionality with confirmation
   - Responsive login UI (portrait/landscape)

2. **Branding & Home Screen**
   - Renamed to "SynapseAI"
   - Time-based greetings (Morning/Afternoon/Evening)
   - Custom medical-themed illustrations
   - User profile widget in settings

3. **Core Editor (Inherited from Saber)**
   - ✅ Handwriting canvas with stylus support
   - ✅ Multiple tools: Pen, Pencil, Highlighter, Eraser, Shape Pen, Laser Pointer, Select
   - ✅ Multi-page documents
   - ✅ PDF import/annotation
   - ✅ Image insertion
   - ✅ Export to PDF/PNG
   - ✅ File format: `.sbn2` (BSON-based)
   - ✅ Screenshot/export capability via `EditorExporter`

4. **Local File System**
   - Files stored in `Documents/Saber/`
   - Folder-based organization
   - Asset caching for images
   - File browser (currently generic, will be replaced)

### 🚧 In Progress

1. **Nextcloud Removal** (Current Task)
   - Cleaning up legacy sync code
   - Removing unused components
   - Preparing for Supabase-based sync

### ❌ Not Yet Implemented

1. **Patient Management** (Priority 1 - Next)
2. **Document Categorization** (Priority 2)
3. **AI Processing Pipeline** (Priority 3)
4. **Supabase Sync** (Priority 4)
5. **Digital Record Review** (Priority 5)

---

## 🏗️ Architecture Design

### Data Model

#### Patient-Centric Organization

```
Supabase Storage Structure:
├── patients/
│   ├── {patient_id}/
│   │   ├── examination_reports/
│   │   │   ├── {timestamp}_{report_id}.sbn2    (Original handwritten file)
│   │   │   ├── {timestamp}_{report_id}.png      (Screenshot for AI)
│   │   │   └── {timestamp}_{report_id}_metadata.json
│   │   ├── prescriptions/
│   │   │   ├── {timestamp}_{prescription_id}.sbn2
│   │   │   ├── {timestamp}_{prescription_id}.png
│   │   │   └── {timestamp}_{prescription_id}_metadata.json
│   │   └── session_notes/
│   │       ├── {timestamp}_{session_id}.sbn2
│   │       ├── {timestamp}_{session_id}.png
│   │       └── {timestamp}_{session_id}_metadata.json
```

#### Local File System (Mirrors Supabase)

```
Documents/SynapseAI/
├── patients/
│   ├── {patient_id}/
│   │   ├── examination_reports/
│   │   ├── prescriptions/
│   │   └── session_notes/
```

### Database Schema (Supabase PostgreSQL)

#### Table: `patients`
```sql
CREATE TABLE patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doctor_id UUID REFERENCES auth.users(id) NOT NULL,
  patient_name TEXT NOT NULL,
  patient_age INTEGER,
  patient_gender TEXT,
  phone_number TEXT,
  email TEXT,
  medical_history JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);

-- RLS Policies
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctors can view their own patients"
  ON patients FOR SELECT
  USING (auth.uid() = doctor_id);

CREATE POLICY "Doctors can create patients"
  ON patients FOR INSERT
  WITH CHECK (auth.uid() = doctor_id);

CREATE POLICY "Doctors can update their own patients"
  ON patients FOR UPDATE
  USING (auth.uid() = doctor_id);
```

#### Table: `medical_documents`
```sql
CREATE TABLE medical_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES auth.users(id) NOT NULL,
  document_type TEXT NOT NULL CHECK (document_type IN ('examination_report', 'prescription', 'session_note')),
  
  -- File references
  handwritten_file_path TEXT NOT NULL,  -- Supabase Storage path to .sbn2
  screenshot_path TEXT NOT NULL,         -- Supabase Storage path to .png
  
  -- AI Processing
  ai_processed BOOLEAN DEFAULT FALSE,
  ai_processing_status TEXT DEFAULT 'pending' CHECK (ai_processing_status IN ('pending', 'processing', 'completed', 'failed')),
  
  -- Document metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Sync status
  local_path TEXT,                       -- Local file system path
  last_synced_at TIMESTAMP WITH TIME ZONE
);

-- RLS Policies
ALTER TABLE medical_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctors can view their own documents"
  ON medical_documents FOR SELECT
  USING (auth.uid() = doctor_id);

CREATE POLICY "Doctors can create documents"
  ON medical_documents FOR INSERT
  WITH CHECK (auth.uid() = doctor_id);
```

#### Table: `structured_medical_records`
```sql
CREATE TABLE structured_medical_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id UUID REFERENCES medical_documents(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES auth.users(id) NOT NULL,
  
  -- AI-extracted structured data
  extracted_text TEXT,                   -- Full OCR text
  structured_data JSONB NOT NULL,        -- Parsed medical data
  
  -- Document-specific fields
  -- For Examination Reports:
  --   { "chief_complaint": "...", "diagnosis": "...", "vital_signs": {...}, "observations": "..." }
  -- For Prescriptions:
  --   { "medications": [{name, dosage, frequency, duration}], "instructions": "..." }
  -- For Session Notes:
  --   { "session_summary": "...", "treatment_plan": "...", "next_steps": "..." }
  
  confidence_score FLOAT,                -- AI confidence (0-1)
  reviewed_by_doctor BOOLEAN DEFAULT FALSE,
  doctor_corrections JSONB,              -- Manual edits by doctor
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE structured_medical_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctors can view their own records"
  ON structured_medical_records FOR SELECT
  USING (auth.uid() = doctor_id);
```

#### Table: `patient_queue` (Reception Feature)
```sql
CREATE TABLE patient_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID REFERENCES patients(id),
  doctor_id UUID REFERENCES auth.users(id) NOT NULL,
  
  queue_status TEXT DEFAULT 'waiting' CHECK (queue_status IN ('waiting', 'in_session', 'completed', 'cancelled')),
  appointment_time TIMESTAMP WITH TIME ZONE,
  arrival_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  priority INTEGER DEFAULT 0,
  notes TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE patient_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctors can view their queue"
  ON patient_queue FOR SELECT
  USING (auth.uid() = doctor_id);
```

---

## 🎨 UI/UX Pages & User Flow

### Phase 1: Dashboard & Patient Management (Current Focus)

#### 1. **Dashboard (Home Page Replacement)**
**Route:** `/home/dashboard`  
**Purpose:** Doctor's command center  

**Components:**
- **Patient Queue Card**
  - Shows patients waiting (fetched from `patient_queue` table)
  - Quick stats: Total waiting, Average wait time
  - "Start Session" button for next patient
  
- **Today's Schedule**
  - Upcoming appointments
  - Completed sessions count
  
- **Quick Actions**
  - "New Patient Registration"
  - "Search Patient"
  - "View All Patients"

- **Recent Activity Feed**
  - Last 5 documents created
  - Recently updated patient records

**Design Notes:**
- Use Material 3 cards with elevation
- Medical color scheme (blues, greens, white)
- Large touch targets for tablet use

#### 2. **Patient List Page**
**Route:** `/patients`  
**Purpose:** Browse all patients  

**Features:**
- Search bar (by name, phone, ID)
- Filter: Active/Inactive, Recent activity
- Sort: Alphabetical, Last visit, Created date
- List/Grid view toggle
- Each patient card shows:
  - Name, Age, Gender
  - Last visit date
  - Number of documents
  - Quick action: "New Session"

#### 3. **Patient Profile Page**
**Route:** `/patients/{patient_id}`  
**Purpose:** Patient's complete medical history  

**Sections:**
- **Header**
  - Patient info (Name, Age, Gender, Contact)
  - Edit button
  - Medical history summary
  
- **Document Tabs**
  - Examination Reports (count badge)
  - Prescriptions (count badge)
  - Session Notes (count badge)
  
- **Timeline View**
  - Chronological list of all documents
  - Thumbnail preview
  - Date, Type, Status (AI processed?)
  
- **Actions**
  - "New Examination Report"
  - "New Prescription"
  - "New Session Note"

### Phase 2: Document Creation Flow

#### 4. **Document Type Selector**
**Modal/Bottom Sheet**  
**Triggered from:** Patient Profile or Dashboard  

**Options:**
- 📋 Examination Report
- 💊 Prescription
- 📝 Session Note

**Each option shows:**
- Icon
- Description
- Template preview (optional)

#### 5. **Editor Page (Enhanced)**
**Route:** `/editor?patient_id={id}&type={type}`  
**Purpose:** Handwriting canvas with patient context  

**Enhancements Needed:**
- **Top Bar Changes:**
  - Patient name badge (constant reminder)
  - Document type badge (Exam/Prescription/Session)
  - "Save & Process" button (replaces generic save)
  
- **Bottom Bar Addition:**
  - "Quick Notes" text field (for typed annotations)
  - Voice memo button (future feature)

**Save Flow:**
1. User taps "Save & Process"
2. Show loading dialog: "Saving document..."
3. Steps:
   - Save `.sbn2` file locally
   - Generate PNG screenshot via `EditorExporter.screenshotPage()`
   - Create metadata JSON
   - Queue for upload (if online)
   - Show success: "Document saved. AI processing will begin shortly."

### Phase 3: AI Processing & Review

#### 6. **Processing Status Page**
**Route:** `/documents/{document_id}/processing`  
**Purpose:** Show AI analysis progress  

**States:**
- **Pending:** "Waiting in queue..."
- **Processing:** Animated progress indicator
- **Completed:** "AI analysis complete. Tap to review."
- **Failed:** Error message with retry button

#### 7. **Document Review Page (Split Screen)**
**Route:** `/documents/{document_id}/review`  
**Purpose:** Verify and correct AI output  

**Layout:**
```
┌─────────────────────────────────────┐
│  Patient: John Doe | Exam Report    │
├──────────────────┬──────────────────┤
│                  │                  │
│  📄 Original     │  🤖 AI Extract   │
│  Handwritten     │                  │
│  Document        │  Editable Form   │
│  (Image View)    │                  │
│                  │  - Chief         │
│  Zoom controls   │    Complaint     │
│  Pan/pinch       │  - Diagnosis     │
│                  │  - Medications   │
│                  │  - Notes         │
│                  │                  │
│                  │  [Save] [Reject] │
└──────────────────┴──────────────────┘
```

**Features:**
- Side-by-side comparison
- Editable fields on right
- Confidence score indicator
- "Approve All" or "Reject & Reprocess"

---

## 🔄 Sync Infrastructure (To Be Implemented)

### Hybrid Sync Strategy

**Goal:** Offline-first with cloud backup

#### Local → Cloud Upload Flow
```dart
class SupabaseSyncService {
  // 1. Monitor local file changes
  Future<void> watchLocalChanges() async {
    FileManager.fileWriteStream.listen((FileOperation op) {
      if (shouldSync(op.filePath)) {
        enqueueUpload(op.filePath);
      }
    });
  }
  
  // 2. Upload queue management
  final uploadQueue = Queue<SyncFile>();
  
  Future<void> enqueueUpload(String localPath) async {
    final syncFile = SyncFile(
      localPath: localPath,
      patientId: extractPatientId(localPath),
      documentType: extractDocumentType(localPath),
    );
    
    uploadQueue.add(syncFile);
    processQueue();
  }
  
  // 3. Actual upload
  Future<void> uploadDocument(SyncFile file) async {
    // Upload .sbn2 to Supabase Storage
    final sbn2Path = await _uploadToStorage(file.localPath);
    
    // Upload .png screenshot
    final pngPath = await _uploadScreenshot(file.localPath);
    
    // Create database record
    await supabase.from('medical_documents').insert({
      'patient_id': file.patientId,
      'doctor_id': currentUserId,
      'document_type': file.documentType,
      'handwritten_file_path': sbn2Path,
      'screenshot_path': pngPath,
      'local_path': file.localPath,
      'last_synced_at': DateTime.now().toIso8601String(),
    });
    
    // Trigger AI processing (via Edge Function)
    await _triggerAIProcessing(pngPath);
  }
}
```

#### Cloud → Local Download Flow
```dart
class SupabaseDownloader {
  // Pull changes from other devices
  Future<void> syncFromCloud() async {
    final lastSync = await getLastSyncTimestamp();
    
    // Fetch new/updated documents
    final docs = await supabase
      .from('medical_documents')
      .select()
      .gte('updated_at', lastSync)
      .eq('doctor_id', currentUserId);
    
    for (final doc in docs) {
      // Download .sbn2 file
      await downloadFromStorage(
        doc['handwritten_file_path'],
        doc['local_path'],
      );
      
      // Update local metadata
      await updateLocalMetadata(doc);
    }
  }
}
```

### Edge Function: AI Processing

**File:** `supabase/functions/process-medical-document/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import OpenAI from 'https://esm.sh/openai@4'

serve(async (req) => {
  const { screenshotPath, documentId, documentType } = await req.json()
  
  // 1. Download image from Storage
  const supabase = createClient(...)
  const { data: imageBlob } = await supabase.storage
    .from('medical-documents')
    .download(screenshotPath)
  
  // 2. Send to Vision Model (GPT-4o or Claude 3.5 Sonnet)
  const openai = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY') })
  
  const prompt = getPromptForDocumentType(documentType)
  // For examination_report: Extract chief complaint, diagnosis, vital signs...
  // For prescription: Extract medications, dosage, frequency, duration...
  // For session_note: Extract session summary, treatment plan...
  
  const response = await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [
      {
        role: "system",
        content: prompt
      },
      {
        role: "user",
        content: [
          { type: "text", text: "Extract medical information from this handwritten document:" },
          { type: "image_url", image_url: { url: imageToBase64(imageBlob) } }
        ]
      }
    ],
    response_format: { type: "json_object" }
  })
  
  const structuredData = JSON.parse(response.choices[0].message.content)
  
  // 3. Save to database
  await supabase.from('structured_medical_records').insert({
    document_id: documentId,
    patient_id: extractPatientId(documentId),
    extracted_text: structuredData.raw_text,
    structured_data: structuredData,
    confidence_score: structuredData.confidence,
  })
  
  // 4. Update document status
  await supabase.from('medical_documents')
    .update({ 
      ai_processed: true, 
      ai_processing_status: 'completed' 
    })
    .eq('id', documentId)
  
  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  })
})
```

---

## 🚀 Implementation Phases

### Phase 1: Foundation & UI (Current - Week 1)
**Goal:** Build the dashboard and patient management UI

- [ ] Clean up Nextcloud legacy code
- [ ] Create Dashboard page replacing old Home
- [ ] Create Patient List page
- [ ] Create Patient Profile page
- [ ] Create Document Type Selector
- [ ] Design document cards/previews

**No backend work yet - use mock data for UI**

### Phase 2: Database Setup (Week 2)
**Goal:** Supabase schema and basic CRUD

- [ ] Create all database tables
- [ ] Set up RLS policies
- [ ] Create Dart models matching schema
- [ ] Build `SupabasePatientService`
- [ ] Build `SupabaseDocumentService`
- [ ] Test with real data

### Phase 3: Editor Integration (Week 3)
**Goal:** Connect editor to patient context

- [ ] Enhance editor with patient context
- [ ] Implement "Save & Process" flow
- [ ] Generate PNG screenshots on save
- [ ] Save to patient-specific folders
- [ ] Create metadata JSON files

### Phase 4: Sync Infrastructure (Week 4)
**Goal:** Bidirectional sync without AI

- [ ] Build `SupabaseSyncService`
- [ ] Implement upload queue
- [ ] Implement download sync
- [ ] Handle conflicts
- [ ] Sync status indicators in UI

### Phase 5: AI Pipeline (Week 5-6)
**Goal:** Automated document processing

- [ ] Create Supabase Edge Function
- [ ] Integrate OpenAI Vision API
- [ ] Create document-specific prompts
- [ ] Build processing status page
- [ ] Build review/correction page

### Phase 6: Polish & Testing (Week 7)
**Goal:** Production ready

- [ ] Error handling
- [ ] Offline mode
- [ ] Performance optimization
- [ ] Security audit
- [ ] User testing with real doctors

---

## 🎨 Design System

### Color Palette
```dart
// Primary: Medical Blue
Color primaryBlue = Color(0xFF2196F3);
Color primaryBlueDark = Color(0xFF1976D2);
Color primaryBlueLight = Color(0xFFBBDEFB);

// Secondary: Healing Green
Color secondaryGreen = Color(0xFF4CAF50);
Color secondaryGreenDark = Color(0xFF388E3C);

// Accent: Warm Amber (for alerts/warnings)
Color accentAmber = Color(0xFFFFC107);

// Error: Medical Red
Color errorRed = Color(0xFFF44336);

// Background
Color backgroundLight = Color(0xFFFAFAFA);
Color backgroundWhite = Color(0xFFFFFFFF);
Color cardSurface = Color(0xFFFFFFFF);

// Text
Color textPrimary = Color(0xFF212121);
Color textSecondary = Color(0xFF757575);
Color textDisabled = Color(0xFFBDBDBD);
```

### Typography
- **Headlines:** Roboto Bold (24-32pt)
- **Body:** Roboto Regular (16pt)
- **Captions:** Roboto Light (12-14pt)
- **Patient Names:** Roboto Medium (18pt) - for emphasis

### Iconography
- Medical icons from Material Icons
- Custom icons for document types
- Consistent 24x24dp size for actions

---

## 🔒 Security Considerations

1. **HIPAA Compliance**
   - All data encrypted at rest (Supabase default)
   - TLS for all network requests
   - Row Level Security for patient data
   - Audit logs for document access

2. **Authentication**
   - Email verification mandatory
   - Strong password requirements
   - Session timeout after 24 hours
   - Logout on app close (optional setting)

3. **Data Privacy**
   - Patients only accessible by their doctor
   - No cross-doctor data sharing
   - AI processing in secure Edge Functions
   - Option to disable cloud sync (local-only mode)

---

## 📝 Notes & Decisions

### Why Patient-Centric Folders?
- Matches doctor's mental model
- Easy to find all documents for one patient
- Natural organization for AI training later
- Simplifies backup/export per patient

### Why Three Document Types?
- **Examination Reports:** Initial diagnosis, physical exams
- **Prescriptions:** Medication records (legal requirement)
- **Session Notes:** Follow-ups, therapy notes, progress tracking

### Why Hybrid Sync?
- **Offline-first:** Clinics may have poor connectivity
- **Local speed:** No lag when opening documents
- **Cloud backup:** Device loss protection
- **Multi-device:** Doctor can use multiple tablets

### Why Screenshot + Original File?
- **Screenshot (.png):** For AI vision models (universal format)
- **Original (.sbn2):** For re-editing with full fidelity (strokes, layers)

---

## 🐛 Known Issues & Tech Debt

1. **Current:**
   - Nextcloud code partially removed but imports still exist
   - Old file browser still shows generic files
   - No patient concept in current UI

2. **Future:**
   - Need to handle very large documents (100+ pages)
   - AI cost management (Vision API is expensive)
   - Conflict resolution for offline edits
   - Backup/restore for local-only users

---

## 📚 References

- **Saber Original Repo:** https://github.com/saber-notes/saber
- **Supabase Docs:** https://supabase.com/docs
- **OpenAI Vision API:** https://platform.openai.com/docs/guides/vision
- **Flutter Medical Apps:** https://pub.dev/packages?q=medical

---

## 🤝 Development Team Notes

**Current Developer:** Working through UI first, then backend integration  
**Approach:** Incremental development, test each phase thoroughly  
**Testing Device:** Tablet (touch + stylus)  
**Target Users:** Mental health professionals (psychiatrists, psychologists, therapists)

**Communication Style:** Detailed documentation before coding, ask questions when unclear, prioritize user experience over technical complexity.

---

**End of Roadmap**  
*This document will be updated as the project evolves.*
