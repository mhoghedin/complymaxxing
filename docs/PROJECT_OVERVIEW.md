# Project Overview — CPQ Quote Machine

## What We're Building

A Salesforce CPQ subscription management and document generation platform. Uses a "Contract per transaction" model (1 Opp = multiple Contract records). A nightly job automatically merges contracts by Account + expiration date into a single renewal opportunity, preserving CSM activity history.

## Goals

## Tech Stack

| Layer | Technology |
|---|---|
| CRM / Backend | Salesforce (SFDX) |
| Frontend | Lightning Web Components (LWC) |
| Integration layer | TBD |
| AI | Claude (Anthropic) |

## Architecture Overview

## Key Constraints & Salesforce Governor Limits

| Limit | Value |
|---|---|
| SOQL queries per transaction | 100 |
| DML statements per transaction | 150 |
| Heap size (sync) | 6 MB |
| CPU time (sync) | 10,000 ms |
| Callouts per transaction | 100 |
| Future calls per transaction | 50 |

## Environments

| Org | Purpose | Alias |
|---|---|---|
| Dev Hub | Scratch org management | `devhub` |
| Scratch Org | Active development | TBD |
| Sandbox | UAT / Stakeholder review | TBD |
| Production | Live | TBD |

## Repo Structure

```
/
├── salesforce/          # SFDX project (force-app metadata)
├── azure-app/           # Not in use
├── docs/                # Project documentation (you are here)
└── .devcontainer/       # Codespace / devcontainer config
```

## Decisions Log

| Date | Decision | Made By | Rationale |
|---|---|---|---|
| 2026-04-23 | Contract per transaction model (1 Opp = multiple Contracts) | Business | Align contract teams across orgs |
| 2026-04-23 | Nightly job merges contracts by Account + Expiration_Date__c into one renewal opp | Claude Code / Architect | Avoids manual merge at renewal; preserves CSM activity on original opp |
| 2026-04-23 | CPQ renewContracts → re-parent quote to existing opp → delete new opp | Claude Code | Keeps persistent renewal opp that CSMs log notes on months in advance |

## Open Questions
