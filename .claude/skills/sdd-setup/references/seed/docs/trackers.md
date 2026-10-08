# Trackers and git hosts

`sdd/config.json` (written by `/sdd-setup`, committed, contains no secrets) is the single source of truth for which tracker and git host are active. See [`config.example.json`](../config.example.json) for the full shape: `tracker`, `vcs`, `base_branch`, Bitbucket repo, and the Jira project key, issue-type map, linked-task type and status workflow.

| Mode | tracker | vcs | Tickets | Code/PRs |
|------|---------|-----|---------|----------|
| GitHub | github | github | GitHub Issues | GitHub |
| Jira | jira | github | Jira | GitHub (PRs reference Jira keys; statuses synced to Jira) |
| Jira + Bitbucket | jira | bitbucket | Jira | Bitbucket Cloud |

`/sdd-setup` detects the GitHub CLI, a Jira MCP, and the git host from the `origin` remote, then asks which mode to use (Jira + Bitbucket is offered when the remote is on bitbucket.org).

## Adapters

Skills call abstract operations defined in [`trackers/protocol.md`](../trackers/protocol.md); each adapter implements them:

- [`trackers/github.md`](../trackers/github.md) — GitHub Issues and PRs via the `gh` CLI
- [`trackers/jira.md`](../trackers/jira.md) — Jira via the Jira MCP
- [`trackers/bitbucket.md`](../trackers/bitbucket.md) + `bitbucket.sh` — Bitbucket Cloud PRs via REST (curl + jq)

## Bitbucket auth

Tokens never go in `sdd/config.json`. Create an Atlassian API token (Atlassian account → Security → API tokens) with scopes `read:repository:bitbucket`, `read:pullrequest:bitbucket`, `write:pullrequest:bitbucket`, and export in your shell profile:

```bash
export BITBUCKET_EMAIL=you@example.com
export BITBUCKET_API_TOKEN=...
```

`BITBUCKET_ACCESS_TOKEN` (a workspace/project/repository access token, sent as Bearer) works instead. Git pushes use the remote's own credentials, not these.

## PR behaviour per tracker

- **GitHub** — the issue is closed when the PR opens.
- **Jira** — the PR body says `Resolves <KEY>` and the ticket moves to In Review; `/sdd-status` moves it to Done after merge.
