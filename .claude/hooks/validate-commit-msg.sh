#!/bin/bash
# Validates that git commit messages follow conventional commits format.
# Used as a PreToolUse hook for the Bash tool.
# Exit 0 = allow, Exit 2 = block with feedback.

INPUT=$(cat)
command -v jq >/dev/null || { echo 'validate-commit-msg: jq not installed; commit not validated' >&2; exit 0; }
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# Only check git commit commands (also when chained or run as `git -C <dir> commit`)
if ! printf '%s\n' "$COMMAND" | grep -qE '(^|[;&|(])[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

MSG=""

# Heredoc-style: -m "$(cat <<'EOF'\n...\nEOF\n)" — subject is the first line after `cat <<`
if printf '%s\n' "$COMMAND" | grep -qE -- '-[a-zA-Z]*m[[:space:]]+"\$\(cat <<'; then
  MSG=$(printf '%s\n' "$COMMAND" | sed -n '/cat <</{n;s/^[[:space:]]*//;p;q;}')
fi

# First -m / -am / --message= on a single line (the first -m is the subject)
FLAT=$(printf '%s' "$COMMAND" | tr '\n' ' ' | sed -E 's/git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)/@@COMMIT@@ /' | sed 's/^.*@@COMMIT@@//')
if [ -z "$MSG" ]; then
  MSG=$(printf '%s\n' "$FLAT" | grep -oE -- "(^|[[:space:]])(-[a-zA-Z]*m[[:space:]]*|--message=)(\"[^\"]*\"|'[^']*')" | head -1 \
    | sed -e 's/^[[:space:]]*//' -e 's/^-[a-zA-Z]*m[[:space:]]*//' -e 's/^--message=//' -e 's/^["'"'"']//' -e 's/["'"'"']$//')
fi

# If we could not extract a message, allow it (might be --amend, -F or interactive)
if [ -z "$MSG" ]; then
  exit 0
fi

# Validate conventional commit format: type(scope): description
PATTERN='^(feat|fix|docs|style|refactor|test|chore|build|ci)(\(.+\))?: .+'

if ! printf '%s\n' "$MSG" | grep -qE "$PATTERN"; then
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
