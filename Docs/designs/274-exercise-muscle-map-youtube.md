# Design: Exercise Muscle Map + YouTube Curation

> Issue: #274 | Status: Design

## Problem

ExerciseDetailView shows primary/secondary muscles as a plain text list. Users can't visualize *which* muscles are being worked. The existing YouTube URLs are YouTube search queries, not curated videos — they open a search results page, not a specific trusted video.

## Current State

- **960 exercises**, 932 with `imageUrl` (free-exercise-db JPGs)
- **33 exercises** with `youtubeUrl` — all are YouTube search query URLs, not pinned videos
- `primaryMuscles` and `secondaryMuscles` are populated across the database (17 unique muscle names)
- `ExerciseDetailView` lists muscles as comma-separated text
- `BodyMapView` shows 6 grouped body parts for recovery — not per-muscle

---

## Decision 1: Muscle Body Map

### Options

| Option | Pros | Cons |
|--------|------|------|
| SVG in WKWebView | Most anatomically accurate, interactive | WKWebView startup cost, web dependency, harder to theme |
| SwiftUI Canvas paths | Native, themeable, offline, fast | Manual path drawing for 17 muscles = significant art effort |
| Static image overlays (front + back PNGs) | Zero art effort if sourced from open data | Less precise highlighting, hard to theme for dark mode |
| SF Symbols only (no body map) | Zero effort | Doesn't answer the ask; just a grid of icons |

### Recommendation: Two-panel SVG rendered as SwiftUI Image via CoreGraphics

Use **pre-rendered SVG source → PNG assets at 3x** for each of the 17 muscles (front-view and back-view silhouettes). Compose them as SwiftUI `ZStack` layers:

1. Base body outline (front or back, gray)
2. Primary muscle highlight layer (Theme.accent, full opacity)
3. Secondary muscle highlight layer (Theme.accent, 40% opacity)

This keeps WKWebView out of the picture, works fully offline, and respects the dark theme.

**Open source asset:** [musclewiki-svg](https://github.com/nicholasgasior/musclewiki-svg) — MIT licensed front/back SVG with named paths per muscle group. Convert muscle paths to separate PNG layers with a one-time Python/CairoSVG script. These can be bundled as `Assets.xcassets` image sets.

### Muscle → View mapping

| View | Muscles |
|------|---------|
| Front | chest, abdominals, quadriceps, biceps, forearms, adductors, shoulders (anterior), neck |
| Back | lats, hamstrings, glutes, traps, lower back, middle back, triceps, calves, abductors, shoulders (posterior) |

Since `shoulders` appears on both views, render it on both panels when selected.

### UI placement

In `ExerciseDetailView`, replace the current plain-text muscle list with a **MuscleMapView** component:

```
┌─────────────────────────────────┐
│  [Front body]   [Back body]     │
│   primary: blue highlight       │
│   secondary: dim blue           │
│                                 │
│  Primary: Chest, Triceps        │
│  Secondary: Shoulders           │
└─────────────────────────────────┘
```

- Both front and back shown side by side (each ~120pt wide)
- Text labels below as before (keep for accessibility)
- No interaction required (tap-to-zoom is V2)

### Component API

```swift
struct MuscleMapView: View {
    let primaryMuscles: [String]    // ["chest", "triceps"]
    let secondaryMuscles: [String]  // ["shoulders"]
}
```

### Asset generation script (one-time)

```bash
# scripts/generate_muscle_layers.py
# Input: musclewiki front.svg + back.svg
# Output: Assets.xcassets/MuscleMap/{muscle}-front.imageset, etc.
# CairoSVG extracts each named path as transparent PNG with fill color
```

---

## Decision 2: YouTube Video Curation

### Current problem

All 33 YouTube URLs are search queries (`youtube.com/results?search_query=...`). Tapping "Form Tutorial" drops the user into YouTube search — not a specific high-quality video. This is worse than nothing for trust.

### Approach: Replace search queries with pinned video IDs

Target: **top 50 most-logged exercises** (legs/arms/shoulders/back/chest/core). Use `youtube.com/shorts`-style links are not available for form tutorials; use `youtu.be/<videoId>` which opens the YouTube app directly.

**Curation criteria:**
1. Video must be from a trusted channel (see below)
2. Must show the full movement from at least 2 angles
3. Prefer videos under 5 minutes (pure form content, no intro padding)
4. No monetization gate / paywall

**Trusted channels (MIT/permissive embedding, no ToS conflict):**

| Channel | Best for |
|---------|---------|
| Jeff Nippard | Compound lifts, evidence-based cues |
| Alan Thrall | Barbell fundamentals (squat, deadlift, press) |
| Renaissance Periodization (Dr. Mike) | Hypertrophy technique |
| Athlean-X | Isolation exercises, cable work |
| FitnessFAQs | Bodyweight / calisthenics |

**Curation plan:** 50 exercises manually curated by a human (not automated). Update `exercises.json` `youtubeUrl` field. No API key needed — URLs opened via iOS `Link` → YouTube app / SFSafariViewController (already wired in `ExerciseDetailView`).

**Maintenance:** YouTube URLs rarely go dead on major channels. Annual audit via a script that checks `curl -I` status codes on the 50 URLs.

### Priority list (top 50 by body part)

**Compound / must-have:**
Barbell Squat, Deadlift, Romanian Deadlift, Bench Press, Incline Bench Press, Overhead Press, Pull-Up, Barbell Row, Power Clean, Front Squat, Hip Thrust

**Legs (11):**
Leg Press, Hack Squat, Goblet Squat, Leg Extension, Leg Curl, Walking Lunges, Calf Raise, Bulgarian Split Squat, Step-Up, Sumo Deadlift, Box Jump

**Chest (5):**
Dumbbell Fly, Cable Crossover, Push-Up, Dips, Incline Dumbbell Press

**Back (5):**
Lat Pulldown, Seated Cable Row, Face Pull, Dumbbell Row, Straight-Arm Pulldown

**Shoulders (5):**
Lateral Raise, Arnold Press, Rear Delt Fly, Dumbbell Shoulder Press, Cable Lateral Raise

**Arms (6):**
Bicep Curl, Hammer Curl, Preacher Curl, Tricep Pushdown, Skull Crusher, Close-Grip Bench Press

**Core (4):**
Plank, Hanging Leg Raise, Ab Wheel Rollout, Russian Twist

---

## Implementation Plan

### Phase 1 — Muscle Map (1 day SENIOR)

1. **Asset generation** (~2h): run `generate_muscle_layers.py`, produce front/back PNG layers per muscle, add to `Assets.xcassets`
2. **MuscleMapView** (~2h): SwiftUI ZStack compositing front+back panels, primary/secondary highlight logic
3. **ExerciseDetailView** update (~30 min): replace text-only muscle section with `MuscleMapView`

### Phase 2 — YouTube curation (2–3h human task)

1. Manually find and verify 50 video URLs (human curation, not automatable)
2. Update `exercises.json` with `youtubeUrl` for each
3. Remove the 33 placeholder search-query URLs — replace with real links or delete

### Phase 3 — BodyMapView upgrade (optional, V2)

Reuse `MuscleMapView` in `BodyMapView` to replace the icon grid with an actual body diagram showing recovery status per muscle. Currently out of scope — the icon grid works fine.

---

## Go / No-Go

**GO on Phase 1 (Muscle Map).**
- Asset source is MIT-licensed, one-time generation script
- MuscleMapView is self-contained, zero network calls, zero model changes needed
- Highest visual impact in the app: makes exercise detail actually informative

**GO on Phase 2 (YouTube curation) — human-only task.**
- Takes a human ~2–3h to vet and fill in 50 video URLs
- Do not automate: automated URL selection will pick wrong videos or search-result pages
- Create a GitHub issue for a human to fill these in

**NO on WKWebView / interactive SVG for now.**
- Added complexity not justified for V1 of this feature
- PNG layer approach achieves 90% of the visual benefit with 10% of the complexity

---

## Open Questions

1. **musclewiki-svg license verified?** Check `LICENSE` file before committing assets. If not MIT, alternative: OpenStax Anatomy textbook SVGs (CC BY 4.0).
2. **Dark mode contrast:** Test primary muscle highlight color against dark background — `Theme.accent` at full opacity may need adjustment for the body map context vs UI buttons.
3. **Muscle name normalization:** `exercises.json` uses `"lower back"` and `"middle back"` — confirm the SVG asset has matching path IDs or build a mapping table.
