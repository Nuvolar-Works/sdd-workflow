---
name: sdd-from-prd
description: End-to-end pipeline from a PRD file to tracker tickets. Reads the PRD, generates OpenSpec artifacts, and creates issues in the configured tracker (GitHub or Jira).
argument-hint: "<feature-slug> [--dry-run]"
disable-model-invocation: true
---

# PRD → OpenSpec → Tickets

You are running the full pipeline: read a PRD, generate OpenSpec artifacts, and create tickets in whichever tracker the project is configured for.

## Input

`$ARGUMENTS` parsed as: `<feature-slug> [--dry-run]`

- Required: `<feature-slug>` (e.g. `time-tracker-v1` or `time-tracker-v2-overtime-rules`).
- Optional: `--dry-run`. When present, set `DRY_RUN=true`. Artifacts still generate locally (revertable via git); tracker writes are mocked with `[DRY RUN]` lines and synthetic `DRY-N` ids.

PRD file expected at: `sdd/prds/<feature-slug>.md` (legacy fallback: `docs/prds/<feature-slug>.md`).

## Phase 0: Tracker Setup

1. Read `sdd/config.json`. Capture `tracker` and `vcs`. If the file is missing, run `/sdd-setup` first.
2. Read `sdd/trackers/protocol.md` for abstract operations and the dry-run convention.
3. Read `sdd/trackers/<tracker>.md` for ticket operations.
4. If `vcs` differs from `tracker`, also read `sdd/trackers/<vcs>.md`.
5. Run `VerifyAuth()`. Stop on failure.

## Phase 0.5: Re-run Safety

6. Detect existing state for this feature:
   - Does `openspec/changes/<feature-slug>/` already exist? List its contents.
   - If `openspec/changes/<feature-slug>/tasks.md` exists, scan its section headers for ticket-id annotations (`## N. <name> (#42)` or `## N. <name> [TT-457]`). Capture (section-number → id) pairs.
   - Does `sdd/tasks/<feature-slug>.md` already exist? Read and capture ticket ids.
   - Merge the two id sources. If they disagree (annotations present without mapping rows, or vice versa), note the divergence for the report.
   - For each captured id, run `FetchTicket(id)` to confirm it still exists and capture current state.

7. If existing state is detected, present:

   ```
   ## Existing State Detected
   OpenSpec change: openspec/changes/<feature-slug>/ (artifacts: <list>)
   Annotations in openspec/changes/<feature-slug>/tasks.md: <count> section headers carry ids
   Mapping: sdd/tasks/<feature-slug>.md (<count> tickets)
   Divergence: <none | sections N,M annotated but missing from mapping | rows in mapping but no annotation | ...>

   Tracker state:
   - <id>: <status>, <comment count> comments
   ```

   Ask: "Continue (skip existing artifacts/tickets, fill in only what's missing) / Regenerate (per-file diff before overwrite) / Abort?" Default Continue.

   - **Continue**: skip artifact generation for files that already exist; the protocol's re-run hook skips ticket creation for sections that already have ids.
   - **Regenerate**: per-file diff for each artifact (proposal.md, design.md, each spec, tasks.md). Per-file `yes` confirmation before overwrite. For tickets, per-ticket diff between current body and what would be generated, with explicit confirmation before replacing: create the replacement, then `CloseTicket(<old>, "Replaced by <new>")`. Old ids are reported in the summary as `replaced by <new id>`.
   - **Abort**: stop.

   When `DRY_RUN`: still run detection and prompt; the skill never destroys or recreates — it prints what would happen.

8. If no existing state, proceed normally to Phase 1.

## Phase 1: Read and Validate the PRD

9. Read `sdd/prds/<feature-slug>.md` (legacy fallback: `docs/prds/<feature-slug>.md`). If neither exists, tell the user and stop.
10. Detect template style: full (`prd-template.md`) or mini (`prd-template-mini.md`). The mini template omits UI/UX Notes, Technical Considerations, Open Questions, and Non-Goals — that is by design, do not warn about missing sections.
11. Check for an `## Open Questions` section. If unresolved questions exist, present them and ask whether to proceed or resolve them first.
12. Extract PRD content: Problem Statement, Goals & Non-Goals, User Stories, UI/UX Notes (if present), Technical Considerations (if present), Dependencies.
13. Check for an `## API Contract` section.
    - If absent or empty, skip API integration work entirely.
    - If the section lists endpoints inline (mini template) instead of a source file/URL, use those bullets as the **API Summary** and skip the rest of this step.
    - If present, extract the reference (file path or URL).
      - Local file: read it. If not found, warn and ask whether to proceed without it.
      - URL: fetch via WebFetch. If fetch fails, warn and ask whether to proceed without it.
    - Parse Swagger/OpenAPI and extract an **API Summary** (title, version, base URL, auth, relevant endpoints, schemas).
    - Hold the **API Summary** in context — not the raw Swagger.

## Phase 1.5: Read Constitution Sections

14. Check for `sdd/constitution/index.md` (legacy fallback: `docs/constitution.md`).
    - If present, read only `sdd/constitution/tech-stack.md` and `sdd/constitution/folder-structure.md`.
    - If only legacy single file exists, read it.
    - If neither exists, proceed and add a final-summary note suggesting `/sdd-constitution`.

    These constraints shape artifact generation: tech stack referenced in proposal/design, scenarios respect the stack, architecture aligns with folder-structure, tasks reference chosen libraries.

## Phase 2: Generate OpenSpec Artifacts

15. `CHANGE_NAME = <feature-slug>`.

16. If `openspec/changes/$CHANGE_NAME/` already exists, skip the `openspec new change` call (any mode). Otherwise:
    ```bash
    openspec new change "$CHANGE_NAME"
    ```

17. If an API Contract source file/URL was found, copy the source into the change folder (`api-contract.yaml` or `.json`). This file is reference material; it is NOT processed by openspec.

18. Get the artifact build order:
    ```bash
    openspec status --change "$CHANGE_NAME" --json
    ```
    Parse `applyRequires` and `artifacts`.

19. Generate each `ready` artifact in dependency order. For each:

    a. Get instructions: `openspec instructions <artifact-id> --change "$CHANGE_NAME" --json`.

    b. Read completed dependency artifacts for context.

    c. **Re-run gate**: if Phase 0.5's mode is **Continue** and this artifact file already exists, skip generation. If **Regenerate**, show the user a diff of the current file vs. the planned regeneration before overwriting; require explicit `yes`.

    d. Create the artifact using the `template` from instructions. Map PRD content to artifact sections:
       - **proposal.md**: Problem → problem, Goals → objectives, Non-Goals → exclusions, User Stories → user needs. Mention API integration scope if relevant.
       - **specs/<capability>/spec.md**: User Stories → GIVEN-WHEN-THEN scenarios. Reference `sdd/templates/given-when-then-examples.md` for shape and edge-case categories. For API stories, include integration scenarios with endpoints, request/response shapes, error paths.
       - **design.md**: Technical Considerations → architecture, Dependencies → integration points, UI/UX → component structure. Add "API Integration" subsection if applicable.
       - **tasks.md**: derived from specs and design — atomic, vertically-sliced, AC-bound. Include API tasks if applicable.

    e. Apply `context` and `rules` as constraints; do NOT copy them into the file.

    f. Re-check status after each artifact.

20. Show a summary of generated (or skipped, in Continue mode) artifacts.

## Phase 2.5: Design Challenge

21. Read `sdd/templates/design-challenge.md`. Produce a challenge against the generated artifacts. Present to user. Apply requested changes before proceeding.

## Phase 3: Create Tickets

22. Ask: "OpenSpec artifacts are ready. Shall I create tickets in `<tracker>` now?" If declined, point at `/sdd-create-tickets <feature-slug>` for later.

23. Read `sdd/templates/ticket-creation-protocol.md`. Follow it with:
    - `change_name = <feature-slug>`
    - `change_dir = openspec/changes/<feature-slug>/`
    - `parent_id = none`
    - `is_work_item = false`
    - `dry_run = DRY_RUN`

    The protocol handles ticket payloads, label creation, ordered creation with id capture, `tasks.md` annotations, mapping-file write, and the summary print. Existing-id detection from Phase 0.5 informs which sections to skip in Continue mode.

24. The protocol prints the final summary. Append a one-line note about the source PRD:
    ```
    PRD: sdd/prds/<feature-slug>.md
    Next: Run /sdd-work <ticket-id> to start developing a ticket.
    ```

## Rules

- The PRD is the source of truth for WHAT to build. Don't invent requirements outside it.
- Respect Non-Goals.
- If the PRD is vague, ask rather than guess.
- Use abstract operation names from `sdd/trackers/protocol.md`.
- The Swagger/OpenAPI doc is supplementary; PRD wins for scope. Don't generate tasks for endpoints not referenced by any PRD user story.
- Re-run safety in Phase 0.5 prevents silent overwrites. Default to Continue; require explicit Regenerate.
- If any step fails, stop and report clearly.
