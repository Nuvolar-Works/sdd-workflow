# Jira Task Decomposition

Used by `/sdd-tasks-from-story` to decompose a Jira user story into Jira sub-tasks **after** an OpenSpec change has been generated for that story. The unit of decomposition is the **significant goal** — a user-visible deliverable named in the story (a panel, a component, an integration point), not a layer of the stack.

## Principles

1. **One sub-task per significant goal.** A "goal" is something the PO would tick off when the story is delivered: "the clock-in panel", "the history panel", "the frontend↔backend integration." It is **not** an implementation layer (data layer, UI scaffolding, error states). Sub-tasks group whatever layers are needed to ship that goal.
2. **Derived from the OpenSpec `tasks.md`.** The OpenSpec change generated for the story owns the canonical task breakdown. Each section in `tasks.md` (`## N. <Goal name>`) becomes one Jira sub-task. Do **not** invent goals that are not in `tasks.md`; if the breakdown looks wrong, fix `tasks.md` first.
3. **Spec-anchored.** Every sub-task references the specific `specs/*.md` file (and ideally the section heading) that defines its acceptance scenarios. This is what reviewers and `/sdd-work` follow back when implementing.
4. **Coexists with backend tasks.** The frontend sub-tasks and the backend's sub-tasks live under the same Jira parent story. Pick goal names that make the split obvious (e.g. "Frontend: clock-in panel" if the team prefixes by area).
5. **Dependency-ordered.** Goals that need other goals' output (e.g. "frontend↔backend integration" depends on the panel that consumes it) come later in the list.
6. **Constitution-aligned.** Goals must respect `sdd/constitution/folder-structure.md` and `sdd/constitution/tech-stack.md`. If decomposition would violate the constitution, surface that to the user rather than papering over it.

## Output shape (per sub-task)

```
### <Goal Title>
- **Type:** Sub-task
- **Description:** <one paragraph: what gets shipped, where it fits in the page/flow>
- **Acceptance Criteria:** <2-4 criteria copied from the matching specs/*.md scenarios>
- **Spec section:** openspec/changes/<change>/specs/<file>.md (heading: <section name>)
- **Source:** openspec/changes/<change>/tasks.md (section <N>)
- **Suggested labels:** <comma-separated>
- **Depends on:** <other goal titles, or "None">
- **Implementation hints:** <key files / patterns from constitution / API endpoints from the integration goal>
```

## Example: "Dashboard page" story

Story (PO-written): *"As an employee, I want a dashboard page that gives me a quick overview of my workday: a clock-in/out control, my recent clock-in history, and a custom panel for upcoming events."*

OpenSpec generation produces `tasks.md` with three sections:
```
## 1. Clock-in panel
## 2. Clock-in history panel
## 3. Frontend↔backend integration for dashboard data
```

Sub-tasks derived from those sections:

```
### Clock-in panel
- **Type:** Sub-task
- **Description:** Build the dashboard's clock-in/out control. Renders current
  state (clocked in / not), exposes a primary action button, shows the running
  timer when active. Lives in src/app/(dashboard)/page.tsx as the first panel.
- **Acceptance Criteria:**
  - The panel shows "Clock in" when the user is not clocked in.
  - Clicking "Clock in" starts the timer and updates to "Clocked in since HH:MM".
  - Clicking "Clock out" stops the timer and posts the entry.
- **Spec section:** openspec/changes/dashboard-page/specs/clock-in-panel.md
- **Source:** openspec/changes/dashboard-page/tasks.md (section 1)
- **Suggested labels:** dashboard,clock-in
- **Depends on:** None
- **Implementation hints:** Use the existing useTimeTracker hook; render via the
  shared Card primitive from src/components/ui/.

### Clock-in history panel
- **Type:** Sub-task
- **Description:** ...

### Frontend↔backend integration for dashboard data
- **Type:** Sub-task
- **Description:** Wire both panels to the dashboard data endpoint. Implement
  the API client, types, and TanStack Query hook. Handle loading and error
  states for each panel.
- **Spec section:** openspec/changes/dashboard-page/specs/dashboard-data.md
- **Source:** openspec/changes/dashboard-page/tasks.md (section 3)
- **Depends on:** Clock-in panel, Clock-in history panel
- **Implementation hints:** Endpoint GET /api/v1/dashboard from the API
  contract; types live under src/types/dashboard.ts.
```

## What NOT to do

- **Don't decompose by layer.** "Data layer" / "UI scaffolding" / "happy path" / "error states" / "tests" is the wrong granularity here — a sub-task is a user-visible goal, and its layers ship together.
- **Don't create a sub-task per file.** The unit is a behaviour the PO can tick off, not a path on disk.
- **Don't recreate the parent story's full description in every child.** Reference the story key and the spec section instead.
- **Don't add "polish" / "review" / "refactor existing code" sub-tasks** unless the story explicitly asks for them.
- **Don't fabricate goals not in `tasks.md`.** If a needed goal is missing, fix `tasks.md` first, then re-derive sub-tasks.
- **Don't split a goal into sub-tasks that can't ship independently.** Two sub-tasks neither of which is releasable on its own is one sub-task pretending to be two.
