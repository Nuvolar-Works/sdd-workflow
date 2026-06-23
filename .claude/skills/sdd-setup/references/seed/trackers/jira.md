# Jira Tracker Recipes

Concrete implementations of `sdd/trackers/protocol.md` operations using the Atlassian Rovo MCP. Used when `tracker` is `jira` in `sdd/config.json`.

All operations route through the `mcp__claude_ai_Atlassian_Rovo__*` tools. The MCP must be authenticated first — use `/sdd-setup` if it isn't.

## Configuration read

Before any operation, read `sdd/config.json` and extract:
- `jira.site` (e.g. `your-org.atlassian.net`)
- `jira.project_key` (e.g. `TT`)
- `jira.issue_type_map` (maps SDD type → Jira issue type name)
- `jira.child_issue_type` (the issue type for goal-level work items created under a story — a board-visible type such as `Task`, **not** a Sub-task type)
- `jira.child_link_type` (the issue-link type used to attach each work item to its parent story — e.g. `Work item split` where available, else `Relates`)
- `jira.status_workflow` (maps SDD status → Jira transition name)
- `jira.source_field` (custom field id for the OpenSpec source link, or `null` to fall back to a comment)

## VerifyAuth

Use `mcp__claude_ai_Atlassian_Rovo__authenticate` (or `complete_authentication` if a flow is already in progress). If the MCP cannot list accessible resources for the configured site, tell the user to re-run `/sdd-setup` and stop.

## FetchTicket(id)

`id` is a Jira issue key (e.g. `TT-456`).

Use the Atlassian Rovo `get_issue` tool (or equivalent) with the issue key. Map the returned payload to the protocol shape:
- `id` → `key`
- `title` → `fields.summary`
- `body` → `fields.description` (rendered to plain text)
- `labels` → `fields.labels`
- `assignees` → `[fields.assignee.displayName]` if present
- `status` → `fields.status.name`
- `parent` → resolve the story this ticket belongs to, in order:
  1. `fields.parent.key` if present (legacy Jira Sub-tasks created before the linked-task model, or items still parented under an Epic).
  2. Otherwise scan `fields.issuelinks` for a link whose `type.name` equals `jira.child_link_type` and return the linked counterpart's key — i.e. whichever of `inwardIssue` / `outwardIssue` is populated on that entry (Jira shows the *other* end relative to this issue, so the populated side is the parent story). For `Work item split` there is exactly one such link per work item (to its story). If several links of that type exist (more likely with the non-directional `Relates` fallback), prefer the counterpart whose issue type matches the story type from `jira.issue_type_map["feat"]`.
  3. If neither resolves, `parent` is unset.
- `Source` → `fields[<source_field>]` if `jira.source_field` is configured; otherwise scan `fields.description` for an `openspec/changes/<name>/` substring.

## CreateTicket(payload)

Use the Atlassian Rovo `create_issue` tool with:
- `project` → `jira.project_key`
- `summary` → `<type>: <title>`
- `issuetype` → `jira.issue_type_map[<type>]`
- `labels` → `payload.labels`
- `description` → multi-paragraph body containing:
  - Description (from payload)
  - Tasks list
  - Acceptance Criteria
  - Implementation Hints
  - Dependencies (Jira keys)
  - A trailing `Source: openspec/changes/<change>/tasks.md` line.
- `customfield_<source_field>` → if `jira.source_field` is set, populate it with the Source URL/path. Otherwise rely on the description footer.

Capture the returned issue key.

## CreateChildTickets(parent_id, payloads[])

Creates one board-visible **work-item ticket** per payload and links each back to the parent story. We do **not** use Jira Sub-tasks here: Sub-tasks (hierarchy level −1) don't appear on the board, which hides the goal-level work. Instead each work item is a standalone issue of `jira.child_issue_type` (e.g. `Task`, hierarchy level 0 — same level as a Story, so it cannot be a true child via `parent`) that is **linked** to the story.

For each payload:

1. **Create the work item.** Call `create_issue` with:
   - `project` → `jira.project_key`
   - `issuetype` → `jira.child_issue_type`
   - `summary`, `description`, `labels` — as in `CreateTicket`.
   - Do **not** set `parent` (the work item is not a sub-task or epic child; the story is at the same hierarchy level).
   Capture the returned key (`<child_key>`).

2. **Link it to the story.** Call `link_issue` (`createIssueLink`) with:
   - `type` → `jira.child_link_type`
   - `inwardIssue` → `parent_id` (the story)
   - `outwardIssue` → `<child_key>` (the new work item)

   This MCP's `createIssueLink` reads as **`inwardIssue <outward-phrase> outwardIssue`** (per its own example, "A is blocked by B" → `inwardIssue: B, outwardIssue: A`, i.e. B blocks A). For the default `Work item split` type (`outward: "split to"`, `inward: "split from"`) this yields **story `split to` work item** / **work item `split from` story** — the intended decomposition direction. If the configured link type is non-directional (e.g. `Relates`), direction is immaterial. Verify the rendered direction on first use and swap inward/outward if the instance inverts it.

Return the list of `<child_key>` values. Each work item now shows on the board and carries a visible link to its parent story.

## UpdateTicketStatus(id, status)

Resolve the Jira transition name from `jira.status_workflow[<status>]`. Use the Atlassian Rovo `transition_issue` tool with the issue key and transition name.

If the transition isn't available from the current status (Jira workflows can have gates), report the available transitions and stop — don't force.

## CloseTicket(id, comment)

1. `CommentOnTicket(id, comment)`.
2. `UpdateTicketStatus(id, "done")`.

## CommentOnTicket(id, body)

Use the Atlassian Rovo `add_comment` tool with the issue key and body. Body is plain text or Atlassian Document Format (ADF); plain markdown-style headings (`## Decision`, `## Blocker`, etc.) render acceptably in the Jira UI.

## FetchComments(id, limit?)

Use the Atlassian Rovo comment-listing tool (`list_comments` / `get_issue_comments` depending on MCP version) with the issue key. Default to the most recent 30 comments; pass `limit = "all"` to retrieve the full thread.

Map each Jira comment to the protocol shape:
- `author` → `author.displayName` (fall back to `author.accountId` if displayName is missing)
- `created_at` → `created`
- `body` → `body` rendered to plain text (Jira comments may be in ADF; flatten to text for the heuristic filters used by the SDD skills)

Order oldest-first. Cap at `limit`. If the Jira API supports pagination natively, fetch the most recent N rather than fetching all and slicing.

## AssignTicket(id, user)

Use the Atlassian Rovo `assign_issue` tool. For `@me`, resolve via `get_current_user` first to get the account id.

## CreateRelatedTicket(payload, related_id, link_type)

Two-step operation:

1. Create the new ticket via the Atlassian Rovo `create_issue` tool. Use the same payload shape as `CreateTicket` (top-level ticket — no `parent`). The new ticket's `issuetype` should reflect its nature (typically `Task` or the type derived from `payload.type`); avoid using the sub-task type here, since this is a standalone tracked item, not a child of `related_id`.

2. Link the new ticket to `related_id` via the Atlassian Rovo `link_issue` tool. Map `link_type` to a Jira issue-link type as follows:

   | `link_type`     | Jira link type | Direction (new → related) |
   |-----------------|----------------|---------------------------|
   | `blocks`        | `Blocks`       | new blocks related        |
   | `is_blocked_by` | `Blocks`       | related blocks new (set the link with the inverse direction) |
   | `relates_to`    | `Relates`      | new relates to related    |
   | `follows_up`    | `Relates`      | new relates to related, **plus** post a comment on the new ticket: `"Follow-up of <related_id>"` so the synthetic semantic is preserved when only the native `Relates` is available. |

   If the team uses a custom Jira link type called `Follow-up` / `Follows-up`, prefer that over the synthetic `Relates`+comment fallback.

3. Post a back-reference comment on `related_id` so it shows up in the original ticket's history:
   - For `is_blocked_by` / `blocks`: `"Tracked: <new-key> ([blocks|is blocked by] this ticket)"`
   - For `follows_up`: `"Follow-up tracked: <new-key>"`
   - For `relates_to`: `"Related: <new-key>"`

Return the new ticket's key.

## SearchTickets(query, limit?)

Aggregate fetch — used by `/sdd-status` to avoid N round-trips.

Use the Atlassian Rovo MCP `search_issues` tool (or `jql_search` depending on MCP version) with a JQL query and a `maxResults` cap.

`<query>` is JQL. Examples:
- `project = "TT" AND labels = "stage-05-time-tracking"` — all tickets in a stage.
- `project = "TT" AND issue in linkedIssues("TT-456", "split to")` — the work items split from a parent story (the linked-task model). Use the **outward** phrase of `jira.child_link_type` (for `Work item split` that is `split to`; for `Relates` use `relates to`).
- `project = "TT" AND (parent = "TT-456" OR issue in linkedIssues("TT-456", "split to"))` — covers both legacy Sub-tasks (`parent`) and current linked work items in one query. Use this for re-run detection so old and new artifacts are both found.
- `project = "TT" AND status != Done AND issuetype != Sub-task` — open top-level work (excludes any legacy sub-tasks).

Map each returned issue to the protocol shape exactly as `FetchTicket` does (see above). Cap defaults to 100. Pagination: if the result count equals the cap, the skill should re-issue with a higher cap or follow-up calls; the recipe doesn't paginate automatically.

## EnsureLabel(name)

Jira labels are free-form strings — no creation step needed. Just include the label in the next `create_issue` or `update_issue` call.

If the project uses Components instead of Labels for category grouping, use `add_component` once per project (idempotent).

## CreateBranch / PushBranch / CreatePR / LinkTicketToPR

These are VCS operations. Read `sdd/trackers/<vcs>.md` (typically `github.md`) for the implementation. The Jira recipe only contributes to `LinkTicketToPR`:

After the PR is created in GitHub:
1. `CommentOnTicket(<jira-key>, "PR opened: <pr-url>")`.
2. `UpdateTicketStatus(<jira-key>, "in_review")`.

Once the PR merges, `/sdd-status` Phase 5 (Class A.1) detects the merge and calls `UpdateTicketStatus(<jira-key>, "done")` automatically. The `/sdd-verify` skill does not transition Jira work-item tickets to `done` — only to `in_review` — because PR merge happens later.

## GetLinkedPR(id)

Resolve the GitHub PR linked to a Jira ticket. Used by `/sdd-status` Phase 5 Class A.1 to detect that a work-item ticket in `in_review` has its PR merged and is ready to transition to `done`.

1. `FetchComments(id)`.
2. Scan comments newest-first for either:
   - `PR opened: <url>` (posted by `LinkTicketToPR` above), or
   - any GitHub PR URL matching `https?://github\.com/[^/]+/[^/]+/pull/(\d+)`.
   Extract the PR number from the first match.
3. If no PR URL is found, return `null`.
4. Otherwise call `gh pr view <pr_number> --json state,mergedAt -q '{state, mergedAt}'` and return `{ pr_number, state, merged_at }`. (`gh` is available because `vcs: github` is the only supported VCS — see `sdd/config.example.json`.)

State is one of `MERGED`, `CLOSED` (not merged), `OPEN`.
