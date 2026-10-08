# SDD — Spec-Driven Development

A workflow that drives PRDs and Jira stories through OpenSpec into trackable tickets, then implements with built-in code review and a sweep that archives changes after merge. Designed for 1-N developer teams.

```
PRD ──► OpenSpec change ──► tickets ──► implementation ──► verify ──► merge ──► sweep
        (proposal/specs/    (GitHub or Jira)           (PR)         (/sdd-status)
         design/tasks)
```

## Getting started

Copy `.claude/skills/sdd-*/` and `.claude/skills/openspec-*/` into any project, then:

1. `/sdd-setup` — detects what's missing, scaffolds `sdd/` from its own bundle, runs `openspec init`, asks for the tracker, wires up MCPs. Idempotent — safe to re-run.
2. `/sdd-constitution` — interview that writes your stack, coding principles and quality gates to `sdd/constitution/`.
3. `/sdd-doctor` — read-only pre-flight check, any time.

## Modes

Set once in `sdd/config.json` — details in [docs/trackers.md](docs/trackers.md).

| Mode | tracker | vcs | Tickets | Code/PRs |
|------|---------|-----|---------|----------|
| GitHub | github | github | GitHub Issues | GitHub |
| Jira | jira | github | Jira | GitHub (PRs reference Jira keys; statuses synced to Jira) |
| Jira + Bitbucket | jira | bitbucket | Jira | Bitbucket Cloud |

The Jira mode was formerly called Hybrid.

## Which entry point?

| Situation | Skill | Input |
|-----------|-------|-------|
| Greenfield, full scope | `/sdd-from-prd <slug>-v1` (or `/sdd-staged` for multi-stage) | `sdd/prds/<slug>-v1.md` from `prd-template.md` |
| v2+ increment | `/sdd-from-prd <slug>-v2-<scope>` | `sdd/prds/<slug>-v2-<scope>.md` from `prd-template-mini.md` |
| Single Jira user story | `/sdd-tasks-from-story <KEY>` | the story itself (the skill generates the spec) |
| Trivial fix | `/openspec-propose "fix X"` then `/sdd-create-tickets <change>` | none |

Then, for every ticket: `/sdd-work <ticket>` → `/sdd-verify` → review and merge → `/sdd-status`. Walkthrough in [docs/workflow.md](docs/workflow.md); PRD writing and versioning in [docs/prds.md](docs/prds.md).

## Skills

All `sdd-*` skills except `/sdd-setup` accept `--dry-run` ([docs/workflow.md § Dry-run](docs/workflow.md#dry-run)); the openspec-* skills do not. Required args in `<angle brackets>`, optional in `[square brackets]`.

**Bootstrap & admin**

| Skill | Purpose |
|-------|---------|
| `/sdd-setup` | Configure tracker, MCPs, scaffold `sdd/`, run `openspec init`. |
| `/sdd-constitution [project-name]` | Detect codebase signals, interview, write `sdd/constitution/*.md`. |
| `/sdd-doctor` | Pre-flight diagnostic: config, tracker reachability, tools, OpenSpec state. Read-only. |
| `/sdd-status` | Project snapshot + post-merge [Completion Sweep](docs/archiving.md). |

**Planning**

| Skill | Purpose |
|-------|---------|
| `/sdd-from-prd <slug>` | PRD → OpenSpec artifacts → design challenge → tickets. |
| `/sdd-staged <slug>` | Multi-stage variant of `/sdd-from-prd`: proposes stages, cross-references tickets. |
| `/sdd-tasks-from-story <KEY>` | Jira story → OpenSpec change + one board-visible Task per goal, linked to the story. Jira mode only. |
| `/sdd-create-tickets <change>` | OpenSpec `tasks.md` → tickets with GIVEN-WHEN-THEN criteria (standalone). |

**Implementation**

| Skill | Purpose |
|-------|---------|
| `/sdd-work <ticket>` | Pick up a ticket. Self-detects Fresh / Resume / Fix-from-PR mode. |
| `/sdd-verify [ticket]` | Acceptance criteria + quality gates + code review → PR. Ticket auto-detected from the branch. |

**OpenSpec** (SDD-customised)

| Skill | Purpose |
|-------|---------|
| `/openspec-propose "description"` | Free-form artifact creation: proposal, specs, design, tasks. |
| `/openspec-apply-change [change]` | Implement directly from artifacts (alternative to the ticket flow). |
| `/openspec-archive-change [change]` | Finalise via the [archiving procedure](docs/archiving.md#archiving-procedure) → update living specs. |
| `/openspec-explore` | Thinking partner for clarifying requirements. |

## Guides

| Guide | Covers |
|-------|--------|
| [docs/workflow.md](docs/workflow.md) | The four paths, the work → verify → status loop, dry-run |
| [docs/prds.md](docs/prds.md) | Writing PRDs, versioning, staged greenfield |
| [docs/review-gates.md](docs/review-gates.md) | Design challenge, code review, constitution enforcement |
| [docs/collaboration.md](docs/collaboration.md) | Ticket comments, parallel developers, re-running planning skills |
| [docs/planning-prs.md](docs/planning-prs.md) | Committing planning artifacts in their own PR |
| [docs/archiving.md](docs/archiving.md) | Completion Sweep and the safe archiving procedure |
| [docs/interface-contracts.md](docs/interface-contracts.md) | API / event contracts: where they live, precedence |
| [docs/trackers.md](docs/trackers.md) | Modes, `config.json`, Bitbucket auth |
| [docs/git-conventions.md](docs/git-conventions.md) | Branches, commits, PRs |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems and fixes |

## Folder layout

```
sdd/
├── README.md                ← you are here
├── docs/                    ← the guides above
├── config.json              ← tracker + VCS selection (config.example.json for reference)
├── constitution/            ← project standards split into one file per concern
├── prds/                    ← versioned PRDs
├── apis/                    ← interface contracts, or pointers to where they live (optional)
├── tasks/                   ← issue-mapping files per change
├── trackers/                ← protocol.md + tracker / git-host recipes (github.md, jira.md, bitbucket.md + bitbucket.sh)
├── templates/               ← shared templates loaded on demand by skills
├── prd-template.md          ← greenfield PRD template
└── prd-template-mini.md     ← v2+ / change-request PRD template
```

`openspec/` lives at the repo root (not under `sdd/`) — that's where the OpenSpec CLI expects it. `/sdd-setup` runs `openspec init --tools none` if `openspec/specs/` is missing.

## Migration from the legacy layout

Coming from pre-`sdd/` (`docs/constitution.md`, `docs/prds/`, `.tasks/`)? `/sdd-constitution` migrates `docs/constitution.md`; move `docs/prds/` to `sdd/prds/` manually. Skills fall back to the legacy paths for one transition cycle if the new locations aren't present yet.
