# GIVEN-WHEN-THEN Examples

Reference for translating PRD user stories into testable scenarios in `openspec/changes/<change>/specs/<capability>/spec.md`. Used by `/sdd-from-prd`, `/sdd-staged`, and `/sdd-tasks-from-story` during artifact generation.

## Shape

Each scenario is a single coherent behaviour, written as:

```
GIVEN <preconditions / starting state>
WHEN <user or system action>
THEN <observable outcome>
[AND <additional outcome>]
```

One user story typically becomes 2-5 scenarios: one happy path plus the most likely error / edge cases.

## Examples by category

### UI interaction

```
GIVEN the user is on the time-tracking page
AND they have not clocked in today
WHEN they click "Clock in"
THEN the timer starts
AND the page shows a "Currently working since HH:MM" indicator
```

```
GIVEN the user is clocked in
WHEN they navigate away from the page
THEN the timer continues running on the server
AND returning to the page shows the elapsed time correctly
```

### API integration

```
GIVEN the user submits the registration form with valid input
WHEN a POST request is sent to /api/v1/users with { email, password, name }
THEN the API returns 201 with the created user object
AND the user sees a success message
AND the user is redirected to the dashboard
```

```
GIVEN the user submits the registration form with an email already in use
WHEN a POST request is sent to /api/v1/users
THEN the API returns 409 with { error: "email_taken" }
AND the form shows the error message inline next to the email field
AND the password field is preserved
```

### Authorisation

```
GIVEN a user with role "employee"
WHEN they request /api/admin/users
THEN the API returns 403
AND the UI hides the "Admin" navigation entry entirely
```

### Data correctness

```
GIVEN a timesheet for the month of February in a leap year
WHEN the user opens the month closure view
THEN February shows 29 working-day candidates
AND the closure summary computes overtime against 29-day baseline
```

### Error / network failure

```
GIVEN the user submits a clock-in
WHEN the request fails with a network error
THEN the UI shows a retry banner
AND the local state stays in "not clocked in"
AND no duplicate entry is sent on retry
```

## Mapping rules

- Every scenario should be **independently testable**. Avoid scenarios that depend on prior scenarios' state.
- Use concrete values where they matter (HTTP codes, role names, error messages). Avoid "the system responds appropriately."
- For API scenarios, when an API contract is provided, reference the actual endpoint path and request/response shape.
- Edge cases to consider routinely: empty input, max-size input, concurrent updates, expired session, role boundary, null/undefined intermediate values.
