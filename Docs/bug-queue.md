# Bug Queue

## Open

### BUG-001 [CRITICAL] Factory reset has no success confirmation
- **File**: MoreTabView.swift lines 125, 197-226
- **Issue**: `resetDone` state is set but never shown to user. No alert, no dismiss.
- **Fix**: Add success alert after reset

### BUG-002 [MEDIUM] Health sync buttons silently fail
- **File**: MoreTabView.swift lines 149, 159, 169
- **Issue**: `try?` swallows all errors. No loading indicator, no success/failure feedback.
- **Fix**: Add loading state + success/error toast

### BUG-003 [MEDIUM] Template delete has no confirmation
- **File**: WorkoutView.swift lines 150-153
- **Issue**: Delete happens immediately, no confirmation dialog
- **Fix**: Add confirmation alert

### BUG-004 [MEDIUM] Workout delete has no confirmation
- **File**: WorkoutView.swift lines 201-204
- **Issue**: Same as BUG-003
- **Fix**: Add confirmation alert

### BUG-005 [LOW] Settings labels unclear
- **File**: MoreTabView.swift lines 153, 163, 173
- **Issue**: "Request Health Access", "Sync Weight", "Full Re-sync" have no explanation
- **Fix**: Add subtitle text explaining each

## Fixed
(none yet)
