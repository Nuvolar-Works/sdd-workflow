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

- **`FetchTicket(id)`** — return title, body/description, labels/components, assignees, status, parent (if sub-task), and the `Source:` link if present. `id` is tracker-native (GitHub issue number or Jira issue key).
- **`CreateTicket(payload)`** — create a top-level ticket. `payload` includes title, body, labels, type, priority, parent (optional), and a `Source` field pointing at the originating OpenSpec change.
- **`CreateChildTickets(parent_id, payloads[])`** — create one or more child tickets under a parent. For Jira this means sub-tasks linked via `parent`. For GitHub this is emulated as separate issues that reference the parent in their body (`Parent: #N`).
- **`UpdateTicketStatus(id, status)`** — transition the ticket to a workflow status (`in_progress`, `in_review`, `done`). Tracker-specific mapping is in `sdd/config.json` under `jira.status_workflow` for Jira; for GitHub this is a no-op (state is implied by issue open/closed and PR linkage) but the operation may still post a status comment.
- **`CloseTicket(id, comment)`** — close the ticket with an explanatory comment. For Jira this transitions to the `done` status. For GitHub this calls `gh issue close --comment`.
- **`CommentOnTicket(id, body)`** — add a comment to a ticket. Used during `/sdd-work` (Decision/Blocker/Follow-up/Clarification posts, closing summary), during `/sdd-verify` (PR URL posting), and during `CloseTicket` (final comment).
- **`FetchComments(id, limit?)`** — return an ordered list of `{author, created_at, body}` for the ticket, oldest first. Default `limit` = 30 (most recent). Pass `limit = "all"` to get the full thread (rare; use only when reasoning about long histories). Used by `/sdd-tasks-from-story` Phase 1.5 (story comments) and `/sdd-work` Phase 1.6 (sub-task + parent comments).
- **`AssignTicket(id, user)`** — assign the ticket to a user. `user` may be `@me` for the current authenticated user. Failures are non-fatal — log and continue (assignment is convenience, not correctness).
- **`SearchTickets(query, limit?)`** — aggregate fetch. Returns an array of ticket payloads (same shape as `FetchTicket`) matching `query`. `query` is tracker-native (JQL for Jira, GitHub search syntax for GitHub). Used by `/sdd-status` to avoid N round-trips when reporting on multiple changes.

### Related tickets

- **`CreateRelatedTicket(payload, related_id, link_type)`** — create a top-level ticket and link it to an existing one. `link_type` is one of:
  - `"blocks"` — the new ticket blocks the related one
  - `"is_blocked_by"` — the new ticket is blocked by the related one (rare; the inverse is more common but listed for completeness)
  - `"relates_to"` — loose relationship
  - `"follows_up"` — a synthesised type for "future work discovered during this implementation". Jira maps it to a "Relates" link plus a labelled comment; GitHub emulates via `Follow-up of #N` body footer.

  Used by `/sdd-work` Phase 3.5 to track blockers and follow-up work as standalone tickets so they don't fall off the radar after the current sub-task ships.

### Labels / metadata

- **`EnsureLabel(name)`** — create the label/component if missing. No-op if it already exists. For Jira this maps to a label string (no creation needed) or a component key.

### VCS operations (provided by the `vcs` tracker file)

- **`CreateBranch(name, base)`** — create and check out a feature branch from `base`. Default base from `sdd/config.json` (`github.default_base_branch`).
- **`PushBranch(name)`** — push the current branch with upstream tracking.
- **`CreatePR(payload)`** — create a pull/merge request. `payload` includes title, body, base, ticket link.
- **`LinkTicketToPR(ticket, pr)`** — record the PR URL on the ticket so reviewers can find the code. For GitHub-only flows this is auto-handled by `Closes #N`. For Jira+GitHub hybrid this means a Jira comment with the PR URL plus a status transition.

## Calling convention

When a skill needs an operation, it should write something like:

> Use `FetchTicket($ARGUMENTS)` from `sdd/trackers/<tracker>.md`.

The active recipe file gives the exact command, JSON shape, and error handling. Skills do **not** embed `gh` or `mcp__claude_ai_Atlassian_Rovo__*` calls inline.

## Dry-run convention

Skills accept a `--dry-run` flag in their arguments (parsed by each skill's Phase 0). When set:

- **Read operations** (`FetchTicket`, `FetchComments`, `SearchTickets`, `VerifyAuth`) run normally — the skill needs them to reason about state.
- **Write operations** (`CreateTicket`, `CreateChildTickets`, `CreateRelatedTicket`, `UpdateTicketStatus`, `CloseTicket`, `CommentOnTicket`, `AssignTicket`, `EnsureLabel`, `CreateBranch`, `PushBranch`, `CreatePR`, `LinkTicketToPR`) are **not executed**. Instead, print a single `[DRY RUN] would <op>(<args>)` line announcing the intended call and continue.
- For operations that return ids the skill needs downstream (e.g. `CreateTicket`), return a synthetic id (`DRY-1`, `DRY-2`, …, incrementing per skill invocation) so dependency wiring still works.

Tracker recipes themselves don't implement `--dry-run` — the calling skill is responsible for short-circuiting writes when its DRY_RUN flag is set. Recipes just describe the real call. This keeps the recipes simple and the dry-run logic in one place per skill.
