# Story Comment Triage

Used by `/sdd-tasks-from-story` Phase 1.5 to read, filter, classify, and surface a Jira story's comment thread before the OpenSpec change is generated. Comments often refine or supersede the original description; ignoring them produces stale specs.

## Step 1: Fetch

Call `FetchComments(story_key)` from the active tracker recipe. Default cap of 30 most-recent comments is enough for almost every story.

## Step 2: Filter to substantive comments

Drop a comment if **any** of:
- Author is a bot or automation. Heuristic: name (case-insensitive) contains `bot`, `automation`, `jira-software`, `github-actions`, `dependabot`.
- Body is ≤10 words **and** contains no link, code reference (backticks, file path, ticket key, issue number), or numeric value.
- Body is purely an emoji reaction (single emoji or sequence of emoji with no text).
- Body is a no-op trailing whitespace / quoted-reply with no new content.

Keep everything else. The heuristic is intentionally permissive — false negatives drop only short reactions, and false positives surface a few more comments to the user than needed (the user reviews each one in Step 4).

**Known false-negative example**: `"We need to validate the API response schema first."` (9 words, no link/code/number) gets dropped. This is acceptable but worth flagging in the digest output ("If you expect more substantive comments than shown, increase the cap or review the full thread manually.").

## Step 3: Classify each surviving comment

Pick the strongest match, in order:

| Tag | Trigger |
|-----|---------|
| **Scope clarification** | Body uses phrases like "this is/isn't included", "out of scope", "let's narrow this to", "let's expand this to", "we agreed to add/drop". |
| **Requirement change** | Body explicitly contradicts the story description. Phrases like "actually", "instead", "we need to change", "the original plan was X but". |
| **Blocker** | Body mentions an external dependency that isn't ready. Phrases like "API not ready", "blocked on", "waiting on", "need backend to", "ETA". Or mentions another team that has unfinished work. |
| **Open question** | Body is a question that hasn't been answered in a later comment. (Check by scanning later comments for answers; if none, it's open.) |
| **Other** | Substantive but doesn't match. Still surface to user. |

A comment can be tagged with at most one category — pick the most actionable.

## Step 4: Present digest to user

```
Story has <total> comments (<substantive count> substantive).

Highlights:
1. [<tag>] <author>, <date>: <one-line summary>
2. [<tag>] <author>, <date>: <one-line summary>
...

For each highlight, factor it into the OpenSpec change?
  yes — include the comment's content in spec generation
  edit — let the user edit the summary before inclusion
  skip — drop the comment from spec generation (still visible on the ticket)
```

Allow the user to view the full body of any highlight by id ("show 2") before deciding.

## Step 5: Hand off to spec generation

Pass the **included** highlights forward to Phase 2 of `/sdd-tasks-from-story` as additional inputs alongside the story description and AC.

**Conflict rule:** when an included comment conflicts with the original story description, the comment wins. Comments are more recent and represent the team's resolved view. The skill should note in `proposal.md` what was overridden — e.g.:

> *Note: the original story description specified X. Comment from <author> on <date> revised this to Y. Spec follows Y.*

## Step 6: Hold blocker candidates

Highlights tagged **Blocker** are saved in a `blocker_candidates` list. They surface again at the design challenge (Phase 2.5) with three resolution options:
- **Accommodate in spec** — the design adapted to the blocker.
- **Accept and proceed** — the spec proceeds optimistically; `/sdd-work` will post a Blocker comment when implementation actually hits the issue.
- **Track as follow-up ticket now** — call `CreateRelatedTicket(payload, parent_id=<story-key>, link_type="is_blocked_by")` immediately so the gap exists in the tracker before sub-tasks are created.

The user picks per-blocker. Default is **Accept and proceed**.
