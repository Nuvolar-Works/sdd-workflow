---
name: sdd-from-prd
description: End-to-end bridge from a PRD file to GitHub issues. Reads the PRD, generates OpenSpec artifacts, and creates tickets — one command for the full pipeline.
argument-hint: "<feature-name>"
disable-model-invocation: true
---

# PRD → OpenSpec → GitHub Issues

You are running the full pipeline: read a PRD, generate OpenSpec specs, and create GitHub issues.

## Input

The feature name is: $ARGUMENTS
The PRD file is at: `docs/prds/$ARGUMENTS.md`

## Phase 1: Read and Validate the PRD

1. **Read the PRD** at `docs/prds/$ARGUMENTS.md`. If the file does not exist, tell the user and stop.

2. **Check for Open Questions** in the PRD. If any exist, present them to the user and ask whether to proceed or resolve them first. Open questions may lead to incomplete or incorrect specs.

3. **Extract the key PRD content** and hold it in context:
   - Problem Statement
   - Goals and Non-Goals
   - User Stories (these drive task generation)
   - UI/UX Notes
   - Technical Considerations
   - Dependencies

4. **Check for an API Contract reference** in the PRD:
   - Look for an `## API Contract` section.
   - If the section is missing or empty, skip this step entirely — the rest of the pipeline works unchanged.
   - If present, extract the reference (file path or URL).
     - **If a local file path**: Read the file. If not found, warn the user and ask whether to proceed without it.
     - **If a URL**: Fetch the content using WebFetch. If the fetch fails, warn the user and ask whether to proceed without it.
   - **Parse the Swagger/OpenAPI content** and extract an API Summary:
     - API title, version, and base URL / servers
     - Authentication / security schemes (e.g., Bearer token, API key)
     - List of endpoints: method, path, summary, request body schema (key fields), response schema (key fields)
     - Shared data models / schemas referenced by multiple endpoints
   - Hold this **API Summary** in context alongside the PRD content. This summary — not the raw Swagger file — is what gets fed into artifact generation.

## Phase 1.5: Read Project Constitution

5. **Check for a project constitution** at `docs/constitution.md`.
   - If it exists, read it and hold it in context. The constitution defines:
     - **Core Principles**: Coding standards and architectural rules (NON-NEGOTIABLE and RECOMMENDED)
     - **Technology Stack**: Framework, language, styling, state management, etc.
     - **Folder Structure**: Where files should be placed
     - **Quality Gates**: What must pass before work is done
   - These constraints MUST be applied when generating all artifacts:
     - **proposal.md**: Reference the constitution's tech stack in the technical approach
     - **specs/*.md**: Scenarios must respect constitution patterns (e.g., if constitution says "no custom CSS", specs should not reference custom stylesheets)
     - **design.md**: Architecture MUST align with constitution's folder structure, component patterns, state management approach, and technology choices
     - **tasks.md**: Tasks must follow constitution conventions (e.g., if constitution mandates Zod for validation, tasks should reference Zod, not yup or manual validation)
   - If the constitution does not exist, proceed without it — but note in the summary: "No project constitution found. Run `/sdd-constitution` to define coding standards."

## Phase 2: Generate OpenSpec Artifacts

6. **Derive a change name** from the feature name in kebab-case (e.g., `user-auth` stays `user-auth`, `User Authentication` becomes `user-authentication`).

7. **Create the OpenSpec change**:
   ```bash
   openspec new change "$CHANGE_NAME"
   ```
   If a change with that name already exists, ask the user whether to continue it or create a new one with a different name.

7. **If an API Contract was found in Phase 1**, copy the Swagger file into the change folder:
   - **If local file**: Copy it to `openspec/changes/$CHANGE_NAME/api-contract.yaml` (or `.json`, matching the source extension).
   - **If URL**: Write the fetched content to `openspec/changes/$CHANGE_NAME/api-contract.yaml` (or `.json`).
   - This file is a reference artifact for developers — it is NOT processed by openspec, just kept alongside the other artifacts.

8. **Get the artifact build order**:
   ```bash
   openspec status --change "$CHANGE_NAME" --json
   ```
   Parse the JSON to get the `applyRequires` array and the `artifacts` list with their statuses and dependencies.

9. **Generate each artifact in dependency order**. For each artifact that is `ready`:

   a. Get instructions:
      ```bash
      openspec instructions <artifact-id> --change "$CHANGE_NAME" --json
      ```

   b. Read any completed dependency artifacts for context.

   c. Create the artifact file using the `template` from instructions as the structure.
      **Use the PRD content as the primary input** — map PRD sections to artifact sections:
      - **proposal.md**: Problem Statement → problem, Goals → objectives, Non-Goals → scope exclusions, User Stories → user needs. **If API Contract exists**: mention the API integration scope in the problem/objectives.
      - **specs/*.md**: User Stories → GIVEN-WHEN-THEN scenarios. Each story becomes one or more testable scenarios. Include edge cases from the story Details. **If API Contract exists**: for user stories involving backend calls, add integration scenarios referencing specific endpoints, request/response shapes, and error paths (4xx/5xx from Swagger). Example:
        ```
        GIVEN the user submits the registration form
        WHEN a POST request is sent to /api/v1/users with { email, password, name }
        THEN the API returns 201 with the created user object
        AND the user sees a success message
        ```
      - **design.md**: Technical Considerations → architecture decisions, Dependencies → integration points, UI/UX Notes → component structure. **If API Contract exists**: add an "API Integration" subsection with endpoint-to-story mapping, TypeScript interfaces derived from Swagger schemas, authentication approach, and error handling strategy.
      - **tasks.md**: Derived from specs and design — atomic, implementable tasks. **If API Contract exists**: include API-specific tasks (create API client/service, implement types/interfaces, wire API calls, handle errors) referencing specific endpoints.

   d. Apply `context` and `rules` from instructions as constraints but do NOT copy them into the file.

   e. After each artifact, re-check status:
      ```bash
      openspec status --change "$CHANGE_NAME" --json
      ```
      Continue until all `applyRequires` artifacts have `status: "done"`.

10. **Show a summary** of generated artifacts with brief descriptions.

## Phase 2.5: Design Challenge

11. **Challenge the design** before moving to tickets. Review the generated artifacts with a critical eye and present a brief challenge report:

    ```
    ## Design Challenge for $CHANGE_NAME

    ### Assumptions
    - <List 2-4 key assumptions the design makes>

    ### Risks & Pitfalls
    - <Identify 2-4 things that could go wrong: over-engineering, missing edge cases, wrong abstraction level, performance traps, security concerns>

    ### Simplification Opportunities
    - <Is there a simpler approach we dismissed too quickly?>
    - <Are we building abstractions we don't need yet?>

    ### Open Questions
    - <Anything that should be answered before implementation?>
    ```

    **Ask the user**: "Here's my design challenge. Want to adjust anything before I create tickets, or proceed as-is?"

    If the user requests changes, update the relevant artifacts (`design.md`, `specs/*.md`, `tasks.md`) before proceeding.

## Phase 3: Create GitHub Issues

12. **Ask the user**: "OpenSpec artifacts are ready. Shall I create GitHub issues from the tasks now?"

    If yes, proceed. If no, tell them they can run `/sdd-create-tickets $CHANGE_NAME` later.

13. **Read all artifacts** for issue context:
    - `openspec/changes/$CHANGE_NAME/tasks.md` — task list
    - `openspec/changes/$CHANGE_NAME/proposal.md` — descriptions
    - `openspec/changes/$CHANGE_NAME/specs/*.md` — GIVEN-WHEN-THEN acceptance criteria
    - `openspec/changes/$CHANGE_NAME/design.md` — implementation hints

14. **Verify GitHub CLI access**:
    ```bash
    gh repo view --json nameWithOwner -q '.nameWithOwner'
    ```
    If this fails, tell the user to run `gh auth login` and stop.

15. **Parse tasks and create issues** following the same logic as `/sdd-create-tickets`:
    - Each `- [ ] N.N description` line → one GitHub issue
    - Infer type from context (setup → chore, UI/feature → feat, test → test)
    - Map GIVEN-WHEN-THEN scenarios as acceptance criteria
    - Pull implementation hints from design.md
    - Create issues in dependency order via `gh issue create`
    - Ensure required labels exist first
    - **If the task involves API integration**: include an "API Contract" section in the issue body with the specific endpoint(s), expected request/response shapes, and a pointer to the full Swagger file at `openspec/changes/$CHANGE_NAME/api-contract.yaml`

16. **Update OpenSpec's tasks.md** by appending issue numbers to each task line.

17. **Write an issue mapping file** to `.tasks/$CHANGE_NAME.md`.

18. **Print the final summary**:
    ```
    ## Pipeline Complete: $ARGUMENTS

    PRD: docs/prds/$ARGUMENTS.md
    OpenSpec change: openspec/changes/$CHANGE_NAME/
    Artifacts: proposal.md, specs/, design.md, tasks.md
    API Contract: openspec/changes/$CHANGE_NAME/api-contract.yaml  ← (only if applicable)

    | Task | Issue | Title | Type | Priority |
    |------|-------|-------|------|----------|
    | 1.1  | #42   | ...   | feat | high     |

    Next: Run /sdd-work <issue-number> to start developing a ticket.
    ```

## Rules
- The PRD is the source of truth. Do not invent requirements that are not in the PRD.
- Respect Non-Goals — do not generate tasks for out-of-scope items.
- If the PRD is vague on a point, ask the user rather than guessing.
- Create issues in dependency order so you can reference real issue numbers.
- Use conventional commit types as issue title prefixes (feat, chore, test, docs).
- Do NOT assign issues unless the user explicitly asks.
- If any step fails (openspec CLI, gh CLI), stop and report the error clearly.
- The Swagger/OpenAPI doc is supplementary context for HOW the backend contract looks. The PRD remains the source of truth for WHAT to build. Do not generate tasks for endpoints not referenced by any PRD user story.
