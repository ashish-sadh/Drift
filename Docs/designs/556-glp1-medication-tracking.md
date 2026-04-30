# Design: GLP-1 / Medication Tracking

> References: Issue #556

## Problem

GLP-1 receptor agonists (Ozempic, Wegovy, Mounjaro, Zepbound) have become a mainstream weight management tool. MyFitnessPal launched GLP-1 tracking on April 28, 2026, signaling this is now an expected feature for health apps targeting weight management. Drift users on GLP-1 currently have no way to:

- Log injections conversationally ("took my Ozempic")
- Track injection site rotation (required to prevent lipohypertrophy)
- Correlate medication start date with nutrition/weight/appetite changes
- Get reminders or AI-assisted status ("when is my next dose?")

Existing supplement tracking is insufficient — it uses a binary taken/not-taken model with no dose/unit/route/site fields, and the UX is not designed for weekly-cadence prescription medications.

## Recommended Approach

**General medication domain, GLP-1 as the first-class persona.**

Rather than adding GLP-1 as a supplement variant or a special case, introduce a lightweight `Medication` domain alongside supplements. This avoids polluting the supplement model with injection sites and dose titration, and leaves room for other medications (thyroid, metformin, insulin) without architectural rework.

GLP-1 drugs are the launch target — their specific needs (weekly injection, site rotation, dose titration) shape the MVP model design.

## UX Flow

### Logging a dose

```
User: "took my Ozempic"
AI: Logged Ozempic (0.5 mg, 2026-04-30). Which injection site — abdomen, thigh, or arm?

User: "left abdomen"
AI: Got it. Logged left abdomen. Your last 3 sites: right thigh → left arm → left abdomen.
```

```
User: "injected Wegovy, right thigh"
AI: Logged Wegovy (1.0 mg, 2026-04-30, right thigh). Next dose due: 2026-05-07.
```

### Status / history

```
User: "did I take my Ozempic this week?"
AI: Yes — logged 2026-04-28, left abdomen. Next dose due 2026-05-05.

User: "where did I inject last time?"
AI: Left abdomen on 2026-04-28. Rotation suggestion: try right thigh or arm next.
```

### Outcome correlation

```
User: "how has my appetite changed since starting GLP-1?"
AI: You started Ozempic 6 weeks ago (2026-03-19). Average daily calories:
    Weeks 1–2: 2,340 cal/day
    Weeks 3–4: 1,980 cal/day
    Weeks 5–6: 1,810 cal/day
    Trend: –530 cal/day since starting. Weight over same period: –2.8 kg.
```

```
User: "how long until my next dose?"
AI: Last Ozempic logged 2026-04-28. Next dose due in 5 days (2026-05-05).
```

## Technical Approach

### New models (`DriftCore/Sources/DriftCore/Models/`)

```swift
struct Medication {
    var id: Int64?
    var name: String            // "Ozempic", "Wegovy"
    var genericName: String?    // "semaglutide"
    var dose: Double?           // 0.5, 1.0, 2.0
    var doseUnit: String?       // "mg"
    var frequencyDays: Int      // 7 for weekly
    var isActive: Bool
    var startDate: String?      // YYYY-MM-DD
}

struct MedicationLog {
    var id: Int64?
    var medicationId: Int64
    var date: String            // YYYY-MM-DD
    var takenAt: String?        // ISO 8601
    var dose: Double?           // override if titrating
    var doseUnit: String?
    var injectionSite: String?  // "left abdomen", "right thigh", "left arm", "right arm"
    var notes: String?
}
```

### New DB tables (migration)
- `medication` and `medication_log` tables
- Migration added to `AppDatabase` alongside existing `supplement`/`supplement_log`

### New domain service (`DriftCore/Sources/DriftCore/Domain/Health/MedicationService.swift`)
- `logDose(name:site:)` — find or create medication, insert log
- `getStatus(name:)` → last log date, days since, next due date
- `recentSites(medicationId:limit:)` → last N injection sites for rotation hint
- `correlateWithNutrition(medicationId:windowDays:)` → weekly avg calories before/after start

### New AI tools
- `log_medication(name, dose?, unit?, site?)` — registers dose taken
- `medication_status(name?)` — last log, next due, site history, compliance rate

### IntentClassifier changes
Add `log_medication` and `medication_status` to the tool list in `IntentClassifier.swift`. Add routing examples to the model prompt.

### Tool registration
Register both tools in `ToolRegistration.swift` alongside existing supplement/insight tools.

### Dual-model interaction
SmolLM handles intent detection. Gemma 4 handles the correlation queries ("how has my appetite changed") — these go through `cross_domain_insight` or a new `medication_insight` tool (post-MVP).

## Scope

### MVP (recommended first ship)
- `Medication` and `MedicationLog` models + DB migration
- `log_medication` AI tool (name, optional dose/site)
- `medication_status` AI tool (last log, next due, recent sites)
- Injection site rotation hint (last 3 sites shown on log)
- AI chat reminder: "your weekly Ozempic is due" when `medication_status` is queried and dose is overdue

### V2 (post-approval)
- `medication_insight` tool: cross-domain correlation with nutrition/weight since start date
- Side effect log (nausea, fatigue, appetite — free-text or structured)
- Dose titration schedule awareness (0.5mg → 1mg → 2mg)
- UI view: medication history + injection site map
- Push notification for dose reminders

### Explicitly out of scope
- Dosing advice or medical recommendations (legal boundary — Drift logs what users tell it)
- Cloud sync or integration with pharmacy/prescription systems
- Any medication other than GLP-1 in MVP validation

## Edge Cases

- **Multiple medications**: `medication_status` with no name argument returns all active medications. Each gets its own log row.
- **Dose titration**: `MedicationLog.dose` overrides the `Medication.dose` default. AI parses "took 1mg Ozempic" and logs the override.
- **Skipped dose**: No explicit skip logging in MVP. Overdue detection is implicit via `nextDueDate > today`.
- **Name variants**: Map "Ozempic", "semaglutide", "GLP-1" → same medication via fuzzy match in `MedicationService.logDose`.
- **Site abbreviations**: "stomach" → "abdomen", "leg" → "thigh" — normalize in tool handler.
- **No supplement collision**: Medication domain is independent; supplement UI and tools are unchanged.

## Open Questions

1. **Side effects in MVP?** Nausea tracking is a top GLP-1 user need but adds model complexity. Defer to V2 unless there's strong user signal.

2. **Proactive insight trigger**: Should Drift proactively surface "you've been on Ozempic 4 weeks — want to see your calorie trend?" Or wait for user query? The latter is safer for MVP.

3. **Reminder mechanism**: AI-proactive mention (in chat) vs push notification. Chat is lower risk and aligns with AI-first tenet. Push notification can follow in V2.

4. **`medication_insight` tool boundary**: Is cross-domain correlation (medication × nutrition × weight) a separate tool or an extension of `cross_domain_insight`? Recommend separate tool to keep prompts clean, but needs human call.

5. **UI view priority**: Is a dedicated Medication screen needed in MVP, or is AI chat + a minimal entry in the health summary sufficient? Recommend chat-only for MVP, screen in V2.

---

*To approve: add `approved` label to the PR. To request changes: comment on the PR.*
