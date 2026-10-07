# Workflow

There are four entry points ([which one?](../README.md#which-entry-point)). Each planning skill ends by offering to commit its artifacts in their own `docs(sdd)` [planning PR](planning-prs.md); merge it before starting work items.

## Path A: PO hands off a PRD (single feature)

```
sdd/prds/user-auth-v1.md            (PO writes this)
        |
        v
/sdd-from-prd user-auth-v1          Reads PRD, generates OpenSpec artifacts,
        |                            creates tickets
        v
/sdd-work <ticket-id>               Picks up ticket, researches codebase,
        |                            creates branch, implements, commits
        v
/sdd-verify                          Checks acceptance criteria, runs tests,
        |                            creates PR
        v
/sdd-status                          Archives change, closes parent ticket
```

v2+ increments: `sdd/prds/<feature>-v2-<scope>.md` (mini template) → `/sdd-from-prd <feature>-v2-<scope>`. See [prds.md](prds.md).

## Path B: Single Jira user story (Jira mode)

No PRD needed. The skill reads the Jira story and creates one board-visible Task per significant goal, each linked to the story (Jira Sub-tasks are avoided because they don't show on the board).

```
/sdd-tasks-from-story TT-456        Reads story, generates OpenSpec change,
        |                            creates linked Jira Tasks
        v
/sdd-work TT-457                    (same as Path A from here)
```

## Path C: Developer-driven (no PRD)

```
/openspec-propose "add order export" Generates proposal, specs, design, tasks
        |
        v
/sdd-create-tickets add-order-export Creates tickets from the tasks
        |
        v
/sdd-work <ticket-id>               (same as Path A from here)
```

## Path D: Staged greenfield (from PRD)

For large greenfield features that benefit from incremental delivery in ordered stages — see [prds.md § Staged greenfield](prds.md#staged-greenfield).

```
sdd/prds/my-app-v1.md              (PO writes this)
        |
        v
/sdd-staged my-app                  Analyzes PRD, proposes stages,
        |                            generates per-stage OpenSpec artifacts,
        |                            creates cross-referenced tickets
        v
/sdd-work <ticket-id>              Work tickets in stage order
        v
/sdd-verify
        v
/sdd-status                          Offers to archive each completed stage
```

## Developing a ticket

```
/sdd-work 42         # GitHub issue
/sdd-work TT-456     # Jira task (linked to a story)
```

`/sdd-work` self-detects whether to start Fresh, Resume in-flight work, or Fix-from-PR review feedback. On a fresh start it:

1. Reads the ticket (description, acceptance criteria, hints) and its comments, plus the parent story's
2. Checks whether blocking dependencies are still open
3. Detects the linked OpenSpec change and lazy-loads only the relevant spec and `design.md` section
4. Researches the codebase (related files, existing patterns)
5. Presents an implementation plan and waits for your approval
6. Creates a branch: `feat/42-add-login-form` or `feat/tt-456-add-login-form`
7. Implements following the constitution
8. Runs the quality gates from `sdd/constitution/quality-gates.md` (tests, static checks, build)
9. Commits with conventional commits: `feat(auth): add login form (#42)` or `feat(auth): add login form [TT-456]`
10. Verifies each acceptance criterion is met

Along the way it offers (opt-in) to post Decision / Blocker / Follow-up / Clarification comments back to the ticket — see [collaboration.md](collaboration.md#ticket-comments).

## Verifying and creating a PR

```
/sdd-verify
```

Checks acceptance criteria, runs the quality gates, performs the [code review](review-gates.md#code-review), checks off the ticket's own section in `tasks.md`, then pushes the branch and creates a PR. GitHub: the issue is closed when the PR opens. Jira: the PR body says `Resolves <KEY>` and the ticket moves to In Review; `/sdd-status` moves it to Done after merge. Merging is always a human decision.

## Completion

```
/sdd-status
```

After a change's tickets are merged, `/sdd-status` runs the [Completion Sweep](archiving.md): reconciles `tasks.md` against ticket statuses, archives the OpenSpec change, and closes the parent Jira story (Jira mode).

## Dry-run

All `sdd-*` skills except `/sdd-setup` accept `--dry-run`; the openspec-* skills do not. Reads always run; tracker writes are mocked with `[DRY RUN] would <op>(<args>)` lines and synthetic `DRY-N` ids for downstream wiring. Branch / push / PR creation skipped. `/sdd-work` halts after the plan — no code edits. Local OpenSpec artifacts are written (git-revertable); mapping and stage-map files and tasks.md annotations are only printed.
