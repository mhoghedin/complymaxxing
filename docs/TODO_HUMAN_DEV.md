# Human Dev TODO

## Up Next

### Option A — Scratch Org (for testing)

**Step 1: Authenticate Dev Hub**
```bash
sf org login web --alias devhub --set-default-dev-hub
```
A browser window will open. Log in with your Dev Hub org credentials.

**Step 2: Create scratch org**
```bash
sf org create scratch \
  --definition-file salesforce/config/project-scratch-def.json \
  --alias dev \
  --set-default \
  --duration-days 30
```

**Step 3: Install Salesforce CPQ managed package**

You need CPQ installed before deploying — the Apex classes won't compile without it.
Get the CPQ package ID from your production org:
- Setup → Installed Packages → Salesforce CPQ → copy the Package Version ID (starts with `04t`)

Then install it:
```bash
sf package install --package <YOUR_CPQ_PACKAGE_VERSION_ID> --target-org dev --wait 20
```

**Step 4: Set the finalized Contract Status value**

Open [salesforce/force-app/main/default/customMetadata/ContractRenewalConfig.Default.md-meta.xml](../salesforce/force-app/main/default/customMetadata/ContractRenewalConfig.Default.md-meta.xml) and replace `REPLACE_WITH_YOUR_STATUS_VALUE` with the actual picklist value (e.g. `Fully Executed`).

**Step 5: Deploy all metadata**
```bash
cd salesforce
sf project deploy start
```

**Step 6: Run tests**
```bash
sf apex run test --synchronous --test-level RunLocalTests
```

**Step 7: Schedule the renewal job**

In the org's Developer Console or Anonymous Apex:
```apex
System.schedule('Contract Renewal Merger', '0 0 2 * * ?', new ContractRenewalScheduler());
```

**Step 8: Add the DocGen wizard to a Lightning page**
- Setup → Lightning App Builder
- Create or edit an App Page
- Drag the `docGenWizard` component onto the page
- Save and Activate

**Step 9: Open the org**
```bash
sf org open
```

---

### Option B — Developer Sandbox (for production use)

> Requires Human Dev approval before any sandbox deployment per TEAM.md.

**Step 1: Authenticate the sandbox**
```bash
sf org login web --alias sandbox --instance-url https://test.salesforce.com
```

**Step 2: Deploy metadata**
```bash
sf project deploy start --target-org sandbox
```
CPQ is already installed in the sandbox — no package install needed.

**Step 3: Update the finalized Contract Status value**

If not already set in metadata, update it in the org directly:
- Setup → Custom Metadata Types → DocGen Group Option / Contract Renewal Config → Manage Records

**Step 4: Run tests in sandbox**
```bash
sf apex run test --synchronous --target-org sandbox --test-level RunLocalTests
```

**Step 5: Schedule the renewal job (if not already scheduled)**
```apex
System.schedule('Contract Renewal Merger', '0 0 2 * * ?', new ContractRenewalScheduler());
```

**Step 6: Add the DocGen wizard to a Lightning page**

Same as scratch org — Lightning App Builder, drag `docGenWizard` onto a page.

---

## In Progress

## Blocked

| Item | Blocked By |
|---|---|
| Scratch org / sandbox deploy | Need CPQ package ID + finalized Contract Status value |

## Done

| Date | Item |
|---|---|
