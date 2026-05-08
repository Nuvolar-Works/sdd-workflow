# Code Review Checklist

Used by `/sdd-verify` for the code-review step. Each section produces either CLEAN or a list of specific findings (with file paths and line numbers). The reviewer runs through the categories in order; any flagged item is presented to the user as a recommendation, not a blocker (the user decides whether to fix or proceed).

## 1. Pattern consistency

- Do the changes follow existing codebase patterns (naming, file layout, component shape, state management)?
- Are imports organized like neighbouring files?
- Are exports (named vs default) consistent with the surrounding module style?
- Flag any deviation with a one-line explanation of the prevailing pattern.

## 2. Security

- XSS vectors: `dangerouslySetInnerHTML`, unescaped user input rendered as HTML, third-party SVG inserted into the DOM without sanitisation.
- Secret exposure: API keys / tokens hardcoded, logged, or shipped to the client when they should be server-only.
- Injection risks: dynamic query construction, shell commands assembled from inputs, unparameterised database calls.
- AuthZ checks: routes / actions that should be gated by RBAC but aren't, missing `requireRole` style guards.

## 3. Performance

- Unnecessary re-renders (`useMemo` / `useCallback` missing on expensive children's props).
- N+1 fetches in lists.
- Large bundles imported when a lighter alternative exists (e.g. moment vs date-fns).
- Unbounded loops, recursive calls, or deep object diffs in render paths.

## 4. Error handling

- System boundaries (API calls, user input, file I/O, external data) are wrapped in error handling appropriate to the layer.
- UI surfaces have explicit error states (not just "loading then nothing").
- Server actions return error shapes the client can map to user feedback.

## 5. Design alignment (only if a linked OpenSpec change exists)

- Read the relevant section of `openspec/changes/<change>/design.md`.
- Do the changes match the architecture described? Components, file placements, integration points?
- Flag deviations as either justified (explain why) or unjustified (recommend reverting to design).

## 6. Constitution compliance (only if `sdd/constitution/` exists)

- Read `sdd/constitution/principles.md`. For each NON-NEGOTIABLE principle, check the changed code. Violations are reported as **blocker recommendations** (still the user's call but flagged loudly).
- For each RECOMMENDED principle, check the changed code. Deviations are reported as advisory.
- For UI changes, also load `sdd/constitution/design-system.md` and check colour tokens, font, shadow scale, border radius, dark-mode support.
- For data-shape changes, also load `sdd/constitution/utilities.md` (e.g. query param serialization rules).

## Output shape

Report results in this format:

```
### Code Review

- Pattern consistency: CLEAN / <issues with file:line>
- Security: CLEAN / <issues>
- Performance: CLEAN / <issues>
- Error handling: CLEAN / <issues>
- Design alignment: CLEAN / N/A / <deviations>
- Constitution compliance: CLEAN / N/A / <violations>
```
