# Design: Medication Tracking (GLP-1 as launch catalyst)

> References: Issue #574

## Problem

MFP launched free GLP-1 support on 2026-04-28 — medication log, dose reminders, and side-effect tracking alongside nutrition. GLP-1 adoption is accelerating; users on Ozempic/Wegovy/Mounjaro are already logging food in Drift and asking the AI about weight trends. The app has no way to record what medication they're on, when they dose, or whether nausea/appetite suppression is correlated with their food log.

Drift's all-in-one health-coach identity is a natural fit — medication context unlocks better AI reasoning ("your calorie intake dropped 18% two weeks after starting semaglutide") and closes a real gap for a fast-growing user segment.

## Proposal

Build a **generic on-device medication log** — not GLP-1-specific — so Drift can track any prescription or OTC medication. The data model, AI tools, and UI are designed for medications in general; GLP-1s are the first promoted use-case but not the only one.

**V1 scope (this doc):**
- `Medication` profile (name, dose, schedule, reminder)
- `MedicationLog` per-dose record (taken-at, optional side-effect note)
- AI chat tools: add/log/remind/query medication
- Minimal UI: medication card inside the existing Health tab
- Weight-chart marker at medication start date

**Out of scope for V1:** injection-site tracking, dose-escalation schedules (GLP-1 titration protocol), multi-device sync, cloud-backed reminders, correlation analytics dashboard, photo-OCR of prescription labels.

## Data Model

### Why separate tables instead of extending `Supplement`

`Supplement` (`DriftCore/Sources/DriftCore/Models/Supplement.swift`) already covers vitamins and protein powder. Medications differ semantically (prescribed, sensitive PHI) and structurally (per-dose logs, weekly schedules, side-effect notes). Merging them forces a type discriminator into every query and complicates future privacy isolation (medication-only export/delete). Three similar lines beat premature abstraction — but `Supplement` and `Medication` are not similar enough to share a table.

### New models (both in `DriftCore`)

```swift
// DriftCore/Sources/DriftCore/Models/Medication.swift
public struct Medication: Identifiable, Codable, Sendable {
    public var id: Int64?
    public var name: String          // generic: "semaglutide"
    public var brandName: String?    // "Ozempic", "Wegovy", "Mounjaro"
    public var doseAmount: Double    // 0.5
    public var doseUnit: String      // "mg" | "mcg" | "mL" | "units" | "IU"
    public var scheduleType: String  // "daily" | "weekly" | "biweekly" | "asneeded"
    public var reminderTime: String? // "HH:mm" (nil = no reminder)
    public var reminderDay: Int?     // 0-6 Sun-Sat, only for weekly/biweekly
    public var startDate: Date?      // when user started (for chart markers)
    public var isActive: Bool        // false = archived, still in history
    public var notes: String?        // free text e.g. "inject in abdomen"
}

// DriftCore/Sources/DriftCore/Models/MedicationLog.swift
public struct MedicationLog: Identifiable, Codable, Sendable {
    public var id: Int64?
    public var medicationId: Int64
    public var takenAt: Date
    public var doseAmount: Double?   // nil = used prescribed dose
    public var sideEffects: String?  // free text: "nausea", "fatigue"
    public var notes: String?
}
```

### GRDB migrations (new migration in `AppDatabase`)

```sql
CREATE TABLE medication (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    brand_name TEXT,
    dose_amount REAL NOT NULL,
    dose_unit TEXT NOT NULL,
    schedule_type TEXT NOT NULL DEFAULT 'daily',
    reminder_time TEXT,
    reminder_day INTEGER,
    start_date TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    notes TEXT
);

CREATE TABLE medication_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    medication_id INTEGER NOT NULL REFERENCES medication(id) ON DELETE CASCADE,
    taken_at TEXT NOT NULL,
    dose_amount REAL,
    side_effects TEXT,
    notes TEXT
);
CREATE INDEX medication_log_taken_at ON medication_log(taken_at DESC);
```

## AI Chat Flows

New tools registered in `DriftCore/Sources/DriftCore/AI/Tools/`:

| Tool | Trigger phrases |
|---|---|
| `add_medication` | "I'm on Wegovy", "add metformin 500mg daily" |
| `log_medication` | "log my semaglutide", "took my Ozempic" |
| `log_medication_side_effect` | "nausea after my GLP-1 shot", "felt tired after meds" |
| `set_medication_reminder` | "remind me to take metformin at 8am every day" |
| `query_medication_logs` | "when did I last take Ozempic?", "show my medication history" |
| `query_medication_correlation` | "how has my weight changed since starting Wegovy?" |

### Example conversations

```
User: "I started Ozempic 0.5mg weekly last Monday"
AI: [add_medication(name:"semaglutide", brandName:"Ozempic", doseAmount:0.5,
      doseUnit:"mg", scheduleType:"weekly", startDate:"2026-04-28")]
AI: "Got it — I've added Ozempic 0.5mg weekly, starting April 28. Want me
     to set a weekly reminder?"

User: "yes, every Friday at 9am"
AI: [set_medication_reminder(medicationId:1, time:"09:00", day:5)]
AI: "Reminder set for Fridays at 9 AM."

User: "log my Ozempic — felt a bit nauseous after"
AI: [log_medication(medicationId:1, takenAt:now,
      sideEffects:"nausea")]
AI: "Logged. Nausea noted — it's common in the first few weeks. Your appetite
     may also be lower today; you don't need to hit your usual calorie target."

User: "how has my weight changed since I started?"
AI: [query_medication_correlation(medicationId:1, domain:"weight")]
AI: "Since starting Ozempic on April 28, you're down 1.8 kg over 3 weeks.
     Your average daily calories also dropped from 1,840 to 1,520."
```

```
User: "remind me to take my metformin at 8am"
AI: [query existing medications matching "metformin"]
     → none found
AI: "I don't have metformin in your medications yet. What dose are you on?"
User: "500mg twice a day"
AI: [add_medication(name:"metformin", doseAmount:500, doseUnit:"mg",
      scheduleType:"daily", reminderTime:"08:00")]
     + schedules second reminder at 20:00 automatically for twice-daily
AI: "Added metformin 500mg twice daily. Reminders set for 8 AM and 8 PM."
```

### Dual-model routing

- **SmolLM** (360M): `log_medication` when medication already exists in profile — direct lookup by name, no reasoning needed.
- **Gemma 4** (2B): `add_medication`, `query_medication_correlation`, side-effect logging (needs context about existing meds), ambiguous brand/generic resolution.

The intent classifier should route `medication` / `meds` / `GLP-1` / brand names (Ozempic, Wegovy, Mounjaro, Zepbound, Metformin) to Gemma 4 by default.

## UX Flow

### First-time setup (chat-driven)

User mentions a medication → AI offers to add it → confirms schedule + reminder → done. No dedicated onboarding screen.

### Settings / Health tab

Existing Health tab gets a **Medications** card (below Biomarkers, above Supplements):

```
┌─ Medications ────────────────────────────────────┐
│  Ozempic 0.5mg  · weekly · last taken Apr 25     │
│  Metformin 500mg · daily  · last taken today      │
│  [+ Add medication]                               │
└───────────────────────────────────────────────────┘
```

Tapping a row → Medication Detail: dose history, side-effect timeline, next reminder.

### Weight chart integration

A vertical dashed line at `startDate` labelled "Ozempic started". Implemented as an overlay in the existing `WeightChartView`. Only shown when `MedicationLog` records exist within the chart's date range.

## Integration with Existing Domains

| Domain | Integration |
|---|---|
| Weight | Chart marker at medication start date; correlation query via `query_medication_correlation` |
| Nutrition | No automatic calorie-target change; AI can note reduced intake in conversation |
| Biomarkers | Correlation query works the same way (e.g., A1c improvement since starting Metformin) |
| Supplements | Independent tab card; no shared model |
| Reminders | Piggybacks on existing `NotificationService`; uses `UNCalendarNotificationTrigger` |

## Privacy Considerations

Medication names are sensitive health data — stronger than food or weight.

- **All on-device.** `Medication` and `MedicationLog` tables live only in the local GRDB database. No sync, no cloud, no analytics.
- **Cloud AI exclusion.** When CloudVision/PhotoLog sends an image to a cloud API, medication context is never included in the prompt. `MedicationService` has no dependency on `CloudVisionKey` or any cloud path.
- **No crash-report leakage.** Medication names must not appear in log lines at `Log.info` or above. Use IDs in logs: `"logged medicationId=\(id)"`, never `"logged \(medication.name)"`.
- **UI disclosure.** The Medications card shows a one-line footer: "Medication data stays on your device and is not shared with any service."
- **Backup note (future).** When iCloud backup ships (design #561), medication data IS included in the backup (it's local health data the user owns). The backup disclosure copy must name it explicitly.

## Edge Cases

- **Brand vs. generic confusion**: "Ozempic" and "semaglutide" are the same drug. The AI should resolve common brand/generic pairs and avoid creating duplicates. Maintain a small static alias table in `StaticOverrides` for the top 10 GLP-1/diabetes brands.
- **Unknown medication**: User logs a drug not in the static alias table → store verbatim as entered, no lookup. Don't fail.
- **Dose override at log time**: User says "took half my dose today" → `MedicationLog.doseAmount = 0.25` (half of prescribed 0.5mg). AI must understand fractional doses.
- **Weekly med logged on wrong day**: Fine — `takenAt` is authoritative, `reminderDay` is just the schedule preference.
- **Archived medication**: `isActive = false` → hidden from active list, still visible in history. Chat can still log to it ("I restarted my metformin").
- **No meds in profile**: `query_medication_logs` returns empty → AI says "I don't have any medications on file. Would you like to add one?"

## Open Questions

1. **Supplement tab vs. Health tab placement**: Should medications appear under the existing Supplement tab (since both cover "things you take") or under a new Medications card in the Health tab? Supplement tab is already discoverable; Health tab has more semantic fit. Recommendation: Health tab — but needs human sign-off before implementation.

2. **Dose escalation for GLP-1**: GLP-1 protocols increase dose every 4 weeks (0.25 → 0.5 → 1.0 → 2.0mg). Should V1 support a dose-escalation schedule, or is manual dose-update sufficient? Manual update is simpler; AI can prompt "Your Ozempic dose was 0.5mg — has it changed?" when logging after 4 weeks.

3. **Side-effect taxonomy**: Free text vs. a picker (nausea, vomiting, fatigue, injection-site reaction, constipation, diarrhea). Free text is lower friction; picker enables aggregation. Recommendation: free text in V1, picker in V2 when there's enough data to design it.

4. **HealthKit write**: Should logged medication doses write to HKCategoryTypeIdentifierMindfulSession (there's no HK medication type)? Answer: No — HK has no medication concept worth shoehorning. Skip HealthKit integration.

---

*To approve: add `approved` label to the PR. To request changes: comment on the PR.*
