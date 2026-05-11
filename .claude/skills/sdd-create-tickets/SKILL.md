---
name: sdd-create-tickets
description: Create tickets in the configured tracker from an OpenSpec change's task breakdown. Standalone alternative to running the full /sdd-from-prd pipeline.
argument-hint: "<change-name> [--dry-run]"
disable-model-invocation: true
---

# Create Tickets from an OpenSpec Change

You are creating tracker tickets from an OpenSpec change's artifacts. The active tracker (GitHub or Jira) is selected via `sdd/config.json`.

## Input

`$ARGUMENTS` parsed as: `<change-name> [--dry-run]`

- Required: `<change-name>`.
- Optional: `--dry-run`. When present, set `DRY_RUN=true`. All write operations in this skill emit `[DRY RUN] would <op>(<args>)` lines and use synthetic `DRY-N` ids; no real tickets are created.

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. Capture `tracker`. If the file is missing, run `/sdd-setup` first.
2. Read `sdd/trackers/protocol.md` for abstract operations and the dry-run convention.
3. Read `sdd/trackers/<tracker>.md` for concrete recipes.
4. Run `VerifyAuth()`. Stop on failure.

## Phase 0.5: Re-run Safety

5. Locate the change directory at `openspec/changes/$ARGUMENTS/`. If it does not exist, tell the user to run `/opsx:propose` first and stop.

6. Detect existing tickets:
   - Read `openspec/changes/$ARGUMENTS/tasks.md`. Scan section headers for ticket-id annotations (`## N. <name> (#42)` or `## N. <name> [TT-457]`). Capture (section-number → id) pairs.
   - Read `sdd/tasks/$ARGUMENTS.md` if present. Capture rows.
   - Merge the two id sources. If they disagree (annotations present without mapping rows, or rows in mapping without an annotation), note the divergence for the report.
   - For each captured id, run `FetchTicket(id)` to confirm it still exists and capture its current state.

7. If any existing tickets are detected, present:

   ```
   ## Existing State Detected
   OpenSpec change: openspec/changes/$ARGUMENTS/
   Annotations in openspec/changes/$ARGUMENTS/tasks.md: <count> section headers carry ids
   Mapping: sdd/tasks/$ARGUMENTS.md (<count> tickets)
   Divergence: <none | sections N,M annotated but missing from mapping | rows in mapping but no annotation | ...>

   Tracker state:
   - <id>: <status>, <comment count> comments
   ```

   Ask: "Continue (skip existing, create only what's missing) / Regenerate (overwrite — show diff first) / Abort?" Default Continue.

   - **Continue**: pass through the captured ids to Phase 1; the protocol's re-run hook skips create for sections that already have ids.
   - **Regenerate**: per-ticket diff between existing state and what the new payload would create; require explicit `yes` per ticket before deletion + recreation. Old ids in the mapping are marked `replaced by <new id>`.
   - **Abort**: stop.

   When `DRY_RUN`: still run the detection. The Continue / Regenerate / Abort prompt still fires, but the skill never actually destroys or recreates — it prints what would happen.

8. If no existing tickets exist, proceed to Phase 1 normally.

## Phase 1: Create Tickets

9. Read `sdd/templates/ticket-creation-protocol.md`. Follow it to:
   - Read change artifacts (proposal, specs, design, optional api-contract).
   - Group by section.
   - Derive payloads (title, type, priority, labels, AC, hints, dependencies).
   - Ensure labels exist.
   - Create tickets in section order, capturing ids for downstream Dependencies.
   - Annotate `tasks.md` section headers.
   - Write the mapping file.
   - Print the summary.

   Inputs to the protocol:
   - `change_name = $ARGUMENTS`
   - `change_dir = openspec/changes/$ARGUMENTS/`
   - `parent_id = none` (these are top-level tickets, not sub-tasks)
   - `is_subtask = false`
   - `dry_run = DRY_RUN`

10. The protocol handles both real and dry-run paths via the convention in `sdd/trackers/protocol.md`. Don't duplicate the algorithm in this skill.

## Rules

- One ticket per section, not per subtask.
- Create in section order so dependency ids resolve correctly.
- Use abstract operation names from `sdd/trackers/protocol.md`; never embed `gh` or MCP calls inline.
- If any creation fails mid-batch, stop and report. Capture which sections succeeded so the user can re-run with **Continue** to finish the rest.
- If the change has no `tasks.md` or it's empty, tell the user and stop.
- Respect the OpenSpec format — never modify `proposal.md`, `specs/`, or `design.md` from this skill (only `tasks.md` for the section-header annotations).
