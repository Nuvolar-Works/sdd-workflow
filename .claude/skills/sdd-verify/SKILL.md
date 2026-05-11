---
name: sdd-verify
description: Verify the current branch's work against its ticket acceptance criteria, run code review, and create a pull request with the ticket linked.
argument-hint: "[ticket-id] [--dry-run]"
disable-model-invocation: true
---

# Verify and Create Pull Request

You are verifying completed work and creating a PR.

## Input

`$ARGUMENTS` parsed for an optional `<ticket-id>` (overrides branch-name detection) and an optional `--dry-run`. When `--dry-run`: verification runs (read-only), PR body and ticket comment drafts are printed, but `gh pr create`, branch push, and ticket transitions are skipped.

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. Capture `tracker` and `vcs`.
2. Read `sdd/trackers/protocol.md` for the dry-run convention.
3. Read `sdd/trackers/<tracker>.md` for ticket operations.
4. If `vcs` differs from `tracker`, also read `sdd/trackers/<vcs>.md` for branch/PR operations.

## Phase 1: Determine Context

5. Identify the current branch:
   ```bash
   git branch --show-current
   ```
   Extract the ticket id from the branch name (e.g. `feat/42-add-login` → `42`; `feat/tt-456-add-login` → `TT-456`).
   If `$ARGUMENTS` includes a positional ticket id, prefer that (excluding the `--dry-run` flag from the parse).

6. Run `FetchTicket(<ticket-id>)` to get the title, body, and labels.

7. Determine the base branch from `sdd/config.json` (`github.default_base_branch`, fall back to `develop`, then `main`):
   ```bash
   git rev-parse --verify <base> 2>/dev/null && echo "<base>" || echo "main"
   ```

## Phase 1.5: OpenSpec Context (lazy, only if linked)

Mirrors `/sdd-work`'s spec-loading so the Design Alignment check in Phase 2 has actual context to compare against. Skip this entire phase if no `Source:` footer is found.

8. Scan the ticket body for a footer:
   ```
   Source: openspec/changes/<CHANGE_NAME>/tasks.md
   ```
   If absent, hold `CHANGE_NAME = none` and skip to Phase 2 — the Design Alignment check will report `N/A`.

9. Open `openspec/changes/<CHANGE_NAME>/tasks.md`. Find the section header containing the ticket id (annotated as `(#N)` for GitHub or `[KEY]` for Jira). Note the section title.

10. **Locate the relevant spec file**, in order of preference:
    a. Read the `Spec section:` footer in the ticket body — sub-task tickets created by `/sdd-tasks-from-story` carry an explicit pointer. When present, use it without prompting.
    b. Heuristic fallback when no footer: glob `openspec/changes/<CHANGE_NAME>/specs/*.md` and score each by keyword overlap with the section title.
       - **Single match**: use it.
       - **Clear winner** (top score ≥ 2× the runner-up): use it; the verification report's Design Alignment row notes "spec inferred from <file>".
       - **Ambiguous** (top two within 1 of each other, or ties at the top): the Design Alignment row reports `AMBIGUOUS: matched <file-a>, <file-b> — could not pick a canonical spec`. Do not silently pick. The reviewer should fix the ticket body to carry an explicit `Spec section:` footer.
       - **No match**: Design Alignment row is `N/A — no spec found for change <CHANGE_NAME>`.

11. Extract only the relevant section of `openspec/changes/<CHANGE_NAME>/design.md` via grep (section name match). Do NOT read the whole file.

12. Read `openspec/changes/<CHANGE_NAME>/proposal.md` (it's short).

13. Hold the spec excerpt, design excerpt, change name, and section title in context for Phase 2's Design Alignment check.

## Phase 2: Verify

14. Review all changes on this branch versus the base:
    ```bash
    git log <base>..HEAD --oneline
    git diff <base>..HEAD --stat
    ```
    Read through the changed files to understand what was implemented.

15. Check each acceptance criterion from the ticket body:
    - Verify it is met by examining the code.
    - Mark as PASS or FAIL.
    - If FAIL, explain what is missing.

16. Run project checks (if configured):
    ```bash
    npm test 2>&1 || true
    npm run lint 2>&1 || true
    npm run build 2>&1 || true
    ```

17. Read these constitution section files (lazy load — only what review needs):
    - `sdd/constitution/principles.md` (always)
    - `sdd/constitution/quality-gates.md` (always)
    - `sdd/constitution/design-system.md` — only if changed files include UI components (under `src/components/` or `src/app/` route files)
    - `sdd/constitution/utilities.md` — only if changed files touch `src/lib/api/`

    Legacy fallback: read `docs/constitution.md` if `sdd/constitution/` is absent.

18. Read `sdd/templates/code-review-checklist.md` and run through each section in order against the changed files. For each category, mark CLEAN or list specific findings with file:line references. The Design Alignment check (checklist § 5) uses the spec + design excerpts captured in Phase 1.5; if `CHANGE_NAME` was `none`, that row is `N/A`.

19. Report verification results in this shape:

    ```
    ## Verification Report for <ticket-id>: <title>

    ### Acceptance Criteria
    - [x] Criterion 1 — PASS
    - [ ] Criterion 2 — FAIL: <reason>

    ### Code Review
    - Pattern consistency: CLEAN / <issues>
    - Security: CLEAN / <issues>
    - Performance: CLEAN / <issues>
    - Error handling: CLEAN / <issues>
    - Design alignment: CLEAN / N/A / <deviations>
    - Constitution compliance: CLEAN / N/A / <violations>

    ### Project Checks
    - Tests: PASS/FAIL/NOT CONFIGURED
    - Lint: PASS/FAIL/NOT CONFIGURED
    - Build: PASS/FAIL/NOT CONFIGURED

    ### Summary
    <Overall assessment>
    ```

20. If any acceptance criterion FAILs or any project check fails, tell the user what needs fixing and stop. Do NOT create a PR for incomplete work.

21. If code review flags issues, present them to the user as recommendations (not blockers). Ask: "I found some code review items. Want to address them before the PR, or proceed as-is?"

22. If everything passes (or the user chooses to proceed), ask: "Ready to push and create a PR?"

## Phase 3: Create PR

23. Run `PushBranch(<current-branch>)` from the active VCS recipe. When `DRY_RUN`, print `[DRY RUN] would PushBranch(<branch>)`.

24. Read `sdd/templates/pr-body.md` for the PR body structure. Substitute the placeholders:
    - Summary, Changes, Acceptance Criteria, Testing
    - `<TICKET_CLOSE_LINE>`:
      - GitHub-only: `Closes #<ticket-id>`
      - Jira (alone or hybrid): `Resolves <JIRA-KEY>`

    Run `CreatePR(payload)` from the active VCS recipe. Capture the PR id and URL. When `DRY_RUN`, print the full payload and the intended `[DRY RUN] would CreatePR(...)` line; assign `DRY-PR-1` as the synthetic id for downstream use.

25. Print the PR URL (or synthetic id when `DRY_RUN`) so the user can review.

26. Run `LinkTicketToPR(<ticket-id>, <pr>)` from the active tracker recipe. This:
    - For GitHub-only: calls `CloseTicket(<ticket-id>, "Resolved in PR #<pr-id>.")` because PRs target `develop` (not the default branch) and GitHub only auto-closes on default-branch merge.
    - For Jira: posts a comment with the PR URL on the ticket and runs `UpdateTicketStatus(<ticket-id>, "in_review")`.
    - For hybrid (Jira tickets, GitHub PRs): same as Jira — Jira gets the comment + status transition, GitHub PR carries the `Resolves <JIRA-KEY>` reference.

    When `DRY_RUN`, print the intended `LinkTicketToPR(...)` call without executing.

## Phase 4: Hand-off Hint

27. Tell the user:
    ```
    PR opened: <pr-url>
    Once the PR merges, run /sdd-status to detect completion. /sdd-status
    will offer to archive the OpenSpec change and close the parent story
    when all sub-tasks are done.
    ```

    For `DRY_RUN`, frame as `[DRY RUN] PR would be opened. Re-run without --dry-run to execute.`

## Rules

- Never create a PR if acceptance criteria are not met.
- The PR title must follow conventional commit format with the ticket reference.
- The PR body must include the ticket close line so the ticket auto-closes (or transitions) on merge where supported.
- Always push before creating the PR (skipped in dry-run).
- Feature PRs target the configured base branch (`develop` by default). Only ask the user to confirm a different base if the configured base does not exist.
- Use abstract operation names from `sdd/trackers/protocol.md`; never embed `gh` or MCP calls inline.
- Do NOT merge the PR. That is a human decision.
- The post-merge cleanup (archive OpenSpec change, close parent story, regenerate tasks.md checkboxes) lives in `/sdd-status`'s Completion Sweep — point the user there in the hand-off message.
