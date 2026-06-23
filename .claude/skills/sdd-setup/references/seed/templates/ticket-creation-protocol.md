# Ticket Creation Protocol

Shared algorithm used by `/sdd-from-prd`, `/sdd-staged`, `/sdd-create-tickets`, and `/sdd-tasks-from-story` when turning OpenSpec `tasks.md` sections into tracker tickets. The skills all follow this protocol so changes to ticket shape, type inference, or labelling happen in one place.

Skills load this file in their Phase 4 (or equivalent ticket-creation phase). Read it before iterating over `tasks.md` sections.

## Inputs

The calling skill provides:
- `change_name` — slug of the OpenSpec change (e.g. `tt-456-dashboard-page`).
- `change_dir` — `openspec/changes/<change_name>/`.
- `parent_id` (optional) — parent story key when creating linked work-item tickets (`/sdd-tasks-from-story`).
- `is_work_item` — boolean. `true` when calling `CreateChildTickets` (goal-level work items linked to a parent story) instead of `CreateTicket`. (Formerly `is_subtask`; renamed because Jira now creates linked Tasks, not Sub-tasks.)
- `dry_run` — boolean. When true, skip writes and emit `[DRY RUN]` lines per the protocol convention.

## Step 1: Read change artifacts

```
Read change_dir/tasks.md
Read change_dir/proposal.md
Read change_dir/specs/*.md (via glob)
Read change_dir/design.md
Optional: read change_dir/api-contract.yaml when present.
```

## Step 2: Group tasks by section header

Each `## N. <Section Name>` in `tasks.md` becomes one ticket. Subtasks under each section header (`- [ ] N.M description`) become a checklist inside the ticket body — they are NOT separate tickets.

If a section header already carries a ticket id annotation (`## 1. Setup (#42)` or `## 1. Setup [TT-457]`), capture the existing id. The calling skill's Phase 0.5 (re-run safety) decides whether to skip, regenerate, or abort.

## Step 3: Per-section payload derivation

For each section, derive:

| Field | Rule |
|-------|------|
| **Title** | Section name verbatim (e.g. "Database Layer", "Clock-in panel"). Optionally prefix with team-area convention (e.g. "Frontend: Clock-in panel"). |
| **Type** | First match of these section-title keywords:<br>- `setup`, `config`, `infrastructure`, `init` → `chore`<br>- `test`, `tests` → `test`<br>- `docs`, `documentation` → `docs`<br>- `refactor` → `refactor`<br>- `fix`, `bug` → `fix`<br>- otherwise → `feat` |
| **Priority** | By section order: first third → `high`, middle third → `medium`, last third → `low`. Override if the section description explicitly states a priority. |
| **Labels** | Kebab-case section name plus the type. Plus any stage label (`stage-NN-<slug>`) if the calling skill is staged. Plus `follow-up` if created by `CreateRelatedTicket`. |
| **Acceptance Criteria** | Match GIVEN-WHEN-THEN scenarios from the relevant `specs/*.md` file (heuristic: section-title keyword match). If no scenario matches, derive 2-4 criteria from the section's subtasks. |
| **Implementation Hints** | Relevant excerpts from `design.md` for this section's scope. |
| **Design Excerpt** | (work-item only — `is_work_item=true`) 5-15 line quote from the relevant section of `design.md` including its heading. |
| **API Integration** | (work-item only) Include the section iff goal type is **Integration** per `sdd/templates/definition-of-done.md` § Goal-type detection. Body: endpoint signature + request/response shape from `api-contract.yaml`. |
| **Definition of Done** | (work-item only) Determine goal type via `sdd/templates/definition-of-done.md` § Goal-type detection, then pull the matching block per § Blocks. Apply the inline-vs-reference rule from § Inlining vs reference (Setup / Refactor get a one-line reference; UI / Integration / Test get the full inlined block). |
| **Dependencies** | Tickets created in earlier sections this run. Use real ids captured from previous `CreateTicket` returns. For a fresh first section, `None`. |

## Step 4: Build the ticket body

```markdown
## Description
<Context from proposal.md scoped to this section.>

## Tasks
- [ ] N.1 <subtask description>
- [ ] N.2 <subtask description>

## Acceptance Criteria
<GIVEN-WHEN-THEN scenarios or derived criteria>

## Implementation Hints
<Relevant excerpts from design.md>

## Design Excerpt                        ← work-item only
<5-15 line excerpt from the relevant design.md section>

## API Integration                       ← integration work-item only
Endpoint: <METHOD path>
Request shape: <key fields>
Response shape: <key fields>
Error responses: <code → meaning>
Source: openspec/changes/<change>/api-contract.yaml

## Definition of Done                    ← work-item only
<DoD block from definition-of-done.md>

## Dependencies
<Comma-separated prior ticket ids, or "None">

---
Spec section: openspec/changes/<change>/specs/<file>.md   ← work-item only
Source: openspec/changes/<change>/tasks.md (section <N>)
```

The trailing footer is mandatory on every ticket. `/sdd-work` Phase 1.5 reads `Spec section:` to lazy-load the relevant spec without scanning all files.

## Step 5: Ensure labels exist

For each unique label across all sections in this run, call `EnsureLabel(<label>)` from the active tracker recipe. Skip if `dry_run` (print the would-be call).

## Step 6: Create tickets in section order

For each section, in section-order:

```
if dry_run:
    print [DRY RUN] would <op>(payload) and assign synthetic id DRY-<n>
else:
    if is_work_item:
        id = CreateChildTickets(parent_id, [payload])[0]
    else:
        id = CreateTicket(payload)
    capture id for downstream sections
```

For `/sdd-tasks-from-story` (`is_work_item=true`), use a single batched `CreateChildTickets(parent_id, payloads)` call instead of N individual creates when the recipe supports it. Falls back to per-payload if needed. (For Jira, `CreateChildTickets` creates a board-visible Task per payload and links it to the parent story — see `sdd/trackers/jira.md`.)

## Step 7: Update OpenSpec tasks.md with ticket annotations

After each successful create, append the ticket id to the section header in `tasks.md`:
```
## 1. Setup (#42)         ← GitHub
## 1. Setup [TT-457]      ← Jira
```

Do NOT modify individual `- [ ]` subtask lines — those stay unannotated. The header annotation is enough for `/sdd-work` to find the section by ticket id.

When `dry_run`: don't write to `tasks.md`. Print the intended annotation.

## Step 8: Write mapping file

Append a row to `sdd/tasks/<change_name>.md`:

```markdown
# Issue Mapping: <change-name>

Source: openspec/changes/<change>/
Tracker: <tracker>
Generated: <YYYY-MM-DD>

| Section | Ticket | Title | Type | Priority | Depends On | Spec Section |
|---------|--------|-------|------|----------|------------|--------------|
| 1       | <id>   | ...   | feat | high     | none       | <file.md>    |
```

The `Spec Section` column applies to linked work-item tickets (those carry `Spec section:` footers); for top-level tickets the column may show the OpenSpec change's primary spec or be empty. The `Tracker` line at the top reflects the active `sdd/config.json` `tracker` value.

When `dry_run`: write the mapping locally (revertable via git). The synthetic `DRY-N` ids appear in the mapping so the user can preview the shape.

## Step 9: Print summary

```
## Tickets Created
Tracker: <tracker>
Change: openspec/changes/<change>/
Total: <N> tickets

| # | Id | Title | Type | Depends On |
|---|----|-------|------|------------|
| 1 | <id> | ... | feat | none |
| 2 | <id> | ... | feat | <id> |

Next: /sdd-work <id>
```

When `dry_run`: prefix the heading with `[DRY RUN] `. Replace ticket ids with `DRY-N`. Add a line at the bottom: `Re-run without --dry-run to create these tickets.`

## Re-run safety hook

When the calling skill's Phase 0.5 detected existing tickets and the user chose **Continue**, this protocol must skip create operations for sections that already have a captured ticket id (from `tasks.md` annotations or the mapping file). Mark those sections in the summary as `existing` rather than `new`.

When the user chose **Regenerate**, the calling skill has already deleted or marked-for-overwrite the existing artifacts; this protocol creates fresh tickets and updates the mapping. The old ticket ids are reported in the summary with `replaced by <new id>`.
