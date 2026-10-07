---
name: sdd-work
description: Pick up a ticket end-to-end. Self-detects branch state — runs Fresh (full plan + implement), Resume (continue in-flight work), or Fix-from-PR (address review feedback) automatically based on the current branch. Works with any tracker (GitHub or Jira) configured via sdd/config.json.
argument-hint: "<ticket-id> [--dry-run]"
disable-model-invocation: true
---

# Work on a Ticket

You are implementing a tracker ticket end-to-end. The skill self-detects which mode to run in based on the current git branch.

## Input

`$ARGUMENTS` parsed as: `<ticket-id> [--dry-run]`

- Required: `<ticket-id>` (e.g. `42` for GitHub or `TT-456` for Jira).
- Optional: `--dry-run`. When present, set `DRY_RUN=true`. Tracker writes are mocked; **code edits do not happen** — the skill stops after presenting the plan.

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. Capture `tracker` and `vcs`.
2. Read `sdd/trackers/protocol.md` for abstract operations and the dry-run convention.
3. Read `sdd/trackers/<tracker>.md` for ticket operations.
4. If `vcs` differs from `tracker`, also read `sdd/trackers/<vcs>.md`.

## Phase 0.5: Branch State Detection (mode selection)

This phase decides whether to run **Fresh**, **Resume**, or **Fix-from-PR** mode. No prompt at the start — the mode falls out of the branch state.

5. Inspect the current branch:
   ```bash
   git branch --show-current
   git log <base>..HEAD --oneline    # base from sdd/config.json (default: develop)
   ```

6. If on the base branch (`develop` or `main`) → **Fresh** mode. Continue at Phase 1.

   If not on the base branch, extract the ticket id from the branch name (same rule as `/sdd-verify` step 5). If it differs from `$ARGUMENTS`, stop and ask: switch to the base branch (Fresh) or abort.

7. Otherwise, check for an existing PR (read-only, run directly):
   ```bash
   gh pr view --json number,state,reviewDecision,reviews,comments,statusCheckRollup,url
   ```
   Treat "no pull requests found" as "No PR yet". The PR check uses `gh` regardless of tracker (PRs live in GitHub).

8. **Mode selection**:

   | State | Mode | Behavior |
   |-------|------|----------|
   | No PR yet (with or without commits) | **Resume** | Skip Phase 2 (codebase research) and the plan-confirmation prompt. Re-state acceptance criteria status from existing commits. Continue at Phase 1 with light context. |
   | PR open, no review feedback, no failing checks | **Resume** | Same as above. |
   | PR open with `reviewDecision = CHANGES_REQUESTED`, `reviews`/`comments` needing reply, or a failing check in `statusCheckRollup` | **Fix-from-PR** | Use `reviews`/`comments` and failing checks (name + details URL) from step 7 — CI's verdict is authoritative for every stack, whatever runs it; fetch inline file:line comments via `gh api repos/{owner}/{repo}/pulls/<n>/comments`. Sync them to the ticket as a Clarification comment (opt-in via Phase 3.5 prompts later). Skip Phase 2's codebase research; present a focused fix plan. |
   | PR merged | — | Tell the user the work is done; suggest running `/sdd-status` to archive the change. Stop. |
   | PR closed (not merged) | — | Stop and ask the user how to proceed. |

   Announce the detected mode:
   ```
   Mode: Fresh / Resume / Fix-from-PR
   Branch: <branch>, <N> commits ahead of <base>
   <details specific to the mode>
   ```

9. **In Resume and Fix-from-PR modes**, remember the existing branch and skip the `CreateBranch` step in Phase 3. Continue using the current branch for further commits.

## Phase 1: Understand the Ticket

10. Run `FetchTicket($ARGUMENTS)` and `AssignTicket($ARGUMENTS, "@me")` from the active tracker recipe (when `DRY_RUN`, print `[DRY RUN] would AssignTicket(...)` instead). Hold the ticket payload (title, body, labels, status, parent) in context.

11. Read the body. Identify what to build, AC, `## Definition of Done` items (if present), dependencies, implementation hints. If dependencies are open, warn the user and ask whether to proceed.

12. Detect a linked OpenSpec change via the `Source:` footer:
    ```
    Source: openspec/changes/<CHANGE_NAME>/tasks.md
    ```
    If found, extract `<CHANGE_NAME>`. If not, skip Phase 1.5.

13. Fresh mode only: call `UpdateTicketStatus($ARGUMENTS, "in_progress")` (Jira: real transition; GitHub: no-op). If it returns `unreachable`, warn with the current status and continue. When `DRY_RUN`, print the intended call.

## Phase 1.5: OpenSpec Context (lazy, only if linked)

14. Open `openspec/changes/<CHANGE_NAME>/tasks.md`. Find the section header carrying the exact annotation `(#<id>)` (GitHub) or `[<KEY>]` (Jira). Note the section title.

15. **Locate the relevant spec file**, in order of preference:
    a. Read the `Spec section:` footer in the ticket body — tickets created via `sdd/templates/ticket-creation-protocol.md` carry an explicit pointer. When present, use it without prompting.
    b. Heuristic fallback when no footer: glob `openspec/changes/<CHANGE_NAME>/specs/*/spec.md` and score each by keyword overlap with the section title.
       - **Single match** (one file has any hits): use it.
       - **Clear winner** (top file's score ≥ 2× the runner-up's): use it; note "spec inferred from <file> — confirm if wrong" in the plan in Phase 2.
       - **Ambiguous** (top two scores within 1 of each other, or two+ files tied at the top): list the top 2–3 candidates with their scores and ask: "Multiple specs match this section. Which one is correct? (1/2/3/none — describe instead)". Do not silently pick.
       - **No match**: tell the user no spec maps cleanly to this ticket and ask whether to proceed without a spec context or pick one manually.

16. If the body has a non-empty `## Design Excerpt`, use it; otherwise extract only the relevant section of `design.md` via grep. Do NOT read the whole file.

17. Read `proposal.md` (it's short).

18. Stage context: if the body has `## Stage Context`, read `sdd/tasks/<feature>-stages.md` for the full stage map and identify what prior stages produced.

## Phase 1.6: Read Ticket Comments (work item + parent story)

19. Run `FetchComments($ARGUMENTS)`.

20. If the ticket has a `parent` (for Jira, the story it was split from — `FetchTicket` resolves this from the child link, or from a legacy `parent` field) or a `Parent: #N` body line (GitHub emulated), also run `FetchComments(<parent-id>)`.

21. Filter substantive comments using the heuristic in `sdd/templates/story-comment-triage.md` § Step 2 (bot/automation, ≤10-word with no link/code/number, pure emoji are dropped).

22. Surface a digest:
    ```
    Comments on this ticket: <count> (<substantive count> substantive)
    Comments on parent <parent-id>: <count> (<substantive count> substantive)

    Substantive highlights:
    - [parent | <author>, <date>] <one-line summary>
    - [ticket | <author>, <date>] <one-line summary>
    ```

23. In **Fix-from-PR mode**: the digest also includes the PR review threads as `[review | <reviewer>] <thread summary>`. These are the primary inputs to the focused fix plan in Phase 2.

24. Comments factor into the plan in Phase 2. **On conflict between body and a comment, the comment wins** unless clearly superseded later.

## Phase 1.7: Constitution Sections (lazy)

25. Read these only:
    - `sdd/constitution/principles.md`
    - `sdd/constitution/folder-structure.md`
    - `sdd/constitution/quality-gates.md`

    Legacy fallback: `docs/constitution.md` if `sdd/constitution/index.md` is absent. Skip if neither exists.

## Phase 2: Plan

26. **Fresh mode**: research the codebase via Glob / Grep / targeted reads. Identify files to modify, files to create, patterns to follow, tests that may need updating. Present the implementation plan:

    ```
    ## Implementation Plan for <ticket-id>: <title>

    ### Files to modify:
    - path — <change>

    ### Files to create:
    - path — <purpose>

    ### Approach:
    <brief description>

    ### OpenSpec Context (if linked):
    - Change: <change-name>
    - Spec: <file>
    - Design: <key points from the relevant section>
    - Prior stages: <reusable outputs>

    ### Risks or open questions:
    <concerns>
    ```

    Ask: "Does this plan look good? Should I proceed?" Don't write code until the user confirms.

    When `DRY_RUN`: print `[DRY RUN] would CreateBranch(<branch-name>, <base>) and implement the plan above`, then stop the skill. Code edits, branch creation, and commits don't happen in dry-run mode.

27. **Resume mode**: skip the codebase research. Walk through each AC and report PASS / PARTIAL / NOT STARTED based on commit history (`git log <base>..HEAD`) and a brief diff scan. Present:

    ```
    ## Resume Status for <ticket-id>: <title>

    Commits so far:
    - <hash> <subject>
    - <hash> <subject>

    Acceptance Criteria status:
    - [x] <criterion> — covered by <hash>
    - [ ] <criterion> — not yet
    - [ ] <criterion> — partial: <what's left>

    Suggested next:
    <concrete next-step suggestion>
    ```

    Ask: "Continue with the suggested next step?" or "Stop and let me decide?"

    When `DRY_RUN`: print `[DRY RUN] would continue work on <current-branch> per the suggested next step`, then stop the skill.

28. **Fix-from-PR mode**: build a fix plan from the PR review threads. For each thread:
    - The reviewer's concern (verbatim).
    - The change required.
    - The file:line if specified.

    Present:

    ```
    ## Fix Plan for <ticket-id>: <title>

    Review threads to address:
    1. <reviewer> on <file>:<line> — <concern>
       Proposed fix: <description>
    2. ...

    Other commits planned: <if any extra fixes Claude noticed>
    ```

    Ask: "Does this fix plan look right? Should I proceed?"

    When `DRY_RUN`: print `[DRY RUN] would apply the fix plan on <current-branch> and push fixes`, then stop the skill.

## Phase 3: Implement

29. **Fresh mode only**: create a feature branch via `CreateBranch(<branch-name>, <base>)`. Branch name: `<type>/<ticket-id-slug>-<short-description>` per the conventions in CLAUDE.md.

    **Resume / Fix-from-PR**: stay on the current branch. Skip branch creation.

    (`DRY_RUN` has already halted the skill at the end of Phase 2 — see steps 26 / 27 / 28.)

30. Implement the changes following the plan. Follow existing patterns. Add or update tests if AC requires. Keep changes focused.

31. Run the gate commands listed in `sdd/constitution/quality-gates.md`, in order. Append `; echo "exit=$?"` to each command; exit 0 → PASS, non-zero → FAIL, command not found → NOT CONFIGURED. A gate with no runnable command (unless marked `review-only`) is NOT CONFIGURED — never skip it silently. Gates marked `CI-only` are not run; list them as `CI-only (not run locally)`. If `quality-gates.md` is absent, run nothing and report `Project checks: NOT CONFIGURED — run /sdd-constitution`; never guess gate commands from build manifests or CI config.

    Fix issues these surface. If any check still fails after fix attempts, ask the user: "Checks still failing (<names>) — keep iterating, or save progress and stop? (/sdd-verify will not open a PR while a check fails.)"

## Phase 3.5: Record Discoveries

32. Read `sdd/templates/work-discovery-comments.md` for detection logic, prompt flow, drafting rules, and follow-up ticket creation. The template covers:
    - Detection signals (divergence, blocker, surprise, confirmation, future-work-placeholder).
    - Per-moment prompt (`yes / edit / skip`).
    - Drafting via `sdd/templates/ticket-comment-shapes.md`.
    - For Blockers / Follow-ups: second prompt for `CreateRelatedTicket` linked to the parent story (or current ticket if no parent).
    - State tracking (decisions / blockers / follow-ups / clarifications) for the Phase 4.5 closing summary.

## Phase 4: Commit and Verify

33. Stage and commit using conventional commits:
    ```bash
    git add <specific-files>
    git commit -m "<type>(<scope>): <description> <ticket-ref>"
    ```
    - `<type>` from ticket labels.
    - `<scope>` is the area touched.
    - `<ticket-ref>`: `(#42)` for GitHub, `[TT-456]` for Jira.
    - Granular commits — one logical change per commit.

34. After implementation, walk through each AC and verify it is met. Report PASS / FAIL per criterion.

35. **Do NOT update `openspec/changes/<CHANGE_NAME>/tasks.md` checkbox state during work.** This is intentional — granular per-edit writes while coding caused merge conflicts when multiple developers worked on the same change. The current ticket's section is checked off later, once, by `/sdd-verify` (Phase 2.8) right before the PR is created, so the checkbox flip ships **inside the feature PR** rather than as a separate post-merge commit. That flip is scoped to the current ticket's own section, so parallel work items stay conflict-free. `/sdd-status` Class C remains a reconciliation backstop. The single source of truth for "is this work item done?" is still the ticket's status.

## Phase 4.5: Closing Summary

36. Read `sdd/templates/ticket-comment-shapes.md` for the **Closing summary** shape.

37. Draft the summary using the work_state from Phase 3.5:
    - **Built**: 1-3 lines from the implementation plan.
    - **Key decisions**: bullets, or `None`.
    - **Deviations from spec**: bullets, or `None`.
    - **Follow-ups created**: bullets with new ticket ids, or `None`.
    - **PR**: `<pending /sdd-verify>`.

38. Show the draft. Ask: "Post this summary to the ticket before handing off to /sdd-verify? (yes / edit / skip)"

39. On `yes` / `edit`, run `CommentOnTicket($ARGUMENTS, <body>)`.

## Phase 5: Hand Off

40. Tell the user:
    ```
    Implementation complete! Run /sdd-verify to review the changes and create a PR.
    ```

    If a check was left failing at step 31, list the failing checks instead of "Implementation complete!".

    In **Fix-from-PR mode**, the PR already exists. Adjust the message:
    ```
    Fix commits are committed locally. Run /sdd-verify to re-run checks and push them to the existing PR.
    ```

## Rules

- ALWAYS confirm the plan with the user before writing code (Fresh and Fix-from-PR modes; Resume mode confirms the next step).
- Granular commits, conventional format, ticket reference in every commit message.
- Do NOT push the branch — that's `/sdd-verify`'s job.
- Do not add features beyond what the ticket asks for.
- Use abstract operation names from `sdd/trackers/protocol.md`; never embed `gh` or MCP calls inline. Exception: read-only lookups of the current branch's PR (`gh pr view`, and its inline review comments via `gh api`) in Phase 0.5.
- Read constitution and OpenSpec artifacts **lazily** — load only sections relevant to this specific ticket.
- The skill **never** updates `openspec/changes/<change>/tasks.md` checkbox state. `/sdd-verify` checks off the current ticket's section (so it ships in the feature PR); `/sdd-status` Class C reconciles any drift.
- `--dry-run` halts the skill after Phase 2 (the plan). Code edits, branch creation, and commits don't happen in dry-run mode. Tracker writes are mocked.
- If you encounter something unexpected, stop and ask the user rather than guessing.
