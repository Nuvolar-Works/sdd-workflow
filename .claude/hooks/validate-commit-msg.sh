#!/bin/bash
# Validates that git commit messages follow conventional commits format.
# Used as a PreToolUse hook for the Bash tool.
# Exit 0 = allow, Exit 2 = block with feedback.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check git commit commands
if ! echo "$COMMAND" | grep -qE '^git commit '; then
  exit 0
fi

# Extract the commit message from -m "..." flag
MSG=$(echo "$COMMAND" | sed -n 's/.*-m "\([^"]*\)".*/\1/p')

# Try single quotes if double quotes didn't match
if [ -z "$MSG" ]; then
  MSG=$(echo "$COMMAND" | sed -n "s/.*-m '\\([^']*\\)'.*/\\1/p")
fi

# Try heredoc-style: -m "$(cat <<'EOF'\n...\nEOF\n)"
if [ -z "$MSG" ]; then
  MSG=$(echo "$COMMAND" | sed -n '/cat <</{n;s/^[[:space:]]*//;p;q;}')
fi

# If we could not extract a message, allow it (might be --amend or interactive)
if [ -z "$MSG" ]; then
  exit 0
fi

# Validate conventional commit format: type(scope): description
PATTERN='^(feat|fix|docs|style|refactor|test|chore|build|ci)(\(.+\))?: .+'

if ! echo "$MSG" | grep -qE "$PATTERN"; then
  echo "BLOCKED: Commit message does not follow conventional commits format." >&2
  echo "" >&2
  echo "Expected: type(scope): description" >&2
  echo "Types: feat, fix, docs, style, refactor, test, chore, build, ci" >&2
  echo "Example: feat(auth): add login form (#42)" >&2
  echo "" >&2
  echo "Your message: $MSG" >&2
  exit 2
fi

exit 0
