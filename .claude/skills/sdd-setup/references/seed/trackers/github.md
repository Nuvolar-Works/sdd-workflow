# GitHub Tracker Recipes

Concrete implementations of `sdd/trackers/protocol.md` operations using the `gh` CLI. Used when `tracker` or `vcs` is `github` in `sdd/config.json`.

## VerifyAuth

```bash
gh auth status 2>&1 | head -5
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

If either fails, tell the user to run `gh auth login` and ensure a GitHub remote is configured. Stop.

## FetchTicket(id)

`id` is a GitHub issue number (e.g. `42`).

```bash
gh issue view <id> --json number,title,body,labels,assignees,state,milestone
```

Map the JSON to the protocol shape:
- `id` → `number`
- `title` → `title`
- `body` → `body` (this contains the `Source:` footer if present, plus dependencies, AC, hints)
- `labels` → `labels[].name`
- `assignees` → `assignees[].login`
- `status` → `state` (`OPEN` | `CLOSED`)
- `parent` → not native; parse from `Parent: #N` line in body if present.

## CreateTicket(payload)

```bash
gh issue create \
  --title "<type>: <title>" \
  --label "<comma-separated-labels>" \
  --body "$(cat <<'ISSUE_EOF'
<payload.body>
ISSUE_EOF
)"
```

`payload.body` is the full body built by `sdd/templates/ticket-creation-protocol.md` Step 4 (including caller additions like Stage Context and the `Source:` footer). Pass it verbatim; do not re-template.

Capture the URL printed by `gh issue create` and parse the issue number from the URL tail.

## CreateChildTickets(parent_id, payloads[])

GitHub has no native parent/child relationship. Emulate by:
1. Calling `CreateTicket` for each child.
2. Including a `Parent: #<parent_id>` line in the child's body (above the `Source:` line).
3. Optionally appending a checklist of child issue numbers to the parent's body via `gh issue edit <parent_id> --body-file -`.

## UpdateTicketStatus(id, status)

GitHub has no workflow states beyond open/closed. For each status:
- `in_progress` → no-op, optionally `gh issue comment <id> --body "Started work."` (skip by default). Return `transitioned`.
- `in_review` → typically the PR creation handles this implicitly; no explicit transition. Return `transitioned`.
- `done` → if the issue is already closed, return `already`; otherwise call `CloseTicket` and return `transitioned`.

Never returns `unreachable`.

## CloseTicket(id, comment)

```bash
gh issue close <id> --comment "<comment>"
```

GitHub auto-closes issues only when a PR merges into the **default** branch. Feature PRs in this project target `develop`, which is not the default branch — so always call this explicitly after PR creation.

## CommentOnTicket(id, body)

```bash
gh issue comment <id> --body "<body>"
```

For multi-paragraph bodies use a heredoc:

```bash
gh issue comment <id> --body "$(cat <<'COMMENT_EOF'
## Decision
<body>
COMMENT_EOF
)"
```

## FetchComments(id, limit?)

```bash
gh issue view <id> --json comments --jq '.comments'
```

Returns an ordered array of `{author: {login}, createdAt, body}`. Map to the protocol shape:
- `author` → `author.login`
- `created_at` → `createdAt`
- `body` → `body` (already plain markdown)

`gh` returns the full comment list in chronological order. If a `limit` is provided and `< all`, slice the array to the most recent N before returning. There is no native pagination flag on `gh issue view`, so for tickets with very long histories the full payload is fetched — acceptable given the 30-comment default cap.

## CreateRelatedTicket(payload, related_id, link_type)

GitHub has no native typed issue links. Emulate via body footer + back-comment:

0. Call `EnsureLabel("follow-up")`.

1. Build the new issue body. Append a footer line based on `link_type`:
   - `blocks`        → `Blocks #<related_id>`
   - `is_blocked_by` → `Blocked by #<related_id>`
   - `relates_to`    → `Related to #<related_id>`
   - `follows_up`    → `Follow-up of #<related_id>`

2. Create the issue:
   ```bash
   gh issue create \
     --title "<type>: <title>" \
     --label "<labels>,follow-up" \
     --body "$(cat <<'ISSUE_EOF'
   ## Description
   <description>

   ## Why
   <what made this surface>

   ## Where
   <code location / placeholder reference>

   ---
   <Footer line per link_type above>
   ISSUE_EOF
   )"
   ```

3. Capture the new issue number from the URL. Post a back-reference comment on `related_id`:
   - `blocks` / `is_blocked_by` → `gh issue comment <related_id> --body "Tracked: #<new> (link: <link_type>)"`
   - `follows_up`               → `gh issue comment <related_id> --body "Follow-up tracked: #<new>"`
   - `relates_to`               → `gh issue comment <related_id> --body "Related: #<new>"`

Return the new issue number.

## AssignTicket(id, user)

```bash
gh issue edit <id> --add-assignee <user>
```

`user` may be `@me` for the current authenticated user. If GitHub rejects the assignment (e.g. the user lacks repo permissions or is outside the org), `gh` exits non-zero and prints the reason. Treat this as a non-fatal warning — log it and continue rather than aborting the whole skill. Assignment is convenience, not correctness.

## SearchTickets(query, limit?)

Aggregate fetch — used by `/sdd-status` to avoid N round-trips.

```bash
gh issue list \
  --state=all \
  --search "<query>" \
  --json number,title,state,labels,assignees,body \
  --limit <limit:-100>
```

`<query>` is GitHub search syntax. Examples:
- `"label:stage-05-time-tracking"` — all tickets in a stage.
- `"label:follow-up in:body \"Follow-up of #42\""` — follow-ups of #42 (matches the `Follow-up of #N` footer written by `CreateRelatedTicket`).
- `"assignee:@me state:open"` — your open work.

Map each issue in the JSON array to the protocol shape:
- `id` → `number`
- `title` → `title`
- `body` → `body`
- `labels` → `labels[].name`
- `assignees` → `assignees[].login`
- `status` → `state` (`OPEN` / `CLOSED`)
- `parent` → parsed from a `Parent: #N` line in `body`, as in `FetchTicket`.

Returns the full result set in one round-trip. Default `limit` of 100 is enough for most projects; pass higher when needed.

## EnsureLabel(name)

```bash
gh label create "<name>" --description "" --color "ededed" 2>/dev/null || true
```

The `|| true` swallows the "already exists" error so the operation is idempotent.

## CreateBranch(name, base)

```bash
git fetch origin <base>
git checkout -b <name> origin/<base>
```

Default `base` from `sdd/config.json` → `github.default_base_branch` (typically `develop`).

## PushBranch(name)

```bash
git push -u origin <name>
```

## CreatePR(payload)

Before creating, check whether the current branch already has a PR (read-only, may be run inline):

```bash
gh pr view --json number,url,state
```

If it is `OPEN`, skip `CreatePR` and `LinkTicketToPR` and reuse that PR. If it is `MERGED` or `CLOSED`, stop and tell the user.

```bash
gh pr create \
  --title "<type>(<scope>): <description>" \
  --base <base> \
  --body "$(cat <<'PR_EOF'
## Summary
<summary>

## Changes
- <change 1>
- <change 2>

## Acceptance Criteria
- [x] <criterion>

## Testing
<what was tested>

Closes #<issue-number>
PR_EOF
)"
```

Capture the PR URL from output. Extract the PR number from the URL tail.

## LinkTicketToPR(ticket, pr)

Call `CloseTicket(ticket, "Resolved in PR #<pr>.")` immediately after PR creation. The PR targets `develop`, not the default branch, so `Closes #<ticket>` does not auto-close the issue.

## GetLinkedPR(id)

Resolve the PR linked to a closed issue. Used by `/sdd-status` Phase 5 Class A to decide whether a change is ready to archive.

Two-tier lookup:

1. **Closing comment (primary)** — scan the issue's comments for the canonical comment posted by `LinkTicketToPR`:
   ```bash
   gh issue view <id> --json comments \
     --jq '.comments | map(select(.body | test("Resolved in PR #([0-9]+)"))) | last'
   ```
   Extract the PR number from the matched body via regex `Resolved in PR #([0-9]+)`.

2. **API (fallback)** — when no closing comment is found:
   ```bash
   gh issue view <id> --json closedByPullRequestsReferences \
     -q '.closedByPullRequestsReferences[]?.number'
   ```
   `closedByPullRequestsReferences` is only populated for PRs into the default branch, so it is usually empty for PRs that target `develop`.

For each candidate PR number, check merge state:

```bash
gh pr view <pr-number> --json state,mergedAt -q '{state, mergedAt}'
```

Return `{ pr_number, state, merged_at }`. State is one of `MERGED`, `CLOSED` (not merged), `OPEN`. If both tiers yield nothing, return `null` — the caller treats that as "closed without merged PR — needs manual review."
