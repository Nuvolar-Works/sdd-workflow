# Work-Discovery Comments

Used by `/sdd-work` Phase 3.5 during implementation. Whenever a moment occurs that's worth recording on the ticket, this template defines the detection logic, the prompt flow, and the handoff to the comment-shapes template for actual drafting.

This template is loaded **lazily** — only when a candidate moment fires, not on every `/sdd-work` invocation.

## Detection — what counts as a candidate moment

While implementing, watch for these signals:

| Signal | Likely shape |
|--------|--------------|
| The chosen implementation diverges from `design.md` (different primitive, different file location, different pattern) | **Decision** |
| Backend / external dependency confirmed missing or different from the spec | **Blocker** |
| A mock, stub, or `TODO` is being left behind for future cleanup | **Follow-up** |
| Confirmation received from another team that resolves a previously-open question | **Clarification** |
| A surprise constraint forced a non-obvious choice (perf, a11y, types, browser bug) | **Decision** |

If multiple signals fire on the same moment, pick the one that best describes the **outcome on the ticket**, not the cause. (E.g. backend confirmed a different shape AND mock left behind → post a **Clarification** for the shape, then a separate **Follow-up** for the mock.)

## Prompt flow

For each candidate moment, ask the user once. Don't batch — moments are momentary, and the user wants the prompt while context is still fresh.

```
This looks like context worth recording on the ticket.
Post as [Decision / Blocker / Follow-up / Clarification] comment? (yes / edit / skip)
```

Defaults:
- `yes` — draft using the matching shape from `sdd/templates/ticket-comment-shapes.md`, show the draft, post via `CommentOnTicket`.
- `edit` — draft, show, accept the user's inline edits, post.
- `skip` — discard. Don't ask again about the same moment.

## Drafting

When the user picks `yes` or `edit`:

1. Read `sdd/templates/ticket-comment-shapes.md` (lazy — only when actually drafting).
2. Use the matching shape's heading and field checklist to draft the comment body.
3. Show the draft to the user with a `(yes / edit / skip)` re-confirmation.
4. On final `yes`, call `CommentOnTicket($ARGUMENTS, <body>)`.

## Follow-up ticket prompt (Blocker and Follow-up only)

After a **Blocker** or **Follow-up** comment is posted, immediately ask:

```
Create a follow-up ticket for this so it's tracked? (yes / no)
```

If `yes`:

1. Build a payload:
   - **Title**: brief and action-oriented. Examples:
     - For a Blocker: `"Replace mock with real /api/v1/dashboard integration"`
     - For a Follow-up: `"Migrate <component> to <new-pattern> when <condition>"`
   - **Description**: 3-line block — *what* needs to happen, *where* (file:line of the placeholder), *why* (one sentence pulled from the comment).
   - **Labels**: `follow-up` plus the area labels of the current work item.
   - **Type**: `feat` for a Blocker (it's deferred work); `chore` for a pure cleanup Follow-up.

2. Determine the related id:
   - If the current work item has a `parent` (for Jira, the story it was split from — resolved by `FetchTicket` from the child link; for GitHub, the `Parent: #N` body line), use the **parent story** as `related_id`. The story is the persistent unit.
   - Otherwise, use `$ARGUMENTS` as `related_id`.

3. Determine the link type:
   - **Blocker** comment → `link_type = "is_blocked_by"`
   - **Follow-up** comment → `link_type = "follows_up"`

4. Call `CreateRelatedTicket(payload, related_id, link_type)`. Capture the new ticket id.

5. If it was a Follow-up: post a one-line `**Tracked as:** <new-id>` reply via `CommentOnTicket`.

   For Blocker comments, no in-place amendment is needed — the recipe's back-reference comment on the parent does the linking.

## State tracking

The skill maintains a list of every comment posted and every follow-up ticket created during this `/sdd-work` invocation. This list feeds the **Closing summary** comment in Phase 4.5:

```
work_state = {
  decisions: [{file, body_summary}, ...],
  blockers: [{summary, follow_up_ticket_id?}, ...],
  follow_ups: [{summary, follow_up_ticket_id}, ...],
  clarifications: [{summary, source}, ...],
}
```

The Closing summary stitches these together into one anchor comment.

## Skip semantics

`skip` on the initial candidate-moment prompt is permanent for that moment — the skill won't re-ask about the same divergence later. If the user changes their mind, they must invoke a new moment (e.g. by surfacing the discovery in chat to Claude).
