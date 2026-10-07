# Tracker Protocol

Tracker-neutral operations used by SDD skills. Each operation has a concrete recipe in `sdd/trackers/<tracker>.md`. Skills reference operations by the names below; only the active tracker's recipe file loads per session.

## Active tracker selection

1. Read `sdd/config.json`. The `tracker` field selects ticket operations (`github` or `jira`). The `vcs` field selects code/PR operations (always `github` for now).
2. Load `sdd/trackers/<tracker>.md` for ticket operations.
3. Load `sdd/trackers/<vcs>.md` for branch/PR operations (often the same file).

## Operations

### Authentication

- **`VerifyAuth()`** — confirm the active tracker is reachable and authenticated. Fail loudly with the remediation step if not.

### Ticket lifecycle

- **`FetchTicket(id)`** — return title, body/description, labels/components, assignees, status, parent (the story this work item belongs to — for Jira, resolved from the child link or a legacy `parent` field), and the `Source:` link if present. `id` is tracker-native (GitHub issue number or Jira issue key).
- **`CreateTicket(payload)`** — create a top-level ticket. `payload` includes title, body, labels, type, priority, parent (optional), and a `Source` field pointing at the originating OpenSpec change.
- **`CreateChildTickets(parent_id, payloads[])`** — create one or more board-visible work-item tickets associated with a parent story. For Jira these are standalone issues of `jira.child_issue_type` (e.g. `Task`) each **linked** to the parent via `jira.child_link_type` — **not** Sub-tasks, which would be hidden from the board. For GitHub this is emulated as separate issues that reference the parent in their body (`Parent: #N`).
- **`UpdateTicketStatus(id, status)`** — transition the ticket to a workflow status (`in_progress`, `in_review`, `done`). For Jira, `jira.status_workflow` in `sdd/config.json` maps each SDD status to the target Jira status name; for GitHub this is a no-op (state is implied by issue open/closed and PR linkage) but the operation may still post a status comment. Returns one of:
  - `transitioned` — the ticket moved to the target status (or the tracker has nothing to move).
  - `already` — the ticket was already in the target status; nothing was written. Covers tracker automations that moved it first.
  - `unreachable { current_status, available_transitions }` — the tracker's workflow does not offer the target from where the ticket is. `current_status` is where the ticket actually is now.

  Recipes never stop the calling skill; the caller decides how to handle `unreachable`, and reports status names from config or from the result, never hard-coded ones.
- **`CloseTicket(id, comment)`** — close the ticket with an explanatory comment. For Jira this transitions to the `done` status. For GitHub this calls `gh issue close --comment`. Also used on Regenerate to retire a replaced ticket: create the replacement, then `CloseTicket(<old>, "Replaced by <new>")` (there is no delete operation).
- **`CommentOnTicket(id, body)`** — add a comment to a ticket. Used during `/sdd-work` (Decision/Blocker/Follow-up/Clarification posts, closing summary), during `/sdd-verify` (PR URL posting), and during `CloseTicket` (final comment).
- **`FetchComments(id, limit?)`** — return an ordered list of `{author, created_at, body}` for the ticket, oldest first. Default `limit` = 30 (most recent). Pass `limit = "all"` to get the full thread (rare; use only when reasoning about long histories). Used by `/sdd-tasks-from-story` Phase 1.5 (story comments) and `/sdd-work` Phase 1.6 (work-item + parent-story comments).
- **`AssignTicket(id, user)`** — assign the ticket to a user. `user` may be `@me` for the current authenticated user. Failures are non-fatal — log and continue (assignment is convenience, not correctness).
- **`SearchTickets(query, limit?)`** — aggregate fetch. Returns an array of ticket payloads (same shape as `FetchTicket`) matching `query`. `query` is tracker-native (JQL for Jira, GitHub search syntax for GitHub). Used by `/sdd-status` to avoid N round-trips when reporting on multiple changes.
- **`GetLinkedPR(id)`** — resolve the PR linked to a ticket. Returns `{ pr_number, state, merged_at }` (state is `MERGED` / `CLOSED` / `OPEN`) or `null` if no PR is linked. Used by `/sdd-status` Phase 5 to detect Class A (GitHub: closed-and-merged → archive eligible) and Class A.1 (Jira: in-review with merged PR → transition to done). GitHub recipe scans for the `Resolved in PR #<n>` closing comment, falling back to `closedByPullRequestsReferences` (only populated for PRs into the default branch); Jira recipe scans ticket comments for a GitHub PR URL and checks its state via `gh`.

### Related tickets

- **`CreateRelatedTicket(payload, related_id, link_type)`** — create a top-level ticket and link it to an existing one. `link_type` is one of:
  - `"blocks"` — the new ticket blocks the related one
  - `"is_blocked_by"` — the new ticket is blocked by the related one
  - `"relates_to"` — loose relationship
  - `"follows_up"` — a synthesised type for "future work discovered during this implementation". Jira maps it to a "Relates" link plus a labelled comment; GitHub emulates via `Follow-up of #N` body footer.

  Used by `/sdd-work` Phase 3.5 to track blockers and follow-up work as standalone tickets so they don't fall off the radar after the current work item ships.

### Labels / metadata

- **`EnsureLabel(name)`** — create the label/component if missing. No-op if it already exists. For Jira this maps to a label string (no creation needed).

### VCS operations (provided by the `vcs` tracker file)

- **`CreateBranch(name, base)`** — create and check out a feature branch from `base`. Default base from `sdd/config.json` (`github.default_base_branch`).
- **`PushBranch(name)`** — push the current branch with upstream tracking.
- **`CreatePR(payload)`** — create a pull/merge request. `payload` includes title, body, base, ticket link.
- **`LinkTicketToPR(ticket, pr)`** — record the PR URL on the ticket so reviewers can find the code. For GitHub, PRs target `develop`, so `Closes #N` does not auto-close; the recipe closes the issue via `CloseTicket` at PR creation. For Jira this means a Jira comment with the PR URL plus a transition to `in_review`.

## Calling convention

When a skill needs an operation, it should write something like:

> Use `FetchTicket($ARGUMENTS)` from `sdd/trackers/<tracker>.md`.

The active recipe file gives the exact command, JSON shape, and error handling. Skills do **not** embed `gh` or `mcp__claude_ai_Atlassian_Rovo__*` calls inline. Exception: read-only lookups of the current branch's PR (`gh pr view`, and its review comments via `gh api repos/{owner}/{repo}/pulls/<n>/comments`) may be run directly.

## Dry-run convention

Skills accept a `--dry-run` flag in their arguments (parsed by each skill's Phase 0). When set:

- **Read operations** (`FetchTicket`, `FetchComments`, `SearchTickets`, `GetLinkedPR`, `VerifyAuth`) run normally — the skill needs them to reason about state.
- **Write operations** (`CreateTicket`, `CreateChildTickets`, `CreateRelatedTicket`, `UpdateTicketStatus`, `CloseTicket`, `CommentOnTicket`, `AssignTicket`, `EnsureLabel`, `CreateBranch`, `PushBranch`, `CreatePR`, `LinkTicketToPR`) are **not executed**. Instead, print a single `[DRY RUN] would <op>(<args>)` line announcing the intended call and continue.
- For operations that return ids the skill needs downstream (e.g. `CreateTicket`), return a synthetic id (`DRY-1`, `DRY-2`, …, incrementing per skill invocation) so dependency wiring still works.

Tracker recipes themselves don't implement `--dry-run` — the calling skill is responsible for short-circuiting writes when its DRY_RUN flag is set. Recipes just describe the real call. This keeps the recipes simple and the dry-run logic in one place per skill.
