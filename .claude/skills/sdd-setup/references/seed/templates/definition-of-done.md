# Definition of Done

Used by `/sdd-tasks-from-story` Phase 4 when building the bodies of the goal-level work-item tickets (Jira Tasks linked to the story). Each goal type pulls a different DoD block so trivial work items aren't bloated with checklist items that don't apply.

## Goal-type detection

Apply heuristics in order; first match wins. Match whole words, case-insensitive.

| Type | Heuristic |
|------|-----------|
| **Project types** | Goal types defined in `sdd/constitution/definition-of-done.md` (if it exists), in the order listed there, using their detection keywords. |
| **Setup / chore** | Section title contains `setup`, `config`, `infrastructure`, `tooling`, `init`, `install`, `dependencies` |
| **Refactor** | Section title contains `refactor`, `cleanup`, `migrate`, `consolidate`, `restructure` |
| **Test** | Section title contains `test`, `tests`, `coverage`, `e2e`, `unit` |
| **Integration** | Section title contains `integration`, `client`, `callout`, `webhook`, `consumer`, `producer`, `wiring`, `sync`; or the goal connects to an interface owned elsewhere (another team's API, an external service, an event stream); or the section description references `api-contract.*` |
| **Data** | Section title contains `schema`, `migration`, `backfill`, `seed`, `pipeline`, `ETL` |
| **UI** | The goal is a screen, view, page, component or form (title or description). |
| **Feature** | Default when nothing above matches. |

## Blocks

Each block is what gets inlined into the work-item body's `## Definition of Done` section.

### Setup / chore (minimal)

```
- All Acceptance Criteria above are met
- Quality gates pass (per `sdd/constitution/quality-gates.md`)
- New configs documented inline or in CLAUDE.md
```

### Refactor

```
- All Acceptance Criteria above are met
- Tests still pass (per `sdd/constitution/quality-gates.md`) — no regressions
- Static checks pass (type check / compile / lint per `sdd/constitution/quality-gates.md`)
- Public interface preserved (or breaking changes documented)
- No behaviour change
```

### Test

```
- All Acceptance Criteria above are met
- New tests pass (run the narrowest test scope the stack supports)
- Tests follow the existing patterns in neighbouring test files
- Coverage for the targeted unit ≥ project threshold, if one is set (per `sdd/constitution/quality-gates.md`)
- No flaky tests introduced (run twice to confirm)
```

### Integration (interface owned elsewhere)

```
- All Acceptance Criteria above are met
- Request/response (or message) shapes modelled from the interface contract (see `sdd/README.md` § Interface contracts), placed per `sdd/constitution/folder-structure.md`
- Failure outcomes the contract documents are handled
- Test doubles match the contract
- Tests cover happy path + at least one failure path
- Caller-visible failure behaviour defined (e.g. UI error state, retry, error response)
```

### Data (schema, migration, pipeline, backfill)

```
- All Acceptance Criteria above are met
- Change is reversible, or the rollback is documented
- Safe to re-run
- Existing data handled (defaults, backfill)
- Validated against representative data
```

### UI (screen, view, page, component, form)

```
- All Acceptance Criteria above are met
- Inputs/props typed per `sdd/constitution/principles.md`
- Primary states covered (default, loading, error, empty if applicable)
- Responsive, accessibility and design-token rules followed per `sdd/constitution/principles.md` and `sdd/constitution/design-system.md`, where they exist
- Files placed per `sdd/constitution/folder-structure.md`
```

### Feature (default)

```
- All Acceptance Criteria above are met
- Tests added or updated, covering happy path + at least one failure path
- Quality gates pass (per `sdd/constitution/quality-gates.md`)
- Files placed per `sdd/constitution/folder-structure.md`
```

## Project extensions

A project can extend this template with `sdd/constitution/definition-of-done.md`:

- **Project goal types**, each with detection keywords, are checked before the built-in types (e.g. an IaC repo defines a `Module` type so its `infrastructure` goals don't fall into Setup / chore).
- **Extra DoD items** listed for a goal type (built-in or project-defined) are appended to that type's block.
- A type marked `replace` uses the project's block instead of this template's.

## Inlining vs reference

Work items for **Setup / chore** and **Refactor** goals get a one-line DoD pointing at this template:

```
## Definition of Done
See `sdd/templates/definition-of-done.md` § <type>. AC above are the primary gate.
```

Work items for **Test**, **Integration**, **Data**, **UI** and **Feature** goals — and project goal types unless they say otherwise — get the **full block** (including any project-appended items) inlined. This is where the meat of the value is — the developer needs the goal-specific items in front of them.

The calling skill (`/sdd-tasks-from-story` Phase 4) decides between inline and reference based on the goal type detection above.
