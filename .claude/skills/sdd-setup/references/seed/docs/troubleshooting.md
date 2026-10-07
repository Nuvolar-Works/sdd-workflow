# Troubleshooting

Run `/sdd-doctor` first — it checks config, tracker reachability, tools and OpenSpec state.

| Problem | Solution |
|---------|----------|
| `gh: command not found` | Install GitHub CLI: `brew install gh` then `gh auth login` |
| `openspec: command not found` | Install OpenSpec: `npm install -g @fission-ai/openspec@latest` |
| Bitbucket call exits with code 2 or HTTP 401/403 | Exit 2: the `origin` remote or the auth env vars are missing. 401/403: the token is invalid or lacks scopes. See [trackers.md § Bitbucket auth](trackers.md#bitbucket-auth), then restart the session. |
| Skills don't appear as slash commands | Restart Claude Code. Skills are discovered on startup. |
| Commit blocked by hook | Your commit message doesn't follow conventional commits. Use `type(scope): description` format. |
| `/sdd-doctor` reports tracker unreachable | Check `sdd/config.json` and that the relevant MCP is running. |
| `/sdd-create-tickets` says "no tasks.md" | Run `/openspec-propose` or `/sdd-from-prd` first to generate the specs. |
| `/sdd-work` warns about open dependencies | A blocking ticket hasn't been closed yet. Close it or proceed with caution. |
| `/sdd-verify` reports FAIL on criteria | Fix the failing criteria before the PR can be created. |
| `/sdd-staged` suggests using `/sdd-from-prd` | Your PRD is too small for staging. Use `/sdd-from-prd` or override if you still want stages. |
| `/sdd-tasks-from-story` not available | Requires Jira tracker mode. Check `sdd/config.json`. |
| Archive failed or left half-written specs | See [archiving.md § Archiving procedure](archiving.md#archiving-procedure) — the snapshot restore covers this. |
