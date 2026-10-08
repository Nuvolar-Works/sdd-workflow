# Git conventions

## Branches

Format: `<type>/<ticket-id-slug>-<short-description>`

- `feat/42-add-login-form` (GitHub)
- `feat/tt-456-add-login-form` (Jira)
- `fix/57-broken-redirect`

Feature branches are cut from the base branch (`base_branch` in `sdd/config.json`, `develop` by default) and merged back via PR. Only `develop` → `main` merges happen on releases. Trunk-based? Set `base_branch` to `main`.

## Commits

Format: `type(scope): description (#issue)` or `type(scope): description [JIRA-KEY]`

| Type | When to use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code restructuring, no behaviour change |
| `test` | Adding or updating tests |
| `chore` | Build, tooling, dependencies |
| `build` | Build system changes |
| `ci` | CI/CD pipeline changes |

A PreToolUse hook (`.claude/hooks/validate-commit-msg.sh`, requires `jq`) blocks commits *made by Claude* that don't follow this format. Your own terminal commits are unaffected. Edit the hook to change the allowed types or format.

## Pull requests

- Title follows conventional commit format
- Body includes: Summary, Changes, Acceptance Criteria (all checked), Testing notes ([`templates/pr-body.md`](../templates/pr-body.md))
- Ticket handling differs per tracker — see [trackers.md](trackers.md#pr-behaviour-per-tracker)
- Merging is always a human decision
