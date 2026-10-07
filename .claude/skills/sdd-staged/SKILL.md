---
name: sdd-staged
description: Staged greenfield development from a PRD. Proposes stages, generates per-stage OpenSpec artifacts, and creates cross-referenced tickets in the configured tracker (GitHub or Jira).
argument-hint: "<feature-slug> [--dry-run]"
disable-model-invocation: true
---

# Staged Greenfield: PRD → Stages → OpenSpec → Tickets

You are running the staged greenfield pipeline: read a PRD, propose development stages, generate per-stage OpenSpec artifacts, and create cross-referenced tickets in whichever tracker the project is configured for.

## Input

`$ARGUMENTS` parsed as: `<feature-slug> [--dry-run]`

- Required: `<feature-slug>` (e.g. `my-app`).
- Optional: `--dry-run`. When present, set `DRY_RUN=true`. Stage artifacts still generate locally; tracker writes are mocked with synthetic `DRY-N` ids.

PRD file expected at: `sdd/prds/<feature-slug>-v1.md` (fallbacks: `sdd/prds/<feature-slug>.md`, then legacy `docs/prds/<feature-slug>.md`).

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. Capture `tracker` and `vcs`. If missing, run `/sdd-setup` first.
2. Read `sdd/trackers/protocol.md` for abstract operations and the dry-run convention.
3. Read `sdd/trackers/<tracker>.md` for ticket operations.
4. If `vcs` differs, also read `sdd/trackers/<vcs>.md`.
5. Run `VerifyAuth()`. Stop on failure.

## Phase 0.5: Re-run Safety

6. Detect existing staged state:
   - List `openspec/changes/<feature-slug>-[0-9][0-9]-*` directories. Capture stage slugs.
   - Read `sdd/tasks/<feature-slug>-stages.md` if present.
   - For each stage directory, scan `openspec/changes/<feature-slug>-NN-<slug>/tasks.md` section headers for ticket-id annotations (`## N. <name> (#42)` or `## N. <name> [TT-457]`). Capture (stage, section-number → id) triples.
   - Read `sdd/tasks/<feature-slug>-NN-<slug>.md` per-stage mappings if present. Capture ticket ids.
   - Merge annotation ids with mapping ids per stage. If they disagree, note the divergence for the report.
   - For each captured id, run `FetchTicket(id)` to confirm and capture state.

7. If existing state is detected, present:

   ```
   ## Existing Staged State Detected
   Stage map: sdd/tasks/<feature-slug>-stages.md
   Stages found: <list>
   Tickets per stage (annotations / mapping): <counts>
   Divergence: <none | stage NN: sections X,Y annotated but missing from mapping | ...>
   ```

   Ask: "Continue (resume staged work, only fill gaps) / Regenerate (per-file diffs) / Abort?" Default Continue.

   - **Continue**: skip stage proposal (use existing `<feature-slug>-stages.md`, or rebuild per step 15); skip artifact generation per-file where files exist; the protocol's re-run hook skips ticket creation for sections with existing ids.
   - **Regenerate**: re-propose stages (warn that this can shift stage boundaries); per-artifact diff before overwrite; per-ticket diff before replacing (create the replacement, then `CloseTicket(<old>, "Replaced by <new>")`).
   - **Abort**: stop.

   When `DRY_RUN`: detection still runs; the prompt still fires; no destructive ops execute.

8. If no existing state, proceed normally.

## Phase 1: Read and Validate the PRD

9. Read the PRD. Try `sdd/prds/<feature-slug>-v1.md`, then `sdd/prds/<feature-slug>.md`, then legacy `docs/prds/<feature-slug>.md`. If none, stop.
10. Check `## Open Questions`. Surface unresolved ones; ask whether to proceed.
11. Extract: Problem, Goals & Non-Goals, User Stories, UI/UX, Technical Considerations, Dependencies.
12. Check `## API Contract`. If present:
    - Local file: read it. URL: WebFetch. On failure, ask whether to proceed without.
    - Parse it (OpenAPI, GraphQL SDL, `.proto`, AsyncAPI, …) and hold an **API Summary** in context (title, version, base URL, auth, relevant operations, schemas).
13. Assess if staging is appropriate. With only 1-2 user stories, suggest `/sdd-from-prd <feature-slug>-v1`. If user wants staging, continue.

## Phase 1.5: Read Constitution Sections

14. Read these section files only:
    - `sdd/constitution/tech-stack.md`
    - `sdd/constitution/folder-structure.md`
    - `sdd/constitution/quality-gates.md` (drives stage-01 setup tasks)

    Legacy fallback: `docs/constitution.md`. Skip if neither exists.

## Phase 2: Analyze and Propose Stages

15. **Continue mode**: skip this phase. Use the existing `<feature-slug>-stages.md` to drive Phase 3. If the stage map is missing, rebuild the stage list from the `openspec/changes/<feature-slug>-NN-*` directories found in Phase 0.5.

    **Otherwise**: propose 3-6 stages. Algorithm:
    - Greenfield defaults: `01-setup` (init, tooling, CI), `02-scaffold` (skeleton of the chosen architecture — e.g. app shell and routing for a UI, service skeleton and persistence wiring for a backend, org/project config and base metadata for a platform project).
    - Group user stories by functional area or dependency chain.
    - Order by dependency: features others depend on come first.
    - If API Contract exists, stages that implement the contract's interface (clients, handlers, shared types) come before stages that depend on them.

16. Present proposed stages as a table. Allow add / remove / reorder / rename / reassign-stories. Wait for explicit approval. Stages with zero user stories (setup/scaffold) are fine. On approval, write the stage map (format in step 22) to `sdd/tasks/<feature-slug>-stages.md` with the Tickets column empty.

## Phase 3: Generate OpenSpec Artifacts Per Stage

17. For each approved stage in order:

    a. `CHANGE_NAME = <feature-slug>-NN-<stage-slug>` (zero-padded).

    b. Re-run gate: if `openspec/changes/$CHANGE_NAME/` already exists, skip `openspec new change` (any mode). Otherwise:
       ```bash
       openspec new change "$CHANGE_NAME"
       ```

    c. If this is the first stage that consumes or implements the API Contract, copy the contract source to `openspec/changes/$CHANGE_NAME/api-contract.<ext>` (keeping the source's extension).

    d. Get artifact build order: `openspec status --change "$CHANGE_NAME" --json`.

    e. Generate each `ready` artifact in dependency order. Per-artifact:
       - Get instructions: `openspec instructions <artifact-id> --change "$CHANGE_NAME" --json`.
       - Read completed deps for context.
       - **Re-run gate**: in Continue mode, skip if file exists. In Regenerate mode, show diff and require explicit `yes`.
       - Create using the `template` from instructions. Scope strictly to this stage. For stages > 01, include a context block summarizing what earlier stages produce.
       - For specs, reference `sdd/templates/given-when-then-examples.md`.
       - For tasks that touch the API Contract, mirror the enrichment from `/sdd-from-prd`.
       - Apply `context` and `rules` as constraints; don't copy them in.
       - Re-check status after each artifact.

    f. Show per-stage progress: `Stage NN-slug: artifacts <generated|skipped|regenerated>.`

18. Show summary of all stages and their artifacts.

## Phase 3.5: Design Challenge

19. Read `sdd/templates/design-challenge.md`. Produce a challenge across the **full set** of stage artifacts (stage ordering, coupling, over-engineering, missing foundations). Apply requested changes.

## Phase 4: Create Tickets (All Stages)

20. Ask: "All N stages have OpenSpec artifacts. Shall I create tickets in `<tracker>` for all stages now?" If declined, point at `/sdd-create-tickets <change-name>` per stage.

21. Read `sdd/templates/ticket-creation-protocol.md`. For each stage in order, follow the protocol with:
    - `change_name = <feature-slug>-NN-<stage-slug>`
    - `change_dir = openspec/changes/<change_name>/`
    - `parent_id = none` (top-level tickets)
    - `is_work_item = false`
    - `dry_run = DRY_RUN`
    - **Stage label**: include `stage-NN-<slug>` in every payload's labels (the protocol's label step calls `EnsureLabel("stage-NN-<slug>")` automatically when it sees a new label).
    - **Cross-stage dependencies**: the **first ticket of each stage after 01** depends on the **last ticket of the previous stage** (stage gate), using its real id whether created this run or captured in Phase 0.5. Add specific cross-references when a section's hints mention a prior-stage output.
    - **Stage Context**: add a `## Stage Context` heading, placed immediately before the protocol's `---` footer, followed by: "This ticket is part of **Stage NN-<slug>** of the `<feature-slug>` staged development. See `sdd/tasks/<feature-slug>-stages.md` for the full stage map."

22. After all stages complete, fill the ticket ids into the master stage map at `sdd/tasks/<feature-slug>-stages.md`:

    ```markdown
    # Staged Development: <feature-slug>

    Source PRD: <prd path used>
    Generated: <YYYY-MM-DD>
    Tracker: <tracker>
    Total Stages: N
    Total Tickets: M

    ## Stages

    | Stage | Change | Tickets | Status |
    |-------|--------|---------|--------|
    | 01-setup | <feature>-01-setup | <range or list> | pending |
    | 02-scaffold | <feature>-02-scaffold | <range> | pending |

    ## Stage Details

    ### 01-setup
    - Change: openspec/changes/<feature>-01-setup/
    - Depends on: (none)

    | Task | Ticket | Title | Type | Depends On |
    |------|--------|-------|------|------------|
    | 1.1  | <id>   | ...   | ...  | none       |
    ```

    When `DRY_RUN`, print the stage map (here and at step 16) instead of writing it.

23. Print the final summary listing each stage, change, ticket range, and description, plus next steps:

    ```
    Next: Run /sdd-work <ticket-id> starting from stage 01.
    Work through stages in order. After all tickets of a change are done,
    /sdd-status will offer to archive that stage's OpenSpec change.
    ```

## Phase 5: Planning PR

24. Offer (AskUserQuestion) to commit the planning artifacts of **all stages created in this run** in one PR per `sdd/README.md` § Committing planning artifacts, with `<change>` = `<feature-slug>`. Paths: each `openspec/changes/<feature-slug>-NN-<slug>/`, each `sdd/tasks/<feature-slug>-NN-<slug>.md`, `sdd/tasks/<feature-slug>-stages.md`, and the PRD under `sdd/prds/` when it is untracked. VCS operations come from `sdd/trackers/<vcs>.md`. When `DRY_RUN`, print the branch, paths and commit message only.

## Rules

- The PRD is the source of truth. Don't invent requirements outside it.
- Respect Non-Goals.
- Target 3-6 stages.
- Stage naming: `<feature>-NN-<slug>` with zero-padded numbers.
- Create tickets in strict stage order so cross-stage references use real ids.
- Use abstract operation names from `sdd/trackers/protocol.md`.
- Re-run safety: default to Continue; require explicit Regenerate.
- If any step fails, stop and report clearly.
