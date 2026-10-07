# SDD Workflow

Spec-Driven Development workflow for a frontend team, powered by [Claude Code](https://claude.ai/claude-code) and [OpenSpec](https://github.com/Fission-AI/OpenSpec).

Automates the full pipeline: **PRD &rarr; specifications &rarr; tickets (GitHub or Jira) &rarr; AI-driven development &rarr; verified PRs**.

Supports two tracker modes: **GitHub** (GitHub Issues + GitHub for code/PRs) and **Jira** (Jira tickets + GitHub for code/PRs). Configured once via `sdd/config.json`.

## Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| [Claude Code](https://claude.ai/claude-code) | `npm install -g @anthropic-ai/claude-code` | AI coding agent with skills and hooks |
| [GitHub CLI](https://cli.github.com/) | `brew install gh` then `gh auth login` | Issue creation, PR management (GitHub mode) |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | `npm install -g @fission-ai/openspec@latest` | Specification generation and management |
| [jq](https://jqlang.github.io/jq/) | `brew install jq` | Used by the conventional-commit hook |
| Jira MCP (optional) | Configure via `/sdd-setup` | Jira story and linked-task management (Jira mode) |

## Quick Start

```bash
# Clone and enter the project
git clone <repo-url>
cd my-project

# One-time bootstrapping: sets up sdd/, configures tracker, wires up MCPs
/sdd-setup

# Define your project's coding standards (one-time setup)
/sdd-constitution

# Run a pre-flight check before starting work
/sdd-doctor
```

Adding the workflow to a codebase you already have? See [Installing into an Existing Repo](#installing-into-an-existing-repo).

## Installing into an Existing Repo

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

**3. Run setup** — `/sdd-setup`, `/sdd-constitution`, `/sdd-doctor`, as in [Quick Start](#quick-start). On an existing codebase `/sdd-constitution` detects your stack from `package.json`, build configs and folder structure; review its proposal rather than writing standards from scratch.

**Check before you start:**
- **Base branch** — `/sdd-setup` asks which branch feature PRs target (`develop` by default). If you're trunk-based, pick `main` and update the branching line in your `CLAUDE.md` to match.
- **Commit hook** — blocks commits *made by Claude* that don't follow conventional commits. Your own terminal commits are unaffected. Requires `jq`.

## Project Setup

### 1. Bootstrap with `/sdd-setup`

Run `/sdd-setup` once to initialise the `sdd/` directory, run `openspec init`, configure your tracker (GitHub or Jira), and wire up any required MCPs. It is idempotent — safe to re-run.

The setup wizard will:
1. **Detect** whether GitHub CLI and/or a Jira MCP are available
2. **Ask** which tracker mode to use (GitHub / Jira)
3. **Write** `sdd/config.json` with your tracker settings (tracker, vcs, base branch, Jira project key, status workflow, linked-task types)
4. **Copy** seed files into `sdd/` (templates, tracker adapters, PRD templates)

### 2. Define coding standards with `/sdd-constitution`

Run `/sdd-constitution` to create split constitution files in `sdd/constitution/`. These capture your tech stack, coding principles, folder structure, and quality gates. SDD skills load only the section files they need.

Once ratified, the constitution is automatically enforced by the SDD skills:

| Skill | How it uses the constitution |
|-------|------------------------------|
| `/sdd-from-prd` | Generates specs, design, and tasks aligned with your stack and patterns |
| `/sdd-staged` | Same as above + drives stage-01 setup tasks from the constitution's tech stack |
| `/sdd-work` | Follows principles during implementation (correct libraries, file locations, patterns) |
| `/sdd-verify` | Adds "Constitution compliance" as a code review category — NON-NEGOTIABLE violations are flagged as blocker recommendations (user decides); RECOMMENDED deviations are advisory |

To update the constitution later, run `/sdd-constitution` again.

### 3. Pre-flight check with `/sdd-doctor`

Run `/sdd-doctor` any time to verify your environment: checks that `sdd/config.json` is valid, the selected tracker is reachable, required tools are installed, and OpenSpec is initialised.

## Workflow Overview

There are four entry points depending on context:

### Path A: PO hands off a PRD (single feature)

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

v2+ increments: `sdd/prds/<feature>-v2-<scope>.md` (mini template) → `/sdd-from-prd <feature>-v2-<scope>`.

### Path B: Single Jira user story (Jira mode)

No PRD needed. The skill reads the Jira story and creates one board-visible Task per significant goal, each linked to the story.

```
/sdd-tasks-from-story TT-456        Reads story, generates OpenSpec change,
        |                            creates linked Jira Tasks
        v
/sdd-work TT-457                    (same as Path A from here)
        v
/sdd-verify
        v
/sdd-status
```

### Path C: Developer-driven (no PRD)

```
/openspec-propose "add dark mode"    Generates proposal, specs, design, tasks
        |
        v
/sdd-create-tickets add-dark-mode   Creates tickets from the tasks
        |
        v
/sdd-work <ticket-id>               (same as Path A from here)
```

### Path D: Staged greenfield (from PRD)

For large greenfield features that benefit from incremental delivery in ordered stages.

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

## Commands Reference

### SDD Commands (custom skills)

| Command | Input | What it does |
|---------|-------|-------------|
| `/sdd-setup` | — | One-time bootstrap: initialises `sdd/`, runs `openspec init`, configures tracker (GitHub or Jira), wires up MCPs. Idempotent. |
| `/sdd-doctor` | — | Pre-flight check: validates `sdd/config.json`, tracker connectivity, required tools, and OpenSpec state. |
| `/sdd-constitution [name]` | Optional project name | Interactive setup: detects codebase signals, interviews for stack/conventions/quality gates, generates split files in `sdd/constitution/`. |
| `/sdd-from-prd <feature>` | Feature name matching a file in `sdd/prds/` | Full pipeline: reads PRD and constitution, generates OpenSpec specs, runs a design challenge, then creates tickets. |
| `/sdd-create-tickets <change>` | OpenSpec change name | Reads OpenSpec artifacts, creates tickets with GIVEN-WHEN-THEN acceptance criteria, updates task file with ticket IDs. |
| `/sdd-tasks-from-story <JIRA-KEY>` | Jira story key | Reads Jira story, generates an OpenSpec change, creates one board-visible Task per significant goal, each linked back to the story. (Jira mode only.) |
| `/sdd-work <ticket-id>` | GitHub issue number or Jira key | Fetches the ticket, reads constitution and linked OpenSpec change for context, researches the codebase, presents an implementation plan for approval, creates a feature branch, implements, commits. |
| `/sdd-staged <feature>` | Feature slug (PRD at `sdd/prds/<feature>-v1.md`) | Staged pipeline: reads PRD and constitution, proposes stages, generates per-stage OpenSpec specs, runs a design challenge, creates cross-referenced tickets. |
| `/sdd-verify [ticket-id]` | Optional ticket ID (auto-detected from branch) | Checks acceptance criteria, runs tests/lint/build, performs a code review, then creates a PR. |
| `/sdd-status [--dry-run]` | — | Completion sweep: syncs ticket statuses into `tasks.md`, archives completed changes, closes parent tickets. |

All `sdd-*` skills except `/sdd-setup` accept `--dry-run` for previewing without committing; the openspec-* skills do not.

### OpenSpec Commands (OpenSpec skills, SDD-customised)

| Command | Input | What it does |
|---------|-------|-------------|
| `/openspec-propose <description>` | Feature description | Generates all OpenSpec artifacts: proposal.md, specs/ (GIVEN-WHEN-THEN), design.md, tasks.md. |
| `/openspec-apply-change [change]` | Optional change name | Implements tasks directly from OpenSpec (alternative to the ticket flow). |
| `/openspec-archive-change [change]` | Optional change name | Archives the completed change via `openspec archive`, updating living specs in `openspec/specs/`. |
| `/openspec-explore [change]` | Optional change name | Explore and understand an existing change's artifacts. |

## Review Gates

The workflow has two built-in review gates:

### Design Challenge

Runs automatically in `/sdd-from-prd`, `/sdd-staged`, and `/sdd-tasks-from-story` — after artifacts are generated but before tickets are created. Surfaces:
- Key assumptions the design makes
- Risks and pitfalls (over-engineering, edge cases, security, performance)
- Simplification opportunities
- Open questions that should be answered first

Template: `sdd/templates/design-challenge.md`

### Code Review

Runs automatically in `/sdd-verify` after acceptance criteria and CI checks. Evaluates:
- **Pattern consistency**: does the code match existing codebase conventions?
- **Security**: XSS, injection, exposed secrets, auth gaps
- **Performance**: unnecessary re-renders, missing memoisation, N+1 fetches
- **Error handling**: system boundaries covered, error states in UI
- **Design alignment**: matches `design.md` if an OpenSpec change is linked
- **Constitution compliance**: NON-NEGOTIABLE violations are flagged as blocker recommendations (user decides); RECOMMENDED deviations are advisory

Checklist: `sdd/templates/code-review-checklist.md`

## Tracker Configuration

`sdd/config.json` (created by `/sdd-setup`, committed; contains no secrets) controls which tracker is active. See `sdd/config.example.json` for the full shape.

Tracker adapters: `sdd/trackers/protocol.md`, `sdd/trackers/github.md`, `sdd/trackers/jira.md`.

## Detailed Usage

### Writing a PRD

Copy the template and fill it in:

```bash
cp sdd/prd-template.md sdd/prds/my-feature-v1.md
```

For v2+ increments (adding to an existing feature), use the mini template:

```bash
cp sdd/prd-template-mini.md sdd/prds/my-feature-v2-scope.md
```

The PRD template sections:

| Section | Purpose | Used for |
|---------|---------|----------|
| **Problem Statement** | What and why (2-3 sentences) | OpenSpec proposal.md |
| **Goals** | Measurable success criteria | Objectives and scope |
| **Non-Goals** | Explicitly out of scope | Prevents AI scope creep |
| **User Stories** | As a..., I want..., so that... | GIVEN-WHEN-THEN specs and task generation |
| **UI/UX Notes** | Wireframes, mockups, descriptions | Design decisions |
| **Technical Considerations** | Constraints, integrations | Implementation hints |
| **Dependencies** | External services, APIs | Blocking issues |
| **API Contract** | Swagger/OpenAPI file path or URL (optional) | API-enriched specs, design, and tasks |
| **Open Questions** | Unresolved items | Flagged before spec generation |

### Adding a Backend API Contract (optional)

Reference the Swagger/OpenAPI spec in the PRD's **API Contract** section:

```markdown
## API Contract
sdd/apis/user-auth.yaml
# or
https://api.example.com/docs/openapi.yaml
```

When `/sdd-from-prd` runs, it will enrich generated specs with endpoint-specific GIVEN-WHEN-THEN scenarios, add API integration sections to `design.md`, and include API integration tasks in `tasks.md`.

### Staged Greenfield Development

Use `/sdd-staged` for large greenfield features (3+ user stories, or projects needing foundational setup before feature work). Use `/sdd-from-prd` for single features or increments on existing codebases.

Stage naming convention: `<feature>-NN-<slug>` (e.g. `my-app-01-setup`, `my-app-02-scaffold`, `my-app-03-auth-flow`).

**Recommended frontend stage patterns:**

| Stage | Typical content |
|-------|----------------|
| `01-setup` | Project init, tooling, linting, CI, dependencies |
| `02-scaffold` | App shell, routing, layout, shared components, state management skeleton |
| `03-xx` onwards | Feature areas grouped by functional domain |

### Developing a Ticket

```
/sdd-work 42         # GitHub issue
/sdd-work TT-456     # Jira task (linked to a story)
```

The agent will:
1. Read the ticket (description, acceptance criteria, hints)
2. Check if blocking dependencies are still open
3. Detect the linked OpenSpec change and read proposal, design, and spec artifacts
4. Research the codebase (find related files, existing patterns)
5. Present an implementation plan and wait for your approval
6. Create a branch: `feat/42-add-login-form` or `feat/tt-456-add-login-form`
7. Implement following constitution principles
8. Run tests, lint, build (if configured)
9. Commit with conventional commits: `feat(auth): add login form (#42)` or `feat(auth): add login form [TT-456]`
10. Verify each acceptance criterion is met

### Verifying and Creating a PR

```
/sdd-verify
```

The agent checks acceptance criteria, runs CI, performs the code review, then — if everything passes — pushes the branch and creates a PR. GitHub: the issue is closed when the PR opens. Jira: the PR body says `Resolves <KEY>` and the ticket moves to In Review; `/sdd-status` moves it to Done after merge.

### Completion and Archiving

```
/sdd-status
```

After all tickets for a change are merged, run `/sdd-status` to reconcile `tasks.md` against authoritative ticket statuses (`/sdd-verify` already checked off each work item's own section inside its PR), archive the OpenSpec change, and close the parent Jira story (Jira mode).

## Project Structure

```
sdd-workflow/
|-- CLAUDE.md                              # AI context: conventions, workflow, file locations
|-- README.md                              # This file
|-- .gitignore
|
|-- .claude/
|   |-- settings.json                      # Hook config (conventional commit enforcement)
|   |-- hooks/
|   |   +-- validate-commit-msg.sh         # Blocks non-conventional commit messages
|   +-- skills/
|       |-- sdd-setup/SKILL.md             # /sdd-setup      One-time bootstrap
|       |-- sdd-doctor/SKILL.md            # /sdd-doctor     Pre-flight environment check
|       |-- sdd-constitution/SKILL.md      # /sdd-constitution  Define project coding standards
|       |-- sdd-staged/SKILL.md            # /sdd-staged     PRD -> stages -> specs -> tickets
|       |-- sdd-from-prd/SKILL.md          # /sdd-from-prd   PRD -> specs -> tickets
|       |-- sdd-create-tickets/SKILL.md    # /sdd-create-tickets  OpenSpec -> tickets
|       |-- sdd-tasks-from-story/SKILL.md  # /sdd-tasks-from-story  Jira story -> linked Tasks
|       |-- sdd-work/SKILL.md              # /sdd-work       Implement a ticket
|       |-- sdd-verify/SKILL.md            # /sdd-verify     Verify + create PR
|       |-- sdd-status/SKILL.md            # /sdd-status     Completion sweep + archive
|       |-- openspec-propose/SKILL.md      # OpenSpec: generate specs from description
|       |-- openspec-apply-change/SKILL.md # OpenSpec: implement tasks directly
|       |-- openspec-archive-change/SKILL.md # OpenSpec: archive completed changes
|       +-- openspec-explore/SKILL.md      # OpenSpec: explore change artifacts
|
|-- sdd/
|   |-- README.md                          # Canonical SDD reference (layout, modes, decision tree)
|   |-- config.example.json               # Tracker config template (commit this)
|   |-- config.json                        # Live tracker config
|   |-- prd-template.md                   # PRD template for the PO (greenfield / v1)
|   |-- prd-template-mini.md              # Mini PRD template for v2+ increments
|   |-- constitution/                      # Project coding standards (generated by /sdd-constitution)
|   |   +-- .gitkeep
|   |-- prds/                              # PRD files go here
|   |   +-- .gitkeep
|   |-- tasks/                             # Ticket mapping files (commit — /sdd-status reads them)
|   |   +-- .gitkeep
|   |-- apis/                              # Swagger/OpenAPI source files (optional)
|   |   +-- .gitkeep
|   |-- templates/                         # Workflow templates (design-challenge, code-review, etc.)
|   +-- trackers/                          # Tracker protocol + GitHub and Jira adapters
|
|-- openspec/
|   |-- specs/                             # Living domain specs (grows over time)
|   +-- changes/                           # Active changes (proposal, specs, design, tasks)
|       +-- archive/                       # Completed and archived changes
```

## Git Conventions

### Branches

Format: `<type>/<ticket-id-slug>-<short-description>`

Examples:
- `feat/42-add-login-form` (GitHub)
- `feat/tt-456-add-login-form` (Jira)
- `fix/57-broken-redirect`

### Commits

Format: `type(scope): description (#issue)` or `type(scope): description [JIRA-KEY]`

| Type | When to use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code restructuring, no behaviour change |
| `test` | Adding or updating tests |
| `chore` | Build, tooling, dependencies |
| `build` | Build system changes |
| `ci` | CI/CD pipeline changes |

A **PreToolUse hook** automatically blocks commits that don't follow this format.

### Branching Strategy

Feature branches are cut from `develop` and merged back to `develop` via PR. Only `develop` → `main` merges happen on releases.

### Pull Requests

- Title follows conventional commit format
- Body includes: Summary, Changes, Acceptance Criteria (all checked), Testing notes
- GitHub: issue closed when the PR opens. Jira: `Resolves <KEY>`, moved to In Review; `/sdd-status` moves it to Done after merge
- Merging is always a human decision

## Customisation

### Adapting for your project

1. **Run `/sdd-setup`** to initialise `sdd/` and configure your tracker.
2. **Run `/sdd-constitution`** to define your tech stack, coding standards, and quality gates.
3. **Update `CLAUDE.md`** — add your project-specific build/test/lint commands in the Commands section.

### Adding new skills

Create a new directory under `.claude/skills/`:

```
.claude/skills/my-skill/
  SKILL.md
```

The `SKILL.md` needs YAML frontmatter with `name`, `description`, and `disable-model-invocation: true`. The markdown body contains the instructions Claude follows when invoked.

### Modifying the commit hook

Edit `.claude/hooks/validate-commit-msg.sh` to change the allowed commit types or format.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh: command not found` | Install GitHub CLI: `brew install gh` then `gh auth login` |
| `openspec: command not found` | Install OpenSpec: `npm install -g @fission-ai/openspec@latest` |
| Skills don't appear as slash commands | Restart Claude Code. Skills are discovered on startup. |
| Commit blocked by hook | Your commit message doesn't follow conventional commits. Use `type(scope): description` format. |
| `/sdd-doctor` reports tracker unreachable | Check `sdd/config.json` credentials and that the relevant MCP is running. |
| `/sdd-create-tickets` says "no tasks.md" | Run `/openspec-propose` or `/sdd-from-prd` first to generate the specs. |
| `/sdd-work` warns about open dependencies | A blocking ticket hasn't been closed yet. Close it or proceed with caution. |
| `/sdd-verify` reports FAIL on criteria | Fix the failing criteria before the PR can be created. |
| `/sdd-staged` suggests using `/sdd-from-prd` | Your PRD is too small for staging. Use `/sdd-from-prd` or override if you still want stages. |
| `/sdd-tasks-from-story` not available | Requires Jira tracker mode. Check `sdd/config.json`. |
