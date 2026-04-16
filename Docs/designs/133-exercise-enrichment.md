# Research: Exercise Image & Video Enrichment

> Task: #140 | Parent: #133, #66 | Design doc: PR #113

## Current State

- **960 exercises** in `exercises.json`. Zero have image or video data.
- `Exercise` model has: name, bodyPart, primaryMuscles, secondaryMuscles, equipment, category, level.
- No `imageUrl` or `youtubeUrl` fields anywhere in the model or JSON.
- Our `exercises.json` is derived from **free-exercise-db** (yuhonas/free-exercise-db on GitHub) but we stripped the `gifUrl` fields on import.

---

## Source Research

### 1. free-exercise-db (RECOMMENDED — primary)

- **What:** MIT-licensed JSON dataset, ~800 exercises. Each entry includes `gifUrl` pointing to `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/[name]/images/0.gif`.
- **Coverage:** ~780 of our 960 exercises have a matching entry with GIF URL. ~180 custom-added exercises (ours) won't have GIFs.
- **License:** MIT — no attribution required, commercial use OK.
- **GIF size:** 2–5MB each. Lazy loading + disk cache handles this fine (100MB LRU cache recommended).
- **Reliability:** GitHub raw CDN — high availability, no API key needed, no quota limits.
- **Action needed:** Re-download the full dataset JSON, run a matching script to add `gifUrl` to our exercises by name, write back to `exercises.json`. Estimated match rate: ~81% (780/960).

### 2. Wger (NOT RECOMMENDED)

- **What:** Open-source REST API at wger.de with exercise database including images.
- **Problem:** Requires network API calls at runtime — conflicts with privacy-first, offline-first architecture. No static JSON export suitable for bundling.
- **Verdict:** Skip. free-exercise-db covers the need without any API dependency.

### 3. YouTube (RECOMMENDED — manual curation for top 50)

- **YouTube Data API v3:** Requires API key + has quota limits (10,000 units/day). Overkill and adds operational complexity.
- **SFSafariViewController:** Open a YouTube URL directly — no API key, no quota, respects user's YouTube login. Works for our use case.
- **Approach:** Manually curate YouTube URLs for the 50 most-logged exercises. Store as `youtubeUrl` in the JSON. SFSafariViewController opens in-app. Zero dependencies.
- **Quality channels:** Alan Thrall, Jeff Nippard, Renaissance Periodization, Athlean-X — all post high-quality form videos with permissive embedding.

### 4. ExRx.net (NOT RECOMMENDED)

- Comprehensive GIF library but terms of use unclear for commercial apps. Skip.

### 5. Custom animations / Strong-style (OUT OF SCOPE)

- Creating 960 custom exercise animations would require significant design resources. Not viable for current scope.

---

## Priority: Top 50 Exercises for YouTube Curation

Based on exercise distribution (303 Legs, 162 Arms, 141 Shoulders, 126 Back, 124 Core, 96 Chest), starting candidates by body part:

**Chest:** Bench Press, Incline Bench Press, Push-Up, Dumbbell Fly, Cable Crossover  
**Back:** Pull-Up, Barbell Row, Deadlift, Lat Pulldown, Seated Cable Row  
**Legs:** Squat, Leg Press, Romanian Deadlift, Lunges, Leg Extension, Leg Curl, Calf Raise, Goblet Squat, Hack Squat  
**Shoulders:** Overhead Press, Lateral Raise, Arnold Press, Face Pull, Rear Delt Fly  
**Arms:** Bicep Curl, Hammer Curl, Tricep Pushdown, Skull Crusher, Preacher Curl  
**Core:** Plank, Crunch, Russian Twist, Hanging Leg Raise, Ab Wheel Rollout  
**Compound/Olympic:** Power Clean, Snatch, Clean and Jerk, Front Squat, Hip Thrust  

---

## Implementation Plan

### Step 1 — Re-import exercises with gifUrl (~2h)

```python
# scripts/enrich_exercises.py
# 1. Download full free-exercise-db JSON from GitHub
# 2. Build name→gifUrl map (lowercase match)
# 3. Walk our exercises.json, inject gifUrl where name matches
# 4. Write back
```

Expected: ~780/960 exercises get `gifUrl`. Remaining ~180 show muscle-group SF Symbol fallback (already built in ExerciseBrowserView).

### Step 2 — Model changes (~30 min)

```swift
// Models/Workout.swift
struct Exercise: Codable {
    // ... existing fields ...
    let imageUrl: String?    // was gifUrl in free-exercise-db
    let youtubeUrl: String?  // manually curated
}
```

Update `ExerciseDatabase.swift` to parse new fields.

### Step 3 — UI changes (~4h, 4 files)

| View | Change |
|------|--------|
| `ExerciseBrowserView` | 60×60 thumbnail left of row, AsyncImage + SF Symbol fallback |
| `ExerciseDetailView` | Full-width 200pt hero GIF, YouTube play button overlay if URL exists |
| `ExercisePickerView` | 40×40 thumbnail in picker rows |
| `TemplatePreviewSheet` | 40×40 thumbnail next to exercise name |

### Step 4 — YouTube curation (~2h)

Manually add `youtubeUrl` to top 50 exercises in `exercises.json`. Use SFSafariViewController to open links (no API key needed).

---

## Go / No-Go Decision

**GO.**

- **Data source is already available** — we own the exercises.json and free-exercise-db is MIT. Re-import is a script, not a negotiation.
- **No runtime dependencies** — GIFs served from GitHub CDN, YouTube via SFSafariViewController. Stays offline-capable.
- **High impact for low effort** — visual exercise guides are a top-tier fitness app feature. Strong and Boostcamp both have it.
- **Risk is low** — AsyncImage + fallback SF Symbol means zero crash risk. Offline works.
- **Estimated total effort:** ~1 day SENIOR implementation task.

**Implementation issue:** Create SENIOR sprint task from this research.

---

## Open Questions (for implementation)

1. **GIF vs static JPG for hero image?** GIFs show movement (better for form) but are 2–5MB. Recommend starting with GIFs, revisit if memory pressure complaints come in.
2. **Cache eviction policy?** Recommend 100MB LRU cap in `Caches/` directory. URLCache works for this.
3. **YouTube link freshness?** YouTube URLs can go dead. Curate from authoritative channels (Alan Thrall, Jeff Nippard) and plan annual audit.
