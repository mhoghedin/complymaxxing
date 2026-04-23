# Project Overview — CPQ Quote Machine

## What We're Building

A Salesforce CPQ subscription management and document generation platform.

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

## Open Questions
