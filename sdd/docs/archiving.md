# Completion Sweep and archiving

## Completion Sweep

Post-merge, run `/sdd-status`. It walks active changes and offers (with prompts):

- **Class A** — archive changes with all tickets done (via the procedure below).
- **Class B** — close parent stories with all linked work items done (status transition + Closing Summary comment).
- **Class C** — reconcile `tasks.md` checkboxes against ticket statuses (backstop for drift; `/sdd-verify` does the primary per-section flip). Always safe; offered separately.

If the sweep wrote files, it offers to commit them in a [planning PR](planning-prs.md).

## Archiving procedure

`openspec archive` is not transactional: when one capability fails validation after others were already written, those writes stay in `openspec/specs/`, the CLI may still print "No files were changed" and exit 0, and a retry then fails with "ADDED already exists". Both archive paths (`/openspec-archive-change` step 5 and `/sdd-status` Class A) run this procedure per change instead of calling the CLI bare:

1. **Pre-flight (read-only).** For each `openspec/changes/<name>/specs/<cap>/` whose living spec `openspec/specs/<cap>/spec.md` exists, run `openspec validate <cap> --type spec --no-interactive`. Also confirm `openspec/changes/archive/<YYYY-MM-DD>-<name>/` does not exist yet. On any failure, report it and do not archive. A failing living spec needs `## Purpose` plus `## Requirements` with `### Requirement:` blocks and no `ADDED`/`MODIFIED`/`REMOVED`/`RENAMED` headers — the user repairs it; never repair it automatically.
2. **Snapshot.** Copy `openspec/specs/` to a temp dir (`SNAP=$(mktemp -d) && cp -R openspec/specs "$SNAP/"`). Skip when archiving with `--skip-specs`.
3. **Archive.** `openspec archive <name> --yes [--skip-specs]`.
4. **Judge success on disk**, not by exit code or output text: `openspec/changes/<name>/` is gone and the archive dir exists. On failure, restore the snapshot wholesale (`rm -rf openspec/specs && cp -R "$SNAP/specs" openspec/specs`), which also removes capability dirs the failed run created. Show the CLI output verbatim.
5. **Mapping.** Only after step 4 confirms success, rename `sdd/tasks/<name>.md` to `sdd/tasks/<name>.archived.md`.

Under `--dry-run`, run step 1 only and print `[DRY RUN] would archive <name>` or `[DRY RUN] would skip <name>: <reason>`.
