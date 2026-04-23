# Architect TODO (Claude Opus)

## Up Next

- [ ] Review contract renewal merging implementation and validate architectural approach
- [ ] Define the full data model — custom objects, fields, relationships beyond Contract
- [ ] Define LWC component hierarchy for the quote/subscription UI
- [ ] Design integration pattern for any external systems (doc generation, e-sign, etc.)
- [ ] Review and update `salesforce/config/project-scratch-def.json` with required CPQ features/settings
- [ ] Review `RISKS.md` and add any architectural risks identified

## In Progress

## Design Decisions Made

| Date | Area | Decision | Rationale |
|---|---|---|---|
| 2026-04-23 | Contract renewal | Nightly scheduled job groups contracts by Account + Expiration_Date__c, calls CPQ renewContracts once per group, re-parents quote to existing opp and deletes duplicate | Keeps CSM notes on one persistent renewal opp; avoids manual merge at renewal time |

## Handoff to Dev
