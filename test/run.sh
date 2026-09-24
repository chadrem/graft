#!/usr/bin/env bash
# Runs the graft test suite: every test_* function in test/test_*.sh, each in
# its own bash process and sandbox.
#
# Usage: test/run.sh [filter]   only tests whose name contains <filter>
#
# Each test runs in a fresh process rather than a subshell because bash
# ignores set -e inside anything tested by `if`, which is how results are read.
set -u

here=$(cd "$(dirname "$0")" && pwd)
filter=${1:-}
pass=0
failed=()

for file in "$here"/test_*.sh; do
  for t in $(sed -n 's/^\(test_[A-Za-z0-9_]*\)() *{.*/\1/p' "$file"); do
    case $t in *"$filter"*) ;; *) continue ;; esac
    if out=$(bash -c 'set -euo pipefail; . "$1"; . "$2"; setup; "$3"' _ \
               "$here/lib.sh" "$file" "$t" 2>&1); then
      pass=$(( pass + 1 ))
      echo "ok    $t"
    else
      failed+=("$t")
      echo "FAIL  $t"
      printf '%s\n' "$out" | sed 's/^/      /'
    fi
  done
done

echo
echo "$pass passed, ${#failed[@]} failed ($(uname -s))"
[ "${#failed[@]}" -eq 0 ]
