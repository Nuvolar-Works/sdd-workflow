# SDD — Spec-Driven Development

A workflow that drives PRDs and Jira stories through OpenSpec into trackable tickets, then implements with built-in code review and a sweep that archives changes after merge. Designed for 1-N developer teams.

The whole `sdd/` folder is portable. Copy it (plus `.claude/skills/sdd-*/` and `.claude/skills/openspec-*/`) into any project, then run `/sdd-setup` to wire up tracker auth.

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

Three modes, controlled by `sdd/config.json`:

| Mode | tracker | vcs | Tickets | Code/PRs |
|------|---------|-----|---------|----------|
| GitHub-only | github | github | GitHub Issues | GitHub |
| Jira-only | jira | github | Jira | GitHub (PRs reference Jira keys) |
| Hybrid | jira | github | Jira | GitHub, status synced back to Jira |

## PRD decision tree

| Situation | Skill | Input |
|-----------|-------|-------|
| Greenfield, full scope | `/sdd-from-prd <slug>-v1` (or `/sdd-staged` for multi-stage) | `sdd/prds/<slug>-v1.md` from `prd-template.md` |
| v2+ increment | `/sdd-from-prd <slug>-v2-<scope>` | `sdd/prds/<slug>-v2-<scope>.md` from `prd-template-mini.md` |
| Single Jira user story | `/sdd-tasks-from-story <KEY>` | the story itself (the skill generates the spec) |
| Trivial fix | `/opsx:propose "fix X"` then `/sdd-create-tickets <change>` | none |

Versioning: `<slug>-v1.md`, `<slug>-v2-<scope>.md`, `<slug>-v2.1-<scope>.md`. Each version is a separate `/sdd-from-prd` run; living specs in `openspec/specs/` accumulate across versions so v2 builds on v1 without re-stating it.

## Skills

All skills accept `--dry-run` (preview mode — see Reference below). Required args in `<angle brackets>`, optional in `[square brackets]`.

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
| `/sdd-tasks-from-story <KEY>` | Jira story → OpenSpec change + sub-tasks per goal. |
| `/sdd-create-tickets <change>` | OpenSpec tasks.md → tickets (standalone). |

**Implementation**

| Skill | Purpose |
|-------|---------|
| `/sdd-work <ticket>` | Pick up a ticket. Self-detects Fresh / Resume / Fix-from-PR mode. |
| `/sdd-verify [ticket]` | AC + code review + project checks → PR. |

**OpenSpec**

| Skill | Purpose |
|-------|---------|
| `/opsx:propose "description"` | Free-form artifact creation. |
| `/opsx:apply <change>` | Implement directly from artifacts. |
| `/opsx:archive <change>` | Finalise → update living specs. |
| `/opsx:explore` | Thinking partner for clarifying requirements. |

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

`openspec/` lives at the repo root (not under `sdd/`) — that's where the OpenSpec CLI expects it. `/sdd-setup` runs `openspec init` if it's missing.

---

## Reference

Pointers to the design choices behind the workflow. The detail lives in skill files and templates; these subsections are navigation, not docs.

### Comments — first-class workflow citizens

`/sdd-work` reads sub-task and parent-story comments on entry, then during implementation prompts opt-in (`yes` / `edit` / `skip`) to post one of five named shapes:

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

`tasks.md` is a derived view, not a control surface. Ticket status is the single source of truth; `/sdd-work` does not write checkbox state during implementation. `/sdd-status`'s Completion Sweep regenerates `tasks.md` from ticket statuses (single writer, atomic — no merge conflicts possible).

| Team size | Behaviour |
|-----------|-----------|
| 1 dev | Run `/sdd-work` and `/sdd-verify`; `/sdd-status` periodically. |
| 2-N devs, different sub-tasks | Parallel work, no shared writes during implementation. |
| 2 devs, same sub-task | Code-level git conflicts still on you. SDD assumes one dev per ticket per branch. |

### Re-run safety

The four ticket-creating skills detect existing state in Phase 0.5 and prompt **Continue** (default — skip what exists, fill gaps) / **Regenerate** (per-file diff before overwrite) / **Abort**. Re-running after editing a PRD or story is safe; you have to explicitly opt into Regenerate to overwrite anything.

### Completion Sweep

Post-merge, run `/sdd-status`. Walks active changes and offers (with prompts):

- **Class A** — archive changes with all tickets done (`openspec archive`).
- **Class B** — close parent stories with all sub-tasks done (status transition + Closing Summary comment).
- **Class C** — regenerate `tasks.md` checkboxes from ticket statuses. Always safe; offered separately.

### Dry-run

Every skill that writes external state accepts `--dry-run`. Reads always run; tracker writes are mocked with `[DRY RUN] would <op>(<args>)` lines and synthetic `DRY-N` ids for downstream wiring. Branch / push / PR creation skipped. `/sdd-work` halts after the plan — no code edits. Local file writes (OpenSpec artifacts, mapping files) do happen because they're git-revertable.

## Configuration

`sdd/config.json` is the single source of truth. See `sdd/config.example.json` for the full shape and field documentation. Personal overrides go in `sdd/config.local.json` (git-ignored).

## Maintenance

After editing anything under `sdd/templates/`, `sdd/trackers/`, or the top-level scaffold (`config.example.json`, `README.md`, `prd-template*.md`):

```bash
bash sdd/scripts/sync-seed.sh
```

Idempotent. Keeps the `/sdd-setup` seed bundle in sync so a fresh project gets the latest.

## Migration from the legacy layout

Coming from pre-`sdd/` (`docs/constitution.md`, `docs/prds/`, `.tasks/`)? `/sdd-setup` offers to migrate. Skills fall back to the legacy paths for one transition cycle if the new locations aren't present yet.
