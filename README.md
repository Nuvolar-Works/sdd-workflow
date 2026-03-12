# SDD Workflow

Spec-Driven Development workflow for a frontend team, powered by [Claude Code](https://claude.ai/claude-code) and [OpenSpec](https://github.com/Fission-AI/OpenSpec).

Automates the full pipeline: **PRD &rarr; specifications &rarr; GitHub issues &rarr; AI-driven development &rarr; verified PRs**.

## Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| [Claude Code](https://claude.ai/claude-code) | `npm install -g @anthropic-ai/claude-code` | AI coding agent with skills and hooks |
| [GitHub CLI](https://cli.github.com/) | `brew install gh` then `gh auth login` | Issue creation, PR management |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | `npm install -g @fission-ai/openspec@latest` | Specification generation and management |

## Quick Start

```bash
# Clone and enter the project
git clone <repo-url>
cd sdd-workflow

# Initialize OpenSpec (if not already done)
npx @fission-ai/openspec@latest init

# Start Claude Code
claude

# Define your project's coding standards (one-time setup)
/sdd-constitution
```

## Project Setup

Before starting any workflow, define your project's coding standards by running:

```
/sdd-constitution
```

This creates `docs/constitution.md` — a single document that captures your tech stack, coding principles, folder structure, and quality gates. The skill will:

1. **Detect** existing project signals (package.json, tsconfig, linting configs, folder structure)
2. **Interview** you in batches for stack choices, conventions, and quality rules
3. **Generate** a constitution with numbered principles (marked NON-NEGOTIABLE or RECOMMENDED)
4. **Present** it for your review and approval before writing

Once ratified, the constitution is automatically enforced by all SDD and OpenSpec skills:

| Skill | How it uses the constitution |
|-------|------------------------------|
| `/sdd-from-prd` | Generates specs, design, and tasks aligned with your stack and patterns |
| `/sdd-staged` | Same as above + drives stage-01 setup tasks from the constitution's tech stack |
| `/opsx:propose` | Applies stack and convention constraints to all generated artifacts |
| `/sdd-work` | Follows principles during implementation (correct libraries, file locations, patterns) |
| `/sdd-verify` | Adds "Constitution compliance" as a code review category — NON-NEGOTIABLE violations block, RECOMMENDED deviations are advisory |

To update the constitution later, run `/sdd-constitution` again. Changes are tracked via a Sync Impact Report and semantic versioning in the document header.

## Workflow Overview

There are three entry points depending on the project context:

### Path A: PO hands off a PRD

The Product Owner writes a PRD using the template, and a developer runs one command to generate specs and GitHub issues.

```
docs/prds/user-auth.md          (PO writes this)
        |
        v
/sdd-from-prd user-auth          Reads PRD, generates OpenSpec artifacts,
        |                         creates GitHub issues
        v
/sdd-work 42                     Picks up issue #42, researches codebase,
        |                         creates branch, implements, commits
        v
/sdd-verify                       Checks acceptance criteria, runs tests,
        |                         pushes branch, creates PR
        v
/opsx:archive                     Archives the change, updates living specs
```

### Path B: Developer-driven (no PRD)

A developer describes what they want to build directly to Claude.

```
/opsx:propose "add dark mode"     Generates proposal, specs, design, tasks
        |
        v
/sdd-create-tickets add-dark-mode Creates GitHub issues from the tasks
        |
        v
/sdd-work 42                     (same as Path A from here)
        v
/sdd-verify
        v
/opsx:archive
```

### Path C: Staged greenfield (from PRD)

For large greenfield features that benefit from incremental delivery in ordered stages (setup, scaffold, then feature work).

```
docs/prds/my-app.md              (PO writes this)
        |
        v
/sdd-staged my-app                Analyzes PRD, proposes stages,
        |                         generates per-stage OpenSpec artifacts,
        |                         creates cross-referenced GitHub issues
        v
/sdd-work 42                     Work issues in stage order
        |                         (stage 01 first, then 02, etc.)
        v
/sdd-verify
        v
/opsx:archive my-app-01-setup    Archive each completed stage
```

## Commands Reference

### SDD Commands (custom skills)

| Command | Input | What it does |
|---------|-------|-------------|
| `/sdd-constitution [name]` | Optional project name | Interactive setup: detects codebase signals, interviews for stack/conventions/quality gates, generates `docs/constitution.md`. All other skills read this file automatically. |
| `/sdd-from-prd <feature>` | Feature name matching a file in `docs/prds/` | Full pipeline: reads PRD and constitution, generates OpenSpec specs, runs a design challenge, then creates GitHub issues. |
| `/sdd-create-tickets <change>` | OpenSpec change name | Reads OpenSpec artifacts from `openspec/changes/<change>/`, creates GitHub issues with GIVEN-WHEN-THEN acceptance criteria, updates task file with issue numbers. |
| `/sdd-work <issue#>` | GitHub issue number | Fetches the issue, reads constitution and linked OpenSpec change for context (design, specs, stage awareness), researches the codebase, presents an implementation plan for approval, creates a feature branch, implements following constitution principles, commits with conventional commits, marks task complete in OpenSpec. |
| `/sdd-staged <feature>` | Feature name matching a file in `docs/prds/` | Staged pipeline: reads PRD and constitution, proposes stages, generates per-stage OpenSpec specs, runs a design challenge across all stages, then creates cross-referenced GitHub issues. |
| `/sdd-verify [issue#]` | Optional issue number (auto-detected from branch) | Checks acceptance criteria, runs tests/lint/build, performs a code review (patterns, security, performance, error handling, design alignment, constitution compliance), then creates a PR with `Closes #<issue>`. |

### OpenSpec Commands (bundled with OpenSpec)

| Command | Input | What it does |
|---------|-------|-------------|
| `/opsx:propose <description>` | Feature description or change name | Generates all OpenSpec artifacts: proposal.md, specs/ (GIVEN-WHEN-THEN), design.md, tasks.md. Includes a design challenge before declaring ready. |
| `/opsx:apply [change]` | Optional change name | Implements tasks directly from OpenSpec (alternative to the GitHub issue flow). |
| `/opsx:archive [change]` | Optional change name | Moves completed change to archive, updates living specs in `openspec/specs/`. |
| `/opsx:explore [change]` | Optional change name | Explore and understand an existing change's artifacts. |

## Detailed Usage

### 1. Writing a PRD

Copy the template and fill it in:

```bash
cp docs/prd-template.md docs/prds/my-feature.md
```

The PRD template has these sections:

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

### 1b. Adding a Backend API Contract (optional)

If the feature integrates with a backend API, reference the Swagger/OpenAPI spec in the PRD's **API Contract** section. You can provide either:

- **A local file** — drop the Swagger file in `docs/apis/` and reference the path:
  ```markdown
  ## API Contract
  docs/apis/user-auth.yaml
  ```

- **A URL** — point to a hosted Swagger endpoint:
  ```markdown
  ## API Contract
  https://api.example.com/docs/openapi.yaml
  ```

When `/sdd-from-prd` runs, it will:
1. Read or fetch the Swagger doc
2. Copy it into the change folder as `openspec/changes/<name>/api-contract.yaml`
3. Enrich generated specs with endpoint-specific GIVEN-WHEN-THEN scenarios
4. Add an API Integration section to `design.md` with TypeScript interfaces and endpoint mapping
5. Include API integration tasks in `tasks.md`
6. Add endpoint details to each relevant GitHub issue body

If the section is absent or empty, the pipeline works exactly as before — no API enrichment is applied.

### 2b. Staged Greenfield Development

For large greenfield features, use `/sdd-staged` to break the PRD into ordered stages:

```
/sdd-staged my-app
```

**When to use staged vs single-stage:**
- **Use `/sdd-from-prd`** for features with 1-2 user stories, or adding to an existing codebase
- **Use `/sdd-staged`** for greenfield projects or large features (3+ stories) that need foundational work before feature development

**Stage naming convention:** `<feature>-NN-<slug>` (e.g., `my-app-01-setup`, `my-app-02-scaffold`, `my-app-03-auth-flow`)

**How it works:**
1. Reads the PRD and proposes 3-6 stages (you can adjust before confirming)
2. Generates a separate OpenSpec change per stage (`openspec/changes/<feature>-NN-<slug>/`)
3. Creates GitHub issues for all stages with cross-stage dependency references
4. Writes a master stage map to `.tasks/<feature>-stages.md`

**Cross-stage dependencies:** Issues in later stages include a "Cross-Stage Dependencies" section referencing blocking issues from earlier stages. The first task of each stage gates on the prior stage completing.

**Recommended frontend stage patterns:**
| Stage | Typical content |
|-------|----------------|
| `01-setup` | Project init (Vite/Next/CRA), tooling, linting, CI, dependencies |
| `02-scaffold` | App shell, routing, layout, shared components, state management skeleton |
| `03-xx` onwards | Feature areas grouped by functional domain (auth, dashboard, settings, etc.) |

**Working through stages:** Complete stage 01 issues before starting stage 02. After all issues in a stage are merged, archive it with `/opsx:archive <feature>-NN-<slug>`.

### 2. Generating Specs and Tickets

**From a PRD (recommended):**
```
/sdd-from-prd my-feature
```

This runs the full pipeline:
1. Reads `docs/prds/my-feature.md`
2. Flags any Open Questions for resolution
3. Creates an OpenSpec change (`openspec/changes/my-feature/`)
4. Generates: proposal.md, specs/ (GIVEN-WHEN-THEN scenarios), design.md, tasks.md
5. Asks for confirmation, then creates GitHub issues
6. Writes issue mapping to `.tasks/my-feature.md`

**From scratch (no PRD):**
```
/opsx:propose "add user authentication with OAuth"
/sdd-create-tickets add-user-authentication
```

### Review Gates

The workflow has two built-in review gates that surface architectural, security, and quality concerns without requiring separate agents:

**Design Challenge** — runs automatically in `/sdd-from-prd`, `/sdd-staged`, and `/opsx:propose` after artifacts are generated but before tickets are created. It surfaces:
- Key assumptions the design makes
- Risks and pitfalls (over-engineering, edge cases, security, performance)
- Simplification opportunities
- Open questions that should be answered first

You can adjust artifacts based on the challenge or proceed as-is.

**Code Review** — runs automatically in `/sdd-verify` after acceptance criteria and CI checks. It evaluates:
- **Pattern consistency**: does the code match existing codebase conventions?
- **Security**: XSS, injection, exposed secrets, auth gaps
- **Performance**: unnecessary re-renders, missing memoization, N+1 fetches
- **Error handling**: system boundaries covered, error states in UI
- **Design alignment**: matches `design.md` if an OpenSpec change is linked
- **Constitution compliance**: checks NON-NEGOTIABLE principles (violations block) and RECOMMENDED principles (deviations are advisory)

Code review issues are recommendations, not blockers — you decide whether to fix them or proceed to PR. Exception: NON-NEGOTIABLE constitution violations are flagged as required fixes.

### 3. Developing a Ticket

```
/sdd-work 42
```

The agent will:
1. **Read** the GitHub issue (description, acceptance criteria, hints)
2. **Check** if blocking dependencies are still open
3. **Detect** linked OpenSpec change (via `Source:` footer in issue body) and read proposal, design, and spec artifacts for richer context. For staged workflows, it also reads the stage map and identifies what prior stages built.
4. **Research** the codebase (find related files, existing patterns)
5. **Present** an implementation plan (including OpenSpec context if available) and **wait for your approval**
6. **Create** a branch: `feat/42-add-login-form`
7. **Implement** the changes following existing codebase patterns
8. **Run** tests, lint, build (if configured)
9. **Commit** with conventional commits: `feat(auth): add login form (#42)`
10. **Verify** each acceptance criterion is met
11. **Mark task complete** in OpenSpec `tasks.md` (if linked change was detected)

The agent will not write code until you approve the plan. If the issue was created manually (no OpenSpec link), steps 3 and 11 are skipped automatically.

### 4. Verifying and Creating a PR

```
/sdd-verify
```

The agent will:
1. Detect the current branch and extract the issue number
2. Fetch acceptance criteria from the GitHub issue
3. Review all changes against the base branch
4. Check each criterion: **PASS** or **FAIL**
5. Run tests/lint/build
6. **Code review**: evaluate pattern consistency, security, performance, error handling, and design alignment
7. If acceptance criteria or CI fail: stop and report what needs fixing
8. If code review flags issues: present them as recommendations (you decide whether to fix or proceed)
9. If everything passes: ask for confirmation, push, and create a PR

The PR includes:
- Summary of changes
- All acceptance criteria (checked off)
- Testing notes
- `Closes #42` to auto-close the issue on merge

### 5. Archiving (after all tickets are done)

```
/opsx:archive
```

Moves the completed change to `openspec/changes/archive/` and updates the living specs in `openspec/specs/`. This builds up a persistent knowledge base of how the system works.

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
|   |-- commands/opsx/                     # OpenSpec slash commands
|   |   |-- propose.md
|   |   |-- apply.md
|   |   |-- archive.md
|   |   +-- explore.md
|   +-- skills/
|       |-- sdd-constitution/SKILL.md      # /sdd-constitution  Define project coding standards
|       |-- sdd-staged/SKILL.md            # /sdd-staged     PRD -> stages -> specs -> tickets
|       |-- sdd-from-prd/SKILL.md          # /sdd-from-prd   PRD -> specs -> tickets
|       |-- sdd-create-tickets/SKILL.md    # /sdd-create-tickets  OpenSpec -> GitHub issues
|       |-- sdd-work/SKILL.md              # /sdd-work        Implement a GitHub issue
|       |-- sdd-verify/SKILL.md            # /sdd-verify      Verify + create PR
|       |-- openspec-propose/SKILL.md      # OpenSpec: generate specs from description
|       |-- openspec-apply-change/SKILL.md # OpenSpec: implement tasks directly
|       |-- openspec-archive-change/SKILL.md # OpenSpec: archive completed changes
|       +-- openspec-explore/SKILL.md      # OpenSpec: explore change artifacts
|
|-- docs/
|   |-- constitution.md                    # Project coding standards (generated by /sdd-constitution)
|   |-- prd-template.md                    # PRD template for the PO
|   |-- prds/                              # PRD files go here
|   +-- apis/                              # Swagger/OpenAPI files (optional)
|
|-- openspec/
|   |-- specs/                             # Living domain specs (grows over time)
|   +-- changes/                           # Active changes (proposal, specs, design, tasks)
|       +-- archive/                       # Completed and archived changes
|
+-- .tasks/                                # Issue mapping files (task <-> GitHub issue)
```

## Git Conventions

### Branches

Format: `<type>/<issue-number>-<short-description>`

Examples:
- `feat/42-add-login-form`
- `fix/57-broken-redirect`
- `chore/63-update-dependencies`

### Commits

Format: `type(scope): description (#issue)`

| Type | When to use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code restructuring, no behavior change |
| `test` | Adding or updating tests |
| `chore` | Build, tooling, dependencies |
| `build` | Build system changes |
| `ci` | CI/CD pipeline changes |

Examples:
```
feat(auth): add login form (#42)
fix(nav): correct redirect after logout (#57)
test(auth): add login form unit tests (#44)
```

A **PreToolUse hook** automatically blocks commits that don't follow this format.

### Pull Requests

- Title follows conventional commit format
- Body includes: Summary, Changes, Acceptance Criteria (all checked), Testing notes
- Auto-closes the issue via `Closes #<number>`
- Merging is always a human decision

## How It All Connects

```
                    +------------------+
                    |   PO writes PRD  |
                    | docs/prds/*.md   |
                    +--------+---------+
                             |
                    /sdd-from-prd <name>
                             |
              +--------------+--------------+
              |                             |
    +---------v----------+       +----------v---------+
    |   OpenSpec specs   |       |   GitHub Issues    |
    | openspec/changes/* |       |   (via gh CLI)     |
    +--------------------+       +----------+---------+
                                            |
                                   /sdd-work <issue#>
                                            |
                                 +----------v---------+
                                 |  Feature Branch     |
                                 |  + Implementation   |
                                 |  + Conventional     |
                                 |    Commits          |
                                 +----------+---------+
                                            |
                                      /sdd-verify
                                            |
                                 +----------v---------+
                                 |   Pull Request     |
                                 |   Closes #issue    |
                                 +----------+---------+
                                            |
                                     /opsx:archive
                                            |
                                 +----------v---------+
                                 |   Living Specs     |
                                 |   openspec/specs/  |
                                 +--------------------+
```

## Customization

### Adapting for your project

1. **Run `/sdd-constitution`** to define your tech stack, coding standards, and quality gates. This is the primary way to configure project-specific conventions — the constitution is automatically enforced by all skills.

2. **Update `CLAUDE.md`** for workflow-level settings:
   - **Commands**: Replace `npm test`, `npm run lint`, `npm run build` with your actual commands
   - **File Locations**: Adjust if your project structure differs
   - **Git Conventions**: Already configured, adjust if needed

### Adding new skills

Create a new directory under `.claude/skills/`:

```
.claude/skills/my-skill/
  SKILL.md
```

The `SKILL.md` needs YAML frontmatter with `name`, `description`, and `disable-model-invocation: true` (for user-invoked skills). The markdown body contains the instructions Claude follows when the skill is invoked.

### Modifying the commit hook

Edit `.claude/hooks/validate-commit-msg.sh` to change the allowed commit types or format. The hook runs as a Claude Code **PreToolUse** hook — it intercepts `git commit` commands before execution and blocks them with an error message if the format is wrong.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh: command not found` | Install GitHub CLI: `brew install gh` then `gh auth login` |
| `openspec: command not found` | Install OpenSpec: `npm install -g @fission-ai/openspec@latest` |
| Skills don't appear as slash commands | Restart Claude Code. Skills are discovered on startup. |
| Commit blocked by hook | Your commit message doesn't follow conventional commits. Use `type(scope): description` format. |
| `/sdd-create-tickets` says "no tasks.md" | Run `/opsx:propose` or `/sdd-from-prd` first to generate the specs. |
| `/sdd-work` warns about open dependencies | A blocking issue hasn't been closed yet. Close it or proceed with caution. |
| `/sdd-verify` reports FAIL on criteria | Fix the failing criteria before the PR can be created. The agent will tell you what's missing. |
| `/sdd-staged` suggests using `/sdd-from-prd` | Your PRD is too small for staging (1-2 stories). Use `/sdd-from-prd` or override if you still want stages. |
| Cross-stage issues missing dependencies | Re-check `.tasks/<feature>-stages.md` for the dependency map. You can manually add "Depends on #N" to issue bodies. |
