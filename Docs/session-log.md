# Self-Improvement Session Log

## Session 2 (April 1-2, 2026)
- **Commits**: 19, all pushed
- **TestFlight**: Build 51 published
- **Tests**: 566 → 614 (+48 new tests, 0 regressions)
- **Food DB**: 716 → 756 items (+51 added, 11 dupes removed, names cleaned)
- **Exercise DB**: 884 → 907 items (+23 added, 4 dupes removed, 21 capitalization fixes)

### Changes
- TDEE base formula soft-capped at 2700 to prevent 3000+ without profile data
- 14 comprehensive TDEE demographic tests (all age groups, weight×activity matrix)
- Dashboard TDEE card shows data source chips + "Add data to improve" hint
- VoiceOver accessibility labels added to dashboard (weight, health pills, recovery)
- Food DB: Chipotle, Panda Express, Chick-fil-A, Popeyes, Five Guys, In-N-Out, Shake Shack, Dunkin', Domino's, common US home-cooked, Asian, Indian snacks, healthy staples, vegetables
- Exercise DB: Bulgarian Split Squat, Chest Fly, Seated Row, Pendlay Row, Ab Wheel, Hip machines, Dragon Flag, L-Sit, Pike Push-Up, machine presses, cable exercises
- Fixed HRV trend detection (all sequential pairs, not just first < last)
- Fixed 3 flaky workout session tests (UserDefaults race conditions)
- Fixed factory reset: now clears TDEE config, exercise favorites, TDEE cache
- Fixed WeightGoal off-main-thread TDEE fallback (now uses soft cap)
- Fixed MoreTabView missing dark background
- Barcode scanner: ml serving size support for liquids
- Lab report OCR: month-name date formats (Mar 15, 2026) + 5 tests
- Dynamic version string from bundle
- Food DB cleaned: 11 duplicates removed, lowercase names capitalized, eggplant recategorized
- Exercise DB: equipment/category capitalization normalized (21 fixes)
- Dead comments removed from DashboardView

---

## Session 1 (March 29-30, 2026)
- **Commits**: 33 total, all pushed to remote
- **TestFlight**: Builds 48 + 49
- **Tests**: 575 passing (4 new)
- **Food DB**: 681 → 714 items (+33)
- **Exercise DB**: 873 → 884 items (+11)
- **0 regressions**

### Highlights
- Fixed launch screen white flash (missing color asset)
- Accent color refined (#A78BFA — softer, less "AI")
- Templates compacted (play icon instead of big Start button)
- Delete confirmations on templates + workouts
- Settings health buttons now show success/error + descriptions
- Factory reset shows confirmation alert
- Sleep fetching deduplicated (-47 lines)
- HealthKit query helper extracted (-18 lines)
- Food data cleaned (broken entries fixed, categories merged)
- Fast food added (McDonald's, Starbucks, Taco Bell, Wendy's)
- Indian foods expanded (korma, vindaloo, dahi, jalebi, etc.)
- Exercises added (Turkish get-up, farmer's walk, battle ropes, etc.)
- Goal edit button in toolbar
- Copy previous day shows calorie count
- Template preview shows last-used weights
- Recovery estimator tests added
- Manual food entry validates numeric input
- Force unwrap removed from GlucoseTabView
