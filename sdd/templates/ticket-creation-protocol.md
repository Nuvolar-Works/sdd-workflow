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
Read change_dir/specs/*/spec.md (via glob)
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
| **Type** | Work items (`is_work_item=true`): derive from the DoD goal type (Setup → `chore`, Refactor → `refactor`, Test → `test`, otherwise → `feat`). Otherwise, first match of these section-title keywords (whole words, case-insensitive):<br>- `setup`, `config`, `infrastructure`, `init` → `chore`<br>- `test`, `tests` → `test`<br>- `docs`, `documentation` → `docs`<br>- `refactor` → `refactor`<br>- `fix`, `bug` → `fix`<br>- otherwise → `feat` |
| **Priority** | By section order: first third → `high`, middle third → `medium`, last third → `low`. Override if the section description explicitly states a priority. Advisory: used for ordering only; tracker recipes do not send it (see each recipe's `CreateTicket`). |
| **Labels** | Kebab-case section name plus the type. Plus any stage label (`stage-NN-<slug>`) if the calling skill is staged. Plus `follow-up` if created by `CreateRelatedTicket`. |
| **Acceptance Criteria** | Match GIVEN-WHEN-THEN scenarios from the relevant `specs/<capability>/spec.md` file (heuristic: section-title keyword match). If no scenario matches, derive 2-4 criteria from the section's subtasks. |
| **Implementation Hints** | Relevant excerpts from `design.md` for this section's scope. |
| **Design Excerpt** | (work-item only — `is_work_item=true`) 5-15 line excerpt from the relevant section of `design.md`, as plain paragraphs with the source heading as a bold lead-in. |
| **API Integration** | (work-item only) Include the section iff goal type is **Integration** per `sdd/templates/definition-of-done.md` § Goal-type detection. Body: endpoint signature + request/response shape from `api-contract.yaml` when present, otherwise from `design.md` § API Integration; omit the section if neither has endpoint details. |
| **Definition of Done** | (work-item only) Determine goal type via `sdd/templates/definition-of-done.md` § Goal-type detection, then pull the matching block per § Blocks. Apply the inline-vs-reference rule from § Inlining vs reference (Setup / Refactor get a one-line reference; UI / Integration / Test / Generic get the full inlined block). |
| **Dependencies** | Ids of earlier sections this section actually needs (per `tasks.md`/`design.md`), whether created this run or captured as existing; `None` if independent. Always ids. |

## Step 4: Build the ticket body

Text copied into the body from `proposal.md`, `design.md` or spec files is written as plain paragraphs: never use `>` blockquotes, and strip a leading `> ` from copied lines — some trackers drop blockquoted lines silently.

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
Source: <api-contract.yaml or design.md § API Integration>

## Definition of Done                    ← work-item only
<DoD block from definition-of-done.md>

## Dependencies
<Comma-separated prior ticket ids, or "None">

---
Spec section: openspec/changes/<change>/specs/<capability>/spec.md
Source: openspec/changes/<change>/tasks.md (section <N>)
```

The trailing footer is mandatory on every ticket; `Spec section:` names the spec file chosen in Step 3. `/sdd-work` Phase 1.5 reads `Spec section:` to lazy-load the relevant spec without scanning all files.

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

For Jira, `CreateChildTickets` creates a board-visible Task per payload and links it to the parent story — see `sdd/trackers/jira.md`.

## Step 7: Update OpenSpec tasks.md with ticket annotations

After each successful create, append the ticket id to the section header in `tasks.md` (if the header already carries an id annotation, replace it instead of appending):
```
## 1. Setup (#42)         ← GitHub
## 1. Setup [TT-457]      ← Jira
```

Do NOT modify individual `- [ ]` subtask lines — those stay unannotated. The header annotation is enough for `/sdd-work` to find the section by ticket id.

When `dry_run`: don't write to `tasks.md`. Print the intended annotation.

## Step 8: Write mapping file

(Re)write `sdd/tasks/<change_name>.md` with one row per section that has an id after this run (both `existing` and `new`):

```markdown
# Issue Mapping: <change-name>

Source: openspec/changes/<change>/
Tracker: <tracker>
Generated: <YYYY-MM-DD>

| Section | Ticket | Title | Type | Priority | Depends On | Spec Section |
|---------|--------|-------|------|----------|------------|--------------|
| 1       | <id>   | ...   | feat | high     | none       | <capability>/spec.md |
```

The `Spec Section` column always mirrors the ticket's `Spec section:` footer. The `Tracker` line at the top reflects the active `sdd/config.json` `tracker` value.

When `dry_run`: do not write the mapping file; print the would-be table (with synthetic `DRY-N` ids).

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

Sections whose key the caller assigned from a pre-existing work item this run are always skipped, including under **Regenerate**.

When the user chose **Regenerate**, this protocol creates fresh tickets, then calls `CloseTicket(<old>, "Replaced by <new>")` for each old ticket (no deletion), and rewrites the mapping. The old ticket ids are reported in the summary with `replaced by <new id>`.
