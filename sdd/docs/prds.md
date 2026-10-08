# PRDs

## Writing a PRD

Copy the template and fill it in:

```bash
cp sdd/prd-template.md sdd/prds/my-feature-v1.md        # greenfield / v1
cp sdd/prd-template-mini.md sdd/prds/my-feature-v2-scope.md   # v2+ increment
```

| Section | Purpose | Used for |
|---------|---------|----------|
| **Problem Statement** | What and why (2-3 sentences) | OpenSpec proposal.md |
| **Goals** | Measurable success criteria | Objectives and scope |
| **Non-Goals** | Explicitly out of scope | Prevents AI scope creep |
| **User Stories** | As a..., I want..., so that... | GIVEN-WHEN-THEN specs and task generation |
| **UI/UX Notes** | Wireframes, mockups, descriptions | Design decisions |
| **Technical Considerations** | Constraints, integrations | Implementation hints |
| **Dependencies** | External services, APIs | Blocking issues |
| **API Contract** | Interface contract file path or URL — OpenAPI, GraphQL SDL, .proto, AsyncAPI… (optional) | API-enriched specs, design, and tasks — see [interface-contracts.md](interface-contracts.md) |
| **Open Questions** | Unresolved items | Flagged before spec generation |

## Versioning

`<slug>-v1.md`, `<slug>-v2-<scope>.md`, `<slug>-v2-1-<scope>.md`. Each version is a separate `/sdd-from-prd` run; living specs in `openspec/specs/` accumulate across versions so v2 builds on v1 without re-stating it.

## Staged greenfield

Use `/sdd-staged` for large greenfield features (3+ user stories, or projects needing foundational setup before feature work). Use `/sdd-from-prd` for single features or increments on existing codebases.

Stage naming convention: `<feature>-NN-<slug>` (e.g. `my-app-01-setup`, `my-app-02-scaffold`, `my-app-03-auth-flow`).

| Stage | Typical content |
|-------|----------------|
| `01-setup` | Project init, tooling, linting, CI, dependencies |
| `02-scaffold` | Skeleton of the chosen architecture: app shell & routing, service skeleton & persistence wiring, or base org/project config |
| `03-xx` onwards | Feature areas grouped by functional domain |

Stage-01 setup tasks are driven by the constitution's tech stack.
