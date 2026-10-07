# Bitbucket Cloud VCS Recipes

Concrete implementations of the `sdd/trackers/protocol.md` **VCS operations** for Bitbucket Cloud (bitbucket.org). Used when `vcs` is `bitbucket` in `sdd/config.json`. Bitbucket is a git host only here — tickets live in Jira (`tracker: jira`).

All API calls go through `sdd/trackers/bitbucket.sh` (curl + jq), which resolves the repo and auth:

- **Repo**: `bitbucket.workspace` / `bitbucket.repo_slug` in `sdd/config.json`, else parsed from the `origin` remote.
- **Auth** (environment variables — never in `sdd/config.json` or the repo): `BITBUCKET_EMAIL` + `BITBUCKET_API_TOKEN` (Atlassian account email + an API token with scopes `read:repository:bitbucket`, `read:pullrequest:bitbucket`, `write:pullrequest:bitbucket`), or `BITBUCKET_ACCESS_TOKEN` for a Bearer token (workspace/project/repository access token). App passwords are retired.

`BB` below is shorthand for `bash sdd/trackers/bitbucket.sh`. Git pushes use the remote's own credentials, not these.

## VerifyVcsAuth()

```bash
bash sdd/trackers/bitbucket.sh GET "" | jq -r '.full_name'
```

Exit code 2 means the remote or auth env vars are missing (the message says which); an HTTP 401/403 means the token is invalid or lacks scopes. Tell the user to create an API token (Atlassian account → Security → API tokens, Bitbucket scopes above), export the env vars in their shell profile, and re-run `/sdd-setup`. Stop.

## CreateBranch(name, base)

```bash
git fetch origin <base>
git checkout -b <name> origin/<base>
```

## PushBranch(name)

```bash
git push -u origin <name>
```

## CreatePR(payload)

Callers check `GetCurrentPR()` first (reuse an `OPEN` PR; stop on `MERGED` / `CLOSED`).

```bash
jq -n --arg title "<title>" --arg body "$(cat <<'PR_EOF'
<body>
PR_EOF
)" --arg head "<current-branch>" --arg base "<base>" \
  '{title: $title, description: $body, source: {branch: {name: $head}}, destination: {branch: {name: $base}}, close_source_branch: true}' \
  | bash sdd/trackers/bitbucket.sh POST /pullrequests \
  | jq '{number: .id, url: .links.html.href}'
```

The description renders Markdown. Bitbucket does not close Jira issues from `Resolves <KEY>`; the Jira recipe's `LinkTicketToPR` handles the ticket.

## GetCurrentPR(detail?)

```bash
bash sdd/trackers/bitbucket.sh GET /pullrequests \
  "q=source.branch.name=\"$(git branch --show-current)\"" \
  state=OPEN state=MERGED state=DECLINED state=SUPERSEDED sort=-updated_on pagelen=1 \
  | jq '.values[0] // null | if . == null then null else {number: .id, url: .links.html.href,
        state: (if .state == "DECLINED" or .state == "SUPERSEDED" then "CLOSED" else .state end)} end'
```

With `detail = true`, also fetch the PR itself (the list omits participants), its comments and its build statuses:

```bash
bash sdd/trackers/bitbucket.sh GET /pullrequests/<number> | jq '{
  review_decision: (if any(.participants[]; .state == "changes_requested") then "CHANGES_REQUESTED"
                    elif any(.participants[]; .approved) then "APPROVED" else "NONE" end),
  reviews: [.participants[] | select(.state != null) | {author: .user.display_name, state: (.state | ascii_upcase), body: ""}]}'

bash sdd/trackers/bitbucket.sh GET /pullrequests/<number>/comments pagelen=100 | jq '.values | map(select(.deleted | not)) | {
  comments: [.[] | select(.inline | not) | {author: .user.display_name, created_at: .created_on, body: .content.raw}],
  inline_comments: [.[] | select(.inline) | {author: .user.display_name, path: .inline.path, line: (.inline.to // .inline.from), body: .content.raw}]}'

bash sdd/trackers/bitbucket.sh GET /pullrequests/<number>/statuses pagelen=100 | jq '{checks: [.values[] | {name: (.name // .key),
  state: ({"SUCCESSFUL": "SUCCESS", "FAILED": "FAILURE", "STOPPED": "FAILURE", "INPROGRESS": "PENDING"}[.state]), url}]}'
```

Bitbucket reviews carry no text — reviewer feedback is in `comments` / `inline_comments`. `checks` holds whatever reports build statuses to the PR (Bitbucket Pipelines, Jenkins, Bamboo, …). If a response has a `next` link, more than 100 items exist; fetch it too.

## GetPR(number)

```bash
bash sdd/trackers/bitbucket.sh GET /pullrequests/<number> | jq '{number: .id, url: .links.html.href,
  state: (if .state == "DECLINED" or .state == "SUPERSEDED" then "CLOSED" else .state end),
  merged_at: (if .state == "MERGED" then .updated_on else null end)}'
```

Bitbucket has no merge timestamp; `updated_on` of a merged PR is the closest value.

## ParsePRUrl(text)

First match of `https?://bitbucket\.org/[^/]+/[^/]+/pull-requests/(\d+)`.
