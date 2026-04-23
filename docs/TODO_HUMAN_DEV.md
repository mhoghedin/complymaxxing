# Human Dev TODO

## Up Next

- [ ] Authenticate Dev Hub: `sf org login web --alias devhub --set-default-dev-hub`
- [ ] Create scratch org: `sf org create scratch --definition-file salesforce/config/project-scratch-def.json --alias dev --set-default`
- [ ] Install CPQ managed package into scratch org
- [ ] Set finalized Contract Status value in `salesforce/force-app/main/default/customMetadata/ContractRenewalConfig.Default.md-meta.xml`
- [ ] Deploy metadata: `sf project deploy start`
- [ ] Schedule the renewal job via Anonymous Apex: `System.schedule('Contract Renewal Merger', '0 0 2 * * ?', new ContractRenewalScheduler());`
- [ ] Run tests: `sf apex run test --synchronous`

## In Progress

## Blocked

| Item | Blocked By |
|---|---|

## Done

| Date | Item |
|---|---|
