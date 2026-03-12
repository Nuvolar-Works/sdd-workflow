---
name: sdd-work
description: Pick up a GitHub issue by number, research the codebase, create a branch, and implement it end-to-end
argument-hint: "<issue-number>"
disable-model-invocation: true
---

# Work on a GitHub Issue

You are implementing a GitHub issue end-to-end.

## Input

The issue number is: $ARGUMENTS

## Phase 1: Understand the Ticket

1. **Fetch the issue** details:
   ```bash
   gh issue view $ARGUMENTS --json title,body,labels,assignees,state
   ```

2. **Read the full issue body** carefully. Identify:
   - What needs to be built
   - The acceptance criteria (these are your definition of done)
   - Any dependencies (check if blocking issues are closed)
   - Implementation hints

3. **Check for blocking dependencies**. If the issue body references dependencies that are still open, warn the user and ask whether to proceed anyway.

4. **Detect linked OpenSpec change**. Look for a `Source:` line at the bottom of the issue body:
   ```
   Source: openspec/changes/<CHANGE_NAME>/tasks.md
   ```
   - If found, extract `<CHANGE_NAME>` and announce: "Linked OpenSpec change detected: `<CHANGE_NAME>`"
   - If not found, skip to Phase 2 — this issue was created manually and the rest of the workflow works as before.

## Phase 1.5: Read OpenSpec Context (only if a linked change was detected)

5. **Read the OpenSpec artifacts** for richer implementation context:
   - `openspec/changes/<CHANGE_NAME>/proposal.md` — overall goals and context
   - `openspec/changes/<CHANGE_NAME>/design.md` — architecture, patterns, API integration
   - `openspec/changes/<CHANGE_NAME>/specs/*.md` — GIVEN-WHEN-THEN acceptance scenarios

   These supplement the issue body. The issue body defines the scope for THIS task; the artifacts provide cross-task design rationale.

6. **Check for stage context**. If the issue body contains a `## Stage Context` section:
   - Extract the feature name and stage number
   - Read `.tasks/<feature>-stages.md` for the full stage map
   - Identify what prior stages produced (components, services, types, routes) so you can reuse them
   - If cross-stage dependencies reference issues that are still open, warn the user

## Phase 1.7: Read Project Constitution

7. **Check for a project constitution** at `docs/constitution.md`.
   - If it exists, read it and hold it in context. During implementation:
     - Follow the constitution's **Core Principles** (NON-NEGOTIABLE rules are mandatory, RECOMMENDED rules should be followed unless there's a justified reason)
     - Use the correct libraries and patterns from the **Technology Stack** (e.g., if the constitution says "Zod for validation", don't use yup)
     - Place files according to the **Folder Structure**
     - Ensure the **Quality Gates** pass before considering work done
   - If the constitution does not exist, proceed without it.

## Phase 2: Research the Codebase

8. **Explore the project structure** to understand existing patterns:
   - Use Glob to find relevant files by name and extension
   - Use Grep to search for related code, imports, or patterns
   - Read key files that will be affected by this change

8. **Identify**:
   - Which existing files need to be modified
   - Which new files need to be created
   - What existing patterns to follow (component structure, naming, imports)
   - What tests exist that might need updating

9. **Present your implementation plan** to the user:
   ```
   ## Implementation Plan for #<number>: <title>

   ### Files to modify:
   - path/to/file.ts — <what changes>

   ### Files to create:
   - path/to/new-file.ts — <purpose>

   ### Approach:
   <Brief description of implementation approach>

   ### OpenSpec Context (if linked change was detected):
   - Change: <change-name>
   - Design approach: <key points from design.md>
   - Related specs: <spec files with key scenarios relevant to this task>
   - Prior stages: <what earlier stages built that this task can reuse>

   ### Risks or open questions:
   <Any concerns>
   ```

   **Ask the user: "Does this plan look good? Should I proceed?"**
   Do NOT write any code until the user confirms.

## Phase 3: Implement

10. **Create a feature branch** from the current branch:
   ```bash
   git checkout -b <type>/$ARGUMENTS-<short-description>
   ```
   Use the issue's label to determine the type (feat, fix, chore, etc.).
   Derive a kebab-case short description from the issue title.

11. **Implement the changes** following the plan:
    - Make code changes following existing codebase patterns
    - Add or update tests if acceptance criteria require it
    - Keep changes focused on what the ticket asks for — no scope creep

12. **Run project checks** if configured:
    ```bash
    npm test 2>&1 || true
    npm run lint 2>&1 || true
    npm run build 2>&1 || true
    ```
    Fix any issues these surface.

13. **Stage and commit** using conventional commits:
    ```bash
    git add <specific-files>
    git commit -m "<type>(<scope>): <description> (#$ARGUMENTS)"
    ```
    - The type comes from the issue labels (feat, fix, chore, etc.)
    - The scope is the area of the codebase affected
    - Always include the issue reference `(#N)` at the end
    - Make commits granular — one logical change per commit, not one giant commit

14. **After implementation**, go through each acceptance criterion and verify it is met. Report the status of each one to the user.

15. **Mark task complete in OpenSpec** (only if a linked change was detected). Find the matching task line in `openspec/changes/<CHANGE_NAME>/tasks.md` (match by issue number `#$ARGUMENTS` or task description) and change `- [ ]` to `- [x]`. This keeps OpenSpec status in sync.

## Phase 4: Hand Off

16. **Tell the user** the implementation is complete and suggest:
    ```
    Implementation complete! Run /sdd-verify to review the changes and create a PR.
    ```

## Rules
- ALWAYS ask the user to confirm the plan before writing any code.
- Make commits granular. One logical change per commit.
- Follow the conventional commit format strictly.
- Reference the issue number in every commit message.
- Do NOT push the branch. That happens during `/sdd-verify`.
- If you encounter something unexpected, stop and ask the user rather than guessing.
- Do not add features or changes beyond what the ticket asks for.
