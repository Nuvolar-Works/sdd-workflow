# Definition of Done

Used by `/sdd-tasks-from-story` Phase 4 when building the bodies of the goal-level work-item tickets (Jira Tasks linked to the story). Each goal type pulls a different DoD block so trivial work items aren't bloated with checklist items that don't apply.

## Goal-type detection

Apply heuristics in order; first match wins. Match whole words, case-insensitive.

| Type | Heuristic |
|------|-----------|
| **Setup / chore** | Section title contains `setup`, `config`, `infrastructure`, `tooling`, `init`, `install`, `dependencies` |
| **Refactor** | Section title contains `refactor`, `cleanup`, `migrate`, `consolidate` |
| **Test** | Section title contains `test`, `tests`, `coverage`, `e2e`, `unit` |
| **Integration** | Section title contains `integration`, `API`, `endpoint`, `client`, `wiring`, `backend`; or section description references `api-contract.yaml` |
| **UI** | Section title or description references components, panels, pages, forms, layout, styling — when none of the above match. (Default for most user-facing goals.) |
| **Generic** | Fallback when nothing matches. Rarely needed. |

## Blocks

Each block is what gets inlined into the work-item body's `## Definition of Done` section.

### Setup / chore (minimal)

```
- All Acceptance Criteria above are met
- Lint passes (per `sdd/constitution/quality-gates.md`)
- Build compiles (per `sdd/constitution/quality-gates.md`)
- New configs documented inline or in CLAUDE.md
```

### Refactor

```
- All Acceptance Criteria above are met
- Tests still pass (per `sdd/constitution/quality-gates.md`) — no regressions
- TypeScript strict mode passes
- No new files added (refactor only); if a file split is necessary, document why in the commit message
- Public API surface preserved (or breaking changes documented)
```

### Test

```
- All Acceptance Criteria above are met
- New tests pass locally (run only the new test file with the project's test runner)
- Tests follow the existing patterns in neighbouring test files
- Coverage for the targeted module ≥ project threshold (per `sdd/constitution/quality-gates.md`)
- No flaky tests introduced (run twice locally to confirm)
```

### Integration (API client, wiring)

```
- All Acceptance Criteria above are met
- TypeScript types defined for request and response shapes (`src/types/<area>.ts`)
- API client function placed per `sdd/constitution/folder-structure.md`
- Error responses (4xx, 5xx) handled with typed error shapes
- Loading and error UI states render correctly (skeletons, error banners)
- Tests cover happy path + at least one error path
- Files placed per folder-structure conventions
```

### UI (component, panel, page)

```
- All Acceptance Criteria above are met
- Component props typed with `{ComponentName}Props` interface (per `sdd/constitution/principles.md`)
- Tests cover the primary states (default, loading, error, empty if applicable)
- Mobile-first responsive (per Mobile-First Responsiveness principle)
- Dark mode renders correctly (semantic tokens only — no hardcoded color classes)
- a11y: semantic HTML, keyboard navigation, visible focus, sufficient contrast
- Files placed per `sdd/constitution/folder-structure.md` (component file in `src/components/...`)
```

### Generic (fallback)

```
- All Acceptance Criteria above are met
- Tests added or updated
- TypeScript strict mode passes (zero `any`)
- Files placed per `sdd/constitution/folder-structure.md`
- Lint and build pass
```

## Inlining vs reference

Work items for **Setup / chore** and **Refactor** goals get a one-line DoD pointing at this template:

```
## Definition of Done
See `sdd/templates/definition-of-done.md` § <type>. AC above are the primary gate.
```

Work items for **UI**, **Integration**, **Test**, and **Generic** goals get the **full block** inlined. This is where the meat of the value is — the developer needs the goal-specific items in front of them.

The calling skill (`/sdd-tasks-from-story` Phase 4) decides between inline and reference based on the goal type detection above.
