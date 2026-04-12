# Product Review Log

Periodic product + engineering reviews. Every 10 cycles of the self-improvement loop.

---

## Review #1 — 2026-04-12 (Cycle 10)

### Product Designer Persona
_Background: 2yr each at MyFitnessPal, Whoop, MacroFactor, Strong, Boostcamp_

#### Competitive Landscape (April 2026)

| App | Recent Moves |
|-----|-------------|
| **MyFitnessPal** | AI photo-based meal scanning (take a photo, get macros), ChatGPT integration for nutrition Q&A, meal planner with dietitian-reviewed recipes, full app redesign in progress |
| **Boostcamp** | Bodyweight tracker linked to lifting analytics, muscle engagement visualization per program/workout, workout notes |
| **Whoop** | Behavior Insights (connect habits to Recovery scores with 90-day data), Advanced Labs Uploads (PDF/screenshot upload, any language), healthspan focus with proactive biomarker tracking |
| **Strong** | Templates search, measurement widgets, exercise renaming, simple timers. Staying minimal and focused. |
| **MacroFactor** | Launched separate MacroFactor Workouts app, expenditure modifier with step-informed data, micronutrient tracking, Apple Health integration coming |

#### Drift Strengths
1. **AI chat is genuinely unique.** No competitor has on-device conversational AI for health tracking. MFP's ChatGPT integration is cloud-based and limited to recipes/Q&A — it can't log food, start workouts, or cross-reference your data. Drift's AI can do all of this locally.
2. **Cross-domain coverage in one app.** Food + weight + exercise + sleep + supplements + glucose + biomarkers + body comp + cycle tracking. Competitors are single-domain or require multiple apps.
3. **Privacy as a feature.** Zero cloud, zero accounts. In 2026 where MFP sends your data to ChatGPT and Whoop uploads labs to their servers, "everything stays on your phone" is a real differentiator.
4. **Dual-model tiered pipeline** is architecturally sound. Tier 0 instant rules handle 60-70% of queries with zero latency. Smart fallback to LLM when needed.

#### Drift Gaps vs Competitors
1. **Food DB breadth** — 1041 foods vs MFP's 14M+. This is the #1 user-facing gap. Common foods are covered but long tail is missing.
2. **Photo food logging** — MFP now has AI photo scanning. This is becoming table stakes for nutrition apps. Drift has no photo input.
3. **Visual exercise presentation** — Boostcamp has muscle group diagrams and engagement visualization. Drift has 873 exercises but text-only. Major visual gap.
4. **Behavior-outcome insights** — Whoop connects daily behaviors to Recovery with statistical evidence. Drift has cross-domain queries but no automated insight generation (e.g., "you sleep 23 min more on days you don't eat after 8pm").
5. **Adaptive calorie targets** — MacroFactor's expenditure algorithm adjusts targets based on real weight trends + step data. Drift has static TDEE.
6. **UI polish** — MFP is redesigning. Strong is famously clean. Drift's UI is functional but rough compared to these polished apps.

#### New Ideas
1. **Automated behavior insights** — "Your weight drops faster in weeks where you log 5+ workouts." Correlate food/exercise/sleep patterns with weight trends. Low-lift with existing cross-domain data.
2. **Lab PDF upload with on-device OCR** — Whoop just launched this. We already have biomarker tracking + VisionKit is built into iOS. Natural extension.
3. **Muscle group heatmaps** — Boostcamp's muscle engagement view but for workout history. "This week: heavy chest/back, light legs." Visual and motivating.
4. **Adaptive TDEE** — Use actual weight trend data to back-calculate true expenditure and auto-adjust calorie targets. This is MacroFactor's killer feature.

#### Proposed Roadmap Changes
- Promote **Adaptive TDEE** from Later to Now (Weight section) — it's a differentiator and we have the weight trend data
- Add **Automated behavior insights** to Now (new section) — low effort, high perceived value
- Move **Photo food logging** from Next to Now (Food section) — table stakes in 2026
- Add **Muscle group heatmaps** to Next (Exercise section) — medium effort, high visual impact

---

### Principal Engineer Persona
_Background: 10yr each at Amazon and Google_

#### Assessment of Designer's Proposals

**Agree: Adaptive TDEE → Now.** This is achievable. We have `WeightTrendService` with trend calculation and `NutritionService` with daily calorie data. The algorithm is: compare predicted weight loss (based on logged calories vs TDEE) to actual weight trend, compute the delta, adjust TDEE estimate. MacroFactor published their approach — it's a moving average, not rocket science. Can be a pure service with tests. **Ship it.**

**Agree: Automated behavior insights → Now, but scoped tightly.** Don't build a general correlation engine. Start with 3-5 hardcoded insights: (1) workout frequency vs weight trend, (2) protein hitting target vs weight trend, (3) sleep duration vs recovery score. Each is a single SQL query over existing tables. Display on dashboard as a card. No ML, no statistical significance testing — just descriptive stats with thresholds. **Ship the simple version.**

**Push back: Photo food logging → Now.** This requires Core ML integration, a food classification model, UI for photo capture + result confirmation, and accuracy that won't embarrass us. MFP uses cloud AI for this — their model is huge. On-device food classification models (MobileNetV3 fine-tuned on food) exist but accuracy on Indian food, mixed dishes, and restaurant plates is poor. We'd ship a feature that works for a banana and fails for dal makhani.

**Counter-proposal:** Keep photo food logging in Next. Instead, prioritize **barcode scanning coverage** (we have the scanner but limited DB) and **voice input via iOS SpeechRecognizer** (text-to-speech → pipe to existing AI chat). Voice is higher ROI: it makes the AI chat faster, works with our existing pipeline, and requires no new model. SpeechRecognizer is on-device in iOS 17+.

**Agree: Muscle group heatmaps → Next.** Good visual feature but not urgent. Our exercise DB has muscle group tags — the data is there. When we get to it, it's a view layer addition, not an architectural change.

#### Technical Sustainability Check

Current architecture is solid for Phase 3c goals:
- **GRDB + SQLite** handles all data needs. No ORM migration risk.
- **Tiered AI pipeline** is the right design. Tier 0 rules keep latency low while LLM handles complex queries.
- **Concern: WeightViewModel stale state pattern** (the LB/KG bug). This isn't just a unit bug — it's a pattern where `@Observable` view models capture `Preferences.*` at init and never re-read. Audit all view models for this pattern when fixing the bug. Don't just fix WeightViewModel — fix the pattern.
- **Test count (729+) is healthy** but coverage has gaps. The coverage-check hook is the right forcing function. Keep it.

#### Sequencing Recommendation
1. **Fix LB/KG bug + audit stale preference pattern** (current sprint P0 — already identified)
2. **Adaptive TDEE** (new service + tests, ~2 cycles)
3. **3-5 hardcoded behavior insights on dashboard** (~1-2 cycles)
4. **UI polish pass** (ongoing, every cycle)
5. **Voice input** via SpeechRecognizer → AI chat pipe (Phase 4 pull-forward, ~2-3 cycles)

---

### Consensus & Roadmap Updates

Both personas agree on:
1. **Adaptive TDEE → Now** in Weight section
2. **Behavior insights (scoped) → Now** as new section
3. **Photo food logging stays in Next** — voice input is higher ROI for Phase 3c
4. **Voice input pulled forward** from Phase 4 to late Phase 3c / early Phase 4
5. **Muscle group heatmaps → Next** in Exercise section
6. **Stale preference pattern audit** added to Quality Now section
