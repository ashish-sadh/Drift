# Design: [Feature Name]

> References: Issue #N

## Problem

What's broken or missing? Who's affected? Include screenshots or failing queries if relevant.

## Proposal

What are we building? One paragraph summary. Be specific about scope — what's in and what's out.

## UX Flow

Step-by-step user journey. For AI chat features, include example conversations:

```
User: "example query"
AI: expected response / tool call
```

For UI features, describe screen-by-screen flow.

## Technical Approach

- Which files/services change?
- New models or database migrations?
- How does this interact with the dual-model architecture (SmolLM vs Gemma)?
- Performance considerations (on-device, no cloud)

## Edge Cases

- What happens when input is malformed?
- What happens with empty state / no data?
- Conflicts with existing features?

## Open Questions

Unresolved decisions that need human input before implementation.

---

*To approve: add `approved` label to the PR. To request changes: comment on the PR.*
