# Claude Code TODO

## Up Next

- [ ] Verify `SBQQ__HeaderContent__c` / `SBQQ__FooterContent__c` field names against installed CPQ version in org
- [ ] Add common merge field tokens to `DocGenRendererCtrl.buildMergeMap` once template content is known

## In Progress

## Blocked

| Item | Blocked By |
|---|---|
| Deploy and test contract renewal job | Human Dev: scratch org auth + CPQ installed + finalized Status value set in Custom Metadata |
| Deploy and test DocGen | Human Dev: scratch org auth + CPQ installed |

## Done

| Date | Item |
|---|---|
| 2026-04-23 | Scaffold Salesforce SFDX project |
| 2026-04-23 | Build automated contract renewal merging job (ContractRenewalScheduler, Queueable, Service, IRenewalApi/CpqRenewalApi, ContractRenewalConfig, 3 test classes, Custom Metadata Type, 2 Contract fields) |
| 2026-04-23 | Build DocGen multi-contract subscription document generator (DocGenWizard LWC, DocGenController, DocGenService, DocGenRendererCtrl, DocGenRenderer VF, wrappers, 2 test classes, DocGen_Request__c + DocGen_Line__c objects) |
