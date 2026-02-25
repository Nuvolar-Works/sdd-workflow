---
name: sdd-from-prd
description: End-to-end bridge from a PRD file to GitHub issues. Reads the PRD, generates OpenSpec artifacts, and creates tickets — one command for the full pipeline.
argument-hint: "<feature-name>"
disable-model-invocation: true
---

# PRD → OpenSpec → GitHub Issues

You are running the full pipeline: read a PRD, generate OpenSpec specs, and create GitHub issues.

## Input

The feature name is: $ARGUMENTS
The PRD file is at: `docs/prds/$ARGUMENTS.md`

## Phase 1: Read and Validate the PRD

1. **Read the PRD** at `docs/prds/$ARGUMENTS.md`. If the file does not exist, tell the user and stop.

2. **Check for Open Questions** in the PRD. If any exist, present them to the user and ask whether to proceed or resolve them first. Open questions may lead to incomplete or incorrect specs.

3. **Extract the key PRD content** and hold it in context:
   - Problem Statement
   - Goals and Non-Goals
   - User Stories (these drive task generation)
   - UI/UX Notes
   - Technical Considerations
   - Dependencies

## Phase 2: Generate OpenSpec Artifacts

4. **Derive a change name** from the feature name in kebab-case (e.g., `user-auth` stays `user-auth`, `User Authentication` becomes `user-authentication`).

5. **Create the OpenSpec change**:
   ```bash
   openspec new change "$CHANGE_NAME"
   ```
   If a change with that name already exists, ask the user whether to continue it or create a new one with a different name.

6. **Get the artifact build order**:
   ```bash
   openspec status --change "$CHANGE_NAME" --json
   ```
   Parse the JSON to get the `applyRequires` array and the `artifacts` list with their statuses and dependencies.

7. **Generate each artifact in dependency order**. For each artifact that is `ready`:

   a. Get instructions:
      ```bash
      openspec instructions <artifact-id> --change "$CHANGE_NAME" --json
      ```

   b. Read any completed dependency artifacts for context.

   c. Create the artifact file using the `template` from instructions as the structure.
      **Use the PRD content as the primary input** — map PRD sections to artifact sections:
      - **proposal.md**: Problem Statement → problem, Goals → objectives, Non-Goals → scope exclusions, User Stories → user needs
      - **specs/*.md**: User Stories → GIVEN-WHEN-THEN scenarios. Each story becomes one or more testable scenarios. Include edge cases from the story Details.
      - **design.md**: Technical Considerations → architecture decisions, Dependencies → integration points, UI/UX Notes → component structure
      - **tasks.md**: Derived from specs and design — atomic, implementable tasks

   d. Apply `context` and `rules` from instructions as constraints but do NOT copy them into the file.

   e. After each artifact, re-check status:
      ```bash
      openspec status --change "$CHANGE_NAME" --json
      ```
      Continue until all `applyRequires` artifacts have `status: "done"`.

8. **Show a summary** of generated artifacts with brief descriptions.

## Phase 3: Create GitHub Issues

9. **Ask the user**: "OpenSpec artifacts are ready. Shall I create GitHub issues from the tasks now?"

   If yes, proceed. If no, tell them they can run `/sdd-create-tickets $CHANGE_NAME` later.

10. **Read all artifacts** for issue context:
    - `openspec/changes/$CHANGE_NAME/tasks.md` — task list
    - `openspec/changes/$CHANGE_NAME/proposal.md` — descriptions
    - `openspec/changes/$CHANGE_NAME/specs/*.md` — GIVEN-WHEN-THEN acceptance criteria
    - `openspec/changes/$CHANGE_NAME/design.md` — implementation hints

11. **Verify GitHub CLI access**:
    ```bash
    gh repo view --json nameWithOwner -q '.nameWithOwner'
    ```
    If this fails, tell the user to run `gh auth login` and stop.

12. **Parse tasks and create issues** following the same logic as `/sdd-create-tickets`:
    - Each `- [ ] N.N description` line → one GitHub issue
    - Infer type from context (setup → chore, UI/feature → feat, test → test)
    - Map GIVEN-WHEN-THEN scenarios as acceptance criteria
    - Pull implementation hints from design.md
    - Create issues in dependency order via `gh issue create`
    - Ensure required labels exist first

13. **Update OpenSpec's tasks.md** by appending issue numbers to each task line.

14. **Write an issue mapping file** to `.tasks/$CHANGE_NAME.md`.

15. **Print the final summary**:
    ```
    ## Pipeline Complete: $ARGUMENTS

    PRD: docs/prds/$ARGUMENTS.md
    OpenSpec change: openspec/changes/$CHANGE_NAME/
    Artifacts: proposal.md, specs/, design.md, tasks.md

    | Task | Issue | Title | Type | Priority |
    |------|-------|-------|------|----------|
    | 1.1  | #42   | ...   | feat | high     |

    Next: Run /sdd-work <issue-number> to start developing a ticket.
    ```

## Rules
- The PRD is the source of truth. Do not invent requirements that are not in the PRD.
- Respect Non-Goals — do not generate tasks for out-of-scope items.
- If the PRD is vague on a point, ask the user rather than guessing.
- Create issues in dependency order so you can reference real issue numbers.
- Use conventional commit types as issue title prefixes (feat, chore, test, docs).
- Do NOT assign issues unless the user explicitly asks.
- If any step fails (openspec CLI, gh CLI), stop and report the error clearly.
