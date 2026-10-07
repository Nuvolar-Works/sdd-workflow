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

7. Determine the base branch from `sdd/config.json` (`github.default_base_branch`, default `develop`) and refresh it:
   ```bash
   git fetch origin <base>
   ```
   If `origin/<base>` does not exist, ask the user which base to use. Diff against `origin/<base>` (step 14), not the possibly stale local branch.

## Phase 1.5: OpenSpec Context (lazy, only if linked)

Mirrors `/sdd-work`'s spec-loading so the Design Alignment check in Phase 2 has actual context to compare against. Skip this entire phase if no `Source:` footer is found.

8. Scan the ticket body for a footer:
   ```
   Source: openspec/changes/<CHANGE_NAME>/tasks.md
   ```
   If absent, hold `CHANGE_NAME = none` and skip to Phase 2 — the Design Alignment check will report `N/A`.

9. Open `openspec/changes/<CHANGE_NAME>/tasks.md`. Find the section header carrying the exact annotation `(#<id>)` (GitHub) or `[<KEY>]` (Jira). Note the section title.

10. **Locate the relevant spec file**, in order of preference:
    a. Read the `Spec section:` footer in the ticket body — tickets created via `sdd/templates/ticket-creation-protocol.md` carry an explicit pointer. When present, use it without prompting.
    b. Heuristic fallback when no footer: glob `openspec/changes/<CHANGE_NAME>/specs/*/spec.md` and score each by keyword overlap with the section title.
       - **Single match**: use it.
       - **Clear winner** (top score ≥ 2× the runner-up): use it; the verification report's Design Alignment row notes "spec inferred from <file>".
       - **Ambiguous** (top two within 1 of each other, or ties at the top): the Design Alignment row reports `AMBIGUOUS: matched <file-a>, <file-b> — could not pick a canonical spec`. Do not silently pick. The reviewer should fix the ticket body to carry an explicit `Spec section:` footer.
       - **No match**: Design Alignment row is `N/A — no spec found for change <CHANGE_NAME>`.

11. Extract only the relevant section of `openspec/changes/<CHANGE_NAME>/design.md` via grep (section name match). Do NOT read the whole file.

12. Read `openspec/changes/<CHANGE_NAME>/proposal.md` (it's short).

13. Hold the spec excerpt, design excerpt, change name, and section title in context for Phase 2's Design Alignment check.

## Phase 2: Verify

If `git status --porcelain` is non-empty, list the files and ask the user to either commit this ticket's files (`git add <paths>` — never `git add -A` or `git add .`, which sweeps in unrelated work) or confirm the rest are unrelated and continue with them left uncommitted (uncommitted edits would pass the checks but never reach the PR).

14. Review all changes on this branch versus the base, using the merge base so changes merged into the base after the branch was cut don't count as this branch's work:
    ```bash
    MB=$(git merge-base origin/<base> HEAD)
    git log origin/<base>..HEAD --oneline
    git diff $MB HEAD --stat
    ```
    If there is no merge base (e.g. a shallow clone), fall back to `git diff origin/<base>..HEAD --stat` and warn that the diff may include base-branch changes. Read through the changed files to understand what was implemented.

    **Stray-file scan.** List the net-diff paths (`git diff $MB HEAD --name-only`) and flag any path under `openspec/`, `sdd/tasks/` or `sdd/prds/` that does not start with `openspec/changes/<CHANGE_NAME>/`, `sdd/tasks/<CHANGE_NAME>` or `sdd/prds/<CHANGE_NAME>`. Living specs (`openspec/specs/**`) and archive output (`openspec/changes/archive/**`) are therefore always flagged, and so is every planning path when `CHANGE_NAME = none`. These usually arrive when another session's `git add -A` sweeps up uncommitted planning files. If any are flagged, list them and ask via **AskUserQuestion**:
    - **Remove from this PR (recommended)** — `git restore --source=$MB --staged -- <paths>`, then commit `chore(sdd): remove stray planning files <ticket-ref>`. Only the index changes; the working-tree copies stay as they are, so nothing is lost. Never rewrite history.
    - **Keep them** — the user confirms they belong in this PR.

    When `DRY_RUN`, list the strays and print `[DRY RUN] would remove <n> stray files in a new commit`.

15. Check each acceptance criterion from the ticket body:
    - Verify it is met by examining the code.
    - Mark as PASS or FAIL.
    - If FAIL, explain what is missing.

    Also check `## Definition of Done` items (if present) and report them under Code Review as recommendations (step 20 stays AC-only).

16. Read these constitution section files (lazy load — only what review needs):
    - `sdd/constitution/principles.md` (always)
    - `sdd/constitution/quality-gates.md` (always)
    - `sdd/constitution/design-system.md` — only if changed files include UI components or route files (if the file exists)
    - `sdd/constitution/utilities.md` — only if changed files touch the API client or shared data-shape utilities (if the file exists)

    Legacy fallback: read `docs/constitution.md` if `sdd/constitution/index.md` is absent.

17. Run the gate commands listed in `sdd/constitution/quality-gates.md`, in order; if absent, fall back to `npm test` / `npm run lint` / `npm run build` for the scripts that exist in `package.json`. Append `; echo "exit=$?"` to each command; exit 0 → PASS, non-zero → FAIL, undefined script → NOT CONFIGURED.

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
    - Contract fidelity: CLEAN / N/A / <issues>
    - Stray files: CLEAN / <removed or kept paths>

    ### Project Checks (one row per gate run in step 17)
    - <gate>: PASS/FAIL/NOT CONFIGURED

    ### Summary
    <Overall assessment>
    ```

20. If any acceptance criterion FAILs or any project check fails, tell the user what needs fixing and stop. Do NOT create a PR for incomplete work.

21. If code review flags issues, present them to the user as recommendations (not blockers); NON-NEGOTIABLE constitution violations are flagged as blocker recommendations, but the user still decides. Ask: "I found some code review items. Want to address them before the PR, or proceed as-is?"

22. If everything passes (or the user chooses to proceed), ask: "Ready to push and create a PR?"

## Phase 2.8: Check off the ticket's tasks.md section (only if linked)

Run this phase **only after the user confirms "yes" at step 22** (proceeding to push + PR), and skip it entirely if `CHANGE_NAME = none`. If the user declines, do not touch `tasks.md`. This marks the **current work item's own section** complete **on the feature branch**, so the checkbox state ships inside the feature PR instead of arriving as a separate post-merge commit. Scope is strictly the current ticket's section — never a full-file regeneration — so parallel work items of the same change edit disjoint lines and merge cleanly. `/sdd-status` Class C remains the reconciliation backstop that catches any drift.

22a. Open `openspec/changes/<CHANGE_NAME>/tasks.md` and locate the section header carrying `<ticket-id>` (`## N. <title> [<KEY>]` for Jira or `(#N)` for GitHub) — the same section identified in Phase 1.5.

22b. Within that section only (from its header up to the next `## ` header), flip every `- [ ]` to `- [x]`. Leave all other sections untouched. If the section is already fully `[x]`, this is a no-op — skip the commit.

22c. Commit on the feature branch (only if something changed):
    ```bash
    git add openspec/changes/<CHANGE_NAME>/tasks.md
    git commit -m "docs(tasks): check off section <N> <title> <ticket-ref>"
    ```
    `<ticket-ref>` follows the repo convention (`[<JIRA-KEY>]` or `(#<n>)`). When `DRY_RUN`, print `[DRY RUN] would check off <ticket-id>'s section in tasks.md` and skip the write + commit.

This commit is pushed in Phase 3, so the checkbox update is part of the feature PR — no separate tasks-only PR is needed.

## Phase 3: Create PR

23. Check for an existing PR on the branch (read-only, run directly): `gh pr view --json number,url,state`. If it is MERGED or CLOSED, stop and tell the user (do not push).

    Run `PushBranch(<current-branch>)` from the active VCS recipe. When `DRY_RUN`, print `[DRY RUN] would PushBranch(<branch>)`.

    If the PR is OPEN, skip steps 24–26 (`CreatePR` and `LinkTicketToPR`), print the existing PR URL, and go to Phase 4.

24. Read `sdd/templates/pr-body.md` for the PR body structure. Substitute the placeholders:
    - Summary, Changes, Acceptance Criteria, Testing
    - `<TICKET_CLOSE_LINE>`:
      - GitHub: `Closes #<ticket-id>`
      - Jira: `Resolves <JIRA-KEY>`

    Run `CreatePR(payload)` from the active VCS recipe. Capture the PR id and URL. When `DRY_RUN`, print the full payload and the intended `[DRY RUN] would CreatePR(...)` line; assign `DRY-PR-1` as the synthetic id for downstream use.

25. Print the PR URL (or synthetic id when `DRY_RUN`) so the user can review.

26. Run `LinkTicketToPR(<ticket-id>, <pr>)` from the active tracker recipe. This:
    - For GitHub: calls `CloseTicket(<ticket-id>, "Resolved in PR #<pr-id>.")` because PRs target `develop` (not the default branch) and GitHub only auto-closes on default-branch merge.
    - For Jira: posts a comment with the PR URL on the ticket and runs `UpdateTicketStatus(<ticket-id>, "in_review")`; the GitHub PR carries the `Resolves <JIRA-KEY>` reference. If that returns `unreachable`, print one warning — `<ticket-id> left in <current_status>; <jira.status_workflow.in_review> not reachable from there. PR link posted; move it manually if needed.` — and continue. Never fail the PR step over it.

    When `DRY_RUN`, print the intended `LinkTicketToPR(...)` call without executing.

## Phase 4: Hand-off Hint

27. Tell the user:
    ```
    PR opened (or updated): <pr-url>
    Once the PR merges, run /sdd-status to detect completion. /sdd-status
    will offer to archive the OpenSpec change and close the parent story
    when all linked work items are done.
    ```

    For `DRY_RUN`, frame as `[DRY RUN] PR would be opened. Re-run without --dry-run to execute.`

## Rules

- Never create a PR if acceptance criteria are not met.
- The PR title must follow conventional commit format with the ticket reference.
- The PR body must include the ticket close line so the ticket auto-closes (or transitions) on merge where supported.
- Always push before creating the PR (skipped in dry-run).
- Feature PRs target the configured base branch (`develop` by default). Only ask the user to confirm a different base if the configured base does not exist.
- Use abstract operation names from `sdd/trackers/protocol.md`; never embed `gh` or MCP calls inline. Exception: read-only `gh pr view` on the current branch's PR (step 23).
- Do NOT merge the PR. That is a human decision.
- The current ticket's `tasks.md` checkboxes are flipped here (Phase 2.8) so they ship in the feature PR. The remaining post-merge cleanup (archive OpenSpec change, close parent story, and a reconciliation pass over tasks.md checkboxes) lives in `/sdd-status`'s Completion Sweep — point the user there in the hand-off message.
