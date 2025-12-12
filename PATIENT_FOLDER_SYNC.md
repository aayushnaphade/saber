# Patient Folder Structure & Sync Implementation

## Overview
This document describes the patient-centric file organization system that replaces the generic file browser in SynapseAI. Each patient has their own folder containing categorized medical documents, with seamless Supabase synchronization.

## Folder Structure

### Local File System
```
Documents/Saber/
└── patients/
    ├── {patient_id_1}/
    │   ├── examination_reports/
    │   │   ├── report_2024_01_15.sbn
    │   │   └── xray_results.sbn
    │   ├── prescriptions/
    │   │   ├── prescription_2024_01_15.sbn
    │   │   └── medication_plan.sbn
    │   └── session_notes/
    │       ├── consultation_notes.sbn
    │       └── treatment_summary.sbn
    └── {patient_id_2}/
        ├── examination_reports/
        ├── prescriptions/
        └── session_notes/
```

### Supabase Storage
```
medical_notes/ (bucket)
├── {doctor_id}/
    ├── {patient_id_1}/
    │   ├── examination_reports/
    │   ├── prescriptions/
    │   └── session_notes/
    └── {patient_id_2}/
        ├── examination_reports/
        ├── prescriptions/
        └── session_notes/
```

## Database Schema

### patients Table
```sql
CREATE TABLE patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  full_name TEXT NOT NULL,
  age INTEGER,
  gender TEXT,
  phone_number TEXT,
  status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'in_consultation', 'completed')),
  last_visit TIMESTAMPTZ,
  doctor_id UUID NOT NULL REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT true
);

-- RLS Policies
-- 1. Doctors can view their own patients
-- 2. Doctors can insert patients
-- 3. Doctors can update their own patients
```

### medical_records Table
```sql
CREATE TABLE medical_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES auth.users(id),
  raw_note_url TEXT,
  ai_summary JSONB,
  transcription TEXT
);

-- RLS Policies
-- 1. Doctors can view records for their patients
-- 2. Doctors can insert records
```

## Implementation Components

### 1. Patient Model (`lib/data/models/patient.dart`)
```dart
class Patient {
  final String id;
  final DateTime createdAt;
  final String fullName;
  final int? age;
  final String? gender;
  final String? phoneNumber;
  final PatientStatus status;
  final DateTime? lastVisit;
  final String doctorId;
  final bool isActive;
}

enum PatientStatus { waiting, inConsultation, completed }
enum DocumentType { examinationReport, prescription, sessionNote }
```

**Helper Methods:**
- `localFolderPath`: Returns local folder path for patient
- `documentFolderPath(DocumentType)`: Returns folder path for document type
- `supabaseFolderPath`: Returns Supabase storage path

### 2. Patient Service (`lib/data/supabase/supabase_patient_service.dart`)

#### CRUD Operations
- `getAllPatients()` - Get all patients for logged-in doctor
- `getActivePatients()` - Get only active patients
- `getWaitingPatients()` - Get patients in waiting queue
- `getPatient(id)` - Get specific patient
- `searchPatients(query)` - Search by name
- `createPatient(...)` - Create new patient with folder structure
- `updatePatient(...)` - Update patient details
- `updatePatientStatus(...)` - Change patient status
- `deactivatePatient(id)` - Soft delete patient
- `deletePatient(id)` - Hard delete patient

#### Real-time Streams
- `watchPatients()` - Stream of all active patients
- `watchWaitingQueue()` - Stream of waiting patients

### 3. Patient Browse Page (`lib/pages/home/patient_browse.dart`)

**Features:**
- Patient list view with cards showing name, age, gender, status
- Patient detail view with document type folders
- Create new patient with dialog form
- Auto-creates folder structure for new patients
- Real-time updates via Supabase streams
- Navigation to patient details and document folders

**Routes:**
- `/home/patients` - Patient list
- `/home/patients/:patientId` - Patient detail
- `/home/patients/:patientId/:documentType` - Document folder

## Sync Strategy

### Current Implementation
1. **Folder Creation**: When a patient is created, local folder structure is automatically generated
2. **Database Sync**: Patient metadata syncs with Supabase `patients` table
3. **Real-time Updates**: Patient list updates automatically via Supabase real-time subscriptions

### Future Enhancements (TODO)

#### 1. Document Upload Sync
```dart
// Pseudocode
Future<void> uploadDocument(Patient patient, DocumentType type, File file) async {
  // 1. Save locally
  final localPath = patient.documentFolderPath(type);
  await FileManager.saveFile(localPath, file);
  
  // 2. Upload to Supabase Storage
  final supabasePath = '${patient.supabaseFolderPath}/${type.folderName}/${file.name}';
  await supabase.storage.from('medical_notes').upload(supabasePath, file);
  
  // 3. Create medical record entry
  await supabase.from('medical_records').insert({
    'patient_id': patient.id,
    'doctor_id': patient.doctorId,
    'raw_note_url': supabasePath,
  });
}
```

#### 2. Document Download Sync
```dart
// Pseudocode
Future<void> syncDocumentsFromSupabase(Patient patient) async {
  // 1. List files from Supabase Storage
  final files = await supabase.storage
    .from('medical_notes')
    .list(patient.supabaseFolderPath);
  
  // 2. Download missing files
  for (final file in files) {
    final localPath = getLocalPathFromSupabasePath(file.name);
    if (!await FileManager.exists(localPath)) {
      final bytes = await supabase.storage
        .from('medical_notes')
        .download(file.name);
      await FileManager.writeBytes(localPath, bytes);
    }
  }
}
```

#### 3. Conflict Resolution
- Last-write-wins strategy
- Timestamp comparison (local modified vs remote modified)
- Option to keep both versions with conflict markers

#### 4. Offline Support
- Queue operations when offline
- Sync when connection restored
- Use `workmanager` for background sync

## Usage Example

```dart
// Create a new patient
final patient = await SupabasePatientService.createPatient(
  fullName: 'John Doe',
  age: 45,
  gender: 'Male',
  phoneNumber: '+1234567890',
);

// Folder structure is automatically created:
// Documents/Saber/patients/{patient.id}/examination_reports/
// Documents/Saber/patients/{patient.id}/prescriptions/
// Documents/Saber/patients/{patient.id}/session_notes/

// Watch for patient updates
SupabasePatientService.watchPatients().listen((patients) {
  print('Patient list updated: ${patients.length} patients');
});

// Update patient status
await SupabasePatientService.updatePatientStatus(
  patient.id,
  PatientStatus.inConsultation,
);
```

## Navigation Flow

1. **Home > Browse Tab** → Shows patient list
2. **Click Patient** → Shows patient details with document type folders
3. **Click Document Type** → Shows documents in that category
4. **Click Document** → Opens editor with note

## Security

### RLS Policies
- Doctors can only see their own patients
- Patient data is scoped by `doctor_id`
- Storage bucket requires authenticated access
- Upload/view policies check doctor ownership

### Data Privacy
- Patient folders are isolated by ID
- No cross-doctor access
- Soft delete preserves audit trail
- Hard delete removes all data

## Benefits

1. **Organization**: Clear folder structure for each patient
2. **Scalability**: Each patient has isolated storage
3. **Offline-first**: Local folders work without internet
4. **Real-time**: Instant updates across devices
5. **Type-safety**: Strongly typed models and enums
6. **Searchable**: Full-text search on patient names
7. **Status Tracking**: Patient queue management

## Next Steps

1. ✅ Patient model and service
2. ✅ Patient browse UI
3. ✅ Folder structure creation
4. ✅ Real-time updates
5. ⏳ Document upload sync
6. ⏳ Document download sync
7. ⏳ Conflict resolution
8. ⏳ Offline queue management
9. ⏳ Background sync service
10. ⏳ AI summary integration
