# Committing planning artifacts

Planning skills write files every developer needs on the base branch: `openspec/changes/<change>/`, `sdd/tasks/<change>.md` (and `<feature>-stages.md`), and the PRD under `sdd/prds/` when it is new. Left uncommitted, they get swept into unrelated feature PRs. At the end of `/sdd-from-prd`, `/sdd-staged`, `/sdd-tasks-from-story` and `/sdd-create-tickets`, the skill offers (AskUserQuestion) to ship them in their own PR:

1. Note the current branch, then `CreateBranch(docs/plan-<change>, <base>)` — uncommitted planning files carry over.
2. `git add` the planning paths explicitly (never `-A` or `.`) and commit `docs(sdd): plan <change>` (append the story ref when there is one).
3. `PushBranch`, then `CreatePR` with the base branch as target and the list of planned tickets as the body.
4. Check out the original branch again.

Merge the planning PR before starting work items, so feature branches build on the committed plan. `/sdd-status` offers the same after a sweep that archived changes or regenerated `tasks.md`, on `chore/sdd-sweep-<YYYY-MM-DD>` with `chore(sdd): archive completed changes`. Under `--dry-run`, print the branch, paths and commit message instead.
