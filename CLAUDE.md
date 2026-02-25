# SDD Workflow

## Overview
Spec-Driven Development workflow for a 2-person frontend team.
Uses OpenSpec for specifications and Claude Code skills for GitHub-driven execution.

## Workflow
1. Run `/opsx:propose "feature description"` to create specs in `openspec/changes/<name>/`
2. Review the generated proposal.md, specs/, design.md, and tasks.md
3. Run `/sdd-create-tickets <change-name>` to create GitHub issues from the tasks
4. Run `/sdd-work <issue-number>` to pick up a ticket, create a branch, and develop it
5. Run `/sdd-verify` to review your work and create a PR
6. After all tickets are done, run `/opsx:archive` to archive the change and update living specs

## Git Conventions
- Conventional commits: `type(scope): description`
- Types: feat, fix, docs, style, refactor, test, chore, build, ci
- Branch naming: `<type>/<issue-number>-<short-description>` (e.g. `feat/42-add-login-form`)
- Always reference the issue number in commits: `feat(auth): add login form (#42)`

## Code Conventions
- Follow existing patterns in the codebase
- When implementing a ticket, read the full GitHub issue body first
- Check for related files before creating new ones

## GitHub
- Use `gh` CLI for all GitHub operations
- Issues have labels matching the task type (feature, bug, chore, docs)
- PRs must reference the issue they close using `Closes #<number>`

## File Locations
- OpenSpec living specs: `openspec/specs/` (domain documentation, grows over time)
- OpenSpec changes: `openspec/changes/<change-name>/` (proposal, specs, design, tasks)
- Issue mappings: `.tasks/<change-name>.md`
- SDD skills: `.claude/skills/sdd-*/SKILL.md`
- OpenSpec skills: `.claude/skills/openspec-*/SKILL.md`
- Legacy PRD template: `docs/prd-template.md` (optional reference)

## Commands
- `npm test` — Run tests
- `npm run lint` — Run linter
- `npm run build` — Build the project
