# Project Overview — CPQ Quote Machine

## What We're Building

A Salesforce CPQ subscription management and document generation platform. Uses a "Contract per transaction" model (1 Opp = multiple Contract records). Two core features:

1. **Contract Renewal Merger** — a nightly scheduled Apex job that automatically groups contracts by Account + Expiration_Date__c and merges them into a single renewal opportunity via the CPQ API, preserving CSM activity history on the original opp.
2. **DocGen Wizard** — an LWC wizard that lets reps select multiple Contracts, preview subscription data grouped by a configurable field (Site or Product), pick a CPQ Quote Template, and generate a PDF attached to each selected Contract.

## Tech Stack

| Layer | Technology |
|---|---|
| CRM / Backend | Salesforce (SFDX) |
| Frontend | Lightning Web Components (LWC) |
| PDF Generation | Visualforce (renderAs="pdf") |
| CPQ API | SBQQ.ServiceRouter |
| AI | Claude (Anthropic) |

## Architecture Overview

### Feature 1 — Contract Renewal Merger

```
ContractRenewalScheduler (Schedulable)
  └── queries Contract WHERE Contract_Status2__c = 'Contracted'
        AND SBQQ__RenewalOpportunity__c = null
  └── groups by AccountId + Expiration_Date__c
  └── enqueues ContractRenewalQueueable per group

ContractRenewalQueueable (Queueable + AllowsCallouts)
  └── ContractRenewalService.processGroup()
        └── CpqRenewalApi.renewContracts()
              └── SBQQ.ServiceRouter.load(ContractRenewer) per contract
              └── merges line items in memory
              └── SBQQ.ServiceRouter.save(QuoteSaver) → creates 1 Opp + Quote
        └── if existing renewal opp: reparentQuote() → delete new opp
        └── sets SBQQ__RenewalOpportunity__c on all contracts in group
```

### Feature 2 — DocGen Wizard

```
LWC: docGenWizard (4-step wizard)
  Step 1: multi-select Contracts (same-account validation)
  Step 2: group by (Site / Product — driven by DocGen_Group_Option__mdt)
  Step 3: live subscription preview table
  Step 4: pick CPQ Quote Template → Generate PDF

Apex: DocGenController
  └── getAvailableTemplates()
  └── getSubscriptionPreview()
  └── generateDocument()
        └── queries SBQQ__Subscription__c WHERE SegmentIndex__c = 1
        └── inserts ContractDocumentRequest__c + ContractDocumentLine__c (staging)
        └── PageReference(ContractDocumentRenderer).getContent() → PDF blob
        └── inserts ContentVersion + ContentDocumentLink per Contract
        └── deletes staging records (try/finally)

VF: ContractDocumentRenderer
  └── reads SBQQ__QuoteTemplate__c header/footer HTML at runtime
  └── renders subscription table between template header and footer
```

## Key Classes

| Class | Purpose |
|---|---|
| `ContractRenewalScheduler` | Schedulable entry point — queries and groups contracts |
| `ContractRenewalQueueable` | Async CPQ API caller — one group per job chained |
| `ContractRenewalService` | Core renewal logic — processGroup, reparentQuote |
| `CpqRenewalApi` | SBQQ.ServiceRouter wrapper — load ContractRenewer, save QuoteSaver |
| `ContractRenewalConfig` | Loads ContractRenewalConfig__mdt settings |
| `IRenewalApi` | Interface for test mocking of CpqRenewalApi |
| `DocGenController` | LWC Apex controller — preview, template list, PDF generation |
| `DocGenService` | Subscription query, grouping, staging record load |
| `DocGenRendererCtrl` | VF controller — reads template HTML, loads staging data |
| `DocGenGroupWrapper` | Wrapper for grouped subscription data (AuraEnabled) |
| `DocGenLineWrapper` | Wrapper for individual subscription lines (AuraEnabled) |

## Custom Metadata Types

| CMT | Purpose |
|---|---|
| `ContractRenewalConfig__mdt` | Job cron, query limit (scheduler is not yet deployed) |
| `DocGen_Group_Option__mdt` | Grouping field options for DocGen wizard (Site, Product) |
| `DocGen_Template_Field__mdt` | CPQ template field API names for header/footer injection |

## Environments

| Org | Purpose | Alias |
|---|---|---|
| Dev Hub | Scratch org management | `devhub` |
| Partial Sandbox | Initial deploy target | `sandbox` (wkhealth-csc--pc) |
| Full Sandbox | Confirmed CPQ working — use for renewal testing | TBD |
| Production | Live | TBD |

## Deployment Status

| Component | Partial Sandbox (pc) | Full Sandbox | Notes |
|---|---|---|---|
| Contract Renewal classes (excl. Scheduler) | ✅ Deployed | ⬜ Pending | Scheduler held back intentionally |
| ContractRenewalScheduler | ⬜ Not deployed | ⬜ Not deployed | Deploy only when ready to go live |
| DocGen classes + VF + LWC | ✅ Deployed | ⬜ Pending | |
| Custom Metadata records | ✅ Deployed | ⬜ Pending | Finalized_Status__c needs org-specific value |

## Repo Structure

```
/
├── salesforce/          # SFDX project (force-app metadata)
├── docs/                # Project documentation (you are here)
└── .devcontainer/       # Codespace / devcontainer config
```

## Decisions Log

| Date | Decision | Made By | Rationale |
|---|---|---|---|
| 2026-04-23 | Contract per transaction model (1 Opp = multiple Contracts) | Business | Align contract teams across orgs |
| 2026-04-23 | Nightly job merges contracts by Account + Expiration_Date__c into one renewal opp | Claude Code / Architect | Avoids manual merge at renewal; preserves CSM activity on original opp |
| 2026-04-23 | CPQ ContractRenewer → re-parent quote to existing opp → delete new opp | Claude Code | Keeps persistent renewal opp that CSMs log notes on months in advance |
| 2026-04-23 | Use SBQQ.ServiceRouter as CPQ API entry point | Claude Code | Only globally accessible CPQ API from unmanaged Apex |
| 2026-04-23 | DocGen uses runtime template injection from SBQQ__QuoteTemplate__c | Claude Code | Rep picks real CPQ template; header/footer auto-updates when admin changes template |
| 2026-04-23 | Group-by field and template field names driven by Custom Metadata | Claude Code | Extensible without code changes; admin can add new grouping options |
| 2026-04-28 | ContractRenewalScheduler not deployed to sandbox | Matt | Control when job runs during testing; deploy only when ready to schedule |
| 2026-04-28 | Use SBQQ__RenewalOpportunity__c (native CPQ field) not custom field | Claude Code | Consistent with how CPQ itself tracks renewal opp; avoids dual-tracking |
| 2026-04-29 | Demote old primary quote in @future (separate tx), not same tx as reparent | Claude Code | CPQ's QuoteAfter trigger is finicky during calculation sequence; separate tx avoids row-lock contention |

## Open Questions

- Full sandbox alias — needed to auth and run end-to-end renewal test
- `ContractRenewalConfig.Default` CMT record: `Finalized_Status__c` value needs to be set per org before scheduling the job
- DocGen: verify `SiteNamelabel__c` field API name in full sandbox (dynamic access used as safety net)
- DocGen: add `docGenWizard` LWC to a Lightning App page in App Builder
