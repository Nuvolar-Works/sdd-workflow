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

## Phase 0.5: Re-run Safety + Team Split Categorisation

5. Detect existing state:
   - Run `FetchTicket($ARGUMENTS)`. Capture description; scan it for an `openspec/changes/<change-name>/` reference. If found, hold the change name.
   - If a change name was found, list the contents of `openspec/changes/<change-name>/`.
   - If `openspec/changes/<change-name>/tasks.md` exists, scan its section headers for sub-task key annotations (`## N. <name> [TT-457]`). Capture (section-number → key) pairs.
   - Run a search on Jira for sub-tasks with `parent = $ARGUMENTS`. Capture each one's key, title, status, and labels.
   - Read `sdd/tasks/<change-name>.md` if it exists.
   - Merge keys from annotations, Jira sub-task search, and the mapping file. If they disagree (annotated section without a Jira sub-task, or Jira sub-task without an annotation), note the divergence for the report.

5b. **Team split categorisation.** Read `jira.team_prefix` from `sdd/config.json`. For each pre-existing sub-task found in step 5, classify into one of three buckets:
   - **same-team** — title starts with `<team_prefix> -` (case-insensitive, with or without spaces) OR carries a label like `team-<lowercase-prefix>`. These sub-tasks may overlap with the goals SDD is about to derive; surface them in Phase 3 for **merge / replace / keep alongside** decisions.
   - **other-team** — title starts with a different known prefix (e.g. `BE -`, `QA -`, `DESIGN -`). These belong to a different team's repo. Their titles + descriptions become **cross-team context** for `Phase 1.6: Codebase Audit` and `design.md`'s API Integration section. They are never in scope as SDD-generated sub-tasks here.
   - **unprefixed** — no recognised prefix. Flag as ambiguous in the report and ask the user per-ticket whether to treat as same-team, other-team (with which team), or ignore.

   If `team_prefix` is `null` or absent, skip categorisation and treat all pre-existing sub-tasks as unprefixed (old behaviour).

6. If existing state is detected, present:

   ```
   ## Existing State Detected
   Story: $ARGUMENTS — <title>
   Linked OpenSpec change: <change-name or "none">
   Annotations in openspec/changes/<change-name>/tasks.md: <count> section headers carry keys
   Sub-tasks under this story: <count>
     Same-team (`<team_prefix>`):
       - <KEY>: <title>, <status>
     Other-team (context only):
       - <KEY>: <title>, <status>
     Unprefixed (ambiguous — needs decision):
       - <KEY>: <title>, <status>
   Mapping: sdd/tasks/<change-name>.md (<rows>)
   Divergence: <none | sections N,M annotated but no matching sub-task | sub-tasks without annotation | ...>
   ```

   For each **unprefixed** sub-task, ask the user (single combined prompt is fine) whether to: (a) treat as same-team, (b) treat as other-team context, or (c) ignore entirely. Persist the decision for the remainder of this run only — do not edit the Jira ticket.

   Then ask: "Continue (skip existing artifacts/sub-tasks; only fill gaps) / Regenerate (per-file diffs and per-sub-task diffs) / Abort?" Default Continue.

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

## Phase 1.6: Codebase Audit

9b. Read `sdd/templates/codebase-audit.md` for the workflow. Run it with:
    - `ac_items` — the AC list extracted from the story description plus any AC-modifying highlights returned by Phase 1.5.
    - `cross_team_subtasks` — the **other-team** bucket from Phase 0.5 step 5b (titles + descriptions only).

    The template:
    - Maps each AC item to likely files via `sdd/constitution/folder-structure.md` (and `Glob`/`Grep` only as a last resort).
    - Reads the inferred files and classifies each AC item as `new`, `partial`, or `done`.
    - Surfaces a single matrix to the user for confirmation, with a Cross-team context subsection for other-team sub-task hints.
    - Hands back the **confirmed audit matrix** as input to Phase 2.

    Why this is mandatory: in an existing codebase, AC items often map to code that is already partially or fully implemented. Without the audit, every AC becomes an `ADDED` requirement and Phase 4 over-creates sub-tasks; `/sdd-work` then re-discovers the existing implementation mid-build. The audit lets Phase 2 mark already-satisfied scenarios as `MODIFIED` (or omit them) and lets `tasks.md` cover only the genuine delta.

    The audit is in-memory input to Phase 2. Phase 2 may optionally persist it to `openspec/changes/<change>/.audit.md` so `/sdd-work` can re-consult it; this skill does not require persistence.

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

    d. Create using the `template`. Inputs: **the story description (with comment-driven adjustments applied) + the included Phase 1.5 highlights + the confirmed Phase 1.6 audit matrix + the Phase 0.5 cross-team context**. On conflict, comments win.
       - **proposal.md**: story description (adjusted) → problem; story goal → objective; AC → success criteria; parent epic noted. Add an **Open Questions** section listing any [open question] comments the user opted to keep.
       - **specs/*.md**: each significant goal becomes one spec file. Use GIVEN-WHEN-THEN. Reference `sdd/templates/given-when-then-examples.md`. Source AC from the story. **Apply audit classifications**: AC items marked `new` in the audit become `ADDED Requirements`; AC items marked `partial` become `ADDED Requirements` whose scenarios explicitly call out the existing code to remove/change; AC items marked `done` become `MODIFIED Requirements` (locking in current behaviour) or are **omitted** if they restate a constitution-level invariant. Never emit an `ADDED` scenario for behaviour already met by the codebase.
       - **design.md**: technical approach across all goals. Component structure, state management, reuse from existing components/hooks (per `folder-structure.md`). Cite the specific files the audit identified as `partial` so the design records what gets replaced vs extended. Add an **API Integration** subsection if the story mentions backend; if Phase 0.5 surfaced **cross-team context** (other-team sub-tasks under the same parent), feed their endpoint/contract hints into this subsection — never into spec scenarios for this repo.
       - **tasks.md**: **one section per significant goal** (`## 1. <Goal name>`, `## 2. <Goal name>`, …). The set of `## N.` sections IS the set of Jira sub-tasks created in Phase 4. **Omit goals whose AC items are all classified `done` in the audit** — there's no work to do there. For `partial` AC items, the corresponding task bullets must reference the existing file paths so reviewers can see what is being replaced.

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

19. Present the draft list as a numbered table. Note: each sub-task corresponds to a `tasks.md` section — adjustments at this stage usually mean editing `tasks.md` (and the relevant `specs/*.md` for AC changes) **first**, because Phase 4's protocol delegation re-derives payloads from those files. Allow approve / edit / reorder / drop / add, and apply edits to `tasks.md` / `specs/` before proceeding. Phase 3's draft is a preview; the canonical inputs are the change artifacts.

19b. **Same-team pre-existing sub-tasks.** If Phase 0.5 step 5b categorised any pre-existing sub-tasks as **same-team**, list them in a separate **Pre-existing same-team sub-tasks** section under the draft table. For each one, ask the user to choose:
    - **Merge into goal N** — fold the pre-existing sub-task into one of the proposed goals; in Phase 4 the protocol will reuse the existing Jira key (annotate the `tasks.md` section with `[KEY]`) instead of creating a new sub-task.
    - **Replace goal N** — drop the proposed goal and treat the pre-existing sub-task as authoritative; remove the `## N.` section from `tasks.md` and replace it with one that points at the existing key.
    - **Keep alongside** — leave the pre-existing sub-task untouched; Phase 4 creates the SDD-derived sub-tasks alongside it. The user accepts the risk of duplicate scope.
    - **Close in Jira** — flag for closure (do NOT close from within this skill; surface as a note in the summary so the user can do it manually or via `/sdd-status`).

    The intent is to never re-create work the PO already split out, while still letting SDD's goal-level decomposition replace layer-level decomposition where the user wants it.

## Phase 4: Create Sub-tasks via Shared Protocol

20. Read `sdd/templates/ticket-creation-protocol.md`. Invoke it with:
    - `change_name = $CHANGE_NAME`
    - `change_dir = openspec/changes/$CHANGE_NAME/`
    - `parent_id = $ARGUMENTS`
    - `is_subtask = true`
    - `dry_run = DRY_RUN`

    The protocol handles: per-section payload derivation (including Design Excerpt, API Integration when the goal type is Integration per `sdd/templates/definition-of-done.md` § Goal-type detection, and the goal-type-keyed Definition of Done block with inline-vs-reference rule), `EnsureLabel` calls, batched `CreateChildTickets`, `tasks.md` header annotations, mapping-file write at `sdd/tasks/$CHANGE_NAME.md`, and the summary print.

    Re-run safety: the protocol's hook honours the **Continue** / **Regenerate** mode set by Phase 0.5, skipping sections whose `tasks.md` header already carries a `[KEY]` annotation or whose mapping row already exists (whichever Phase 0.5 captured).

## Phase 5: Story-specific Summary Addendum

21. After the protocol's summary prints, append story-specific context the protocol doesn't carry:

    ```
    Parent story: $ARGUMENTS — <story title>
    Source story: <jira-url-or-key>
    ```

    Then the existing `Next: /sdd-work <first-key>` line from the protocol's summary already covers the hand-off.

## Rules

- **Spec at story level, sub-tasks at goal level.** One OpenSpec change per story; one Jira sub-task per `## N.` section in `tasks.md`.
- **Don't decompose by layer.** Goals are user-visible deliverables (panels, components, integrations). Layers (data, UI, state, errors, tests) ship together within each goal.
- **`tasks.md` is canonical.** Sub-tasks derive from it. If decomposition feels wrong, fix `tasks.md` first.
- Each sub-task body MUST include a `Spec section:` line so `/sdd-work` Phase 1.5 can lazy-load the right spec without heuristic guessing.
- All sub-tasks created via `CreateChildTickets` so `parent` is populated.
- Re-run safety: default to Continue; require explicit Regenerate.
- If the story is genuinely tiny (one goal), suggest `/opsx:propose` instead.
- If too large for 2-6 sub-tasks, suggest splitting the story first.
- **Audit before you spec.** Phase 1.6 is not optional in a mature codebase. AC items already met by existing code MUST NOT become `ADDED` requirements.
- **Other-team sub-tasks are context, never scope.** When a parent story has sub-tasks for other teams (BE/QA/design/etc.), their content informs `design.md` (API Integration section) but never produces spec scenarios or sub-tasks in this repo.
