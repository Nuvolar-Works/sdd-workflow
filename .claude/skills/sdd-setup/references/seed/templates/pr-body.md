# PR Body Template

Used by `/sdd-verify` when creating pull requests. Substitute the placeholders before passing to `gh pr create --body`.

```markdown
## Summary
<2-3 sentence summary of what this PR does and why>

## Changes
- <Bulleted list of key changes made>
- <Each bullet should be a single, scannable line>

## Acceptance Criteria
- [x] <criterion 1 from the linked ticket>
- [x] <criterion 2>
<all original criteria, all checked off>

## Testing
<What was tested and how — automated tests added/updated, manual verification steps>

<TICKET_CLOSE_LINE>
```

`TICKET_CLOSE_LINE` is one of:
- GitHub: `Closes #<issue-number>`
- Jira: `Resolves <JIRA-KEY>` (also call `LinkTicketToPR` to comment on the Jira ticket)

## Title format

Conventional commit, with the ticket reference at the end:

- GitHub: `<type>(<scope>): <description from issue title> (#<issue-number>)`
- Jira: `<type>(<scope>): <description from story summary> [<JIRA-KEY>]`

`<scope>` is the area of the codebase touched (e.g. `auth`, `time-tracking`, `admin-panel`). Match existing PR titles in the repo's history for consistency.
