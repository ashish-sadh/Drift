# Code Improvements Queue

### CODE-001 [TRIVIAL] Settings health button labels need descriptions
- Add subtitles: "Request Health Access" → explain what permissions, "Sync Weight" → explain it syncs since last, "Full Re-sync" → explain it re-imports all
- File: MoreTabView.swift

### CODE-002 [TRIVIAL] LabReport manual date parsing
- Replace manual month-name mapping with DateFormatter
- File: Models/LabReport.swift lines 46-56
