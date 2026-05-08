---
name: sdd-create-tickets
description: Create GitHub issues from an OpenSpec change's task breakdown. Use after /opsx:propose to push tasks to GitHub as trackable issues.
argument-hint: "<change-name>"
disable-model-invocation: true
---

# Create GitHub Issues from OpenSpec Change

You are creating GitHub issues from an OpenSpec change's artifacts.

## Input

The change name is: $ARGUMENTS

## Steps

1. **Locate the change directory** at `openspec/changes/$ARGUMENTS/`. If it does not exist, tell the user to run `/opsx:propose` first and stop.

2. **Read all OpenSpec artifacts** for context:

   a. Read `openspec/changes/$ARGUMENTS/tasks.md` — this is the task list you will create issues from. Each task is a `- [ ] N.N description` line under section headers (`## N. Section`).

   b. Read `openspec/changes/$ARGUMENTS/proposal.md` — extract the problem statement and scope. Use this for issue descriptions.

   c. Read all spec files from `openspec/changes/$ARGUMENTS/specs/` (use Glob for `openspec/changes/$ARGUMENTS/specs/*.md`). Extract GIVEN-WHEN-THEN scenarios. These become acceptance criteria on the issues.

   d. Read `openspec/changes/$ARGUMENTS/design.md` — extract the technical approach. Use this for implementation hints on issues.

3. **Verify GitHub CLI access** by running:
   ```bash
   gh repo view --json nameWithOwner -q '.nameWithOwner'
   ```
   If this fails, tell the user to run `gh auth login` and ensure a GitHub remote is configured.

4. **Group tasks by section**. Parse `tasks.md` and group subtasks under their parent section header (`## N. Section Name`). Each section becomes one GitHub issue; its subtasks become a checklist inside.

   For each section, determine:
   - **Title**: The section name (e.g. "Database Layer")
   - **Type**: Infer from the section name:
     - Contains "setup", "config", "infrastructure" → `chore`
     - Contains "test" → `test`
     - Contains "docs", "documentation" → `docs`
     - Contains "refactor" → `refactor`
     - Everything else → `feat`
   - **Priority**: Based on section order (first sections = `high`, middle = `medium`, last = `low`)
   - **Labels**: Derive from the section name (kebab-case, e.g., "Database Layer" → `database-layer`) plus the type
   - **Dependencies**: Later sections depend on earlier sections completing (reference their issue numbers).
   - **Acceptance criteria**: Match GIVEN-WHEN-THEN scenarios from specs that relate to this section's area. If no direct match, derive criteria from the section's tasks.
   - **Implementation hints**: Pull relevant details from `design.md` for this section's scope.

5. **Ensure required labels exist**. For each unique label, create if missing:
   ```bash
   gh label create "<label>" --description "" --color "ededed" 2>/dev/null || true
   ```

6. **Create one issue per section**, in order (first section first). For each section:

   ```bash
   gh issue create \
     --title "<type>: <section title>" \
     --label "<labels>" \
     --body "$(cat <<'ISSUE_EOF'
   ## Description
   <Context from proposal.md scoped to this section>

   ## Tasks
   - [ ] N.1 <subtask description>
   - [ ] N.2 <subtask description>
   ...

   ## Acceptance Criteria
   <GIVEN-WHEN-THEN scenarios from specs, or derived criteria>
   - [ ] <criterion>
   - [ ] <criterion>

   ## Implementation Hints
   <Relevant details from design.md for this section>

   ## Dependencies
   <List dependency issue numbers from prior sections, or "None">

   ---
   Source: openspec/changes/$ARGUMENTS/tasks.md
   ISSUE_EOF
   )"
   ```

7. **After creating each issue**, note the returned issue number. Use it in the Dependencies section of subsequent section issues.

8. **Update OpenSpec's tasks.md** by appending the section's issue number to each section header line:
   ```
   ## 1. Setup (#42)
   - [ ] 1.1 Create auth context
   - [ ] 1.2 Configure middleware
   ```

9. **Write an issue mapping file** to `.tasks/$ARGUMENTS.md` for tracking:
   ```markdown
   # Issue Mapping: <change-name>

   Source: openspec/changes/$ARGUMENTS/
   Generated: <YYYY-MM-DD>

   | Section | Issue | Title | Type | Priority | Depends On |
   |---------|-------|-------|------|----------|------------|
   | 1       | #42   | ...   | feat | high     | none       |
   | 2       | #43   | ...   | feat | medium   | #42        |
   ```

10. **Print a summary** showing the table above and the total number of issues created.

## Rules
- Create one issue per section (not per subtask). Subtasks live as a checklist inside the issue body.
- Create issues in section order so you can reference real issue numbers in dependencies.
- Use the inferred type as prefix in the issue title (e.g. "feat: Database Layer").
- Do NOT assign issues to anyone unless the user explicitly asks.
- If any issue creation fails, stop and report the error. Do not continue with remaining issues.
- Always update OpenSpec's tasks.md with issue numbers on the section header lines after creation.
- If the change has no tasks.md or tasks.md is empty, tell the user and stop.
- Respect the OpenSpec format — do not modify proposal.md, specs/, or design.md.
