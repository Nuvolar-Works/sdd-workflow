# Codebase Audit Template

Used by `/sdd-tasks-from-story` Phase 1.6 (and, in future, `/sdd-from-prd` and `/sdd-staged`) to audit the existing codebase for prior implementation of story AC items **before** generating specs. The audit drives whether each spec scenario lands as `ADDED` (genuinely new), `ADDED + remove existing` (partial — replace what's there), `MODIFIED`/`ADDED` (locking in current behaviour; `MODIFIED` only if a living spec exists), or omitted entirely.

Without this audit, a mature codebase produces specs that overstate scope: every AC becomes an `ADDED` requirement, every goal becomes a new Task, and `/sdd-work` re-discovers existing implementation mid-build.

## Inputs

- **AC list** — extracted from the story description (and Phase 1.5 comment highlights, if any). One row per AC item.
- **Folder structure** — `sdd/constitution/folder-structure.md` is the primary source of truth for *where* relevant code lives.
- **Interface contract** (optional) — resolved per `sdd/docs/interface-contracts.md`. Read it before classifying any AC item that names an operation or field: present in the contract means supported, even if prose omits it.
- **Cross-team context** (optional) — descriptions of work items owned by other teams/repos (any layer) under the same parent (`jira.team_prefix` is used to identify which work items belong to *other* teams; their titles/descriptions are pulled for context only, never as scope).

## Process

1. **Infer likely files for each AC item.** Use the constitution's folder structure plus the AC's domain language. Illustrative examples (the real paths come from folder-structure.md):
   - "sign-in screen" → `src/app/(auth)/login/` (Next.js) · `force-app/main/default/lwc/loginForm/` (Salesforce)
   - "session lifetime" → `src/lib/auth.ts` (Next.js) · `src/main/java/.../security/SessionConfig.java` (Spring)
   - "discount rule on order save" → `force-app/main/default/classes/OrderTriggerHandler.cls` (Salesforce) · `app/services/order_service.py` (Python)
   - When the heuristic is weak, use `Glob` and `Grep` once each and stop — wide searches are a last resort and must be surfaced in Notes.

2. **Read the inferred files.** For each:
   - Does the file exist?
   - What behaviour is implemented now?
   - Does it match, partially match, or contradict the AC item?

3. **Classify** each AC item as:
   - **`new`** — no relevant code; AC becomes an `ADDED` spec scenario; work is needed.
   - **`partial`** — relevant code exists but doesn't fully satisfy the AC; AC becomes an `ADDED` spec scenario whose task list includes removing/changing the existing piece; the existing file paths are explicit inputs to `design.md`.
   - **`done`** — code already satisfies the AC; AC becomes a `MODIFIED` requirement only when `openspec/specs/<capability>/spec.md` already has a requirement with the same header, otherwise an `ADDED` requirement (to lock in the behaviour) or is **omitted** if the AC is a constitution-level invariant; no new task.

4. **Cross-team context.** For each other-team work item under the parent story:
   - Extract any interface (endpoint, event, callout), contract, dependency, or environment-variable hints from its title and description.
   - These flow into `design.md`'s **API Integration** subsection, *not* into spec scenarios for this repo.
   - Check them against the interface contract (if any); the contract wins on shape. Note disagreements in the matrix Notes.

## Output

Present a single matrix to the user. Illustrative (frontend repo):

```
## Codebase Audit for <STORY-KEY>

| # | AC item | Status | Files / current behaviour | Notes |
|---|---------|--------|---------------------------|-------|
| 1 | Single-button sign-in screen | partial | src/app/(auth)/login/page.tsx — currently shows email+password form | Form must be removed; replace with single button. |
| 2 | Click redirects to provider SSO | done | src/app/api/auth/[...nextauth]/route.ts — Google provider already configured | No work needed. Lock in via spec scenario; no task. |
| 3 | 16-hour session | new | src/lib/auth.ts — session.maxAge defaults to 30d | Set session.maxAge + jwt.maxAge to 16*60*60. |
| 4 | Domain allow-list | new | (no current implementation) | Implement in signIn callback. |
| 5 | Role-aware post-sign-in redirect | partial | src/middleware.ts — redirects authed users to /dashboard but is not role-aware | Extract to /post-signin server component or extend middleware. |

### Cross-team context (other-team work items under <STORY-KEY>)

- **<OTHER-KEY> "API - SSO callback endpoint"** (excerpt from description): the API team will expose `POST /api/auth/sso-callback` accepting Google ID token; returns JWT with `role` claim.
- **<OTHER-KEY> "API - User provisioning"** (excerpt): the API auto-provisions on first sign-in for allow-listed domains; no work in this repo.
```

## Confirmation

After printing the matrix, ask the user:

> Does this match the codebase? Edit any row (status, files, notes), or proceed to spec generation.

Accept inline corrections (e.g. *"row 2 is actually partial — there's a stale credentials provider still wired in `src/lib/auth-credentials.ts`"*). The audit is **in-memory input to Phase 2** — it does not get written to disk in the change directory.

## Rules

- **Use folder-structure.md as the primary lookup.** Falling back to a wide `grep` is the last resort and must be surfaced in the row's Notes column.
- **Audit reads only.** Never modify existing code during the audit.
- **Quantify caveats.** If a file is too large to read fully, say so in Notes — do not claim coverage you don't have.
- **Cross-team rows are context, not scope.** Never let other-team work-item content become an `ADDED` spec scenario in this repo.
- **Don't conflate "constitution invariant" with "implemented".** Some AC items restate the constitution (e.g. "strict typing", "all queries bulkified"); those are `done` by virtue of the constitution and are usually omitted from the spec entirely.
