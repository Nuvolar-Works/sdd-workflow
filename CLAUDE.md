# SDD Workflow

## Overview
Spec-Driven Development workflow for a 2-person frontend team.
Uses OpenSpec for specifications and Claude Code skills for GitHub-driven execution.

## Project Setup (one-time)
1. Run `/sdd-constitution` to define the project's coding standards, tech stack, and quality gates
   - This creates `docs/constitution.md` — the single source of truth for project conventions
   - All SDD and OpenSpec skills automatically read this file and enforce its rules
   - To update standards later, run `/sdd-constitution` again

## Workflow

### From PRD (PO hands off a PRD file)
1. PO writes a PRD in `docs/prds/<feature-name>.md` using the template at `docs/prd-template.md`
   - If the feature integrates with a backend API, include the Swagger/OpenAPI file path or URL in the PRD's "API Contract" section
2. Run `/sdd-from-prd <feature-name>` — reads PRD, generates OpenSpec specs, creates GitHub issues
3. Run `/sdd-work <issue-number>` to pick up a ticket, create a branch, and develop it
4. Run `/sdd-verify` to review your work and create a PR
5. After all tickets are done, run `/opsx:archive` to archive the change and update living specs

### From PRD (staged greenfield)
1. PO writes a PRD in `docs/prds/<feature-name>.md` using the template at `docs/prd-template.md`
2. Run `/sdd-staged <feature-name>` — reads PRD, proposes development stages, generates per-stage OpenSpec artifacts, creates cross-referenced GitHub issues
3. Work through stages in order: run `/sdd-work <issue-number>` starting from stage 01
4. Run `/sdd-verify` after each ticket to create PRs
5. After each stage is complete, run `/opsx:archive <feature>-NN-<slug>` to archive that stage
6. After all stages are done, archive remaining stages

### From scratch (no PRD, developer-driven)
1. Run `/opsx:propose "feature description"` to create specs in `openspec/changes/<name>/`
2. Review the generated proposal.md, specs/, design.md, and tasks.md
3. Run `/sdd-create-tickets <change-name>` to create GitHub issues from the tasks
4. Run `/sdd-work <issue-number>` to pick up a ticket, create a branch, and develop it
5. Run `/sdd-verify` to review your work and create a PR
6. After all tickets are done, run `/opsx:archive` to archive the change and update living specs

## Review Gates

The workflow has two built-in review gates that act as architect/devil's advocate without separate agents:

1. **Design Challenge** (in `/sdd-from-prd`, `/sdd-staged`, `/opsx:propose`) — after generating artifacts but before creating tickets, the design is challenged: assumptions surfaced, risks identified, simplification opportunities explored. The user decides whether to adjust or proceed.

2. **Code Review** (in `/sdd-verify`) — beyond acceptance criteria and CI checks, every PR goes through a code review covering: pattern consistency, security, performance, error handling, and design alignment. Issues are flagged as recommendations; the user decides whether to fix or proceed.

## Git Conventions
- Conventional commits: `type(scope): description`
- Types: feat, fix, docs, style, refactor, test, chore, build, ci
- Branch naming: `<type>/<issue-number>-<short-description>` (e.g. `feat/42-add-login-form`)
- Always reference the issue number in commits: `feat(auth): add login form (#42)`

## Code Conventions
- Follow existing patterns in the codebase
- When implementing a ticket, read the full GitHub issue body first
- `/sdd-work` automatically detects linked OpenSpec changes (via the `Source:` footer in issue bodies) and reads proposal, design, and spec artifacts for richer context. It also marks tasks complete in tasks.md after implementation.
- Check for related files before creating new ones

## GitHub
- Use `gh` CLI for all GitHub operations
- Issues have labels matching the task type (feature, bug, chore, docs)
- PRs must reference the issue they close using `Closes #<number>`

## File Locations
- OpenSpec living specs: `openspec/specs/` (domain documentation, grows over time)
- OpenSpec changes: `openspec/changes/<change-name>/` (proposal, specs, design, tasks)
- Issue mappings: `.tasks/<change-name>.md`
- Stage maps: `.tasks/<feature-name>-stages.md`
- SDD skills: `.claude/skills/sdd-*/SKILL.md`
- OpenSpec skills: `.claude/skills/openspec-*/SKILL.md`
- PRD template: `docs/prd-template.md`
- PRDs: `docs/prds/<feature-name>.md`
- API contracts (per-change): `openspec/changes/<change-name>/api-contract.yaml`
- Project constitution: `docs/constitution.md` (coding standards, tech stack, quality gates)
- API source docs: `docs/apis/` (optional, for local Swagger files)

## Commands
- `npm test` — Run tests
- `npm run lint` — Run linter
- `npm run build` — Build the project
