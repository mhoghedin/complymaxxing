# Risks

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|
| R1 | Apex CPU limit hit during quote calculation | Medium | High | Bulkify early, profile with Limits class | Claude Code | Open |
| R2 | Callout timeout on document generation | Medium | High | Async via Queueable, set timeout explicitly | Architect | Open |
| R3 | DML + callout in same transaction | High | Medium | Enforce via code review, Queueable pattern | Claude Code | Open |
| R4 | Scratch org feature gaps vs production | Low | Medium | Keep scratch def aligned with prod features | Human Dev | Open |

---

## Risk Ratings

**Likelihood:** Low / Medium / High  
**Impact:** Low / Medium / High  
**Status:** Open / Mitigated / Closed

---

## Closed Risks

| # | Risk | Resolution | Date |
|---|---|---|---|
