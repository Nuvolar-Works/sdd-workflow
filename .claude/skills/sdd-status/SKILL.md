---
name: sdd-status
description: Project snapshot plus completion sweep. Reports open tickets across active changes, current branch and linked ticket, last commits. Detects fully-completed changes and offers to archive them and close parent stories. Closes the post-merge loop.
argument-hint: "[--dry-run]"
disable-model-invocation: true
---

# SDD Status

You are producing a project snapshot **and** running the post-merge completion sweep. The status report is read-only; the sweep prompts before performing actions (archive, parent-story closure, derived `tasks.md` regeneration).

## Input

`$ARGUMENTS` parsed for `--dry-run`. When present, set `DRY_RUN=true`. Reads run normally; sweep actions print `[DRY RUN] would <op>(...)` instead of executing.

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. If missing, tell the user to run `/sdd-setup` and stop.
2. Read `sdd/trackers/protocol.md` for the dry-run convention.
3. Read `sdd/trackers/<tracker>.md` for `FetchTicket`, `SearchTickets`, `UpdateTicketStatus`, `CommentOnTicket`.

## Phase 1: Inventory Active Changes

4. List active OpenSpec changes:
   ```bash
   ls openspec/changes/ 2>/dev/null | grep -v '^archive$'
   ```

5. List `sdd/tasks/*.md` mapping files. Each represents a change with tickets. Parse the markdown table to capture ticket ids per change.

6. Compute the union of ticket ids across all mapping files. Use this as the input to a single `SearchTickets` call (or one per change if the tracker requires it).

## Phase 2: Aggregate Ticket Statuses (one query, not N)

7. Build a tracker-native query:
   - **Jira**: `project = "<PROJ>" AND key in (<comma-separated-ids>)` — single JQL search via `SearchTickets`.
   - **GitHub**: `gh issue list --state=all` plus filtering by ticket numbers client-side, OR a search query like `"in:body Source: openspec/changes"` — one shot. The recipe handles either path.

8. Call `SearchTickets(query)` once per tracker (or once total if the tracker can express a single query). Result: an array of ticket payloads with statuses.

9. Group by change:
   - Walk each `sdd/tasks/<change>.md` mapping.
   - For each ticket id, look up the status from the search result.
   - Count open / in-progress / done per change.

   When the search misses a ticket id (e.g. deleted), report it as `unknown` and continue.

## Phase 3: Current Branch Context

10. Run:
    ```bash
    git branch --show-current
    git log -5 --oneline
    git status --porcelain | wc -l
    ```

11. Extract the ticket id from the branch name if it matches the convention (`<type>/<ticket-id>-<slug>`).

12. If a ticket id was extracted, look it up in the search result for its status. (No extra `FetchTicket` call needed — it's already in the aggregate.)

## Phase 4: Status Report

Format compactly:

```
## SDD Status

Tracker: <tracker> (<site/repo>)
Active changes: <count>

| Change | Open | In Progress | Done | Total |
|--------|------|-------------|------|-------|
| <change-a> | 3 | 1 | 8 | 12 |
| <change-b> | 2 | 0 | 0 | 2 |

Current branch: <branch>
Linked ticket: <id> — <title> (status: <status>)
Uncommitted files: <count>

Last 5 commits:
- <hash> <subject>
- <hash> <subject>
...
```

If the current branch is the base branch (`develop` or `main`), omit the "Linked ticket" line.

## Phase 5: Completion Sweep

Walk the change list one more time and identify three classes of follow-up:

**Class A — Fully-done changes ready to archive.** A change is ready when every ticket in its mapping is `Done` (Jira) or **closed and resolved by a merged PR** (GitHub). The merge check matters because `/sdd-verify`'s `LinkTicketToPR` closes GitHub issues at PR-creation time as a workaround (PRs target `develop`, not the default branch, so GitHub's auto-close-on-merge doesn't fire). Without verifying the PR merged, a change can be archived while its work is still in review.

For each GitHub ticket in a candidate change:

1. `gh issue view <id> --json state` — confirm `state == CLOSED`. If not, the change is not Class A.
2. Call `GetLinkedPR(<id>)` from the GitHub recipe. This tries the GraphQL API (`closedByPullRequestsReferences`) first and falls back to the comment-text scan for `Resolved in PR #<n>`. Returns `{ pr_number, state, merged_at }` or `null`.
3. The returned `state` must be `MERGED`. Any other value (`OPEN`, `CLOSED` without merge) disqualifies the change from Class A.
4. If `GetLinkedPR` returns `null`, or the linked PR is not `MERGED`, surface the change in a separate **"Closed without merged PR — needs manual review"** row in the sweep output and skip archiving.

**Class A.1 — Jira work-item tickets ready to transition to Done.** Applies when `tracker = jira` (full Jira or hybrid). `/sdd-verify` transitions Jira work-item tickets (the goal-level Tasks linked to a story) to `In Review` at PR-creation time but does not transition to `Done` — that happens here, after the PR actually merges.

For each Jira ticket in the aggregate that is **not yet** `Done` (typically `In Review`, but also any pre-`Done` status):

1. Call `GetLinkedPR(<jira-key>)` from the Jira recipe. This scans the ticket's comments for a GitHub PR URL (posted by `LinkTicketToPR`) and checks the PR state via `gh`. Returns `{ pr_number, state, merged_at }` or `null`.
2. If `state == MERGED`, the ticket is a Class A.1 candidate — its PR has merged but the Jira status hasn't caught up.
3. If `state` is `OPEN` or `CLOSED` (not merged), or `null`, skip — the ticket is genuinely still in review (or has no PR yet).

A Jira work-item ticket that's already `Done` counts toward Class A; one still pre-`Done` with no merged PR keeps the parent change out of Class A.

**Class B — Parent stories ready to close.** For each fully-done change (counting Class A.1 candidates as effectively done), identify the parent story (read the mapping's "Source story:" line, or scan a sample ticket body for a `Parent:` line). If the parent story exists and is **not yet** in `Done` status, it's a candidate.

**Class C — `tasks.md` checkbox reconciliation (backstop).** As of the Phase 2.8 step in `/sdd-verify`, the primary checkbox flip happens on the feature branch and ships inside each work item's PR. Class C is now a **reconciliation backstop**: it catches drift where a ticket is `Done` but its section is still `[ ]` — e.g. work merged before this step existed, a hotfix that skipped `/sdd-verify`, or a ticket transitioned manually. For every change (not just fully-done ones), each section header carries a ticket id; the checklist under it should be `[x]` if the ticket is `Done`, `[ ]` otherwise. Usually a no-op once `/sdd-verify` has run for each merged work item.

13. Present the sweep:

    ```
    ## Completion Sweep

    Ready to archive (Class A):
    - openspec/changes/<change> (parent: <story-key> — story status: In Review)

    Closed without merged PR — needs manual review:
    - openspec/changes/<change> (ticket #<id> closed but PR #<n> is <state>)

    Jira work-item tickets ready to transition to Done (Class A.1):
    - <jira-key> (PR #<n> merged <merged_at>; current status: In Review)

    Parent stories ready to close (Class B):
    - <story-key> (<X> of <X> work items done)

    tasks.md regeneration (Class C):
    - openspec/changes/<change>/tasks.md — <N> checkboxes will flip to [x]

    Run completion actions? (yes / select / no)
    ```

    - **yes**: run all classes for all candidates.
    - **select**: per-item prompt.
    - **no**: skip the whole sweep.

14. **Class C is always safe** to run — it's a single-writer regeneration from authoritative tracker statuses. Even on `no`, offer to run **just the regeneration** ("Regenerate tasks.md anyway? (y/n)") because it has no side effects beyond the local repo and resolves the concurrency issue described in `sdd/README.md` § Concurrency.

15. **Execution** (when not `DRY_RUN`):
    - **Class A**: for each archive candidate, run `openspec archive <change>`. Update the mapping file: rename to `sdd/tasks/<change>.archived.md` or append `**Status:** Archived <YYYY-MM-DD>` to the front matter.
    - **Class A.1**: for each Jira work-item ticket whose PR is merged, run `UpdateTicketStatus(<jira-key>, "done")`. Order matters — run Class A.1 **before** Class A's archive check is re-evaluated for the same change, so a change whose only remaining "not done" work item is a Class A.1 candidate becomes eligible for Class A archival in the same sweep. (Practical execution: process A.1 first, then A, then B, then C.)
    - **Class B**: for each parent story, draft a Closing Summary comment aggregating the work-item summaries (use `sdd/templates/ticket-comment-shapes.md` § Closing summary). Show the draft. On user `yes`, post via `CommentOnTicket(<story-key>, body)` then run `UpdateTicketStatus(<story-key>, "done")`.
    - **Class C**: for each change, regenerate `openspec/changes/<change>/tasks.md`:
      - Read the current `tasks.md`.
      - For each `## N. <title> [<key>]` (or `(#N)`) section header:
        - Look up the ticket status from the aggregate.
        - If `Done` / `closed`: change every `- [ ]` in the section to `- [x]`.
        - Otherwise: leave as-is (in-progress and open both stay `[ ]`; the file is meant to reflect "is this section's work shipped?").
      - Write atomically (single read-modify-write). One git commit per regeneration is fine; the user can stage / commit as they like.

16. **Execution** (when `DRY_RUN`):
    - For each candidate, print `[DRY RUN] would <op>(...)`.
    - Don't write anything.
    - The output otherwise looks identical so the user can preview the impact.

## Rules

- The status report (Phases 1-4) is always read-only.
- The completion sweep (Phase 5) requires explicit user `yes` / `select` to run anything; default behaviour is to display.
- Class C (tasks.md regeneration) is safe enough that it can be offered separately even when the user declines the rest of the sweep.
- Use `SearchTickets` once per tracker (or once total) — never loop `FetchTicket` for the per-change counts. The 20-call cap from the previous version is gone.
- If `sdd/tasks/` is empty, show only the current-branch context and last commits. The sweep has nothing to do.
- Jira post-merge sync is handled by Class A.1 (see Phase 5). No manual transition is needed once a PR merges and the user runs `/sdd-status`.
