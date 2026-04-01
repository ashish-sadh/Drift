# UI Improvements Queue

### UI-001 [HIGH] Accent color too saturated
- **Current**: #8B5CF6 (bright purple, reads as "AI-generated")
- **Proposed**: #A78BFA (softer indigo, more premium, less harsh on dark backgrounds)
- **Rationale**: Current purple is 100% saturated which strains the eye on dark mode. Professional health apps use more muted tones. The proposed color maintains the purple identity but feels more sophisticated.
- **Files**: Theme.swift line 9 (single source, all views auto-update)

### UI-002 [HIGH] Templates list too bulky
- **Current**: Each template row has a big purple "Start" pill button
- **Proposed**: Remove explicit Start button, use tap-to-start + context menu. Show subtle chevron instead.
- **Files**: WorkoutView.swift lines 99-157

### UI-003 [MEDIUM] Macro chip opacity inconsistent
- **Current**: 0.08 in DashboardView, 0.1 in FoodTabView
- **Proposed**: Standardize to 0.1

### UI-004 [LOW] Button corner radius mixed (8 vs 10)
- Standardize to 10pt for buttons/inputs
