---
name: sdd-staged
description: Staged greenfield development from a PRD. Analyzes a PRD, proposes development stages, generates OpenSpec artifacts per stage, and creates cross-referenced GitHub issues with dependency tracking.
argument-hint: "<feature-name>"
disable-model-invocation: true
---

# Staged Greenfield: PRD → Stages → OpenSpec → GitHub Issues

You are running the staged greenfield pipeline: read a PRD, propose development stages, generate per-stage OpenSpec artifacts, and create cross-referenced GitHub issues.

## Input

The feature name is: $ARGUMENTS
The PRD file is at: `docs/prds/$ARGUMENTS.md`

## Phase 1: Read and Validate the PRD

1. **Read the PRD** at `docs/prds/$ARGUMENTS.md`. If the file does not exist, tell the user and stop.

2. **Check for Open Questions** in the PRD. If any exist, present them to the user and ask whether to proceed or resolve them first.

3. **Extract the key PRD content** and hold it in context:
   - Problem Statement
   - Goals and Non-Goals
   - User Stories (these drive stage and task generation)
   - UI/UX Notes
   - Technical Considerations
   - Dependencies

4. **Check for an API Contract reference** in the PRD:
   - Look for an `## API Contract` section.
   - If missing or empty, skip — the pipeline works without it.
   - If present, extract the reference (file path or URL).
     - **Local file**: Read it. If not found, warn and ask whether to proceed without it.
     - **URL**: Fetch with WebFetch. If fetch fails, warn and ask whether to proceed without it.
   - **Parse the Swagger/OpenAPI content** and extract an API Summary (title, version, base URL, auth, endpoints, schemas).
   - Hold the **API Summary** in context alongside the PRD content.

5. **Assess if staging is appropriate**. If the PRD has only 1-2 user stories, suggest using `/sdd-from-prd $ARGUMENTS` instead — staging adds overhead without benefit for small features. If the user still wants staged, proceed.

## Phase 2: Analyze and Propose Stages

6. **Analyze the PRD holistically** and propose a staged breakdown. Target **3-6 stages**.

   Use this algorithm:
   a. **Greenfield defaults**: For a new project, propose:
      - `01-setup` — Project initialization, tooling, CI, dependencies, dev environment
      - `02-scaffold` — App shell, routing, layout components, state management skeleton, shared utilities
   b. **Group user stories** by functional area or dependency chain. Stories that share UI components, data models, or API endpoints cluster together.
   c. **Order by dependency**: Features that others depend on come first. If story B requires a component from story A, story A's stage comes first.
   d. **API contract consideration**: If present, stages that set up API clients/types come before stages that consume them.

7. **Present the proposed stages** to the user:

   ```
   ## Proposed Stages for $ARGUMENTS

   | # | Stage | Description | User Stories |
   |---|-------|-------------|-------------|
   | 01 | setup | Project init, tooling, CI | — |
   | 02 | scaffold | Routing, layout, shared components | Story 1 |
   | 03 | auth-flow | Authentication UI and API integration | Story 2, Story 3 |
   | 04 | dashboard | Main dashboard views | Story 4, Story 5 |

   You can: add, remove, reorder, rename stages, or reassign stories between them.
   Approve to proceed with artifact generation.
   ```

   Wait for user approval. Allow adjustments. If a stage ends up with zero user stories (like setup/scaffold), that is fine — those are infrastructure stages.

## Phase 3: Generate OpenSpec Artifacts Per Stage

8. **For each approved stage**, in order, generate OpenSpec artifacts:

   a. **Derive the change name**: `$ARGUMENTS-NN-<stage-slug>` (e.g., `my-app-01-setup`, `my-app-02-scaffold`).

   b. **Create the OpenSpec change**:
      ```bash
      openspec new change "$CHANGE_NAME"
      ```
      If a change with that name already exists, ask the user whether to continue it or skip it.

   c. **If this is the first API-consuming stage and an API Contract was found**, copy the Swagger file into this change folder:
      - Local file: Copy to `openspec/changes/$CHANGE_NAME/api-contract.yaml`
      - URL content: Write to `openspec/changes/$CHANGE_NAME/api-contract.yaml`

   d. **Get the artifact build order**:
      ```bash
      openspec status --change "$CHANGE_NAME" --json
      ```

   e. **Generate each artifact in dependency order**. For each artifact that is `ready`:
      - Get instructions:
        ```bash
        openspec instructions <artifact-id> --change "$CHANGE_NAME" --json
        ```
      - Read any completed dependency artifacts for context.
      - Create the artifact file using the `template` from instructions as the structure.
      - **Scope to this stage only**: Use only the PRD content relevant to this stage's user stories.
      - **Prior stage context**: For stages after 01, include a context block summarizing what earlier stages produce (components, services, types, routes, utilities). This prevents re-creating things and enables referencing them.
      - **API enrichment** (same as `/sdd-from-prd`):
        - **specs/*.md**: Add integration scenarios for API-consuming stories.
        - **design.md**: Add "API Integration" subsection with endpoint mapping, TypeScript interfaces, auth approach.
        - **tasks.md**: Include API-specific tasks (client, types, wiring, error handling).
      - Apply `context` and `rules` from instructions as constraints — do NOT copy them into the file.
      - After each artifact, re-check status:
        ```bash
        openspec status --change "$CHANGE_NAME" --json
        ```

   f. **Show progress** after each stage: "Stage NN-slug: artifacts generated."

9. **Show a summary** of all stages and their artifacts.

## Phase 3.5: Design Challenge

10. **Challenge the overall staged design** before creating tickets. Review the full set of stage artifacts holistically and present a brief challenge report:

    ```
    ## Design Challenge for $ARGUMENTS (Staged)

    ### Assumptions
    - <List 2-4 key assumptions the staging and design make>

    ### Risks & Pitfalls
    - <Stage ordering issues, coupling between stages, over-engineering in early stages, missing foundations>
    - <Security concerns, performance traps, wrong abstraction level>

    ### Simplification Opportunities
    - <Can any stages be merged?>
    - <Are we building scaffolding we don't need yet?>
    - <Is the stage boundary in the right place?>

    ### Open Questions
    - <Anything that should be answered before implementation?>
    ```

    **Ask the user**: "Here's my design challenge across all stages. Want to adjust anything before I create tickets, or proceed as-is?"

    If the user requests changes, update the relevant stage artifacts before proceeding.

## Phase 4: Create GitHub Issues (All Stages)

11. **Ask the user**: "All N stages have OpenSpec artifacts. Shall I create GitHub issues for all stages now?"

    If no, tell them they can run `/sdd-create-tickets <change-name>` per stage later.

12. **Verify GitHub CLI access**:
    ```bash
    gh repo view --json nameWithOwner -q '.nameWithOwner'
    ```
    If this fails, tell the user to run `gh auth login` and stop.

13. **Ensure per-stage labels exist**. For each stage, create a label:
    ```bash
    gh label create "stage-NN-<slug>" --description "Stage NN: <description>" --color "ededed" 2>/dev/null || true
    ```

14. **Create issues stage by stage, in order**. Maintain a cross-stage mapping: `{stage-slug: {task-id: issue-number}}`.

    For each stage, read its artifacts:
    - `openspec/changes/$CHANGE_NAME/tasks.md`
    - `openspec/changes/$CHANGE_NAME/proposal.md`
    - `openspec/changes/$CHANGE_NAME/specs/*.md`
    - `openspec/changes/$CHANGE_NAME/design.md`

    For each task (`- [ ] N.N description`):

    a. **Infer type** (same as `sdd-create-tickets`):
       - setup/config/infrastructure → `chore`
       - test → `test`
       - docs/documentation → `docs`
       - refactor → `refactor`
       - Everything else → `feat`

    b. **Map acceptance criteria** from GIVEN-WHEN-THEN scenarios in specs.

    c. **Pull implementation hints** from design.md.

    d. **Determine cross-stage dependencies**:
       - The **first task of each stage after 01** automatically depends on the **last task of the previous stage** (stage gate).
       - If a task explicitly references outputs from a prior stage (e.g., "uses the auth service from stage 01"), add a specific "Depends on #N" reference.

    e. **Create the issue**:
       ```bash
       gh issue create \
         --title "<type>: <task title>" \
         --label "<type>,stage-NN-<slug>" \
         --body "$(cat <<'ISSUE_EOF'
       ## Description
       <Context from proposal.md + task description>

       ## Acceptance Criteria
       <GIVEN-WHEN-THEN scenarios or derived criteria>
       - [ ] <criterion>

       ## Implementation Hints
       <Relevant details from design.md>

       ## Dependencies
       <Intra-stage dependency issue numbers, or "None">

       ## Cross-Stage Dependencies
       <"Depends on #N (stage NN-slug: task title)" or "None — this is stage 01">

       ## Stage Context
       This issue is part of **Stage NN-<slug>** of the `$ARGUMENTS` staged development.
       See full stage map: `.tasks/$ARGUMENTS-stages.md`

       ---
       Source: openspec/changes/$CHANGE_NAME/tasks.md
       ISSUE_EOF
       )"
       ```

    f. **Record the issue number** in the cross-stage mapping.

    g. **If the task involves API integration**: include an "API Contract" section with endpoint details and pointer to the Swagger file.

15. **Update each stage's tasks.md** by appending issue numbers:
    ```
    - [ ] 1.1 Create auth context (#42)
    ```

16. **Write per-stage issue mapping files** to `.tasks/$CHANGE_NAME.md` (same format as `sdd-create-tickets`).

## Phase 5: Write Stage Map and Summary

17. **Write the master stage map** to `.tasks/$ARGUMENTS-stages.md`:

    ```markdown
    # Staged Development: $ARGUMENTS

    Source PRD: docs/prds/$ARGUMENTS.md
    Generated: <YYYY-MM-DD>
    Total Stages: N
    Total Issues: M

    ## Stages

    | Stage | Change | Issues | Status |
    |-------|--------|--------|--------|
    | 01-setup | $ARGUMENTS-01-setup | #42-#44 | pending |
    | 02-scaffold | $ARGUMENTS-02-scaffold | #45-#48 | pending |

    ## Stage Details

    ### 01-setup
    - Change: openspec/changes/$ARGUMENTS-01-setup/
    - Depends on: (none)

    | Task | Issue | Title | Type | Depends On |
    |------|-------|-------|------|------------|
    | 1.1 | #42 | Initialize project | chore | none |
    | 1.2 | #43 | Configure linting | chore | #42 |

    ### 02-scaffold
    - Change: openspec/changes/$ARGUMENTS-02-scaffold/
    - Depends on: Stage 01 (#42-#44)

    | Task | Issue | Title | Type | Depends On |
    |------|-------|-------|------|------------|
    | 1.1 | #45 | Create app shell | feat | #44 (stage 01) |
    ```

18. **Print the final summary**:
    ```
    ## Staged Pipeline Complete: $ARGUMENTS

    PRD: docs/prds/$ARGUMENTS.md
    Stages: N
    Total Issues: M
    Stage Map: .tasks/$ARGUMENTS-stages.md

    | Stage | Change | Issues | Description |
    |-------|--------|--------|-------------|
    | 01-setup | $ARGUMENTS-01-setup | #42-#44 | Project init, tooling |
    | 02-scaffold | $ARGUMENTS-02-scaffold | #45-#48 | Routing, layout |

    Next: Run /sdd-work <issue-number> starting from stage 01 issues.
    Work through stages in order. After completing a stage, run /opsx:archive <change-name>.
    ```

## Rules
- The PRD is the source of truth. Do not invent requirements not in the PRD.
- Respect Non-Goals — do not generate tasks for out-of-scope items.
- If the PRD is vague on a point, ask the user rather than guessing.
- Target 3-6 stages. Fewer defeats the purpose; more creates overhead for a small team.
- Stage naming convention: `<feature>-NN-<slug>` with zero-padded numbers.
- Create issues in strict stage order so cross-stage references use real issue numbers.
- Use conventional commit types as issue title prefixes (feat, chore, test, docs).
- Do NOT assign issues unless the user explicitly asks.
- If any step fails (openspec CLI, gh CLI), stop and report the error clearly.
- If existing stage changes are detected (`openspec/changes/$ARGUMENTS-01-*` exists), ask whether to continue existing work or start fresh.
- The Swagger/OpenAPI doc is supplementary context for HOW the backend works. The PRD remains the source of truth for WHAT to build.
