# Design: Automatic iCloud Backup for Device Migration

> References: Issue #561

## Problem

Drift is single-device with no backup story. Users who lose, break, or upgrade their phone lose their entire history — food logs, weight entries, recipes, biomarkers, goals. Drift's value compounds with history; losing it is a trust-breaking hard reset.

V1 delivers automatic daily backup to iCloud Drive so users can restore on a new device. Scope is backup-only, not sync.

## Proposal

Write SQLite DB + UserDefaults snapshot to a `.driftbackup` file (zip: DB + JSON sidecar + manifest) in the app's iCloud Drive ubiquity container. Retain a ring buffer of 7 daily + 4 weekly = 11 snapshots. BGTaskScheduler fires nightly; a "Back up now" button bypasses the scheduler. Backup is opt-in; restore auto-detects on fresh install. No photos, no Keychain entries, no client-side encryption beyond what iCloud provides.

---

## A. iCloud Integration

### Ubiquity container configuration

**Entitlements** (`Drift.entitlements`):
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.ashish-sadh.Drift</string>
</array>
<key>com.apple.developer.ubiquitous-container-identifiers</key>
<array>
    <string>iCloud.com.ashish-sadh.Drift</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudDocuments</string>
</array>
```

**Info.plist** — no additional keys required for NSFileManager-based ubiquity containers (CloudDocuments service only; we are not using NSUbiquitousKeyValueStore or CloudKit).

**Capability:** Xcode project.yml adds `com.apple.iCloud` capability with `CloudDocuments: true`. This is sufficient; no CloudKit private DB capability needed.

### File naming convention

```
drift-backup-2026-05-02T030012.driftbackup
              └──────────────── ISO 8601, UTC, no colons (filesystem-safe)
```

Pattern: `drift-backup-YYYY-MM-DDTHHMMSS.driftbackup`

### Folder layout in iCloud Drive

```
iCloud Drive/
  Drift/                              ← ubiquity container document root
    Backups/
      drift-backup-2026-05-02T030012.driftbackup
      drift-backup-2026-05-01T030008.driftbackup
      ...                             ← up to 11 files (ring buffer)
```

The `Backups/` subdirectory is created on first backup if absent. Files appear in the Files app under **On My iPhone → Drift → Backups** (and sync to iCloud Drive).

### iCloud Drive disabled or user signed out

- `FileManager.default.url(forUbiquityContainerIdentifier:)` returns `nil` when iCloud Drive is off or the user is not signed in.
- `BackupService.containerURL()` wraps this call and throws `BackupError.iCloudUnavailable` when nil.
- The Settings UI reflects this as an error state immediately (no background task attempt).
- BGTaskScheduler task exits early with `.taskCompleted(success: false)` — iOS will reschedule per normal backoff.

### iCloud quota exceeded

- Write to a temp file in `FileManager.default.temporaryDirectory` first. If the copy to the ubiquity container fails with `NSFileWriteOutOfSpaceError` (code 640), throw `BackupError.quotaExceeded`.
- Surface in Settings: "iCloud storage full — free up space to resume backups."
- Do not silently drop the backup; the user must take action.

---

## B. Snapshot Construction

### DB snapshot — VACUUM INTO

Use SQLite `VACUUM INTO '/path/to/temp.sqlite'`:

```swift
try db.execute(sql: "VACUUM INTO ?", arguments: [tempDBURL.path])
```

**Why VACUUM INTO over WAL checkpoint + copy:** VACUUM INTO produces a clean, defragmented, single-file snapshot atomically without requiring exclusive lock on the live DB. WAL checkpoint requires a write lock that can block concurrent inserts. VACUUM INTO is available since SQLite 3.27 (iOS 12+). GRDB exposes `Database.execute(sql:)` so no raw C API needed.

**Caveat:** VACUUM INTO holds a shared lock for its duration (~50–200ms for typical Drift DB). This is acceptable; it does not block readers but will retry if a writer holds an exclusive lock (SQLite busy handler, default 5s timeout in GRDB config).

### UserDefaults snapshot

Explicit allowlist (prefix-based scan is fragile; system keys pollute the namespace):

```swift
static let backupKeys: [String] = [
    "drift.weightGoal",
    "drift.tdeeConfig",
    "drift.dailyCalorieTarget",
    "drift.userBirthYear",
    "drift.userHeightCm",
    "drift.userSex",
    "drift.activityLevel",
    "drift.onboardingComplete",
    "drift.backupEnabled",
    "drift.preferredUnits",
    "drift.foodSortOrder",
    // extend as new Drift-owned keys are added
]
```

Serialized to `preferences.json` (UTF-8). Values are only `Bool`, `Int`, `Double`, `String` — all JSON-serializable. If a key is absent (nil), it is omitted from the JSON (not stored as null) so defaults apply on restore.

**Boy scout note:** `UserDefaults` currently has mixed Drift/system keys with no enforced prefix. A follow-up sub-task should audit all `UserDefaults.standard.set(_, forKey:)` callsites and ensure they use the `drift.` prefix. This design doc's allowlist is the authoritative list for V1 backup; any key not on it is not backed up.

### Bundling — `.driftbackup` format

A `.driftbackup` file is a standard ZIP containing:

```
drift-backup-2026-05-02T030012.driftbackup  (ZIP)
  ├── manifest.json
  ├── drift.sqlite
  └── preferences.json
```

**manifest.json** — V1 schema:

```json
{
  "backupFormatVersion": 1,
  "appBuild": "1042",
  "appVersion": "2.1.0",
  "timestamp": "2026-05-02T03:00:12Z",
  "schemaVersion": 14,
  "files": {
    "drift.sqlite": {
      "sha256": "a3f2c1...",
      "sizeBytes": 2097152
    },
    "preferences.json": {
      "sha256": "b7e9d4...",
      "sizeBytes": 512
    }
  }
}
```

`backupFormatVersion` is bumped only when the manifest schema itself changes. `schemaVersion` is the GRDB migration version from `AppDatabase.migrator` — used to detect forward/backward migration needs on restore.

### Integrity validation on read

Before unpacking a backup during restore:

1. Verify `manifest.json` parses without error.
2. Compute SHA-256 of each file in the ZIP; compare to `manifest.files[name].sha256`. Abort if mismatch.
3. Open `drift.sqlite` in read-only mode and run `PRAGMA integrity_check;`. Abort if result ≠ `ok`.

---

## C. BGTaskScheduler Integration

### Task identifier

`com.ashish-sadh.Drift.dailyBackup` — registered in `Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.ashish-sadh.Drift.dailyBackup</string>
</array>
```

### Registration and submission pattern

```swift
// In DriftApp.init() or AppDelegate.application(_:didFinishLaunchingWithOptions:)
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.ashish-sadh.Drift.dailyBackup",
    using: nil
) { task in
    BackupScheduler.shared.handleBackgroundTask(task as! BGProcessingTask)
}
```

`BackupScheduler.scheduleNextBackup()` is called:
- On app launch (in case it was never scheduled or OS cancelled it)
- On completion of the current background task

```swift
func scheduleNextBackup() {
    let request = BGProcessingTaskRequest(identifier: "com.ashish-sadh.Drift.dailyBackup")
    request.earliestBeginDate = Calendar.current.nextDate(
        after: Date(),
        matching: DateComponents(hour: 3, minute: 0),
        matchingPolicy: .nextTime
    )
    request.requiresNetworkConnectivity = true   // iCloud upload needs network
    request.requiresExternalPower = false         // don't require charging — run opportunistically
    try? BGTaskScheduler.shared.submit(request)
}
```

**Wi-Fi / charging:** `requiresNetworkConnectivity = true` ensures iOS only fires the task when network is available. We do not require external power — the backup is fast enough (~200ms write) that battery impact is negligible. iOS may still run it during charging if that's when conditions are met.

### Manual "Back up now"

`BackupService.performBackup()` is called directly on a background `Task`. It bypasses BGTaskScheduler entirely — no task request, no scheduling side effects. The Settings UI shows a spinner and updates the last-success/last-error display on completion.

---

## D. Restore Flow

### Detection on launch

In `DriftApp.init()`, after wiring platform seams:

```swift
if AppDatabase.shared.isEmpty && BackupService.shared.availableBackups().isEmpty == false {
    showRestorePrompt = true
}
```

`AppDatabase.isEmpty` returns `true` when the food_entries, weight_entries, and workout_entries tables all have 0 rows — meaning fresh install or wiped data.

**Key UX decision (from issue):** restore detection does NOT require backup to have been enabled on this device. The ubiquity container is accessible to any device signed in to the same iCloud account. We check for backups regardless of `drift.backupEnabled` preference.

### Listing available backups

`BackupService.availableBackups()` enumerates the `Backups/` directory in the ubiquity container, parses each manifest, and returns a sorted list (newest first):

```swift
struct BackupInfo: Identifiable {
    let url: URL
    let timestamp: Date
    let appVersion: String
    let appBuild: String
    let backupFormatVersion: Int
    let schemaVersion: Int
}
```

iCloud may not have finished downloading file metadata; use `URLResourceKey.ubiquitousItemDownloadingStatusKey` to filter out files not yet available. Show a "Checking iCloud…" state while `NSMetadataQuery` is running.

### Restore UI

1. List screen: each backup shows date, time, app version. User taps one.
2. Confirmation sheet: "This will replace your current Drift data. You cannot undo this. Continue?" — explicit confirm button.
3. Progress: indeterminate spinner. Restore takes <2s on-device.
4. Completion: app relaunches to home tab with restored data.

### Atomic restore

```
1. Download backup file from iCloud (may already be local)
2. Unzip to a temp directory
3. Validate integrity (manifest checksums + PRAGMA integrity_check)
4. Run forward migrations if schemaVersion < current
5. Move temp .sqlite to AppDatabase.databaseURL using FileManager.replaceItem(at:withItemAt:)
6. Reload AppDatabase
7. Apply preferences.json to UserDefaults (only keys in backupKeys allowlist)
```

`FileManager.replaceItem(at:withItemAt:)` is atomic at the filesystem level. If it fails, the original DB is intact. If step 7 (UserDefaults apply) throws, data is restored but preferences may be at defaults — this is a safe degraded state, not a data loss.

### App version / schema version mismatch

| Condition | Action |
|-----------|--------|
| `backupFormatVersion` > app's max supported (currently 1) | Refuse: "This backup was created with a newer version of Drift. Please update the app." |
| `schemaVersion` < current app's migrator version | Run forward migrations on the restored DB before moving into place |
| `schemaVersion` > current app's migrator version | Refuse: "This backup requires a newer version of Drift. Please update the app." |

---

## E. Settings UI

Location: **Settings → Data → Backup** (new section).

### Controls

```
Automatic Backups (iCloud)          [Toggle — off by default]
Last backed up: Today at 3:02 AM
Last attempt:   Today at 3:00 AM
Status:         ✓ Backed up successfully

[Back Up Now]                       (button, disabled while backup running)
[Restore from Backup…]              (shows list of available backups)

What's in my backup?
  ↓ (disclosure group)
  Your food log, weight history, recipes, workouts, biomarkers,
  and app preferences. Not included: photos, HealthKit data
  (Apple syncs this separately), and security keys.
```

### Error states

- Toggle ON but iCloud unavailable: show inline error "iCloud Drive is off. Enable it in Settings → [Your Name] → iCloud → iCloud Drive."
- Last attempt failed: show last error string below status (e.g., "iCloud storage full").
- >3 days without successful backup: banner on home tab "Last backed up N days ago — tap to fix."

Banner implementation: `BackupMonitor` (new service, iOS-only, lives in `Drift/`) checks `lastSuccessfulBackupDate` from `UserDefaults` on app foreground. If gap > 3 days, posts a `Notification.Name.backupStaleBanner` that `HomeView` observes to show a banner.

---

## F. Failure Modes

| Failure | Detection | User-facing copy | Recovery path |
|---------|-----------|-----------------|---------------|
| iCloud Drive disabled by user | `containerURL()` returns nil | "iCloud Drive is off. Enable it in Settings → Apple ID → iCloud." | User enables iCloud Drive; retry via "Back Up Now" |
| iCloud signed out mid-session | `containerURL()` returns nil after previously returning a URL | "You're signed out of iCloud. Sign in to resume backups." | User signs in; next scheduled task picks up |
| iCloud quota exceeded | `NSFileWriteOutOfSpaceError` (640) on container write | "iCloud storage is full. Free up space to resume backups." | User manages iCloud storage; retry via "Back Up Now" |
| Network unavailable when BG task fires | BGTask exits early; OS reschedules | (silent — no user action needed; OS reschedules) | OS fires task when network available |
| Disk full writing temp snapshot | `NSFileWriteOutOfSpaceError` on device temp dir | "Not enough space on your device to create a backup." | User frees device storage |
| DB busy / locked (concurrent write) | GRDB busy timeout (5s) throws `DatabaseError` | "Backup failed — please try again." | Retry via "Back Up Now"; BG task will retry next night |
| Restore: manifest checksum mismatch | SHA-256 comparison fails | "This backup file appears to be corrupted and cannot be restored." | User selects a different backup from list |
| Restore: schema version unsupported (too new) | `schemaVersion > appMaxSchema` | "This backup requires a newer version of Drift. Update the app and try again." | User updates app |
| Restore: user cancels mid-restore | User taps Cancel on confirmation sheet | (no action taken — original data intact) | N/A |
| iCloud upload async — file written but not yet uploaded | `ubiquitousItemUploadingErrorKey` set on file URL | "Backup saved to device, uploading to iCloud…" (in-progress state) | Monitor with NSMetadataQuery; update status when upload completes |
| Restore: backup for newer app version (format v2+) | `backupFormatVersion > 1` | "This backup was made with a newer version of Drift. Update the app to restore it." | User updates app |

---

## G. Test Plan

### Tier 0 — DriftCoreTests (swift test, no iOS dependencies)

`DriftCoreTests/BackupManifestTests.swift`
- Manifest serialization roundtrip (encode → decode → fields match)
- SHA-256 checksum computation for known inputs
- Ring buffer pruning: given 12 backup filenames sorted by date, returns oldest 1 for deletion
- Schema version comparison logic (older / same / newer branches)
- UserDefaults allowlist serialization: only `backupKeys` keys appear in output JSON
- preferences.json deserialization: nil keys are absent, not null

`DriftCoreTests/BackupRoundTripTests.swift`
- Snapshot + restore roundtrip on in-memory GRDB DB: insert 100 food entries, snapshot, restore to new DB, verify row count and content match
- Corrupt a manifest checksum → restore returns `.corrupted` error
- Missing manifest file → restore returns `.invalidFormat` error

### Tier 1 — DriftTests (iOS Simulator)

`DriftTests/BackupServiceTests.swift`
- BGTaskScheduler task registration: `BGTaskScheduler.shared.registeredTaskIdentifiers` contains `com.ashish-sadh.Drift.dailyBackup`
- Ubiquity container access: `FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.ashish-sadh.Drift")` returns non-nil in test environment
- `BackupService.containerURL()` returns nil when `FileManager` mock returns nil; throws `BackupError.iCloudUnavailable`
- Restore picker UI: given 3 mock `BackupInfo` items, `RestorePickerView` renders 3 rows

`DriftTests/BackupSettingsViewTests.swift`
- Toggle off by default on fresh install
- "Back Up Now" button disabled while `isBackingUp == true`
- Error string appears when `lastBackupError` is non-nil

### Tier 3 / Manual acceptance — device-to-device restore

Not automatable in CI. Document as release acceptance criteria:
1. Device A: enable backup, tap "Back Up Now", confirm success.
2. Device B: fresh install (same iCloud account), launch Drift.
3. Expected: restore prompt appears listing Device A's backup.
4. Restore: all food entries, weight entries, preferences from Device A appear on Device B.

---

## H. Defer to V2

The V1 `.driftbackup` manifest uses `"backupFormatVersion": 1`. V2 additions must increment this field and add new top-level keys — not modify existing ones. Restore code reads V1 format; V2 restore code reads both.

| Feature | Why deferred |
|---------|-------------|
| Photos in backup | Large file size; iCloud quota impact; separate user consent needed |
| User-selected non-iCloud storage (Files picker / Dropbox / Drive) | Requires `UIDocumentPickerViewController` + provider abstraction; iCloud is the 95% case |
| Client-side passphrase encryption | Adds UX friction and key management complexity; iCloud ADP covers the threat model for V1 |
| Merge-on-restore | Requires conflict resolution strategy; replace-with-confirmation is safe and simple |
| Multi-device sync | Fundamentally different problem — requires CRDT or operational transform; separate design doc |
| Selective restore (pick which data types) | Adds UI complexity; full restore is the right default |

---

## UX Flow

### First launch on new device (no existing data)

```
[App launches on new iPhone]
  → Drift detects empty DB
  → Checks ubiquity container for backups
  → Finds backup(s) from old device

Sheet: "Restore your Drift data?"
  "A backup from May 1, 2026 was found in iCloud.
   Restore to get your food log, weight history, and more."
  [Restore →]     [Start Fresh]

  → User taps Restore
  → Picks backup from list (or auto-selects most recent)
  → Confirmation: "Replace current data? (You have no data yet)"
  → Restore runs
  → Home tab loads with restored data
```

### Existing user enabling backup

```
Settings → Data → Backup
  [Toggle: Automatic Backups] OFF → ON
  iCloud Drive availability check passes
  "First backup will run tonight at 3 AM."
  [Back Up Now]  ← user taps for immediate backup
  Spinner → "Backed up — uploading to iCloud…"
  NSMetadataQuery confirms upload → "Last backed up: Just now"
```

---

## Technical Approach

### New files

| File | Target | Purpose |
|------|--------|---------|
| `DriftCore/.../Domain/Backup/BackupManifest.swift` | DriftCore | Manifest Codable model, format version constant |
| `DriftCore/.../Domain/Backup/BackupPackager.swift` | DriftCore | Snapshot construction, zip bundling, checksum |
| `DriftCore/.../Domain/Backup/BackupRestorer.swift` | DriftCore | Integrity validation, atomic restore |
| `DriftCore/.../Domain/Backup/BackupRingBuffer.swift` | DriftCore | Ring buffer pruning (7 daily + 4 weekly) |
| `Drift/BackupService.swift` | iOS | iCloud container access, BGTaskScheduler, file upload monitoring |
| `Drift/BackupScheduler.swift` | iOS | BGProcessingTask registration + scheduling |
| `Drift/BackupMonitor.swift` | iOS | Stale-backup banner logic (>3 days check) |
| `Drift/Views/Settings/BackupSettingsView.swift` | iOS | Settings UI |
| `Drift/Views/Settings/RestorePickerView.swift` | iOS | Restore list + confirmation sheet |
| `DriftCoreTests/BackupManifestTests.swift` | Tier 0 | Manifest + ring buffer + roundtrip tests |
| `DriftTests/BackupServiceTests.swift` | Tier 1 | iOS integration tests |

### DriftCore / iOS split rationale

`BackupPackager` and `BackupRestorer` use only `Foundation` + GRDB — no iOS frameworks. They belong in DriftCore for testability (`swift test`, no simulator). `BackupService` needs `FileManager` ubiquity container APIs and `BGTaskScheduler` (iOS 13+, no macOS) — stays in the iOS target.

### Database migration

No schema changes required for V1. The backup stores the DB as-is; restore runs existing `AppDatabase.migrator` forward migrations if the backed-up schema is older than the current app.

### iCloud upload confirmation

Use `NSMetadataQuery` scoped to the `Backups/` subdirectory:

```swift
query.predicate = NSPredicate(format: "%K == %@",
    NSMetadataItemFSNameKey, backupFileName)
query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
```

Watch for `NSMetadataQueryDidUpdateNotification`. When `NSMetadataUbiquitousItemUploadingErrorKey` is nil and `NSMetadataUbiquitousItemIsUploadedKey` is `true`, record `lastSuccessfulBackupDate`.

---

## Open Questions

None — all decisions locked per issue #561 operator alignment on 2026-04-30.

---

## Effort Estimate

| Area | Estimate |
|------|----------|
| iCloud integration + container setup | 6h |
| Snapshot construction (DB + UserDefaults + manifest + zip) | 4h |
| Ring buffer + pruning | 2h |
| BGTaskScheduler integration | 3h |
| Restore flow + atomic swap + migration | 5h |
| Settings UI + stale-backup banner | 4h |
| Failure-mode handling | 3h |
| Tests (Tier 0 + Tier 1) | 4h |
| **Total** | **~31h** |

---

*To approve: add `approved` label to the PR. To request changes: comment on the PR.*
