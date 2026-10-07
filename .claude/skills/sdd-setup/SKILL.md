---
name: sdd-setup
description: Bootstrap a project's SDD workflow — scaffold sdd/, run openspec init, configure tracker (GitHub or Jira), wire up MCPs, and offer to chain into /sdd-constitution. Idempotent, safe to re-run.
disable-model-invocation: true
---

# SDD Setup

You are bootstrapping (or reconfiguring) the SDD workflow for this project. This is the **single entry point** — it detects what's missing, asks the user for choices, and sets up the rest.

This skill is **idempotent**. Re-running on an already-configured project detects existing pieces and only asks about gaps.

## Phase 1: Detect Current State

Walk through these checks and build a `state` summary. Don't act yet.

| Check | Path / command | Marker |
|-------|----------------|--------|
| sdd folder | `sdd/` | dir exists? |
| sdd config | `sdd/config.json` | file exists? |
| sdd config — tracker | `sdd/config.json` `.tracker` | value present? |
| Constitution (split) | `sdd/constitution/index.md` | file exists? |
| Constitution (legacy) | `docs/constitution.md` | file exists? |
| PRD template | `sdd/prd-template.md` | file exists? |
| Tracker recipes + shared templates | every `.claude/skills/sdd-setup/references/seed/{trackers,templates}/*.md` has a counterpart under `sdd/` | files exist? |
| OpenSpec | `openspec/specs/` | dir exists? |
| GitHub auth | `gh auth status` | exit code 0? |
| Atlassian Rovo MCP | a quick test call | authed? |
| `.mcp.json` | `.mcp.json` | file exists? |
| Git remote | `git remote -v` | has any remote? |

Present the findings in a checklist (✓ configured, ✗ missing, ? unknown).

## Phase 2: Bootstrap Missing Pieces

For each missing piece, ask the user before acting. Run them in this order:

### 2.1 Create `sdd/` folder hierarchy

Always run (no-clobber; fills in any missing files):

```bash
mkdir -p sdd/{constitution,prds,apis,tasks,trackers,templates}
```

Then copy seed files from this skill's bundle to `sdd/`:

```bash
SEED=".claude/skills/sdd-setup/references/seed"
cp -n "$SEED/README.md" sdd/README.md
cp -n "$SEED/config.example.json" sdd/config.example.json
cp -n "$SEED/prd-template.md" sdd/prd-template.md
cp -n "$SEED/prd-template-mini.md" sdd/prd-template-mini.md
cp -n "$SEED/trackers/"*.md sdd/trackers/
cp -n "$SEED/templates/"*.md sdd/templates/
```

`cp -n` skips overwrite — only fills in genuinely missing files.

### 2.2 Initial config.json

Do not create `sdd/config.json` here; write it at the end of 2.4 from the answers, using `config.example.json` only as the shape.

### 2.3 Run `openspec init`

If `openspec/specs/` is missing (`[ -d openspec/specs ]` fails):

```bash
openspec init --tools none
```

`--tools none` creates `openspec/{specs,changes}` without regenerating the SDD-customised `.claude/skills/openspec-*` skills.

If `openspec` is not on the PATH, tell the user to install it (`npm install -g @fission-ai/openspec@latest`) and skip this step. The rest of setup still works; OpenSpec can be initialised later.

### 2.4 Tracker Selection

Use AskUserQuestion to ask which tracker:

- **GitHub** — tickets and code in GitHub. Default for most projects.
- **Jira** — tickets in Jira, code and PRs in GitHub. Use when product management is in Jira.

#### GitHub branch

1. Verify auth:
   ```bash
   gh auth status
   ```
   If this fails, tell the user to run `gh auth login` and pause this phase until they confirm.

2. Determine the default base branch. Ask:
   - "What base branch should feature PRs target? (`develop` recommended; some projects use `main`)"
   - Default: check `git branch -a` for `develop` first, then `main`. Pre-fill the answer.

3. Write `sdd/config.json`:
   ```json
   {
     "tracker": "github",
     "vcs": "github",
     "github": {
       "default_base_branch": "<answer>"
     }
   }
   ```

#### Jira branch

1. Verify `gh auth status` (PRs always go through GitHub); if it fails, tell the user to run `gh auth login`. Then, if the Atlassian Rovo MCP is unauthenticated, trigger its `authenticate` tool (or `complete_authentication` if a flow is already in progress).

2. Once auth completes, list accessible Jira sites (`getAccessibleAtlassianResources`) and projects (`getVisibleJiraProjects`). Present them to the user. Ask them to confirm which site (e.g. `your-org.atlassian.net`) and which project key (e.g. `TT`).

3. Try to discover the OpenSpec "Source" custom-field id by listing custom fields on the chosen project. If exactly one field name matches `Source` or `OpenSpec`, use it. Otherwise present the candidates and ask the user. If none exist, ask whether the user wants to create one (Jira admin permissions required) — if not, leave `source_field` as `null` and skills will fall back to a description footer.

4. Discover the Jira workflow **target status names** for In Progress / In Review / Done (`status_workflow` values are status names, not transition names; skills pick the transition whose `to.name` matches). List the statuses available for the project's default issue type. Ask the user to confirm the mapping; pre-fill with the names returned by Jira.

5. Configure the **linked-task model** keys (`/sdd-tasks-from-story` creates one board-visible Task per goal, linked to the story — never hidden Sub-tasks):
   - `child_issue_type`: list the project's issue types (`getJiraProjectIssueTypesMetadata`) and pick a non-subtask, hierarchy-level-0 type — `Task` if present. Confirm with the user.
   - `child_link_type`: list available link types (`getIssueLinkTypes`) and prefer a decomposition-style link in this order: `Work item split` (`split to`/`split from`) → `Relates`. Confirm with the user, defaulting to the first match found.

6. Write `sdd/config.json` with the Jira section (including `child_issue_type` and `child_link_type`), plus `vcs: "github"` and the GitHub `default_base_branch` answer (still ask for it — even Jira-tracker projects use GitHub for code).

### 2.5 MCP Wiring

For each MCP, ask the user (multi-select via AskUserQuestion):

- **Atlassian Rovo MCP** — required if tracker is Jira. Pre-select.
- **Playwright MCP** — optional. Useful for `/sdd-verify` to do live UI verification on frontend projects.
- **Context7 MCP** — optional. Useful for fetching framework docs during implementation.

For each selected MCP, append the MCP server entry to `.mcp.json` (creating the file if it doesn't exist). Use the official server config for each MCP. Then update `sdd/config.json` `mcps_enabled` accordingly.

Skip recommending the `code-review` plugin: prior session noted it consumed roughly half a session's allowance for one PR, and the inline review in `/sdd-verify` covers the same ground.

### 2.6 Constitution

Check `sdd/constitution/index.md`:

- If present, skip — the constitution is already in place.
- If absent but `docs/constitution.md` exists (legacy), tell the user the existing constitution will be migrated next time they run `/sdd-constitution`. Skills will fall back to the legacy file in the meantime.
- If neither exists, ask: "Project standards (constitution) are missing. Run `/sdd-constitution` now to create them?" If yes, exit setup with a hand-off message; the user runs `/sdd-constitution` next.

## Phase 3: Final Summary

Print a concise summary table:

```
## SDD Setup Complete

| Component | Status |
|-----------|--------|
| sdd/ folder | ✓ created (or ✓ already present) |
| sdd/config.json | ✓ written |
| Tracker | ✓ <tracker> ([details]) |
| MCPs | ✓ <list> |
| OpenSpec | ✓ initialised (or ⚠ pending — install openspec) |
| Constitution | ✓ present (or ⚠ pending — run /sdd-constitution) |

Next steps:
- (if no constitution) Run /sdd-constitution to define project standards.
- Otherwise: write a PRD at sdd/prds/<feature>-v1.md and run /sdd-from-prd <feature>-v1.
```

## Rules

- This skill is idempotent. Re-running must NOT clobber existing answers — read current `sdd/config.json` and only ask about fields that are missing or that the user explicitly wants to change.
- Never write secrets (API tokens, passwords) into `sdd/config.json`. The Atlassian MCP handles its own credentials.
- Never overwrite a non-empty `sdd/config.json` without confirming.
- Never install MCPs the user did not select.
- For brand-new projects with no git remote: ask the user to add one first if the chosen tracker is GitHub. Jira-tracker projects can proceed without a remote (PRs come later).
- If the user aborts mid-setup, leave the partial state in place — they can re-run to continue.
