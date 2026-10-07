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
├── apis/                    ← Swagger / OpenAPI files (optional)
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

- **Class A** — archive changes with all tickets done (`openspec archive <change> --yes`).
- **Class B** — close parent stories with all linked work items done (status transition + Closing Summary comment).
- **Class C** — reconcile `tasks.md` checkboxes against ticket statuses (backstop for drift; `/sdd-verify` does the primary per-section flip). Always safe; offered separately.

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
