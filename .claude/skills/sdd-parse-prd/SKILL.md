---
name: sdd-parse-prd
description: Parse a PRD file and generate a structured task breakdown
argument-hint: "<feature-name>"
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep
---

# Parse PRD into Tasks

You are parsing a PRD to generate a structured task breakdown.

## Input

The feature name is: $ARGUMENTS

## Steps

1. **Read the PRD** at `docs/prds/$ARGUMENTS.md`. If the file does not exist, tell the user and stop.

2. **Read the template** at `docs/prd-template.md` to understand the expected structure.

3. **Check for open questions** in the PRD. If any exist, present them to the user and ask whether to proceed or resolve them first.

4. **Analyze the PRD** and decompose it into atomic, implementable tasks. Each task should:
   - Be completable in a single PR (roughly 1-4 hours of work)
   - Have a clear definition of done
   - Map to exactly one GitHub issue
   - Have explicit dependencies on other tasks (if any)

5. **Determine task order** based on dependencies. Tasks with no dependencies come first. Group tasks into phases if there is a natural sequence.

6. **Write the task file** to `.tasks/$ARGUMENTS.md` using this exact format:

```markdown
# Tasks: <Feature Name from PRD>

Source PRD: docs/prds/$ARGUMENTS.md
Generated: <YYYY-MM-DD>
Status: draft

## Task 1: <Short title>
- **Type**: feat | fix | chore | docs | refactor | test
- **Priority**: high | medium | low
- **Depends on**: none | Task N
- **Labels**: <comma-separated GitHub labels>
- **Description**: <1-2 sentence summary of what to build>
- **Acceptance criteria**:
  - [ ] <Specific, testable criterion>
  - [ ] <Another criterion>
- **Implementation hints**: <Optional: key files to touch, patterns to follow>

## Task 2: <Short title>
...
```

7. **Print a summary** showing:
   - Total number of tasks generated
   - Task titles with their types and priorities
   - Dependency graph (which tasks block which)

## Rules
- Keep tasks atomic. If a task has more than 4 acceptance criteria, consider splitting it.
- Every user-facing feature should have a corresponding test task.
- Infrastructure or setup tasks come before feature tasks.
- Prefer more small tasks over fewer large ones.
- Do NOT create GitHub issues yet — that is a separate step via `/sdd-create-tickets`.
- Non-goals from the PRD must be respected. Do not generate tasks for out-of-scope items.
