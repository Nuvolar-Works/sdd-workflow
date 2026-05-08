# SDD Workflow

The Spec-Driven Development workflow is documented in [sdd/README.md](sdd/README.md). That file is the canonical reference for the folder layout, the three tracker modes (GitHub-only / Jira-only / Hybrid), the PRD decision tree, and the full skill catalogue.

## Project Setup (one-time, brand-new project)

1. Run `/sdd-setup` — bootstraps `sdd/`, runs `openspec init`, configures the tracker (GitHub or Jira), wires up MCPs. Idempotent and safe to re-run.
2. Run `/sdd-constitution` — defines the project's coding standards, tech stack, and quality gates. Writes split files into `sdd/constitution/`. All SDD and OpenSpec skills load only the section files they need.

## Workflow Quick Reference

The full decision tree (greenfield vs increment vs Jira story vs trivial) lives in [sdd/README.md](sdd/README.md). Quick map:

- **Greenfield from a PRD** → write `sdd/prds/<feature>-v1.md` using `sdd/prd-template.md`, then `/sdd-from-prd <feature>-v1` (or `/sdd-staged <feature>` for multi-stage greenfield).
- **v2+ increment** → write `sdd/prds/<feature>-v2-<scope>.md` using `sdd/prd-template-mini.md`, then `/sdd-from-prd <feature>-v2-<scope>`.
- **Single Jira user story** → `/sdd-tasks-from-story <JIRA-KEY>`. No PRD needed; the skill generates an OpenSpec change for the story and creates one Jira sub-task per significant goal under it.
- **Trivial fix or chore** → `/opsx:propose "description"` then `/sdd-create-tickets <change>`.

For implementation: `/sdd-work <ticket-id>` → code → `/sdd-verify` → review + PR → after merge, `/sdd-status` to archive + close parent. `/sdd-work` self-detects whether to run Fresh, Resume in-flight work, or Fix-from-PR review feedback. `/sdd-doctor` for a pre-flight check.

Every skill that writes external state accepts `--dry-run` for previewing without committing — see [sdd/README.md § Dry-run](sdd/README.md).

## Review Gates

1. **Design Challenge** (in `/sdd-from-prd`, `/sdd-staged`, `/opsx:propose`) — after artifact generation, before ticket creation. Surfaces assumptions, risks, simplification opportunities. The shape lives in `sdd/templates/design-challenge.md`.

2. **Code Review** (in `/sdd-verify`) — pattern consistency, security, performance, error handling, design alignment, constitution compliance. The checklist lives in `sdd/templates/code-review-checklist.md`. Issues are recommendations, not blockers.

## Git Conventions

- Conventional commits: `type(scope): description`
- Types: feat, fix, docs, style, refactor, test, chore, build, ci
- Branch naming: `<type>/<ticket-id-slug>-<short-description>` — e.g. `feat/42-add-login-form` (GitHub) or `feat/tt-456-add-login-form` (Jira).
- Always reference the ticket in commits: `feat(auth): add login form (#42)` (GitHub) or `feat(auth): add login form [TT-456]` (Jira).
- **Branching strategy**: feature branches are cut from `develop` and merged back to `develop` via PR. Only `develop` → `main` merges happen on releases.

## Code Conventions

- Follow existing patterns in the codebase.
- When implementing a ticket, read the full ticket body first — the SDD skills do this automatically.
- `/sdd-work` lazy-loads the relevant OpenSpec spec and the relevant section of `design.md` for the ticket — it does NOT read the entire change. This keeps token costs down.
- `/sdd-work` also reads ticket comments (sub-task + parent story) on entry and offers to post Decision / Blocker / Follow-up / Clarification comments back during work. Comment shapes live in [sdd/templates/ticket-comment-shapes.md](sdd/templates/ticket-comment-shapes.md). Posting is always opt-in — Claude prompts before each comment.
- `/sdd-work` does **not** update `openspec/changes/<change>/tasks.md` checkbox state during work. That file is a derived view; `/sdd-status`'s Completion Sweep regenerates it from authoritative ticket statuses. This makes parallel work on different sub-tasks of the same change conflict-free.
- Check for related files before creating new ones.

## File Locations

- SDD docs and assets: `sdd/` (see [sdd/README.md](sdd/README.md) for the layout).
- SDD skills: `.claude/skills/sdd-*/SKILL.md`.
- OpenSpec skills: `.claude/skills/openspec-*/SKILL.md`.
- OpenSpec living specs: `openspec/specs/` (grows over time, archive of completed changes).
- OpenSpec changes in flight: `openspec/changes/<change-name>/` (proposal, specs, design, tasks; api-contract.yaml when an API is involved).

## Commands

<!-- Project-specific commands go here. Examples: -->
# <project-specific commands here>
# e.g. npm test — Run all tests
# e.g. npm run lint — Run linter
# e.g. npm run build — Build the project

## Test Conventions

- When debugging a failing test, prefer running a single test file with a minimal reporter over the full suite — dramatically less context consumed.
- Only run the full test suite for the final quality gate after all fixes are in.
