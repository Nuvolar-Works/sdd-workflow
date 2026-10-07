---
name: sdd-constitution
description: Generate or update a project constitution — coding standards, architectural rules, and quality gates split across files in sdd/constitution/ that the SDD skills enforce.
argument-hint: "[project-name] [--dry-run]"
disable-model-invocation: true
---

# Generate Project Constitution

## Input

`$ARGUMENTS` parsed for an optional project name (used in the title; defaults to the repo name) and an optional `--dry-run`. When `--dry-run`: the interview still runs and the file contents are drafted to the chat for review, but **no files are written**. Re-run without `--dry-run` to commit the constitution to disk.

You are creating or updating the project constitution — a living document split across files in `sdd/constitution/` that defines coding standards, architectural rules, and quality gates. SDD skills load only the section files they need at the time they need them.

## Phase 1: Gather Project Context

1. Check for an existing constitution. Look in this order:
   - `sdd/constitution/index.md` (current layout)
   - `docs/constitution.md` (legacy single-file layout)

   If either exists, read it and ask: "A constitution already exists. Update it, or start fresh?" If updating, use the existing content as a baseline. If the legacy single file exists but the split layout doesn't, plan to migrate to the split layout in Phase 3 regardless of the answer.

2. Detect existing project signals:
   - Build / framework configs: `package.json`, `tsconfig.json`, `next.config.*`, `vite.config.*`, `angular.json`, etc.
   - Linting: `.eslintrc*`, `.prettierrc*`, `biome.json`
   - Testing: `vitest.config.*`, `jest.config.*`, `playwright.config.*`
   - Build manifests and task runners: `Makefile`, `pom.xml`, `build.gradle*`, `pyproject.toml`, `go.mod`, `*.csproj`, `sfdx-project.json`, etc.
   - CI config: pipeline files such as `.github/workflows/*.yml`, `.gitlab-ci.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`, `.circleci/config.yml`, or a path the user gives
   - Existing PRDs in `sdd/prds/` or `docs/prds/` for any "Technical Considerations" sections
   - Source code patterns (folder structure, naming, imports)

3. Present findings to the user:
   ```
   ## Detected Project Context

   - Framework: <detected or "not detected">
   - Language: <detected or "not detected">
   - Styling: <detected or "not detected">
   - State Management: <detected or "not detected">
   - Testing: <detected or "not detected">
   - Linting: <detected or "not detected">
   - Folder structure: <detected pattern or "not detected">
   ```

   Ask: "Confirm, correct, or add details for anything I missed."

## Phase 2: Interview for Principles

4. For any areas not covered, ask in batches (not one by one) to keep momentum:

   **Batch 1 — Stack & Architecture** (skip items already known): framework + version, language + strictness, UI primitives, styling approach, state management, routing, forms/validation, i18n.

   **Batch 2 — Conventions & Patterns** (skip known): folder pattern (feature-/layer-/domain-based), naming conventions, component patterns, import conventions, error handling.

   **Batch 3 — Quality & Governance**: quality gates (proposed from CI config when found — see step 10), test expectations (unit / E2E / coverage), accessibility, performance, security, NON-NEGOTIABLE rules from past incidents.

   For each batch, present detected/inferred defaults and let the user confirm or override. Only ask about genuinely unknown items.

## Phase 3: Generate the Split Constitution

5. Create the directory structure if it doesn't exist:
   ```bash
   mkdir -p sdd/constitution
   ```

6. Write **`sdd/constitution/index.md`** with:
   - The Sync Impact Report HTML comment block at the top (version 0.0.0 → 1.0.0 for a new constitution; bump appropriately for an update).
   - A short table of contents (one row per section file: file, purpose, read by).
   - A Governance section (the constitution supersedes other conventions; amendments require a PR with updated Sync Impact Report; one approver minimum).
   - The version + ratified + last-amended footer.

7. Write **`sdd/constitution/principles.md`** with all Core Principles. For each principle:
   - Title with `(NON-NEGOTIABLE)` or `(RECOMMENDED)` suffix.
   - Concrete description of what MUST or SHOULD happen.
   - Rationale paragraph.
   - Mark NON-NEGOTIABLE only when the user explicitly said so or when it represents safety/correctness (e.g. TypeScript strict mode, no `any`). Default to RECOMMENDED otherwise.

8. Write **`sdd/constitution/tech-stack.md`** as a flat bullet list of technologies and versions:
   ```markdown
   - **Framework**: ...
   - **Language**: ...
   - ... etc
   ```

9. Write **`sdd/constitution/folder-structure.md`** with:
   - A code-fenced tree showing the expected `src/` layout with one-line descriptions of each folder.
   - A naming-conventions table (Files, Components, Hooks, Constants, Types, Props Interfaces, API Functions, etc.).
   - Any nested rules (i18n hook conventions, variable naming, etc.) the user specified.

10. Write **`sdd/constitution/quality-gates.md`** with:
    - The numbered list of NON-NEGOTIABLE quality gates. If CI config was detected, read the jobs that run on pull/merge requests to the base branch and propose each step as one of:
      - **local** — the project's own entry point as CI invokes it (script, task-runner target or CLI command), its source (`CI job <name>` | manifest | user), and prerequisites (required env var names, org/account alias, running services — never values).
      - **CI-only** — with a one-line reason: deploys/publishes/releases, needs CI-only infrastructure or credentials, or too slow to run per ticket.

      Mark steps mapped from a CI action/task rather than a plain command as `derived — confirm`. Never propose deploy/publish/release steps as local gates. The user confirms or edits the whole list.
    - Every gate carries an exact command in backticks, or is explicitly marked `review-only` or `CI-only` — a gate without either is reported NOT CONFIGURED by `/sdd-work` and `/sdd-verify`. Shape: `` `<command>` — source: CI job `<name>` ``.
    - When gates were derived from CI, a `CI baseline:` line with the CI config paths and the commit they were read at, so `/sdd-verify` and `/sdd-doctor` can warn when CI changes.
    - Coverage threshold and RBAC verification where applicable.
    - Error handling rules.
    - Specification / Plan / Task content requirements.
    - Development workflow notes (cross-reference CLAUDE.md for git conventions instead of duplicating them).

11. If the project has UI / design conventions, write **`sdd/constitution/design-system.md`** with:
    - Color tokens (table: token, use case, opacity variants).
    - Migration rules (legacy classes → semantic tokens).
    - Font, shadow scale, border radius, animations, dark mode, header controls, sidebar conventions.
    - Skip this file if the project has no UI / design system. If skipping it and one exists from a previous version, ask whether to remove it; in dry-run, note it.

12. If the project has shared utilities with mandatory usage rules, write **`sdd/constitution/utilities.md`** with each rule and the import path that must be used. If skipping this file and one exists from a previous version, ask whether to remove it; in dry-run, note it.

13. Tailor every section to the project. Do NOT pad with generic best-practices content. If a section would be empty for this project, skip it and remove the corresponding row from `index.md`'s table of contents.

## Phase 4: Cross-Reference Validation

14. After all section files are drafted, scan each `.md` for markdown links to sibling files (`[design-system.md](design-system.md)`, etc.). For each link:
    - If the target file exists at `sdd/constitution/<target>.md` → keep the link.
    - If the target is **optional** (`design-system.md`, `utilities.md`) and was intentionally skipped (because the project has no UI / no shared utility rules) → rewrite the link inline as `<see <target> when added>` so it's clearly aspirational rather than a dangling reference.
    - If the target is **required** (`principles.md`, `tech-stack.md`, `folder-structure.md`, `quality-gates.md`, `index.md`) and missing → abort and report the inconsistency. The constitution is incomplete.

    This validation runs before writing files in `--dry-run` mode (against the in-memory drafts) and after writing in normal mode (final consistency check).

## Phase 5: Migration of Legacy File

15. If a legacy `docs/constitution.md` exists and the user did not opt into starting fresh:
    - Confirm with the user that they want to remove the legacy file (since the split version is now in place).
    - If yes, `git rm docs/constitution.md` (or note it in the user-facing summary so they can do it manually).
    - If no, leave it in place — skills will fall back to the legacy file if `sdd/constitution/index.md` is not yet present.

    When `DRY_RUN`: skip this phase entirely. The user can run again without `--dry-run` to commit the new constitution and then rerun once more to migrate the legacy file.

## Phase 6: Review and Ratify

16. Present a summary of the generated files (paths + line counts) and the Sync Impact Report block to the user. Ask:
    > Review the constitution. You can: approve as-is, request changes to any section, add principles I missed, or change any NON-NEGOTIABLE ↔ RECOMMENDED classifications.

17. Apply requested changes and re-present.

18. Once approved, the files are already on disk (or, in `--dry-run`, drafted to the chat only). Print the final summary:

    ```
    ## Constitution Ratified

    Location: sdd/constitution/
    Files: index.md, principles.md, tech-stack.md, folder-structure.md, quality-gates.md, design-system.md (if applicable), utilities.md (if applicable)
    Principles: N
    Quality Gates: N
    Version: 1.0.0

    Loaded by:
    - /sdd-from-prd — tech-stack.md + folder-structure.md
    - /sdd-staged — tech-stack.md + folder-structure.md + quality-gates.md
    - /sdd-work — principles.md + folder-structure.md + quality-gates.md
    - /sdd-verify — principles.md + quality-gates.md (+ design-system.md if changed files include UI components or route files, utilities.md if changed files touch the API client or shared data-shape utilities)
    - /sdd-tasks-from-story — tech-stack.md + folder-structure.md

    To update the constitution later, run /sdd-constitution again.
    ```

## Rules

- The constitution MUST be specific to this project. No generic "best practices" filler.
- Every principle needs a Rationale.
- The user has final say. Present your case and defer.
- Do NOT duplicate what's already in CLAUDE.md (git conventions, branch naming) — reference CLAUDE.md instead.
- For greenfield projects with no code, rely entirely on user input for conventions.
- Keep each section file scannable. The point of the split is that skills read only what they need.
- The Sync Impact Report block is mandatory in `index.md` — always include it, always bump the version when amending.
- Use today's date for ratification.
