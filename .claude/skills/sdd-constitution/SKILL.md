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
   - Build manifests and task runners: `package.json`, `pom.xml`, `build.gradle*`, `pyproject.toml` / `tox.ini`, `go.mod`, `*.sln` / `*.csproj`, `sfdx-project.json` + `force-app/`, `pubspec.yaml`, `Cargo.toml`, `dbt_project.yml`, `*.tf`, `Makefile` / `justfile` / `Taskfile.yml`, monorepo workspace files (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`, `settings.gradle*`, etc.)
   - Framework configs (examples across stacks): `next.config.*`, `vite.config.*`, `angular.json`, `tsconfig.json`, Spring `application.{yml,properties}`, Django `settings.py`, etc.
   - Linting and static analysis: `eslint.config.*` / `.eslintrc*`, `.prettierrc*`, `biome.json`, Checkstyle / Spotless config, `ruff.toml` / mypy config, PMD rulesets / Salesforce Code Analyzer config, `.tflint.hcl`, etc.
   - Testing: `vitest.config.*`, `jest.config.*`, `playwright.config.*`, JUnit sources, `pytest.ini` / `conftest.py`, Apex test classes (`@IsTest`), `*_test.go`, dbt tests, etc.
   - CI config: pipeline files such as `.github/workflows/*.yml`, `.gitlab-ci.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`, `.circleci/config.yml`, or a path the user gives
   - Existing PRDs in `sdd/prds/` or `docs/prds/` for any "Technical Considerations" sections
   - Source code patterns (folder structure, naming, imports)
   - Layers present — infer from the signals and the source tree which of these exist: **UI** (screens, views, components), **service/API** (endpoints, handlers, business services), **persistence/data** (schemas, migrations, ORM, data pipelines), **integration/events** (outbound clients, callouts, producers/consumers), **platform** (code that runs inside a hosted platform, e.g. a Salesforce org), **infra** (IaC, deploy config). A repo may have one layer or several; Phase 2 asks follow-ups only for the layers present.

3. Present findings to the user:
   ```
   ## Detected Project Context

   - Platform / runtime: <detected or "not detected">
   - Language(s): <detected or "not detected">
   - Frameworks: <detected or "not detected">
   - Layers present: <UI | service/API | persistence/data | integration/events | platform | infra — whichever apply>
   - Build & task runner: <detected or "not detected">
   - Testing: <detected or "not detected">
   - Linting / static analysis: <detected or "not detected">
   - CI: <detected or "not detected">
   - Deploy target: <detected or "not detected">
   - Folder structure: <detected pattern or "not detected">
   ```

   Ask: "Confirm, correct, or add details for anything I missed."

## Phase 2: Interview for Principles

4. For any areas not covered, ask in batches (not one by one) to keep momentum:

   **Batch 1 — Stack & Architecture** (skip items already known): platform/runtime + version, language(s) + strictness (type checking, nullability, compiler warnings), frameworks + versions, build tool, deploy target. Then follow-ups **only for the layers present**:
   - *UI*: UI primitives / component library, styling approach, state management, routing, forms/validation, i18n, accessibility target.
   - *Service/API (and integration/events)*: API style (REST, GraphQL, gRPC, messaging), persistence / ORM, transaction boundaries, authN/authZ, error model returned to callers.
   - *Platform* (e.g. Salesforce): org strategy (scratch orgs, sandboxes), sharing model, trigger/automation framework, governor-limit patterns, metadata deploy approach.
   - *Data / infra*: migration tool and reversibility policy, environments, state/backends (e.g. Terraform remote state).

   **Batch 2 — Conventions & Patterns** (skip known): module/package layout (feature-, layer- or domain-based), naming conventions per artifact kind, patterns for the main units of code, import/dependency conventions, error handling.

   **Batch 3 — Quality & Governance**: quality gates (proposed from CI config when found — see step 10), test expectations (unit / integration / E2E / coverage, and where tests run — locally or in an org/environment), accessibility (UI layer only), performance, security, NON-NEGOTIABLE rules from past incidents, stack-specific review heuristics the generic review checklist can't know (step 13), and project goal types or extra Definition-of-Done items (step 14).

   For each batch, present detected/inferred defaults and let the user confirm or override. Only ask about genuinely unknown items.

## Phase 3: Generate the Split Constitution

5. Create the directory structure if it doesn't exist:
   ```bash
   mkdir -p sdd/constitution
   ```

6. Write **`sdd/constitution/index.md`** with:
   - The Sync Impact Report HTML comment block at the top (version 0.0.0 → 1.0.0 for a new constitution; bump appropriately for an update).
   - A short table of contents with columns `File | Purpose | Load when`, one row per section file written. `Load when` is `always` for the required files, `review-checklist.md` and `definition-of-done.md` (loaded whenever a skill that consumes them runs); for `design-system.md` and `utilities.md` it is the comma-separated list of path globs recorded in steps 11–12 (e.g. `src/components/**, src/app/**` or `force-app/**/lwc/**`). Skills load a glob-triggered file only when a changed or planned path matches one of its globs. When updating an older constitution whose table lacks the `Load when` column, add it.
   - A Governance section (the constitution supersedes other conventions; amendments require a PR with updated Sync Impact Report; one approver minimum).
   - The version + ratified + last-amended footer.

7. Write **`sdd/constitution/principles.md`** with all Core Principles. For each principle:
   - Title with `(NON-NEGOTIABLE)` or `(RECOMMENDED)` suffix.
   - Concrete description of what MUST or SHOULD happen.
   - Rationale paragraph.
   - Mark NON-NEGOTIABLE only when the user explicitly said so or when it represents safety/correctness (e.g. strict type checking with no unchecked nulls, no queries or DML inside loops, every migration reversible). Default to RECOMMENDED otherwise.

8. Write **`sdd/constitution/tech-stack.md`** as a flat bullet list of technologies and versions:
   ```markdown
   - **Platform / runtime**: ...
   - **Language(s)**: ...
   - **Frameworks**: ...
   - ... etc (one bullet per layer-specific choice from Batch 1)
   ```

9. Write **`sdd/constitution/folder-structure.md`** with:
   - A code-fenced tree of the project's actual source layout (whatever its root is — `src/`, `force-app/main/default/`, `app/`, `modules/`, a monorepo's `packages/*`) with one-line descriptions of each folder.
   - A naming-conventions table keyed by the project's own artifact kinds — e.g. Components / Hooks / API functions in a React app, Apex classes / triggers / test classes / LWC bundles in Salesforce, packages / services / DTOs in a Gradle service, modules / variables / outputs in Terraform.
   - Any nested rules (i18n key conventions, variable naming, etc.) the user specified.

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

11. If the project has a UI layer with design conventions, write **`sdd/constitution/design-system.md`** with:
    - Its `Load when` globs for `index.md`: the paths that hold UI code (e.g. `src/components/**, src/app/**` or `force-app/**/lwc/**`), confirmed by the user.
    - Design tokens (table: token, use case, variants).
    - Migration rules (legacy classes/styles → tokens).
    - Font, shadow scale, border radius, animations, theming, layout/navigation conventions — whichever the project defines.
    - Skip this file if the project has no UI layer or design system. If skipping it and one exists from a previous version, ask whether to remove it; in dry-run, note it.

12. If the project has shared utilities with mandatory usage rules, write **`sdd/constitution/utilities.md`** with each rule and the import path or fully-qualified name that must be used. Record its `Load when` globs for `index.md`: the paths whose code is expected to use those utilities (e.g. `src/features/**, src/lib/**` or `force-app/main/default/classes/**`). If skipping this file and one exists from a previous version, ask whether to remove it; in dry-run, note it.

13. If the user confirmed stack-specific review heuristics, write **`sdd/constitution/review-checklist.md`** organised under the generic checklist's category headings — `Pattern consistency`, `Security`, `Performance`, `Error handling` (see `sdd/templates/code-review-checklist.md`) — one line per heuristic, phrased as a check. `/sdd-verify` applies them on top of the generic checklist. Illustrative: React — no derived state synced through effects; Salesforce — no SOQL/DML inside loops, stay within governor limits, enforce sharing/FLS, justify every `without sharing`; ORM services — no N+1 queries, explicit transaction boundaries; migrations — reversible; IaC — blast radius stated for state-changing resources. Include only heuristics the user confirmed. If skipping this file and one exists from a previous version, ask whether to remove it; in dry-run, note it.

14. If the user named project goal types or extra Definition-of-Done items, write **`sdd/constitution/definition-of-done.md`** with:
    - Project goal types — each with a name, detection keywords and its DoD items. Ticket creation checks these before the built-in types (Setup / chore, Refactor, Test, Integration, Data, UI, Feature — see `sdd/templates/definition-of-done.md`). A project type's block is inlined in full unless it says otherwise.
    - Extra items per goal type (built-in or project) — appended to that type's template block. Mark a type `replace` to replace the template block instead.
    - Illustrative: a Salesforce project adds an `Automation` type (keywords: trigger, flow, scheduled job) with "bulk-safe for 200 records"; a Gradle service appends "migration has a tested rollback" to Data.
    - If skipping this file and one exists from a previous version, ask whether to remove it; in dry-run, note it.

15. Tailor every section to the project. Do NOT pad with generic best-practices content. If a section would be empty for this project, skip it and remove the corresponding row from `index.md`'s table of contents.

## Phase 4: Cross-Reference Validation

16. After all section files are drafted, scan each `.md` for markdown links to sibling files (`[design-system.md](design-system.md)`, etc.). For each link:
    - If the target file exists at `sdd/constitution/<target>.md` → keep the link.
    - If the target is **optional** (`design-system.md`, `utilities.md`, `review-checklist.md`, `definition-of-done.md`) and was intentionally skipped (because the project has no UI layer / no shared utility rules / no stack-specific review heuristics / no DoD additions) → rewrite the link inline as `<see <target> when added>` so it's clearly aspirational rather than a dangling reference.
    - If the target is **required** (`principles.md`, `tech-stack.md`, `folder-structure.md`, `quality-gates.md`, `index.md`) and missing → abort and report the inconsistency. The constitution is incomplete.

    This validation runs before writing files in `--dry-run` mode (against the in-memory drafts) and after writing in normal mode (final consistency check).

## Phase 5: Migration of Legacy File

17. If a legacy `docs/constitution.md` exists and the user did not opt into starting fresh:
    - Confirm with the user that they want to remove the legacy file (since the split version is now in place).
    - If yes, `git rm docs/constitution.md` (or note it in the user-facing summary so they can do it manually).
    - If no, leave it in place — skills will fall back to the legacy file if `sdd/constitution/index.md` is not yet present.

    When `DRY_RUN`: skip this phase entirely. The user can run again without `--dry-run` to commit the new constitution and then rerun once more to migrate the legacy file.

## Phase 6: Review and Ratify

18. Present a summary of the generated files (paths + line counts) and the Sync Impact Report block to the user. Ask:
    > Review the constitution. You can: approve as-is, request changes to any section, add principles I missed, or change any NON-NEGOTIABLE ↔ RECOMMENDED classifications.

19. Apply requested changes and re-present.

20. Once approved, the files are already on disk (or, in `--dry-run`, drafted to the chat only). Print the final summary:

    ```
    ## Constitution Ratified

    Location: sdd/constitution/
    Files: index.md, principles.md, tech-stack.md, folder-structure.md, quality-gates.md, design-system.md (if UI layer), utilities.md, review-checklist.md, definition-of-done.md (each if applicable)
    Principles: N
    Quality Gates: N
    Version: 1.0.0

    Loaded by:
    - /sdd-from-prd — tech-stack.md + folder-structure.md
    - /sdd-staged — tech-stack.md + folder-structure.md + quality-gates.md
    - /sdd-tasks-from-story — tech-stack.md + folder-structure.md
    - Ticket creation (/sdd-from-prd, /sdd-staged, /sdd-tasks-from-story, /sdd-create-tickets) — definition-of-done.md (if present) with sdd/templates/definition-of-done.md
    - /sdd-work — principles.md + folder-structure.md + quality-gates.md (+ design-system.md / utilities.md when a planned path matches their Load-when globs)
    - /sdd-verify — principles.md + quality-gates.md + review-checklist.md (if present) (+ design-system.md / utilities.md when a changed path matches their Load-when globs)

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
