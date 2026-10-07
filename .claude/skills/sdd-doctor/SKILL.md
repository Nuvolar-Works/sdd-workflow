---
name: sdd-doctor
description: Pre-flight diagnostic for SDD. Verifies sdd/config.json is valid, the active tracker is authenticated, the constitution is present, OpenSpec is installed, and the working tree is clean. Run before /sdd-work if anything feels off.
argument-hint: "[--dry-run]"
disable-model-invocation: true
---

This skill is read-only. The `--dry-run` flag is accepted for consistency with other skills but has no effect (there are no writes to mock).

# SDD Doctor

You are running a quick health check on the SDD setup. Output is a single screen of pass/fail rows. No actions, no fixes — just diagnosis with specific remediation hints.

## Checks

Run each check, capture the result, and assemble a report. Don't stop on the first failure — collect all results so the user sees the full picture.

### 1. `sdd/config.json` exists and is valid JSON

- File exists at `sdd/config.json`?
- Parses as JSON?
- Has `tracker` and `vcs` fields with allowed values (`github` or `jira` for tracker; `github` for vcs)?
- If tracker is `jira`, has non-null `jira.site`, `project_key`, `child_issue_type`, `child_link_type`, `status_workflow.{in_progress,in_review,done}`?

Fail row example: `✗ sdd/config.json: tracker is "jira" but jira.project_key is null. Re-run /sdd-setup.`

### 2. Active tracker is authenticated

Read `tracker` from `sdd/config.json`. Then:

- **Always** (PRs go through GitHub in both modes): run `gh auth status` and capture exit code + first line of output.
- **jira**: also run the `VerifyAuth` operation from `sdd/trackers/jira.md`. Pass if it succeeds; fail on an auth error or if `jira.site` is not listed.

Fail row example: `✗ Jira auth: Atlassian Rovo MCP not authenticated. Run /sdd-setup to re-auth.`

### 3. Constitution is present

- Pass if `sdd/constitution/index.md` exists.
- Soft-pass with note if only the legacy `docs/constitution.md` exists.
- Fail if neither exists.
- If `sdd/constitution/quality-gates.md` has a `CI baseline:` line, run `git diff <baseline-commit>..HEAD -- <ci-paths>`. Warn (don't fail) if it adds or changes commands CI executes: `⚠ CI config changed since the gates were set — re-run /sdd-constitution`. Version-pin bumps alone don't count.

### 4. OpenSpec CLI is installed and `openspec/` is initialised

- `openspec --version` succeeds?
- `openspec/specs/` exists?
- `jq --version` succeeds? (the commit-message hook needs it)

### 5. MCP availability matches `sdd/config.json` `mcps_enabled`

For each entry in `mcps_enabled`, check that the corresponding MCP is reachable. For Atlassian Rovo, a lightweight call (e.g. listing accessible resources) is enough. Skip MCPs that aren't enabled.

### 6. Git working tree state

- `git status --porcelain` is empty? (clean)
- Or list the modified/untracked files (note, don't fail).
- Current branch and base branch:
  - `git branch --show-current`
  - Base branch from `sdd/config.json`. Verify it exists locally (`git rev-parse --verify <base>`).

### 7. Branch / ticket linkage (informational)

If the current branch matches the convention (`<type>/<ticket-id>-<slug>`), extract the ticket id and report it. Don't run `FetchTicket` here — that's `/sdd-work`'s job. Just confirm the branch is shaped to map to a ticket.

### 8. tasks.md drift (informational)

For each `openspec/changes/<change>/tasks.md`, scan for section headers with ticket-id annotations. If at least one annotated section exists, note that `tasks.md` is a derived view; `/sdd-verify` checks off each ticket's section and `/sdd-status` Class C reconciles drift. Informational only — don't verify per-section state here.

### 9. Change ↔ mapping consistency (informational)

Detect orphans on either side of the change-directory / mapping-file pairing. Both should always exist together; missing one points to an interrupted skill run or a manual cleanup that didn't finish.

- List `openspec/changes/*/` directories (skip `archive/`).
- List `sdd/tasks/*.md` mapping files (skip `*.archived.md` and `*-stages.md`).
- Strip the trailing slash / `.md` extension to get a slug for each side.
- For staged changes, the mapping pattern is `sdd/tasks/<feature>-NN-<slug>.md`; the change side is `openspec/changes/<feature>-NN-<slug>/`. Match per-stage slugs.

Report rows:

- `ℹ Change without mapping: openspec/changes/<slug>/` — for each change-side slug missing from the mapping side. Suggested fix: re-run `/sdd-create-tickets <slug>` to regenerate the mapping, or `/sdd-from-prd` / `/sdd-tasks-from-story` if the change is mid-pipeline.
- `ℹ Mapping without change: sdd/tasks/<slug>.md` — for each mapping-side slug missing on the change side. Suggested fix: the change was likely archived without renaming the mapping; rename to `sdd/tasks/<slug>.archived.md` or `git rm` it.
- No row when both sides match exactly.

This check is informational only — never `✗`. Orphans don't block work but do confuse `/sdd-status`'s sweep.

## Output format

```
## SDD Doctor Report

✓ sdd/config.json: valid (tracker=jira, vcs=github)
✓ Jira auth: authenticated to your-org.atlassian.net (project TT)
✓ Constitution: sdd/constitution/index.md present (v1.4.0)
✓ OpenSpec: v0.x.x, openspec/ initialised
✓ MCPs: atlassian-rovo reachable
⚠ Working tree: 3 modified files (src/components/foo.tsx, src/lib/bar.ts, ...)
ℹ Current branch: feat/tt-456-add-clock-in (ticket TT-456)

Overall: 5/5 critical checks pass; 1 warning.
```

## Rules

- Never modify state. This skill is read-only.
- Group failures so the user sees the most actionable items first.
- Always finish all checks even if one fails.
- Keep each row to one line where possible.
- Never emit emojis other than the leading status glyph (✓ ✗ ⚠ ℹ).
