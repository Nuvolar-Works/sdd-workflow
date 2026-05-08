# Design Challenge Template

Used by `/sdd-from-prd`, `/sdd-staged`, and `/opsx:propose` after artifact generation but before tickets are created. The point is to act as a devil's-advocate review before committing to a build plan.

## Output shape

```
## Design Challenge for <change-name>

### Assumptions
- <List 2-4 key assumptions the design makes that, if wrong, would invalidate the design>

### Risks & Pitfalls
- <Identify 2-4 things that could go wrong:>
  - Over-engineering for hypothetical future needs
  - Missing edge cases (especially around concurrency, partial failure, empty/large input)
  - Wrong abstraction level (too generic / too specific)
  - Performance traps (eager loads, N+1, unbounded growth)
  - Security concerns (missing auth, leakage, unsafe defaults)
  - Operational concerns (rollback, migration, monitoring gaps)

### Simplification Opportunities
- <Is there a simpler approach we dismissed too quickly?>
- <Are we building abstractions we don't need yet?>
- <Could a smaller change deliver 80% of the value?>

### Open Questions
- <Anything that should be answered before implementation?>
- <Stakeholders who should weigh in?>
```

## Decision

After presenting the challenge, ask the user:

> Want to adjust any of `design.md`, `specs/*.md`, or `tasks.md` before I create tickets, or proceed as-is?

If the user requests changes, update the relevant artifacts and present a one-line diff summary, then re-ask. Don't create tickets until the user explicitly proceeds.
