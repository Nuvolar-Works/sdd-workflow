---
name: sdd-constitution
description: Generate a project constitution — coding standards, architectural rules, and quality gates that all SDD and OpenSpec skills enforce during artifact generation and code review.
argument-hint: "[project-name]"
disable-model-invocation: true
---

# Generate Project Constitution

You are creating a project constitution — a living document that defines the coding standards, architectural rules, and quality gates for this project. All SDD and OpenSpec skills will read this document and enforce its principles during artifact generation, implementation, and code review.

## Input

The project name is: $ARGUMENTS (optional — used in the document title; defaults to the repo name)

## Phase 1: Gather Project Context

1. **Check for an existing constitution**. Look for `docs/constitution.md`.
   - If it exists, read it and ask the user: "A constitution already exists. Do you want to update it or start fresh?"
   - If updating, use the existing content as a baseline and proceed to Phase 2.

2. **Detect existing project signals**. Scan the codebase for clues about the current stack and conventions:
   - Check `package.json`, `tsconfig.json`, `next.config.*`, `vite.config.*`, `angular.json`, etc.
   - Check for existing linting configs (`.eslintrc*`, `.prettierrc*`, `biome.json`)
   - Check for test frameworks (`vitest.config.*`, `jest.config.*`, `playwright.config.*`)
   - Check `docs/prds/` for any PRDs with Technical Considerations filled in
   - Check existing source code for patterns (folder structure, naming conventions, imports)

3. **Present findings** to the user:
   ```
   ## Detected Project Context

   - Framework: <detected or "not detected">
   - Language: <detected or "not detected">
   - Styling: <detected or "not detected">
   - State Management: <detected or "not detected">
   - Testing: <detected or "not detected">
   - Linting: <detected or "not detected">
   - Folder structure: <detected pattern or "not detected">
   ```

   Ask: "Here's what I detected. Please confirm, correct, or add details for anything I missed. You can also provide your full stack and conventions if you prefer."

   Wait for user input before proceeding.

## Phase 2: Interview for Principles

4. **For any areas not covered by detection or user input**, ask targeted questions. Group them and ask in batches (not one by one) to keep momentum:

   **Batch 1 — Stack & Architecture** (skip items already known):
   - Framework and version?
   - Language and strictness settings?
   - UI library / component primitives?
   - Styling approach?
   - State management strategy?
   - Routing approach?
   - Form handling / validation?
   - Internationalization?

   **Batch 2 — Conventions & Patterns** (skip items already known):
   - Folder structure pattern? (feature-based, layer-based, domain-based)
   - Naming conventions? (files, components, variables, types)
   - Component patterns? (composition style, props patterns, co-location rules)
   - Import conventions? (barrel exports, path aliases, absolute vs relative)
   - Error handling approach?

   **Batch 3 — Quality & Governance**:
   - What quality gates must pass before code is considered done? (lint, test, build, type-check)
   - Minimum test expectations? (unit tests required? E2E? coverage threshold?)
   - Accessibility requirements?
   - Performance constraints?
   - Security rules?
   - Any NON-NEGOTIABLE rules the team has learned from past incidents?

   For each batch, present what you've detected or inferred as defaults and let the user confirm or override. Only ask about genuinely unknown items.

## Phase 3: Generate the Constitution

5. **Generate `docs/constitution.md`** using the following structure. Adapt the number of principles to what's relevant — don't pad with generic rules. Every principle must be specific and actionable.

   ```markdown
   <!--
   ==============================================================================
   SYNC IMPACT REPORT
   ==============================================================================
   Version change: 0.0.0 → 1.0.0 (initial ratification)

   Modified principles: N/A
   Added sections: <list sections>
   Removed sections: N/A

   Follow-up TODOs: <any unresolved items, or "None">
   ==============================================================================
   -->

   # <Project Name> Constitution

   ## Core Principles

   ### I. <Principle Title> (NON-NEGOTIABLE | RECOMMENDED)

   <Clear, specific description of what MUST or SHOULD be done, with concrete
   examples of correct and incorrect usage where helpful.>

   **Rationale**: <Why this rule exists — what problem it prevents or what value
   it ensures. Link to past incidents if applicable.>

   <!-- Repeat for each principle -->

   ## Technology Stack

   - **Framework**: <framework and version>
   - **Language**: <language and config>
   - **UI Primitives**: <component library>
   - **Styling**: <approach — what is allowed and forbidden>
   - **Component Variants**: <CVA, styled-components, etc.>
   - **State Management**: <approach and when to use what>
   - **Routing**: <approach>
   - **Form Validation**: <library>
   - **Internationalization**: <approach>
   - **Testing**: <frameworks and expectations>
   - **Linting/Formatting**: <tools>
   - **Build Tool**: <tool>
   - **Package Manager**: <tool>

   ## Folder Structure

   <Describe the expected folder structure with brief explanations of what
   belongs where. Use a tree format.>

   ```
   src/
   ├── app/          — <description>
   ├── components/   — <description>
   │   ├── ui/       — <description>
   │   └── <feature>/— <description>
   ├── lib/          — <description>
   ├── stores/       — <description>
   └── types/        — <description>
   ```

   ## Development Workflow

   - **Branching**: <convention>
   - **Commits**: <convention>
   - **Constitution compliance**: Every PR and code review should verify principles
     are followed.

   ## Quality Gates (NON-NEGOTIABLE)

   All of the following MUST pass before work is considered complete:

   1. <gate 1 — e.g., `npm run lint` passes with zero errors>
   2. <gate 2 — e.g., `npm run build` compiles without errors>
   3. <gate 3 — e.g., TypeScript strict mode passes>
   4. <gate 4 — e.g., minimum test coverage>

   ## Governance

   This constitution supersedes all other project conventions. Where conflicts
   arise between this document and other guidance, this constitution takes
   precedence.

   **Amendment procedure**:
   1. Propose the change as a PR that updates this file.
   2. The PR MUST include an updated Sync Impact Report (HTML comment at the top).
   3. At least one other contributor MUST approve the PR before merge.

   **Version**: 1.0.0 | **Ratified**: <YYYY-MM-DD> | **Last Amended**: <YYYY-MM-DD>
   ```

6. **Tailor the principles** to the specific project:
   - Do NOT include generic filler principles. Every principle must reflect something the user specified or that was detected from the codebase.
   - Mark rules as `NON-NEGOTIABLE` only if the user explicitly said so or if they represent fundamental safety/correctness concerns (e.g., TypeScript strict mode, no `any`).
   - Mark rules as `RECOMMENDED` for conventions that are preferred but may have legitimate exceptions.
   - Include **Rationale** for every principle — this helps future developers understand *why*, not just *what*.

## Phase 4: Review and Ratify

7. **Present the full constitution** to the user for review.

8. **Ask**: "Review the constitution above. You can:
   - Approve it as-is
   - Request changes to any principles
   - Add principles I missed
   - Change any NON-NEGOTIABLE ↔ RECOMMENDED classifications"

9. **Apply any requested changes** and present the updated version.

10. **Once approved**, write the final version to `docs/constitution.md`.

11. **Print summary**:
    ```
    ## Constitution Ratified

    Location: docs/constitution.md
    Principles: N
    Quality Gates: N
    Version: 1.0.0

    This constitution will be enforced by:
    - /sdd-from-prd and /sdd-staged — artifact generation follows these standards
    - /opsx:propose — design and task generation respects these rules
    - /sdd-work — implementation follows these patterns
    - /sdd-verify — code review checks constitution compliance

    To update the constitution later, run /sdd-constitution again.
    ```

## Rules
- The constitution MUST be specific to this project. Do not generate generic "best practices" documents.
- Every principle needs a Rationale. No rules without reasons.
- The user has final say on all principles. Do not argue — present your case and defer.
- Do NOT include rules that duplicate what's already in CLAUDE.md (git conventions, branch naming, etc.) — reference CLAUDE.md for those.
- If the project has no code yet (greenfield), rely entirely on user input for conventions.
- Keep the document concise. Aim for principles that are easy to scan and enforce, not an essay.
- The Sync Impact Report header is for tracking changes across versions — always include it.
- Use the current date for ratification.
