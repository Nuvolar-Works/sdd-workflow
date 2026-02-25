# SDD Workflow

## Overview
Spec-Driven Development workflow for a 2-person frontend team.
Automates: PRD → tasks → GitHub issues → AI-driven development → verified PRs.

## Workflow
1. Write a PRD in `docs/prds/<feature-name>.md` using the template at `docs/prd-template.md`
2. Run `/sdd-parse-prd <feature-name>` to generate structured tasks in `.tasks/<feature-name>.md`
3. Run `/sdd-create-tickets <feature-name>` to create GitHub issues from those tasks
4. Run `/sdd-work <issue-number>` to pick up a ticket, create a branch, and develop it
5. Run `/sdd-verify` to review your work and create a PR

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
- PRD template: `docs/prd-template.md`
- PRDs: `docs/prds/<feature-name>.md`
- Parsed tasks: `.tasks/<feature-name>.md`
- Skills: `.claude/skills/sdd-*/SKILL.md`

## Commands
- `npm test` — Run tests
- `npm run lint` — Run linter
- `npm run build` — Build the project
