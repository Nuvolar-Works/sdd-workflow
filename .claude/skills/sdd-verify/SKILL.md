---
name: sdd-verify
description: Verify the current branch's work against its ticket acceptance criteria and create a pull request
argument-hint: "[issue-number]"
disable-model-invocation: true
---

# Verify and Create Pull Request

You are verifying completed work and creating a PR.

## Phase 1: Determine Context

1. **Identify the current branch**:
   ```bash
   git branch --show-current
   ```
   Extract the issue number from the branch name (e.g. `feat/42-add-login` → issue #42).
   If $ARGUMENTS is provided and not empty, use that as the issue number instead.

2. **Fetch the issue** to get acceptance criteria:
   ```bash
   gh issue view <issue-number> --json title,body,labels
   ```

3. **Determine the base branch**:
   ```bash
   git rev-parse --verify main 2>/dev/null && echo "main" || echo "master"
   ```

## Phase 2: Verify

4. **Review all changes** on this branch versus the base branch:
   ```bash
   git log <base>..HEAD --oneline
   git diff <base>..HEAD --stat
   ```
   Read through the changed files to understand what was implemented.

5. **Check each acceptance criterion** from the issue body:
   - Verify it is met by examining the code
   - Mark as PASS or FAIL
   - If FAIL, explain what is missing

6. **Run project checks** (if configured):
   ```bash
   npm test 2>&1 || true
   npm run lint 2>&1 || true
   npm run build 2>&1 || true
   ```

7. **Code review** — read every changed file and evaluate:

   a. **Pattern consistency**: Do the changes follow existing codebase patterns (naming, file structure, component patterns, state management approach)? Flag deviations.

   b. **Security**: Check for XSS vectors (dangerouslySetInnerHTML, unescaped user input), exposed secrets/keys, injection risks, improper auth checks.

   c. **Performance**: Unnecessary re-renders, missing memoization on expensive computations, N+1 data fetching, large bundles imported where a lighter alternative exists.

   d. **Error handling**: Are system boundaries covered (API calls, user input, external data)? Are error states handled in the UI?

   e. **Design alignment** (only if a linked OpenSpec change exists): Do the changes match the architecture described in `design.md`? Flag any deviations.

   For each category, mark as CLEAN or flag specific issues with file and line references.

8. **Report verification results**:
   ```
   ## Verification Report for #<number>: <title>

   ### Acceptance Criteria
   - [x] Criterion 1 — PASS
   - [ ] Criterion 2 — FAIL: <reason>

   ### Code Review
   - Pattern consistency: CLEAN / <issues>
   - Security: CLEAN / <issues>
   - Performance: CLEAN / <issues>
   - Error handling: CLEAN / <issues>
   - Design alignment: CLEAN / N/A / <deviations>

   ### Project Checks
   - Tests: PASS/FAIL/NOT CONFIGURED
   - Lint: PASS/FAIL/NOT CONFIGURED
   - Build: PASS/FAIL/NOT CONFIGURED

   ### Summary
   <Overall assessment>
   ```

9. **If any criteria FAIL or checks fail**, tell the user what needs fixing and stop. Do NOT create a PR for incomplete work.

10. **If code review flags issues**, present them to the user. These are recommendations, not blockers — the user decides whether to fix them or proceed. Ask: "I found some code review items. Want to address them before the PR, or proceed as-is?"

11. **If everything passes** (or the user chooses to proceed), ask the user: "Ready to push and create a PR?"

## Phase 3: Create PR

12. **Push the branch**:
    ```bash
    git push -u origin $(git branch --show-current)
    ```

13. **Create the pull request**:
    ```bash
    gh pr create \
      --title "<type>(<scope>): <description from issue title>" \
      --body "$(cat <<'PR_EOF'
    ## Summary
    <2-3 sentence summary of what this PR does and why>

    ## Changes
    <Bulleted list of key changes made>

    ## Acceptance Criteria
    - [x] <criterion 1>
    - [x] <criterion 2>
    ...all checked off...

    ## Testing
    <What was tested and how — tests added, manual verification steps>

    Closes #<issue-number>
    PR_EOF
    )"
    ```

14. **Print the PR URL** so the user can review it in the browser.

## Rules
- Never create a PR if acceptance criteria are not met.
- The PR title must follow conventional commit format.
- The PR body must include `Closes #<number>` to auto-close the issue on merge.
- Always push before creating the PR.
- If the base branch is not `main`, ask the user which base branch to use.
- Do NOT merge the PR. That is a human decision.
