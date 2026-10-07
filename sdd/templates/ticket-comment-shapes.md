# Ticket Comment Shapes

Used by `/sdd-work` (Phases 3.5, 4.5) and `/sdd-status` (Class B) when posting comments to a ticket. Five categories, each with a templated heading so future readers can scan a long thread quickly.

Skills load this file lazily — only when a comment is about to be drafted, not on every invocation. Comments are posted via `CommentOnTicket(id, body)` from the active tracker recipe and only after the user explicitly confirms (`yes` / `edit` / `skip`).

## When to post each shape

| Shape | Trigger | Posted by |
|-------|---------|-----------|
| Decision | Implementation choice that diverges from `design.md` or the ticket body's stated approach | `/sdd-work` Phase 3.5 |
| Blocker | External dependency surfaced during work (API not ready, missing infra, awaiting another team) | `/sdd-work` Phase 3.5 |
| Follow-up | Known future work created as a placeholder during this implementation (stub or test double to be replaced, TODO with a real owner) | `/sdd-work` Phase 3.5 |
| Clarification | Confirmation from another team / source that resolves an ambiguity in the ticket | `/sdd-work` Phase 3.5 |
| Closing summary | End-of-implementation overview before handing off to `/sdd-verify` | `/sdd-work` Phase 4.5 |

## Decision

```
## Decision

**Chose:** <what was implemented>
**Spec/design suggested:** <what design.md or the ticket body said to do>
**Why diverged:** <reason — be specific; "the suggested primitive doesn't support X")
**Where:** <file:line or file/module name>
```

## Blocker

```
## Blocker

**What's blocked:** <feature / behaviour / criterion>
**Owner:** <team / system / person — who owns the resolution>
**Workaround in this implementation:** <e.g. "stubbed the response", "hardcoded the flag",
  "left as TODO behind a feature gate">
**Impact when resolved:** <what changes when the blocker clears — file paths and what to
  flip on>
```

If the workaround warrants a tracked future fix, immediately follow this comment with a follow-up ticket via `CreateRelatedTicket(..., "is_blocked_by")`. The skill will offer this as a second prompt after the comment is posted.

## Follow-up

```
## Follow-up

**Future work:** <one-line description>
**Placeholder location:** <file:line — where the stub / test double / TODO lives in the code>
**Trigger to revisit:** <e.g. "when the v2 orders endpoint ships", "when the ERP callout is available
  in UAT", "after the auth refactor lands">
**Tracked as:** <ticket key/number — populated after CreateRelatedTicket runs, or "untracked">
```

If the user opts to create a follow-up ticket, the new ticket id is posted as a one-line `**Tracked as:** <id>` reply. If they decline, leave it as `untracked` so future readers know the work was deliberately not tracked.

## Clarification

```
## Clarification

**Question:** <the ambiguity that was open>
**Answer:** <what was resolved>
**Source:** <who/what — "@<other-team> in #channel on YYYY-MM-DD",
  "Slack thread <link>", "follow-up call with PO">
**How it shaped this implementation:** <what code differs because of the answer>
```

## Closing summary

```
## Implementation Summary

**Built:** <1-3 lines describing what shipped>

**Key decisions:**
- <decision 1 — refer to the Decision comment above if posted separately>
- <decision 2>
- <or "None">

**Deviations from spec:** <or "None">
- <deviation 1>
- <deviation 2>

**Follow-ups created:** <or "None">
- <ticket-key> — <one-line description>

**PR:** <pr-url, or "<pending /sdd-verify>" when posted before PR creation>
```

The closing summary should be the **last** comment Claude posts on the ticket before handing off to `/sdd-verify`. It supersedes a flat list of micro-comments by giving readers a single anchor — older Decision/Blocker/Follow-up/Clarification comments still sit in the thread for detail, but the summary tells the reader where to start.

## Editing rules

- The user always sees the draft before posting and can pick **edit** to modify it inline.
- Skill must not invent fields. If a value is unknown (e.g. no clear owner for a blocker), use `unknown` or `unspecified` — don't fabricate.
- Headings (`## Decision`, etc.) are mandatory; future tooling may grep for them.
- Keep the Closing summary tight. If a section is empty, write `None` rather than omitting the heading.
