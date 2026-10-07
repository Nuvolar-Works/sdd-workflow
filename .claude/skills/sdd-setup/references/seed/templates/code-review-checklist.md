# Code Review Checklist

Used by `/sdd-verify` for the code-review step. Each section produces either CLEAN or a list of specific findings (with file paths and line numbers). The reviewer runs through the categories in order; any flagged item is presented to the user as a recommendation, not a blocker (the user decides whether to fix or proceed).

## 1. Pattern consistency

- Do the changes follow existing codebase patterns (naming, file layout, module shape, layering)?
- Are imports / dependencies organized like neighbouring files?
- Is the public surface (exports, visibility, access modifiers) consistent with the surrounding module style?
- Flag any deviation with a one-line explanation of the prevailing pattern.

## 2. Security

- Untrusted input reaching an interpreter or renderer without escaping, parameterisation or sanitisation (HTML/DOM, SQL/SOQL, shell, templates).
- Secrets hard-coded, logged, or shipped to clients when they should stay server-side.
- Authorisation checks missing where the surrounding code applies them (route guards, `with sharing` / FLS, policy checks).

## 3. Performance

- Work repeated per item inside loops: queries, DML or API calls per record (N+1).
- Unbounded loops or recursion.
- Avoidable re-computation on hot paths (e.g. re-renders, repeated parsing).
- Heavy dependencies imported where a lighter one exists.
- Resource or limit exhaustion (governor limits, memory, connection pools).

## 4. Error handling

- System boundaries (external calls, user input, file I/O, external data) are wrapped in error handling appropriate to the layer.
- Failure states are visible to the caller, not swallowed (UI error states, error responses, retries / dead-letter, transaction rollback).

## 5. Design alignment (only if a linked OpenSpec change exists)

- Read the relevant section of `openspec/changes/<change>/design.md`.
- Do the changes match the architecture described? Modules/components, file placements, integration points?
- Flag deviations as either justified (explain why) or unjustified (recommend reverting to design).

## 6. Constitution compliance (only if `sdd/constitution/index.md` exists)

- Read `sdd/constitution/principles.md`. For each NON-NEGOTIABLE principle, check the changed code. Violations are reported as **blocker recommendations** (still the user's call but flagged loudly).
- For each RECOMMENDED principle, check the changed code. Deviations are reported as advisory.
- If `sdd/constitution/review-checklist.md` exists, apply its stack-specific heuristics under the matching category above (§§ 1-4) and report findings there.
- Load `sdd/constitution/design-system.md` and `sdd/constitution/utilities.md` (if they exist) only when a changed path matches one of the file's `Load when` globs in `sdd/constitution/index.md`; check the changes against the rules it defines. If the table has no `Load when` column, load the file when the changed paths plausibly fall in the area its Purpose describes.

## 7. Contract fidelity (only if an interface contract resolves per `sdd/README.md` § Interface contracts and the diff produces or consumes that interface or its test doubles)

- Every operation, field, enum value and outcome the changed code uses exists in the contract with the same name, type and optionality. Flag anything invented beyond it ("the other side might send it").
- Test doubles (mocks, stubs, fakes, fixtures, recorded responses) return the contract's shape and only outcomes it documents (responses, error codes, events). A double that returns an outcome the real interface never produces hides bugs behind green tests.
- Where the contract is untyped or opaque, the code or PR body says where the shape came from (advisory).
- If this repo commits the contract it publishes, implementation and contract agree, and any contract change ships in the same PR.

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
- Contract fidelity: CLEAN / N/A / <issues>
```
