---
name: sdd-create-tickets
description: Create GitHub issues from a parsed task file
argument-hint: "<feature-name>"
disable-model-invocation: true
allowed-tools: Read, Edit, Bash
---

# Create GitHub Issues from Tasks

You are creating GitHub issues from a previously generated task file.

## Input

The feature name is: $ARGUMENTS

## Steps

1. **Read the task file** at `.tasks/$ARGUMENTS.md`. If it does not exist, tell the user to run `/sdd-parse-prd $ARGUMENTS` first and stop.

2. **Check the task file status**. If the status is anything other than `draft`, warn the user that tickets may have already been created and ask for confirmation before proceeding.

3. **Verify GitHub CLI access** by running:
   ```bash
   gh repo view --json nameWithOwner -q '.nameWithOwner'
   ```
   If this fails, tell the user to run `gh auth login` and ensure they are in a repo connected to GitHub.

4. **Ensure required labels exist**. For each unique label across all tasks, check and create if missing:
   ```bash
   gh label create "<label>" --description "" --color "ededed" 2>/dev/null || true
   ```

5. **Create issues in dependency order** (tasks with no dependencies first). For each task:

   ```bash
   gh issue create \
     --title "<Type>: <Task title>" \
     --label "<labels>" \
     --body "$(cat <<'ISSUE_EOF'
   ## Description
   <Description from task>

   ## Acceptance Criteria
   <Acceptance criteria checkboxes from task>

   ## Implementation Hints
   <Implementation hints if present, otherwise omit this section>

   ## Dependencies
   <List dependency issue numbers if any, or "None">

   ---
   Source: .tasks/$ARGUMENTS.md | Task: <number>
   ISSUE_EOF
   )"
   ```

6. **After creating each issue**, note the returned issue number. For later tasks that depend on earlier ones, use the actual GitHub issue numbers in the Dependencies section.

7. **Update the task file** `.tasks/$ARGUMENTS.md`:
   - Change `Status:` from `draft` to `tickets-created`
   - Add an `- **Issue**: #<number>` field to each task after the Labels line

8. **Print a summary table**:
   ```
   | # | Issue  | Title              | Type | Priority | Depends On |
   |---|--------|--------------------|------|----------|------------|
   | 1 | #42    | Set up auth context| feat | high     | none       |
   | 2 | #43    | Build login form   | feat | high     | #42        |
   ```

## Rules
- Create issues in dependency order so you can reference real issue numbers.
- Use the task Type as prefix in the issue title (e.g. "feat: Add login form").
- Do NOT assign issues to anyone unless the user explicitly asks.
- If any issue creation fails, stop and report the error. Do not continue with remaining issues.
- The task file must be updated with issue numbers before finishing.
