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

## Phase 2: Research the Codebase

4. **Explore the project structure** to understand existing patterns:
   - Use Glob to find relevant files by name and extension
   - Use Grep to search for related code, imports, or patterns
   - Read key files that will be affected by this change

5. **Identify**:
   - Which existing files need to be modified
   - Which new files need to be created
   - What existing patterns to follow (component structure, naming, imports)
   - What tests exist that might need updating

6. **Present your implementation plan** to the user:
   ```
   ## Implementation Plan for #<number>: <title>

   ### Files to modify:
   - path/to/file.ts — <what changes>

   ### Files to create:
   - path/to/new-file.ts — <purpose>

   ### Approach:
   <Brief description of implementation approach>

   ### Risks or open questions:
   <Any concerns>
   ```

   **Ask the user: "Does this plan look good? Should I proceed?"**
   Do NOT write any code until the user confirms.

## Phase 3: Implement

7. **Create a feature branch** from the current branch:
   ```bash
   git checkout -b <type>/$ARGUMENTS-<short-description>
   ```
   Use the issue's label to determine the type (feat, fix, chore, etc.).
   Derive a kebab-case short description from the issue title.

8. **Implement the changes** following the plan:
   - Make code changes following existing codebase patterns
   - Add or update tests if acceptance criteria require it
   - Keep changes focused on what the ticket asks for — no scope creep

9. **Run project checks** if configured:
   ```bash
   npm test 2>&1 || true
   npm run lint 2>&1 || true
   npm run build 2>&1 || true
   ```
   Fix any issues these surface.

10. **Stage and commit** using conventional commits:
    ```bash
    git add <specific-files>
    git commit -m "<type>(<scope>): <description> (#$ARGUMENTS)"
    ```
    - The type comes from the issue labels (feat, fix, chore, etc.)
    - The scope is the area of the codebase affected
    - Always include the issue reference `(#N)` at the end
    - Make commits granular — one logical change per commit, not one giant commit

11. **After implementation**, go through each acceptance criterion and verify it is met. Report the status of each one to the user.

## Phase 4: Hand Off

12. **Tell the user** the implementation is complete and suggest:
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
