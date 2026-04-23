# Team Structure

## Hierarchy

```
Stakeholder
│
│   Strategic decisions, requirements, sign-off
│
└── Claude Opus (Architect)
    │
    │   System design, data model, ADRs, technical direction
    │   Reads the full GitHub repo before making decisions
    │
    ├── Human Dev
    │   │
    │   │   Org auth, secrets, code review, judgment calls
    │   │   Final authority on what ships
    │   │
    │   └── Claude Code (Developer)
    │
    │           Implementation, Apex, LWC, tests, CI
    │           Works from Architect specs and Human Dev direction
```

---

## Roles

### Stakeholder
- Owns the business requirements
- Makes product decisions
- Reviews and approves milestones
- See [TODO_STAKEHOLDER.md](TODO_STAKEHOLDER.md)

### Claude Opus — Architect
- Designs the system before Claude Code implements anything
- Owns the data model, integration patterns, and component hierarchy
- Reads the full repo on each session before acting
- Logs all decisions in [TODO_ARCHITECT.md](TODO_ARCHITECT.md) and the Decisions Log in [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)

### Human Dev
- Authenticates and manages Salesforce orgs
- Reviews all code before it merges
- Resolves ambiguity between Stakeholder requirements and technical constraints
- Has final say on what gets deployed
- See [TODO_HUMAN_DEV.md](TODO_HUMAN_DEV.md)

### Claude Code — Developer
- Implements from Architect specs
- Writes Apex, LWC, tests, and CI config
- Never pushes to non-scratch orgs without Human Dev approval
- Flags governor limit risks before writing code
- See [TODO_CLAUDE_CODE.md](TODO_CLAUDE_CODE.md)

---

## Decision Flow

```
Business question → Stakeholder
Technical question → Human Dev → Claude Opus if design needed
Implementation question → Claude Code → Human Dev to confirm
```

## Escalation

If Claude Code is blocked → update Blocked table in [TODO_CLAUDE_CODE.md](TODO_CLAUDE_CODE.md)  
If a design decision is needed → add to [TODO_ARCHITECT.md](TODO_ARCHITECT.md)  
If a business decision is needed → add to [TODO_STAKEHOLDER.md](TODO_STAKEHOLDER.md)
