#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Self-test for scripts/check-action-pinning.js. Each case builds a tiny
# .github/workflows tree and asserts the checker's exit code. The cases are
# the gaps found in review of the earlier template copy, so a regression to
# line matching, a global lock set, or a name exemption fails here first.
# Needs bun on PATH. No network.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$here/../check-action-pinning.js"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
pass=0; fail=0
SHA=3d3c42e5aac5ba805825da76410c181273ba90b1

# tree <name> <workflow-yaml> [lock-yaml] — workflow lands at a.yml.
tree() {
  mkdir -p "$work/$1/.github/workflows"
  printf '%s\n' "$2" > "$work/$1/.github/workflows/a.yml"
  [ -n "${3:-}" ] && printf '%s\n' "$3" > "$work/$1/.github/workflows/actions.lock"
  return 0
}
expect() { # expect <label> <want-exit> <name>
  bun "$checker" --root "$work/$3" > "$work/$3.out" 2>&1; local rc=$?
  if [ "$rc" -eq "$2" ]; then pass=$((pass+1)); echo "ok   $1"
  else fail=$((fail+1)); echo "FAIL $1 (want $2, got $rc)"; sed 's/^/     /' "$work/$3.out"; fi
}
lock() { # lock <workflow-list-entry> <dep-key> <ref> <commit>
  printf "version: 'v0.0.3'\nworkflows:\n    '.github/workflows/a.yml':\n        - '%s'\ndependencies:\n    '%s':\n        ref: '%s'\n        commit: 'sha1-%s'\n        owner_id: 1\n        repo_id: 2\n" "$1" "$2" "$3" "$4"
}
LOCKED="$(lock actions/checkout@v7.0.1 actions/checkout@v7.0.1 v7.0.1 $SHA)"
step() { printf 'on: push\njobs:\n  j:\n    runs-on: ubuntu-24.04\n    steps:\n      %s\n' "$1"; }

tree sha        "$(step "- uses: actions/checkout@$SHA")"
expect "inline SHA, no lock: pass" 0 sha
tree tag        "$(step "- uses: actions/checkout@v7.0.1")"
expect "tag, no lock: fail" 1 tag
tree locked     "$(step "- uses: actions/checkout@v7.0.1")" "$LOCKED"
expect "tag listed and resolved by lock: pass" 0 locked
tree quoted     "$(step "- uses: \"actions/checkout@v7.0.1\"")" "$LOCKED"
expect "quoted ref is decoded, then locked: pass" 0 quoted
tree quotedsha  "$(step "- uses: 'actions/checkout@$SHA'")"
expect "quoted inline SHA: pass" 0 quotedsha
tree flow       "$(step '- { uses: "octo-org/tool@main" }')"
expect "flow-style step is seen: fail" 1 flow
tree script     "$(step "- uses: evil-actions/github-script@main")"
expect "no github-script name exemption (evil-actions): fail" 1 script
tree script2    "$(step "- uses: actions/github-script@main")"
expect "no github-script name exemption (actions): fail" 1 script2
tree otherwf    "$(step "- uses: actions/checkout@v7.0.1")" "$(lock actions/cache@v6.1.0 actions/checkout@v7.0.1 v7.0.1 $SHA)"
expect "record exists but not listed under this workflow: fail" 1 otherwf
tree norecord   "$(step "- uses: actions/checkout@v7.0.1")" "$(lock actions/checkout@v7.0.1 actions/cache@v6.1.0 v6.1.0 $SHA)"
expect "listed but no dependency record: fail" 1 norecord
tree badcommit  "$(step "- uses: actions/checkout@v7.0.1")" "$(lock actions/checkout@v7.0.1 actions/checkout@v7.0.1 v7.0.1 not-a-sha)"
expect "dependency record without a commit: fail" 1 badcommit
tree reftag     "$(step "- uses: actions/checkout@v7.0.1")" "$(lock actions/checkout@v7.0.1 actions/checkout@v7.0.1 v9.9.9 $SHA)"
expect "record ref does not match its key: fail" 1 reftag
tree subpath    "$(step "- uses: github/codeql-action/init@v4")" "$(lock github/codeql-action@v4 github/codeql-action@v4 v4 $SHA)"
expect "subpath action keyed by repo root: pass" 0 subpath
tree case       "$(step "- uses: SonarSource/scan@v1")" "$(lock sonarsource/scan@v1 sonarsource/scan@v1 v1 $SHA)"
expect "owner case-insensitive: pass" 0 case
tree local      "$(step "- uses: ./.github/actions/x")"
expect "local action is not a GitHub ref: pass" 0 local
tree reusable   "$(printf 'on: push\njobs:\n  r:\n    uses: o/r/.github/workflows/x.yml@main\n')"
expect "job-level reusable on a branch: fail" 1 reusable
tree reusable2  "$(printf 'on: push\njobs:\n  r:\n    uses: o/r/.github/workflows/x.yml@%s\n' $SHA)" "$LOCKED"
expect "job-level reusable SHA-pinned, absent from lock: pass" 0 reusable2
tree broken     "on: [push"
expect "unparsable workflow is an error, not a pass: fail" 1 broken

echo
echo "check-action-pinning-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
