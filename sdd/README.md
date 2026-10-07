# SDD — Spec-Driven Development

A workflow that drives PRDs and Jira stories through OpenSpec into trackable tickets, then implements with built-in code review and a sweep that archives changes after merge. Designed for 1-N developer teams.

Copy `.claude/skills/sdd-*/` and `.claude/skills/openspec-*/` into any project, then run `/sdd-setup` — it seeds `sdd/` from its own bundle and wires up tracker auth.

## Quickstart

```
/sdd-setup
```

Detects what's missing, scaffolds `sdd/`, runs `openspec init`, asks for tracker (GitHub or Jira), wires up MCPs, optionally chains into `/sdd-constitution` for project standards. Idempotent — safe to re-run.

## Workflow

```
PRD ──► OpenSpec change ──► tickets ──► implementation ──► verify ──► merge ──► sweep
        (proposal/specs/    (GitHub or Jira)           (PR)         (/sdd-status)
         design/tasks)
```

Two modes, controlled by `sdd/config.json`:

| Mode | tracker | vcs | Tickets | Code/PRs |
|------|---------|-----|---------|----------|
| GitHub | github | github | GitHub Issues | GitHub |
| Jira | jira | github | Jira | GitHub (PRs reference Jira keys; statuses synced to Jira) |

The Jira mode was formerly called Hybrid.

## PRD decision tree

| Situation | Skill | Input |
|-----------|-------|-------|
| Greenfield, full scope | `/sdd-from-prd <slug>-v1` (or `/sdd-staged` for multi-stage) | `sdd/prds/<slug>-v1.md` from `prd-template.md` |
| v2+ increment | `/sdd-from-prd <slug>-v2-<scope>` | `sdd/prds/<slug>-v2-<scope>.md` from `prd-template-mini.md` |
| Single Jira user story | `/sdd-tasks-from-story <KEY>` | the story itself (the skill generates the spec) |
| Trivial fix | `/openspec-propose "fix X"` then `/sdd-create-tickets <change>` | none |

Versioning: `<slug>-v1.md`, `<slug>-v2-<scope>.md`, `<slug>-v2-1-<scope>.md`. Each version is a separate `/sdd-from-prd` run; living specs in `openspec/specs/` accumulate across versions so v2 builds on v1 without re-stating it.

## Skills

All `sdd-*` skills except `/sdd-setup` accept `--dry-run` (preview mode — see Reference below); the openspec-* skills do not. Required args in `<angle brackets>`, optional in `[square brackets]`.

**Bootstrap & admin**

| Skill | Purpose |
|-------|---------|
| `/sdd-setup` | Configure tracker, MCPs, scaffold `sdd/`, run `openspec init`. |
| `/sdd-constitution [project-name]` | Interview to write `sdd/constitution/*.md`. |
| `/sdd-doctor` | Pre-flight diagnostic. Read-only. |
| `/sdd-status` | Project snapshot + post-merge Completion Sweep. |

**Planning**

| Skill | Purpose |
|-------|---------|
| `/sdd-from-prd <slug>` | PRD → OpenSpec artifacts → tickets. |
| `/sdd-staged <slug>` | Multi-stage variant of `/sdd-from-prd`. |
| `/sdd-tasks-from-story <KEY>` | Jira story → OpenSpec change + one board-visible Task per goal, linked to the story. |
| `/sdd-create-tickets <change>` | OpenSpec tasks.md → tickets (standalone). |

**Implementation**

| Skill | Purpose |
|-------|---------|
| `/sdd-work <ticket>` | Pick up a ticket. Self-detects Fresh / Resume / Fix-from-PR mode. |
| `/sdd-verify [ticket]` | AC + code review + project checks → PR. |

**OpenSpec**

| Skill | Purpose |
|-------|---------|
| `/openspec-propose "description"` | Free-form artifact creation. |
| `/openspec-apply-change <change>` | Implement directly from artifacts. |
| `/openspec-archive-change <change>` | Finalise via `openspec archive` → update living specs. |
| `/openspec-explore` | Thinking partner for clarifying requirements. |

## Folder layout

```
sdd/
├── README.md                ← you are here
├── config.json              ← tracker + VCS selection (config.example.json for reference)
├── constitution/            ← project standards split into one file per concern
├── prds/                    ← versioned PRDs
├── apis/                    ← interface contracts, or pointers to where they live (optional)
├── tasks/                   ← issue-mapping files per change
├── trackers/                ← protocol.md + per-tracker recipes (github.md, jira.md)
├── templates/               ← shared templates loaded on demand by skills
├── prd-template.md          ← greenfield PRD template
└── prd-template-mini.md     ← v2+ / change-request PRD template
```

`openspec/` lives at the repo root (not under `sdd/`) — that's where the OpenSpec CLI expects it. `/sdd-setup` runs `openspec init --tools none` if `openspec/specs/` is missing.

---

## Reference

Pointers to the design choices behind the workflow. The detail lives in skill files and templates; these subsections are navigation, not docs.

### Comments — first-class workflow citizens

`/sdd-work` reads work-item and parent-story comments on entry, then during implementation prompts opt-in (`yes` / `edit` / `skip`) to post one of five named shapes:

| Shape | When |
|-------|------|
| Decision | Implementation diverges from `design.md` or the ticket body. |
| Blocker | External dependency surfaced (API not ready, missing infra). |
| Follow-up | Known future work left as a placeholder. |
| Clarification | Outstanding question got answered. |
| Closing summary | End-of-implementation overview before `/sdd-verify`. |

Blockers and Follow-ups also offer to create a tracked follow-up ticket via `CreateRelatedTicket` (`is_blocked_by` in Jira, emulated `Blocked by #N` body footer in GitHub).

Detail: [`templates/ticket-comment-shapes.md`](templates/ticket-comment-shapes.md), [`templates/work-discovery-comments.md`](templates/work-discovery-comments.md), [`templates/story-comment-triage.md`](templates/story-comment-triage.md).

### Concurrency — N developers per change

`tasks.md` is a derived view, not a control surface — ticket status is the single source of truth. `/sdd-work` does not write checkbox state during implementation (granular per-edit writes caused conflicts). Instead, `/sdd-verify` checks off **only the current ticket's own section** just before opening the PR, so the flip ships inside the feature PR rather than as a separate post-merge commit. Because each work item touches only its own section, parallel work on the same change stays conflict-free. `/sdd-status`'s Completion Sweep (Class C) then reconciles any residual drift from ticket statuses (idempotent — usually a no-op).

| Team size | Behaviour |
|-----------|-----------|
| 1 dev | Run `/sdd-work` and `/sdd-verify`; `/sdd-status` periodically. |
| 2-N devs, different work items | Parallel work, no shared writes during implementation. |
| 2 devs, same work item | Code-level git conflicts still on you. SDD assumes one dev per ticket per branch. |

### Re-run safety

The four ticket-creating skills detect existing state in Phase 0.5 and prompt **Continue** (default — skip what exists, fill gaps) / **Regenerate** (per-file diff before overwrite) / **Abort**. Re-running after editing a PRD or story is safe; you have to explicitly opt into Regenerate to overwrite anything.

### Completion Sweep

Post-merge, run `/sdd-status`. Walks active changes and offers (with prompts):

- **Class A** — archive changes with all tickets done (via the § Archiving procedure below).
- **Class B** — close parent stories with all linked work items done (status transition + Closing Summary comment).
- **Class C** — reconcile `tasks.md` checkboxes against ticket statuses (backstop for drift; `/sdd-verify` does the primary per-section flip). Always safe; offered separately.

### Archiving

`openspec archive` is not transactional: when one capability fails validation after others were already written, those writes stay in `openspec/specs/`, the CLI may still print "No files were changed" and exit 0, and a retry then fails with "ADDED already exists". Both archive paths (`/openspec-archive-change` step 5 and `/sdd-status` Class A) run this procedure per change instead of calling the CLI bare:

1. **Pre-flight (read-only).** For each `openspec/changes/<name>/specs/<cap>/` whose living spec `openspec/specs/<cap>/spec.md` exists, run `openspec validate <cap> --type spec --no-interactive`. Also confirm `openspec/changes/archive/<YYYY-MM-DD>-<name>/` does not exist yet. On any failure, report it and do not archive. A failing living spec needs `## Purpose` plus `## Requirements` with `### Requirement:` blocks and no `ADDED`/`MODIFIED`/`REMOVED`/`RENAMED` headers — the user repairs it; never repair it automatically.
2. **Snapshot.** Copy `openspec/specs/` to a temp dir (`SNAP=$(mktemp -d) && cp -R openspec/specs "$SNAP/"`). Skip when archiving with `--skip-specs`.
3. **Archive.** `openspec archive <name> --yes [--skip-specs]`.
4. **Judge success on disk**, not by exit code or output text: `openspec/changes/<name>/` is gone and the archive dir exists. On failure, restore the snapshot wholesale (`rm -rf openspec/specs && cp -R "$SNAP/specs" openspec/specs`), which also removes capability dirs the failed run created. Show the CLI output verbatim.
5. **Mapping.** Only after step 4 confirms success, rename `sdd/tasks/<name>.md` to `sdd/tasks/<name>.archived.md`.

Under `--dry-run`, run step 1 only and print `[DRY RUN] would archive <name>` or `[DRY RUN] would skip <name>: <reason>`.

### Interface contracts

An interface contract is a machine-readable schema for an interface whose other side is not built or tested in this repo — another team's API, an external service, an event stream (OpenAPI, GraphQL SDL, `.proto`, AsyncAPI, JSON Schema, …). In-repo schemas the toolchain already enforces (ORM models, platform object metadata, data-model definitions) don't count.

- **Where it lives.** The maintained source is `sdd/apis/` (the contract itself, or a short pointer file to where it lives) or the path/URL a PRD's `## API Contract` section references. `openspec/changes/<change>/api-contract.*` is a snapshot taken when the change was created — use it only when no maintained source is available. If the two disagree on something in scope, report contract drift rather than picking one.
- **Precedence.** On shape — operation and field names, types, optionality, enum values, documented outcomes — the contract beats prose (`design.md`, other teams' ticket text, story text). The PRD still wins on scope.
- **Used by** `/sdd-tasks-from-story` (design and codebase audit) and `/sdd-verify` (code-review checklist § 7).

### Dry-run

All `sdd-*` skills except `/sdd-setup` accept `--dry-run`; the openspec-* skills do not. Reads always run; tracker writes are mocked with `[DRY RUN] would <op>(<args>)` lines and synthetic `DRY-N` ids for downstream wiring. Branch / push / PR creation skipped. `/sdd-work` halts after the plan — no code edits. Local OpenSpec artifacts are written (git-revertable); mapping and stage-map files and tasks.md annotations are only printed.

## Configuration

`sdd/config.json` is the single source of truth. See `sdd/config.example.json` for the full shape.

## Maintenance (sdd-workflow source repo only)

After editing anything under `sdd/templates/`, `sdd/trackers/`, or the top-level scaffold (`config.example.json`, `README.md`, `prd-template*.md`):

```bash
bash sdd/scripts/sync-seed.sh
```

Idempotent. Keeps the `/sdd-setup` seed bundle in sync so a fresh project gets the latest.

## Migration from the legacy layout

Coming from pre-`sdd/` (`docs/constitution.md`, `docs/prds/`, `.tasks/`)? `/sdd-constitution` migrates `docs/constitution.md`; move `docs/prds/` to `sdd/prds/` manually. Skills fall back to the legacy paths for one transition cycle if the new locations aren't present yet.
