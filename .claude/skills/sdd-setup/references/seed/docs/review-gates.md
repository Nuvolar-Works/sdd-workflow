# Review gates

Two gates are built in. Both produce recommendations; you decide.

## Design challenge

Runs in `/sdd-from-prd`, `/sdd-staged`, and `/sdd-tasks-from-story` — after artifacts are generated, before tickets are created. Surfaces:

- Key assumptions the design makes
- Risks and pitfalls (over-engineering, edge cases, security, performance)
- Simplification opportunities
- Open questions that should be answered first

Template: [`templates/design-challenge.md`](../templates/design-challenge.md)

## Code review

Runs in `/sdd-verify` after acceptance criteria and quality gates. Evaluates:

- **Pattern consistency** — does the code match existing codebase conventions?
- **Security** — injection (SQL, SOQL, XSS…), exposed secrets, auth and permission gaps
- **Performance** — work repeated per item inside loops (N+1 queries, queries/DML in loops, avoidable re-renders), unbounded data loads
- **Error handling** — system boundaries covered, failures surfaced to callers or users
- **Design alignment** — matches `design.md` if an OpenSpec change is linked
- **Contract fidelity** — matches the [interface contract](interface-contracts.md), when one applies
- **Constitution compliance** — see below

Checklist: [`templates/code-review-checklist.md`](../templates/code-review-checklist.md)

## Constitution enforcement

Once ratified with `/sdd-constitution`, the constitution is applied by the SDD skills. Each loads only the section files it needs from `sdd/constitution/`.

| Skill | How it uses the constitution |
|-------|------------------------------|
| `/sdd-from-prd` | Generates specs, design, and tasks aligned with your stack and patterns |
| `/sdd-staged` | Same, and drives stage-01 setup tasks from the tech stack |
| `/sdd-work` | Follows principles during implementation (libraries, file locations, patterns) |
| `/sdd-verify` | NON-NEGOTIABLE violations are flagged as blocker recommendations (you decide); RECOMMENDED deviations are advisory |

To update the constitution, run `/sdd-constitution` again.
