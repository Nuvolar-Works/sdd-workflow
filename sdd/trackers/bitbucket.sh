#!/usr/bin/env bash
# Bitbucket Cloud REST helper for sdd/trackers/bitbucket.md.
#
# Usage: bash sdd/trackers/bitbucket.sh <METHOD> <path> [key=value ...]
#   <path> is relative to /2.0/repositories/<workspace>/<repo_slug> ("" for the repo itself).
#   key=value pairs become URL-encoded query parameters (repeat a key to repeat the parameter).
#   For POST/PUT, the JSON body is read from stdin.
#
# Examples:
#   bash sdd/trackers/bitbucket.sh GET ""
#   bash sdd/trackers/bitbucket.sh GET /pullrequests 'q=source.branch.name="feat/42-x"' state=OPEN state=MERGED
#   jq -n '{title:"t"}' | bash sdd/trackers/bitbucket.sh POST /pullrequests
#
# Auth (environment, never sdd/config.json):
#   BITBUCKET_ACCESS_TOKEN                   Bearer: API token or workspace/project/repository access token
#   BITBUCKET_EMAIL + BITBUCKET_API_TOKEN    Basic: Atlassian account email + API token
# Repo: bitbucket.workspace / bitbucket.repo_slug in sdd/config.json, else parsed from the origin remote.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: bitbucket.sh <METHOD> <path> [key=value ...]" >&2
  exit 2
fi
method=$1
path=$2
shift 2

ws=""
slug=""
if [[ -f sdd/config.json ]] && command -v jq >/dev/null; then
  ws=$(jq -r '.bitbucket.workspace // empty' sdd/config.json)
  slug=$(jq -r '.bitbucket.repo_slug // empty' sdd/config.json)
fi
if [[ -z $ws || -z $slug ]]; then
  remote=$(git remote get-url origin 2>/dev/null || true)
  re='bitbucket\.org[:/]([^/]+)/([^/]+)$'
  if [[ ! $remote =~ $re ]]; then
    echo "bitbucket.sh: origin ($remote) is not a bitbucket.org remote; set bitbucket.workspace and bitbucket.repo_slug in sdd/config.json" >&2
    exit 2
  fi
  ws=${ws:-${BASH_REMATCH[1]}}
  slug=${slug:-${BASH_REMATCH[2]%.git}}
fi

if [[ -n ${BITBUCKET_ACCESS_TOKEN:-} ]]; then
  auth=(-H "Authorization: Bearer $BITBUCKET_ACCESS_TOKEN")
elif [[ -n ${BITBUCKET_EMAIL:-} && -n ${BITBUCKET_API_TOKEN:-} ]]; then
  auth=(-u "$BITBUCKET_EMAIL:$BITBUCKET_API_TOKEN")
else
  echo "bitbucket.sh: set BITBUCKET_ACCESS_TOKEN, or BITBUCKET_EMAIL and BITBUCKET_API_TOKEN" >&2
  exit 2
fi

args=(-sS --fail-with-body -X "$method" "${auth[@]}" -H "Accept: application/json")
if [[ $method == GET ]]; then
  [[ $# -gt 0 ]] && args+=(-G)
  for kv in "$@"; do
    args+=(--data-urlencode "$kv")
  done
else
  args+=(-H "Content-Type: application/json" --data-binary @-)
fi

curl "${args[@]}" "https://api.bitbucket.org/2.0/repositories/$ws/$slug$path"
