# Interface contracts

An interface contract is a machine-readable schema for an interface whose other side is not built or tested in this repo — another team's API, an external service, an event stream (OpenAPI, GraphQL SDL, `.proto`, AsyncAPI, JSON Schema, …). In-repo schemas the toolchain already enforces (ORM models, platform object metadata, data-model definitions) don't count.

- **Where it lives.** The maintained source is `sdd/apis/` (the contract itself, or a short pointer file to where it lives) or the path/URL a PRD's `## API Contract` section references. `openspec/changes/<change>/api-contract.*` is a snapshot taken when the change was created — use it only when no maintained source is available. If the two disagree on something in scope, report contract drift rather than picking one.
- **Precedence.** On shape — operation and field names, types, optionality, enum values, documented outcomes — the contract beats prose (`design.md`, other teams' ticket text, story text). The PRD still wins on scope.
- **Used by** `/sdd-from-prd` (specs, design, tasks), `/sdd-tasks-from-story` (design and codebase audit) and `/sdd-verify` (code-review checklist § 7).

## Referencing one from a PRD

```markdown
## API Contract
sdd/apis/user-auth.yaml
# or
https://api.example.com/docs/openapi.yaml
```

`/sdd-from-prd` then enriches the generated specs with operation-specific GIVEN-WHEN-THEN scenarios, adds API integration sections to `design.md`, and includes API integration tasks in `tasks.md`.
