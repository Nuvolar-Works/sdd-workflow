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
```

## Workflow Overview

There are two entry points depending on who initiates the work:

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

## Commands Reference

### SDD Commands (custom skills)

| Command | Input | What it does |
|---------|-------|-------------|
| `/sdd-from-prd <feature>` | Feature name matching a file in `docs/prds/` | Full pipeline: reads PRD, generates OpenSpec specs, creates GitHub issues. One command from PRD to tickets. |
| `/sdd-create-tickets <change>` | OpenSpec change name | Reads OpenSpec artifacts from `openspec/changes/<change>/`, creates GitHub issues with GIVEN-WHEN-THEN acceptance criteria, updates task file with issue numbers. |
| `/sdd-work <issue#>` | GitHub issue number | Fetches the issue, researches the codebase, presents an implementation plan for approval, creates a feature branch, implements, commits with conventional commits. |
| `/sdd-verify [issue#]` | Optional issue number (auto-detected from branch) | Checks each acceptance criterion against the code, runs tests/lint/build, and if everything passes creates a PR with `Closes #<issue>`. |

### OpenSpec Commands (bundled with OpenSpec)

| Command | Input | What it does |
|---------|-------|-------------|
| `/opsx:propose <description>` | Feature description or change name | Generates all OpenSpec artifacts: proposal.md, specs/ (GIVEN-WHEN-THEN), design.md, tasks.md. |
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

### 3. Developing a Ticket

```
/sdd-work 42
```

The agent will:
1. **Read** the GitHub issue (description, acceptance criteria, hints)
2. **Check** if blocking dependencies are still open
3. **Research** the codebase (find related files, existing patterns)
4. **Present** an implementation plan and **wait for your approval**
5. **Create** a branch: `feat/42-add-login-form`
6. **Implement** the changes following existing codebase patterns
7. **Run** tests, lint, build (if configured)
8. **Commit** with conventional commits: `feat(auth): add login form (#42)`
9. **Verify** each acceptance criterion is met

The agent will not write code until you approve the plan.

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
6. If anything fails: stop and report what needs fixing
7. If everything passes: ask for confirmation, push, and create a PR

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

The `CLAUDE.md` file is the AI's project context. Update these sections when you set up your actual project:

- **Commands**: Replace `npm test`, `npm run lint`, `npm run build` with your actual commands
- **Code Conventions**: Add framework-specific patterns (React, Angular, Vue, etc.)
- **File Locations**: Adjust if your project structure differs

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
