# SynapseAI Document Sync Strategy Analysis

## Current Storage Architecture

### File Format Analysis

**Saber uses TWO file formats:**

1. **`.sbn2` (Current Format)** - Binary BSON + ZIP Archive
   - Main file contains BSON-encoded metadata and stroke data
   - Separate `.sba` (Saber Assets) folder for images/PDFs
   - Structure:
     ```
     document.sbn2 (ZIP archive containing):
     ├── main.bson (stroke data, pages, metadata)
     └── assets/ (embedded or referenced)
     
     document.sba/ (separate folder):
     ├── image_1.png
     ├── image_2.jpg
     └── pdf_3.pdf
     ```

2. **`.sbn` (Legacy Format)** - Pure JSON
   - Single JSON file with all data
   - Images embedded as base64
   - Being phased out

### How Canvas Data is Stored

**EditorCoreInfo Structure:**
```dart
{
  "v": 19,  // File version
  "bg": {"a": 255, "r": 255, "g": 255, "b": 255},  // Background color
  "p": "none",  // Background pattern
  "l": 40,  // Line height
  "z": [  // Pages array
    {
      "w": 1920,  // Width
      "h": 1080,  // Height
      "s": [  // Strokes array
        {
          "p": [...],  // Points as BSON Binary
          "c": {...},  // Color
          "sw": 2.5,  // Stroke width
          "t": 0,  // Tool type (pen, highlighter, etc.)
          // ... more stroke properties
        }
      ],
      "i": [  // Images array
        {
          "id": 1,  // Asset ID
          "x": 100, "y": 200,  // Position
          "w": 500, "h": 300,  // Dimensions
          // ... more image properties
        }
      ],
      "q": {...}  // Quill/text data (if any)
    }
  ]
}
```

**Storage Size:**
- Typical handwritten page: 50-200 KB (binary)
- With images: Can reach 5-10 MB
- Assets stored separately reduce main file size

---

## Sync Strategy Options

### Option 1: Supabase Storage Bucket (RECOMMENDED ⭐)

**How it works:**
```
Local: /patients/{id}/session_notes/session_1/notes.sbn2
Cloud: medical_notes/{doctor_id}/{patient_id}/session_notes/session_1/notes.sbn2

Local: /patients/{id}/session_notes/session_1/notes.sba/image_1.png
Cloud: medical_notes/{doctor_id}/{patient_id}/session_notes/session_1/notes.sba/image_1.png
```

**Advantages:**
✅ **Simple implementation** - Direct file upload/download
✅ **Preserves file format** - No conversion needed
✅ **Handles large files** - Storage buckets are optimized for this
✅ **Asset management** - .sba folders work naturally
✅ **Version control** - Can keep file versions
✅ **Bandwidth efficient** - Only upload changed files
✅ **Offline-first friendly** - Files available immediately locally
✅ **No size limits** - Can handle multi-MB documents with images

**Disadvantages:**
❌ **Not queryable** - Can't search stroke content in DB
❌ **Two-tier system** - Metadata in DB, files in storage
❌ **Sync complexity** - Need to track which files to upload

**Implementation Complexity:** LOW 🟢

---

### Option 2: Store BSON in Database Column

**How it works:**
```sql
CREATE TABLE session_documents (
  id UUID PRIMARY KEY,
  patient_id UUID REFERENCES patients(id),
  session_number INT,
  document_type TEXT, -- 'session_notes', 'prescription', etc.
  bson_data BYTEA,  -- Binary BSON data
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);

-- Separate table for assets
CREATE TABLE document_assets (
  id UUID PRIMARY KEY,
  document_id UUID REFERENCES session_documents(id),
  asset_id INT,  -- Matches EditorCoreInfo asset IDs
  file_data BYTEA,  -- Image/PDF binary
  file_type TEXT,  -- 'png', 'jpg', 'pdf'
  file_size INT
);
```

**Advantages:**
✅ **Centralized** - Everything in database
✅ **ACID transactions** - Atomic updates
✅ **Metadata queryable** - Can query document properties
✅ **Backup included** - Part of DB backups

**Disadvantages:**
❌ **Database bloat** - PostgreSQL not optimized for large BLOBs
❌ **Performance issues** - Large BYTEA columns slow down queries
❌ **Size limitations** - PostgreSQL has practical limits (~100MB)
❌ **Complex queries** - Can't easily index binary data
❌ **Expensive storage** - Database storage costs more than object storage
❌ **Memory overhead** - Loading entire document into memory

**Implementation Complexity:** MEDIUM 🟡

---

### Option 3: Hybrid - Metadata in DB + Files in Storage (BEST ⭐⭐⭐)

**How it works:**
```sql
CREATE TABLE session_documents (
  id UUID PRIMARY KEY,
  patient_id UUID REFERENCES patients(id),
  session_number INT,
  document_type TEXT,
  file_path TEXT,  -- Path in storage bucket
  thumbnail_url TEXT,  -- Generated preview
  page_count INT,
  has_images BOOLEAN,
  stroke_count INT,
  word_count INT,  -- From Quill data
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  synced_at TIMESTAMPTZ,
  local_modified_at TIMESTAMPTZ,
  cloud_modified_at TIMESTAMPTZ
);

-- Sync queue for offline changes
CREATE TABLE document_sync_queue (
  id UUID PRIMARY KEY,
  document_id UUID REFERENCES session_documents(id),
  operation TEXT,  -- 'upload', 'download', 'delete'
  status TEXT,  -- 'pending', 'in_progress', 'completed', 'failed'
  retry_count INT DEFAULT 0,
  created_at TIMESTAMPTZ
);
```

**Storage Structure:**
```
Storage Bucket: medical_notes/
├── {doctor_id}/
    └── {patient_id}/
        └── session_notes/
            └── session_1/
                ├── {document_id}.sbn2
                ├── {document_id}.sba/
                │   ├── 1.png
                │   └── 2.jpg
                └── {document_id}_thumb.png (auto-generated)
```

**Advantages:**
✅ **Best of both worlds** - Queryable metadata + efficient file storage
✅ **Fast queries** - Can filter/search by metadata
✅ **Scalable** - Storage bucket handles large files
✅ **Offline-first** - Queue system handles connectivity issues
✅ **Smart sync** - Only upload when needed
✅ **Analytics ready** - Can track usage patterns
✅ **Conflict resolution** - Track modification timestamps
✅ **Progress tracking** - Can show sync status in UI

**Disadvantages:**
❌ **More complex** - Need to manage both DB and storage
❌ **Consistency challenges** - Must keep DB and files in sync
❌ **More code** - Sync logic, queue management, conflict resolution

**Implementation Complexity:** HIGH 🔴

---

## Recommended Approach

### Phase 1: Simple Storage Bucket Sync (Start Here)

**Priority:** Implement basic sync ASAP

```dart
class DocumentSyncService {
  /// Upload document to Supabase Storage
  static Future<void> uploadDocument(
    String localPath,
    Patient patient,
    DocumentType type,
  ) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    
    // Construct cloud path
    final cloudPath = _getCloudPath(patient, type, localPath);
    
    // Upload main file
    await supabase.storage
      .from('medical_notes')
      .uploadBinary(cloudPath, bytes);
    
    // Upload assets if they exist
    await _uploadAssets(localPath, cloudPath);
  }
  
  /// Download document from Supabase Storage
  static Future<void> downloadDocument(
    String cloudPath,
    String localPath,
  ) async {
    final bytes = await supabase.storage
      .from('medical_notes')
      .download(cloudPath);
    
    await File(localPath).writeAsBytes(bytes);
    await _downloadAssets(cloudPath, localPath);
  }
}
```

**Trigger Points:**
- After saving document in editor
- On app startup (check for cloud changes)
- On patient folder open (lazy load)

### Phase 2: Add Metadata Tracking

Add `session_documents` table to track:
- What files exist
- Last modified times
- Sync status
- File sizes

### Phase 3: Implement Sync Queue

Add offline support:
- Queue uploads when offline
- Background sync service
- Conflict resolution

### Phase 4: Add AI Processing

After document is synced:
1. Extract canvas as image/PDF
2. Send to AI for analysis
3. Store AI output in separate tables
4. Generate markdown files in appropriate folders

---

## Storage Costs Comparison

**Supabase Pricing (as of 2024):**
- **Storage:** $0.021/GB/month
- **Bandwidth:** $0.09/GB

**Typical Usage (100 patients, 10 sessions each):**
- Average session: 500 KB (with images)
- Total: 1000 sessions × 0.5 MB = 500 MB
- **Cost:** ~$0.01/month storage + bandwidth

**Database Storage:**
- More expensive
- Not designed for BLOBs
- Performance degradation

**Winner:** Storage Bucket 🏆

---

## My Recommendation

**Start with Option 1 (Storage Bucket), then evolve to Option 3 (Hybrid)**

### Immediate Implementation:
1. ✅ Create storage bucket structure
2. ✅ Implement basic upload/download
3. ✅ Add to existing FileManager hooks
4. ✅ Test with one patient

### Next Phase (Week 2):
1. Add metadata table
2. Track sync status
3. Show sync indicators in UI

### Future Phase (Week 3-4):
1. Offline queue
2. Conflict resolution
3. Background sync worker

**Why this approach:**
- ✅ Get sync working quickly
- ✅ Learn from real usage
- ✅ Iterate based on needs
- ✅ Avoid over-engineering
- ✅ Storage bucket is the right tool for file storage

---

## Code Integration Points

### 1. Hook into FileManager.writeFile()
```dart
// In file_manager.dart line ~245
void afterWrite() {
  broadcastFileWrite(FileOperationType.write, filePath);
  
  // NEW: Queue for Supabase upload
  if (filePath.contains('/patients/')) {
    DocumentSyncService.queueUpload(filePath);
  }
}
```

### 2. Hook into Patient Profile
```dart
// When opening patient profile
await DocumentSyncService.syncPatientDocuments(patient.id);
```

### 3. Background Worker
```dart
// Use workmanager for periodic sync
Workmanager().registerPeriodicTask(
  "document-sync",
  "syncDocuments",
  frequency: Duration(minutes: 15),
);
```

---

## Decision

**🎯 I recommend starting with Option 1 (Storage Bucket) immediately.**

Why? Because:
1. It's the simplest and fastest to implement
2. It matches how the files are already structured locally
3. Supabase Storage is designed for this use case
4. You can add metadata tracking later without disrupting the core sync
5. The cost is minimal and scales well

**Would you like me to implement the basic storage bucket sync now?**
