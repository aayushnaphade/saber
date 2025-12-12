# Document Sync Implementation

## Overview
Implemented automatic document synchronization between local storage and Supabase Storage bucket for patient medical records. This enables secure cloud backup and multi-device access for SynapseAI patient documentation.

## Implementation Components

### 1. DocumentSyncService (`lib/data/supabase/document_sync_service.dart`)

A comprehensive service for managing document sync operations with Supabase Storage.

**Key Features:**
- Automatic upload of patient documents to cloud storage
- Download documents from cloud to local device
- Handles both `.sbn2` note files and `.sba` asset folders
- Patient-specific folder structure: `{doctor_id}/{patient_id}/{document_type}/{session}/`
- Error handling and logging for all operations

**Main Methods:**
- `uploadDocument(String localPath)` - Upload a single document file
- `downloadDocument(String cloudPath, String localPath)` - Download a document
- `syncPatientDocuments(String patientId)` - Sync all documents for a patient
- `deleteDocument(String cloudPath)` - Delete a document from cloud
- `queueUpload(String localPath)` - Queue a file for background upload

**File Structure in Storage:**
```
medical_notes/
└── {doctor_id}/
    └── {patient_id}/
        ├── session_notes/
        │   └── session_1/
        │       ├── notes.sbn2
        │       └── notes.sba/  (asset folder)
        │           ├── image_1.png
        │           └── image_2.jpg
        ├── examination_reports/
        ├── prescriptions/
        └── session_notes/
```

### 2. FileManager Integration (`lib/data/file_manager/file_manager.dart`)

Integrated DocumentSyncService with FileManager's `writeFile()` method to automatically sync documents when saved.

**Changes:**
- Added import for `DocumentSyncService`
- Modified `afterWrite()` callback to queue uploads for patient documents
- Automatic sync triggered when saving files in `/patients/` directory

**Code Flow:**
```dart
FileManager.writeFile() 
  → afterWrite() 
    → DocumentSyncService.queueUpload() 
      → Upload to Supabase Storage
```

### 3. Patient Profile UI (`lib/pages/home/patient_profile.dart`)

Enhanced patient profile page with manual sync controls and status indicators.

**New Features:**
- Manual sync button in AppBar (cloud icon)
- Sync progress indicator (spinning CircularProgressIndicator)
- Sync status feedback via SnackBars
- `_syncDocuments()` method to manually trigger sync

**UI Behavior:**
- Cloud sync icon (📥) when idle
- Spinning progress indicator during sync
- Success/error messages via SnackBar
- Disabled during sync operation

## Storage Bucket Configuration

**Bucket Details:**
- **Name:** `medical_notes`
- **Type:** STANDARD
- **Privacy:** Private (requires authentication)
- **File Size Limit:** None (unlimited)
- **Created:** 2025-12-10 14:32:10

**RLS Policies:**
- Doctor-scoped access (users can only access their own patients' documents)
- Enforced via `doctor_id` prefix in storage paths

## File Format Support

### .sbn2 Files (Saber Notes)
- ZIP archive containing BSON-encoded stroke data
- Contains pages, strokes, images, and text
- Synced as single binary file

### .sba Folders (Saber Assets)
- Separate folder for images, PDFs, and attachments
- Each asset file uploaded individually
- Preserved folder structure in cloud storage

## Automatic Sync Workflow

### On Document Save:
1. User edits document in editor
2. Editor saves document via `FileManager.writeFile()`
3. FileManager triggers `afterWrite()` callback
4. DocumentSyncService checks if path contains `/patients/`
5. If yes, queues document for upload
6. Document uploaded to: `{doctor_id}/{patient_id}/...`
7. Assets folder (.sba) uploaded if exists

### On Manual Sync:
1. User clicks cloud sync button in patient profile
2. `_syncDocuments()` method called
3. Lists all files in patient's cloud folder
4. Downloads missing files to local storage
5. Uploads new local files to cloud
6. Shows success/error feedback

## Error Handling

**Upload Failures:**
- Logged to console with stack trace
- SnackBar shown to user with error message
- File queued for retry (TODO: implement proper queue)

**Download Failures:**
- Logged with detailed error information
- User notified via SnackBar
- Sync operation continues for other files

**Network Issues:**
- Graceful degradation (local-first approach)
- Files remain accessible locally
- Sync retried on next save or manual sync

## Security Features

1. **Authentication Required:**
   - All operations require authenticated user
   - `SupabaseAuthService.currentUser` checked before operations

2. **Doctor-Scoped Access:**
   - Files stored under `{doctor_id}/` prefix
   - RLS policies enforce doctor can only access own patients

3. **Private Bucket:**
   - Files not publicly accessible
   - Requires valid Supabase auth token

4. **File Validation:**
   - Only patient directory files synced
   - Path validation prevents directory traversal

## Performance Optimizations

1. **Background Upload:**
   - `queueUpload()` uses fire-and-forget approach
   - Non-blocking UI during upload

2. **Selective Sync:**
   - Only `/patients/` directory files synced
   - Skips temporary files and non-patient data

3. **Asset Folder Handling:**
   - Assets uploaded separately to optimize bandwidth
   - Failed asset uploads don't fail main document upload

## Testing Recommendations

### Manual Testing:
1. Create a new patient
2. Start a session and add notes
3. Save the document
4. Check Supabase Storage dashboard for uploaded file
5. Delete local file
6. Click sync button in patient profile
7. Verify file downloaded successfully

### Edge Cases to Test:
- Network offline during save
- Large asset files (images, PDFs)
- Concurrent edits on multiple devices
- Storage quota limits
- Invalid file paths

## Future Enhancements

### Phase 2: Metadata Tracking
- Create `document_metadata` table
- Track upload/download timestamps
- Monitor sync status per document
- Enable conflict resolution

### Phase 3: Offline Queue
- Implement proper offline sync queue
- Retry failed uploads with exponential backoff
- Background sync using WorkManager (Android) / BackgroundTasks (iOS)

### Phase 4: Real-time Sync
- Listen to storage bucket changes
- Auto-download new documents from other devices
- Real-time collaboration support

### Phase 5: Versioning
- Track document versions in metadata table
- Enable restore to previous versions
- Conflict resolution for concurrent edits

## Cost Estimates

Based on 100 patients with average usage:
- **Storage:** 10 GB @ $0.021/GB/month = $0.21/month
- **Transfer:** 1 GB @ $0.09/GB = $0.09/month
- **Total:** ~$0.30/month

Scales linearly with patient count and document volume.

## Monitoring and Maintenance

**Logs to Monitor:**
- Upload success/failure rates
- Download latency
- Storage usage growth
- Error frequency by type

**Maintenance Tasks:**
- Review and clean up orphaned files
- Monitor storage bucket size
- Audit RLS policies
- Update SDK dependencies

## Related Files

- `lib/data/supabase/document_sync_service.dart` - Sync service implementation
- `lib/data/file_manager/file_manager.dart` - FileManager integration
- `lib/pages/home/patient_profile.dart` - UI with sync controls
- `lib/data/supabase/supabase_patient_service.dart` - Patient CRUD operations
- `lib/data/models/patient.dart` - Patient model
- `DOCUMENT_SYNC_ANALYSIS.md` - Initial analysis and strategy

## Configuration

**Environment Variables (if needed):**
- Supabase URL: Already configured in `supabase_client.dart`
- Supabase Anon Key: Already configured
- Storage Bucket Name: `medical_notes` (hardcoded in service)

## Deployment Checklist

- [x] DocumentSyncService implemented
- [x] FileManager integration complete
- [x] Patient profile UI updated
- [x] Storage bucket verified
- [x] RLS policies configured
- [x] Error handling implemented
- [ ] Manual testing completed
- [ ] Edge case testing
- [ ] Performance benchmarking
- [ ] Production deployment

## Summary

Successfully implemented automatic document synchronization for SynapseAI medical documentation. The system provides:

✅ **Local-First Architecture** - Documents always accessible locally
✅ **Automatic Sync** - Upload on save, no user intervention needed
✅ **Manual Sync** - User-triggered sync for downloads/updates
✅ **Secure Storage** - Private bucket with RLS policies
✅ **Asset Support** - Handles both notes and asset folders
✅ **Error Handling** - Graceful degradation and user feedback
✅ **Doctor-Scoped** - Multi-tenant support with data isolation

The implementation follows best practices for Flutter/Dart development and Supabase Storage integration.
