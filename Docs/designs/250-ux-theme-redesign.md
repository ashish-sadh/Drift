# Design: Drift UX & Theme Redesign

> Issue: #250 | Status: Awaiting approval — do NOT implement until direction is chosen

## What's boring about the current theme

The existing design is functional dark-mode with a violet accent (#8B7CF6) on near-black (#0E0E12). Problems:

1. **Generic palette.** Violet + near-black is the default "dark fitness app" aesthetic (used by Strong, Hevy, Cronometer). Nothing about it says *Drift*.
2. **Flat information density.** The 5-tab structure puts everything behind equal-weight tabs. The AI chat tab — which is the *showstopper feature* — is buried in "More".
3. **Macro color soup.** 10+ domain colors (calorie blue, protein red, carbs green, fat yellow, etc.) compete for attention. No visual hierarchy between what matters and what's detail.
4. **Cards feel samey.** Every section is the same dark card with a 0.5pt border. No breathing room, no contrast between hero stats and secondary info.
5. **Typography is utilitarian.** Rounded large titles look friendly but generic — no distinct voice or rhythm.

---

## Design Directions

Three distinct directions to evaluate. **Pick one before any implementation begins.**

---

### Direction A — "Warm Mineral"

**Vibe:** Premium wellness app. Think Oura Ring meets a high-end journal. Less "gym bro", more "mindful health tracking."

**Palette:**
- Background: Warm charcoal `#1A1714` (red-tinted black, not blue-tinted)
- Card: `#252019` with 1pt `#4A3F2F` border
- Primary accent: Amber gold `#F5A623` — used sparingly for CTAs and active states
- Secondary: Muted terracotta `#C97B5E`
- Semantic: Same green/red for surplus/deficit (these are non-negotiable per tenets)
- Text: Warm white `#F5EFE6` primary, `#A89880` secondary

**Typography:** Serif display for dashboard hero numbers (Georgia or New York). Keeps body text in SF Pro. Creates distinction between "at-a-glance value" (serif, large) and "detail" (sans-serif, small).

**Tab structure change:** Relocate AI chat to a persistent floating action button (FAB) at the bottom center — always visible, not buried in a tab. Reduces tab bar to 4 tabs: Dashboard, Log, Workouts, More.

**Character:** Feels like a leather-bound journal. Earthy, warm, calm. Good for users who want health tracking to feel like self-care, not training data.

---

### Direction B — "Neon Midnight"

**Vibe:** High-energy, data-forward, sports performance. Think Nike Training Club meets a Bloomberg terminal.

**Palette:**
- Background: True black `#000000`
- Card: `#0D0D0D` with neon border on active/highlighted only
- Primary accent: Electric teal `#00F5D4` (on black = high contrast, no fatigue)
- Secondary: Hot coral `#FF3366`
- Gradient: Teal→coral on hero elements (replaces current violet→coral)
- Semantic: Teal for deficit, coral for surplus (ties into the main palette)
- Text: Pure white `#FFFFFF` primary, `#888888` secondary

**Typography:** All SF Pro, but with extreme size contrast: hero stats at 48pt bold, labels at 11pt. Numbers *pop*.

**Tab structure change:** Replace the "Drift" dashboard tab with a full-screen AI chat as the *first* tab (renamed "Chat"). Dashboard summary becomes a contextual header *within* the chat view (slides in as a card when relevant). Everything else stays.

**Character:** Fast, sharp, athletic. Good for gym-focused users who want a tool that feels as serious as their training. The AI chat restructuring makes the showstopper feature impossible to miss.

---

### Direction C — "Soft System" (iterative, lowest risk)

**Vibe:** Polished but approachable. Modern iOS design language, elevated. Think Apple Health if it had personality.

**Palette:**
- Background: Keep `#0E0E12` (works well, not broken)
- Card: Subtle gradient `#1A1B24` → `#1E1F2E`, no border (gradient creates depth without a line)
- Primary accent: Shift violet to **indigo** `#6366F1` (less saturated, feels more premium)
- Secondary: Keep coral `#FF6B8A` for highlights
- Domain colors: Consolidate from 10 to 4: calorie orange, macro neutral-white, goal-green, against-goal-red. Everything else uses indigo.
- Text: Unchanged

**Typography:** Keep SF Pro. Add large decorative numbers in a tabular variant with tight tracking for dashboard stats. No font change, just better size ramp.

**Tab structure change:** Move AI chat to **tab 1** (swap with Dashboard). Dashboard becomes tab 2. No other structural changes.

**Character:** Familiar iOS aesthetic, elevated. Safe for users who resist novelty. Easiest to implement — 80% of the impact comes from the tab restructure and macro color consolidation.

---

## Approval Gate

This doc defines three directions. **Do not proceed to implementation until the owner picks a direction.**

Steps after approval:
1. Owner selects A, B, or C (comment on issue #250)
2. Generate mockup screens for the selected direction (Claude Artifacts or Figma) showing: Dashboard, AI Chat, Exercise Detail, Food Log
3. Owner approves mockups
4. Create SENIOR implementation issue with scope, file list, and rollout plan
5. Implement behind a feature flag so the old theme can be toggled for regression testing

**Figma / Claude design generation:** Claude Code can generate SwiftUI previews with the new palette/typography. For Figma-style visual comps, use Claude.ai's Artifacts feature or provide the color tokens to a Figma template.

---

## Constraints (non-negotiable)

- Green = deficit (goal-aligned), Red = surplus (against goal) — these colors cannot change
- Indian food must remain legible in all food lists under the new theme (test with long names like "Paneer Butter Masala")
- AI chat must be *more prominent* in the new structure, not less
- Privacy-first: no cloud theme sync, no analytics on which theme variant is selected
- Dark mode only — no light mode variant

---

## Recommendation

**Start with Direction C** (Soft System) to reduce risk, then revisit A or B for v2 after user feedback. The tab restructure (Chat → tab 1) is the single highest-leverage change regardless of palette direction.

If the owner wants a bold swing: **Direction B** (Neon Midnight) is the most differentiated and pairs best with the AI-first positioning.
