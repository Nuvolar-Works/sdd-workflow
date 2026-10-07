---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.3.1"
---

Archive a completed change in the experimental workflow.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the **AskUserQuestion tool** to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

3. **Check task completion status**

   Read the tasks file (typically `tasks.md`) to check for incomplete tasks.

   Count tasks marked with `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning showing count of incomplete tasks
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

   **If no tasks file exists:** Proceed without task-related warning.

4. **Assess delta spec sync state**

   Check for delta specs at `openspec/changes/<name>/specs/`. If none exist, proceed without sync prompt.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Show a combined summary before prompting

   **Prompt options:**
   - If changes needed: "Sync now (recommended)", "Archive without syncing"
   - If already synced: "Archive now", "Sync anyway", "Cancel"

   Record the choice.

5. **Perform the archive**

   Follow `sdd/docs/archiving.md` § Archiving procedure (pre-flight, snapshot, `openspec archive "<name>" --yes`, on-disk success check, rollback). Add `--skip-specs` if the user chose "Archive without syncing" or "Archive now" (already synced); stop on "Cancel". The CLI applies the delta specs to `openspec/specs/` and moves the change to `openspec/changes/archive/YYYY-MM-DD-<name>/`. If pre-flight or the archive fails, show the error and stop — the procedure has already rolled back `openspec/specs/`.

   **Archive the SDD mapping (if present):**

   Only after the archive succeeded: if `sdd/tasks/<name>.md` exists, the change has a tracker-side mapping that `/sdd-doctor` Check #9 will flag as an orphan once the change directory has moved. Ask via **AskUserQuestion**:

   - **Archive the mapping too (recommended)** — rename to `sdd/tasks/<name>.archived.md` so the doctor knows to skip it.
     ```bash
     mv sdd/tasks/<name>.md sdd/tasks/<name>.archived.md
     ```
   - **Leave the mapping** — the user will handle it manually.

   If `sdd/tasks/<name>.md` does not exist, skip this prompt entirely.

6. **Display summary**

   Show archive completion summary including:
   - Change name
   - Schema that was used
   - Archive location
   - Whether specs were synced (if applicable)
   - Whether the SDD mapping was archived alongside (if applicable)
   - Note about any warnings (incomplete artifacts/tasks)

**Output On Success**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs" or "Sync skipped")
**Mapping:** ✓ sdd/tasks/<name>.archived.md (or "Left in place" or "No mapping file")

All artifacts complete. All tasks complete.
```

**Guardrails**
- Always prompt for change selection if not provided
- Use artifact graph (openspec status --json) for completion checking
- Don't block archive on warnings - just inform and confirm
- Show clear summary of what happened
- If delta specs exist, always run the sync assessment and show the combined summary before prompting
