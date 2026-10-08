# SDD Workflow

Spec-Driven Development workflow for any stack, powered by [Claude Code](https://claude.ai/claude-code) and [OpenSpec](https://github.com/Fission-AI/OpenSpec).

Automates the full pipeline: **PRD &rarr; specifications &rarr; tickets (GitHub or Jira) &rarr; AI-driven development &rarr; verified PRs**.

Supports three modes: **GitHub** (GitHub Issues + GitHub for code/PRs), **Jira** (Jira tickets + GitHub for code/PRs) and **Jira + Bitbucket** (Jira tickets + Bitbucket Cloud for code/PRs). Configured once via `sdd/config.json`.

## Prerequisites

| Tool | Install | Needed for |
|------|---------|------------|
| [Claude Code](https://claude.ai/claude-code) | `npm install -g @anthropic-ai/claude-code` | Everything |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | `npm install -g @fission-ai/openspec@latest` | Specification generation and archiving |
| [jq](https://jqlang.github.io/jq/) | `brew install jq` | The conventional-commit hook and the Bitbucket helper |
| [GitHub CLI](https://cli.github.com/) | `brew install gh` then `gh auth login` | GitHub tracker or GitHub git host |
| Jira MCP | Configured by `/sdd-setup` | Jira modes |
| Bitbucket API token | See [sdd/docs/trackers.md § Bitbucket auth](sdd/docs/trackers.md#bitbucket-auth) | Jira + Bitbucket mode |

Node/npm is needed only to install the Claude Code and OpenSpec CLIs, not for your project's own stack.

## Quick start

In a new project created from this repo:

```bash
/sdd-setup          # one-time: scaffolds sdd/, configures the tracker, wires up MCPs
/sdd-constitution   # one-time: your stack, coding standards and quality gates
/sdd-doctor         # pre-flight check, any time
```

Then pick an entry point from [sdd/README.md § Which entry point?](sdd/README.md#which-entry-point).

## Installing into an existing repo

**1. Copy the skills and the commit hook** from a local clone of this repo:

```bash
SRC=/path/to/sdd-workflow
cd /path/to/your-project

mkdir -p .claude/skills .claude/hooks
cp -R "$SRC"/.claude/skills/sdd-* "$SRC"/.claude/skills/openspec-* .claude/skills/
cp "$SRC"/.claude/hooks/validate-commit-msg.sh .claude/hooks/
```

You don't need to copy `sdd/` — `/sdd-setup` seeds it from its own bundle.

**2. Merge (don't overwrite)** into files your repo may already have:

| File | What to add |
|------|-------------|
| `.claude/settings.json` | The `PreToolUse` hook entry from [.claude/settings.json](.claude/settings.json). If you already have a `hooks.PreToolUse` array, append to it. |
| `CLAUDE.md` | The *Workflow Quick Reference*, *Review Gates*, *Git Conventions* and *Code Conventions* sections from [CLAUDE.md](CLAUDE.md). Keep your own project sections (commands, architecture, etc.). |
| `.gitignore` | `.claude/settings.local.json` |

`.mcp.json` needs no manual merge — `/sdd-setup` appends to it.

**3. Run setup** as in [Quick start](#quick-start). On an existing codebase `/sdd-constitution` detects your stack from build manifests, CI config and folder structure, and proposes quality gates from what CI runs on pull requests; review its proposal rather than writing standards from scratch. Then add your build/test/lint commands to the *Commands* section of your `CLAUDE.md`.

**Check before you start:**
- **Base branch** — `/sdd-setup` asks which branch feature PRs target (`develop` by default). If you're trunk-based, pick `main` and update the branching line in your `CLAUDE.md` to match.
- **Commit hook** — blocks commits *made by Claude* that don't follow conventional commits. Your own terminal commits are unaffected.

**Upgrading** — re-copy the skills (step 1), then re-run `/sdd-setup`. It only fills in missing `sdd/` files, so new guides and templates arrive without overwriting your edits.

## Documentation

[sdd/README.md](sdd/README.md) is the hub — modes, entry points, skill catalogue, folder layout. It ships into every project via `/sdd-setup`, together with these guides:

| Guide | Covers |
|-------|--------|
| [Workflow](sdd/docs/workflow.md) | The four paths, the work → verify → status loop, dry-run |
| [PRDs](sdd/docs/prds.md) | Writing PRDs, versioning, staged greenfield |
| [Review gates](sdd/docs/review-gates.md) | Design challenge, code review, constitution enforcement |
| [Collaboration](sdd/docs/collaboration.md) | Ticket comments, parallel developers, re-running planning skills |
| [Planning PRs](sdd/docs/planning-prs.md) | Committing planning artifacts in their own PR |
| [Archiving](sdd/docs/archiving.md) | Completion Sweep and the safe archiving procedure |
| [Interface contracts](sdd/docs/interface-contracts.md) | API / event contracts: where they live, precedence |
| [Trackers](sdd/docs/trackers.md) | Modes, `config.json`, Bitbucket auth |
| [Git conventions](sdd/docs/git-conventions.md) | Branches, commits, PRs |
| [Troubleshooting](sdd/docs/troubleshooting.md) | Common problems and fixes |

## Working on this repo

```
.claude/
  settings.json                      PreToolUse hook config
  hooks/validate-commit-msg.sh       conventional-commit enforcement
  skills/sdd-*/SKILL.md              SDD skills
  skills/openspec-*/SKILL.md         OpenSpec skills, SDD-customised
  skills/sdd-setup/references/seed/  copy of sdd/ shipped to new projects
sdd/                                 the workflow's own docs, templates and tracker adapters
openspec/                            living specs and in-flight changes
```

**Keep the seed in sync.** After editing anything under `sdd/docs/`, `sdd/templates/`, `sdd/trackers/`, or the top-level scaffold (`config.example.json`, `README.md`, `prd-template*.md`), run:

```bash
bash sdd/scripts/sync-seed.sh
```

Idempotent. Keeps the `/sdd-setup` seed bundle up to date so a fresh project gets the latest.

**Adding a skill.** Create `.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `disable-model-invocation: true`); the markdown body holds the instructions Claude follows when invoked.
