---
name: sdd-tasks-from-story
description: Generate an OpenSpec change for a Jira user story, then create one Jira sub-task per significant goal under the story. Each sub-task references the spec section it implements. Works for full-Jira and hybrid (Jira tickets + GitHub VCS) modes.
argument-hint: "<jira-story-key> [--dry-run]"
disable-model-invocation: true
---

# Generate Spec + Sub-tasks for a Jira Story

You are turning a PO-written Jira user story (e.g. `TT-456`) into:
1. An OpenSpec change scoped to the whole story (proposal + specs + design + tasks).
2. One Jira sub-task per significant goal in that story, under the story as parent. Each sub-task references the specific spec section it implements.

This works in two modes:
- **Full Jira** (`tracker: "jira"` in `sdd/config.json`): tickets and code both flow through Jira context.
- **Hybrid** (`tracker: "jira"`, `vcs: "github"`): sub-tasks are Jira sub-tasks; later `/sdd-work` will create GitHub branches and PRs that link back via the Jira key.

## Input

`$ARGUMENTS` parsed as: `<jira-story-key> [--dry-run]`

- Required: `<jira-story-key>` (e.g. `TT-456`).
- Optional: `--dry-run`. When present, set `DRY_RUN=true`. OpenSpec artifacts still generate locally; sub-task creation is mocked with `[DRY RUN]` lines and synthetic `DRY-N` ids.

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. The `jira` section MUST be configured (`project_key`, `site`, `subtask_type`, `status_workflow`). If `tracker` is `github` and the `jira` section is empty, this skill requires Jira setup — stop.
2. Read `sdd/trackers/protocol.md` for abstract operations and the dry-run convention.
3. Read `sdd/trackers/jira.md` for `FetchTicket`, `FetchComments`, `CreateChildTickets`, `CreateRelatedTicket`, etc.
4. Run `VerifyAuth()`. Stop on failure.

## Phase 0.5: Re-run Safety

5. Detect existing state:
   - Run `FetchTicket($ARGUMENTS)`. Capture description; scan it for an `openspec/changes/<change-name>/` reference. If found, hold the change name.
   - If a change name was found, list the contents of `openspec/changes/<change-name>/`.
   - Run a search on Jira for sub-tasks with `parent = $ARGUMENTS`. Capture their keys and current statuses.
   - Read `sdd/tasks/<change-name>.md` if it exists.

6. If existing state is detected, present:

   ```
   ## Existing State Detected
   Story: $ARGUMENTS — <title>
   Linked OpenSpec change: <change-name or "none">
   Sub-tasks under this story: <count>
     - <KEY>: <status>, <comment count> comments
   Mapping: sdd/tasks/<change-name>.md (<rows>)
   ```

   Ask: "Continue (skip existing artifacts/sub-tasks; only fill gaps) / Regenerate (per-file diffs and per-sub-task diffs) / Abort?" Default Continue.

   - **Continue**: in Phase 2 skip artifact generation per file when the file exists; in Phase 4 the protocol's re-run hook skips creation for sections whose section header already carries a `[KEY]` annotation.
   - **Regenerate**: per-file artifact diff + per-sub-task body diff before any overwrite or recreate; explicit `yes` per item.
   - **Abort**: stop.

   When `DRY_RUN`: detection still runs; the prompt fires; nothing destructive executes.

## Phase 1: Fetch the Story

7. Capture story title, description, labels, parent (epic if any), AC from the FetchTicket result above.

8. If the issue type isn't a story-shaped type (Story / Epic), warn and ask whether to proceed (some teams use Tasks as stories — OK if confirmed).

## Phase 1.5: Read Story Comments

9. Read `sdd/templates/story-comment-triage.md` for the workflow. Run it with `story_key = $ARGUMENTS`. The template:
   - Calls `FetchComments($ARGUMENTS)`.
   - Filters bot/short-reaction noise.
   - Classifies surviving comments (scope clarification / requirement change / blocker / open question / other).
   - Surfaces a digest, lets the user include / edit / skip each highlight.
   - Hands back a list of **included highlights** for Phase 2.
   - Holds **blocker candidates** for the design challenge (Phase 2.5).

   On conflict between the story description and an included comment, the comment wins (more recent).

## Phase 2: Generate the OpenSpec Change

10. Read constitution sections needed for spec generation:
    - `sdd/constitution/tech-stack.md`
    - `sdd/constitution/folder-structure.md`

    Legacy fallback: `docs/constitution.md`. Skip if neither exists.

11. Derive a change name: slug the story title in kebab-case, prefix with the lowercased story key. E.g. `TT-456` "Dashboard page" → `tt-456-dashboard-page`.

12. **Re-run gate**: if Phase 0.5 mode is **Continue** and the change directory already exists, skip `openspec new change`. Otherwise:
    ```bash
    openspec new change "$CHANGE_NAME"
    ```

13. Get the artifact build order:
    ```bash
    openspec status --change "$CHANGE_NAME" --json
    ```

14. Generate each `ready` artifact in dependency order. Per-artifact:

    a. Get instructions: `openspec instructions <artifact-id> --change "$CHANGE_NAME" --json`.

    b. Read completed deps for context.

    c. **Re-run gate**: in Continue mode, skip if the file exists. In Regenerate mode, show diff and require explicit `yes`.

    d. Create using the `template`. Inputs: **the story description (with comment-driven adjustments applied) + the included Phase 1.5 highlights**. On conflict, comments win.
       - **proposal.md**: story description (adjusted) → problem; story goal → objective; AC → success criteria; parent epic noted. Add an **Open Questions** section listing any [open question] comments the user opted to keep.
       - **specs/*.md**: each significant goal becomes one spec file. Use GIVEN-WHEN-THEN. Reference `sdd/templates/given-when-then-examples.md`. Source AC from the story.
       - **design.md**: technical approach across all goals. Component structure, state management, reuse from existing components/hooks (per `folder-structure.md`). Add an "API Integration" subsection if the story mentions backend.
       - **tasks.md**: **one section per significant goal** (`## 1. <Goal name>`, `## 2. <Goal name>`, …). The set of `## N.` sections IS the set of Jira sub-tasks created in Phase 4.

    e. Apply `context` and `rules` as constraints; don't copy them in.

    f. Re-check status after each artifact.

15. Append a back-reference at the top of `proposal.md`:
    ```
    Source story: <jira-url-or-key> ($ARGUMENTS)
    ```

## Phase 2.5: Design Challenge

16. Read `sdd/templates/design-challenge.md`. Produce the challenge against the generated artifacts. Special focus: are the goals in `tasks.md` the right ones? Right granularity? Spec coverage matches AC?

    If Phase 1.5 returned **blocker candidates**, list them under a **Blockers from story comments** subsection with three options each:
    - (a) **Accommodate in spec** — design adapted (already done).
    - (b) **Accept and proceed** — `/sdd-work` will post a Blocker comment when implementation hits the issue.
    - (c) **Track now as follow-up ticket** — call `CreateRelatedTicket(payload, related_id=$ARGUMENTS, link_type="is_blocked_by")` immediately; capture the new ticket id.

    Apply requested artifact changes and create approved follow-up tickets before continuing.

## Phase 3: Derive Sub-task Proposals from `tasks.md`

17. Read `openspec/changes/$CHANGE_NAME/tasks.md`. Each `## N. <Goal name>` section is one proposed Jira sub-task. (Sub-tasks are derived from `tasks.md`, never invented separately.)

18. For each goal section, build a draft sub-task using `sdd/templates/jira-task-decomposition.md` for shape and `sdd/templates/definition-of-done.md` for the goal-type-specific DoD. Draft fields:
    - **Title**: the goal name (with optional team-area prefix).
    - **Description**: one paragraph derived from the section's intro + relevant `design.md` excerpt.
    - **Acceptance Criteria**: 2-4 criteria copied from the matching `specs/<file>.md` scenarios.
    - **Spec section**: `openspec/changes/$CHANGE_NAME/specs/<best-match>.md` (heuristic on goal name).
    - **Source**: `openspec/changes/$CHANGE_NAME/tasks.md (section N)`.
    - **Suggested labels**: kebab-case of area + type.
    - **Depends on**: prior goal titles in `tasks.md` order, or "None".
    - **Implementation hints**: relevant excerpts from `design.md`.
    - **Goal type** (used by definition-of-done.md to pick the DoD block): apply the heuristics from `definition-of-done.md` § Goal-type detection.

19. Present the draft list as a numbered table. Note: each sub-task corresponds to a `tasks.md` section — adjustments at this stage usually mean editing `tasks.md` first. Allow approve / edit / reorder / drop / add. Keep `tasks.md` and the sub-task list in sync.

## Phase 4: Create Sub-tasks in Jira

20. For each finalised sub-task in dependency order, build the body. Read `sdd/templates/ticket-creation-protocol.md` for the body shape and the protocol-level mechanics; build the `description` field with:

    ```
    <Description>

    ## Acceptance Criteria
    - <criterion>

    ## Implementation Hints
    <hints>

    ## Design Excerpt
    <5-15 line excerpt from the relevant section of design.md, including the
    section heading. Anchored quote — preserve original phrasing.>

    ## API Integration                ← integration goals only
    Endpoint: <METHOD path>
    Request shape: <key fields and types>
    Response shape: <key fields and types>
    Error responses: <code → meaning>
    Source: openspec/changes/$CHANGE_NAME/api-contract.yaml

    ## Definition of Done
    <DoD block from sdd/templates/definition-of-done.md, keyed by goal type:>
    <  - Setup / chore: minimal block (4 items).>
    <  - Refactor: refactor block.>
    <  - Test: test block.>
    <  - Integration: full integration block (inlined).>
    <  - UI: full UI block (inlined).>
    <  - Generic: fallback block.>
    <Trivial goals (Setup / Refactor) get a one-line reference instead of inline:>
    <  "See `sdd/templates/definition-of-done.md` § <type>. AC above are the primary gate.">

    ## Depends on
    <Jira keys, populated as we go, or "None">

    ---
    Spec section: openspec/changes/$CHANGE_NAME/specs/<file>.md
    Source: openspec/changes/$CHANGE_NAME/tasks.md (section <N>)
    ```

    The **API Integration** section appears only when the goal type is integration. The **Design Excerpt** is mandatory for every sub-task. The **Definition of Done** uses the inline-vs-reference rule from `definition-of-done.md`.

21. Run `CreateChildTickets(parent_id=$ARGUMENTS, payloads=[...])` from the Jira recipe. **Re-run gate**: in Continue mode, skip sub-tasks whose section header in `tasks.md` already carries a `[KEY]` annotation.

    When `DRY_RUN`: print `[DRY RUN] would CreateChildTickets($ARGUMENTS, [...])` with `DRY-N` synthetic ids. Don't call Jira.

22. Capture the returned Jira keys. As later sub-tasks are created, populate `Depends on` fields with real keys.

23. Update `openspec/changes/$CHANGE_NAME/tasks.md` by appending each Jira key to its section header (e.g. `## 1. Clock-in panel [TT-457]`). When `DRY_RUN`, print the intended annotation.

## Phase 5: Update Mapping File

24. Write `sdd/tasks/$CHANGE_NAME.md`:

    ```markdown
    # Story Decomposition: $ARGUMENTS — <story title>

    Source story: <jira-url-or-key>
    OpenSpec change: openspec/changes/$CHANGE_NAME/
    Tracker: jira
    Generated: <YYYY-MM-DD>

    | # | Sub-task | Title | Type | Spec section | Depends On |
    |---|----------|-------|------|--------------|------------|
    | 1 | TT-457   | Clock-in panel | feat | clock-in-panel.md | none |
    | 2 | TT-458   | Clock-in history panel | feat | history-panel.md | none |
    | 3 | TT-459   | Frontend↔backend integration | feat | dashboard-data.md | TT-457, TT-458 |
    ```

    When `DRY_RUN`: write locally with `DRY-N` ids; the file is git-revertable.

## Phase 6: Summary

25. Print a compact summary:

    ```
    [DRY RUN] Story Decomposition: $ARGUMENTS  ← prefix with [DRY RUN] when dry

    Parent story: $ARGUMENTS — <title>
    OpenSpec change: openspec/changes/$CHANGE_NAME/
    Sub-tasks created: <count>

    | # | Key | Title | Spec section |
    |---|-----|-------|--------------|
    | 1 | TT-457 | Clock-in panel | clock-in-panel.md |
    | ... |

    Mapping: sdd/tasks/$CHANGE_NAME.md
    Next: Run /sdd-work TT-457 to start the first sub-task.
    ```

## Rules

- **Spec at story level, sub-tasks at goal level.** One OpenSpec change per story; one Jira sub-task per `## N.` section in `tasks.md`.
- **Don't decompose by layer.** Goals are user-visible deliverables (panels, components, integrations). Layers (data, UI, state, errors, tests) ship together within each goal.
- **`tasks.md` is canonical.** Sub-tasks derive from it. If decomposition feels wrong, fix `tasks.md` first.
- Each sub-task body MUST include a `Spec section:` line so `/sdd-work` Phase 1.5 can lazy-load the right spec without heuristic guessing.
- All sub-tasks created via `CreateChildTickets` so `parent` is populated.
- Re-run safety: default to Continue; require explicit Regenerate.
- If the story is genuinely tiny (one goal), suggest `/opsx:propose` instead.
- If too large for 2-6 sub-tasks, suggest splitting the story first.
