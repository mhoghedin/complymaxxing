# CLAUDE.md — CPQ Quote Machine

## Project

Salesforce CPQ subscription management and document generation platform.

## Repo Structure

```
/
├── salesforce/          # SFDX project
├── azure-app/           # Python/Flask integration layer
├── docs/                # Project management docs
└── .devcontainer/       # Devcontainer config
```

## Salesforce Orgs

| Org | Alias | Purpose |
|---|---|---|
| Dev Hub | `devhub` | Scratch org management |
| Scratch | TBD | Active development |

## Key Commands

```bash
# Auth
sf org login web --alias devhub --set-default-dev-hub
sf org create scratch --definition-file salesforce/config/project-scratch-def.json --alias dev --set-default

# Deploy / retrieve
sf project deploy start
sf project retrieve start

# Open org
sf org open

# Run tests
sf apex run test --synchronous
```

## Apex Standards

- All Apex must be bulkified — no SOQL or DML inside loops
- Every class needs a test class with 85%+ coverage minimum
- Use `@TestVisible` over public access modifiers for test access
- No hardcoded IDs or endpoints anywhere

## Governor Limits — Check Before Writing Apex

| Limit | Value |
|---|---|
| SOQL queries per transaction | 100 |
| DML statements per transaction | 150 |
| Heap size (sync) | 6 MB |
| CPU time (sync) | 10,000 ms |
| Callouts per transaction | 100 |
| Future calls per transaction | 50 |

## Callouts

- All external callouts via Named Credentials — no hardcoded URLs
- Never mix DML and callouts in the same transaction — use `@future(callout=true)` or Queueable

## Deployments

- Never deploy to non-scratch orgs without Human Dev approval
- See [docs/TEAM.md](docs/TEAM.md) for decision flow

## Docs to Keep Updated

After every session update the relevant files in [docs/](docs/):
- [docs/TODO_CLAUDE_CODE.md](docs/TODO_CLAUDE_CODE.md)
- [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md)
