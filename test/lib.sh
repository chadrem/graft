# Shared setup and assertions for the graft test suite. Sourced by run.sh into
# a fresh bash process per test, so every test gets its own sandbox and a
# failing assertion only ends that test.

GRAFT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/graft"

# A throwaway repo with one commit on main, a fake claude, and a private
# CLAUDE_CONFIG_DIR. Leaves the cwd at the repo root.
setup() {
  W=$(mktemp -d); W=$(cd "$W" && pwd -P)
  trap 'rm -rf "$W"' EXIT
  REPO=$W/repo
  export W REPO
  export CLAUDE_CONFIG_DIR=$W/claude GRAFT_CLAUDE_BIN=$W/bin/claude
  export FAKE_LOG=$W/claude.log
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  unset GRAFT_SUBDIR GRAFT_WORKTREE_DIR GRAFT_BRANCH_PREFIX GRAFT_BASE_BRANCH \
        GRAFT_SEED_FILES GRAFT_MAX_NAME FAKE_DO FAKE_EXIT FAKE_NO_TRANSCRIPT COLUMNS

  # Stands in for claude. Logs its cwd and args (last call only), records a
  # transcript the way Claude Code does, then runs $FAKE_DO so a test can act
  # "during the session".
  mkdir -p "$W/bin"
  cat > "$W/bin/claude" <<'EOF'
#!/usr/bin/env bash
{ printf 'cwd=%s\n' "$PWD"; for a in "$@"; do printf 'arg=%s\n' "$a"; done; } > "$FAKE_LOG"
if [ -z "${FAKE_NO_TRANSCRIPT:-}" ]; then
  d="$CLAUDE_CONFIG_DIR/projects/${PWD//[^A-Za-z0-9]/-}"
  mkdir -p "$d" && echo '{}' > "$d/$$-$RANDOM.jsonl"
fi
if [ -n "${FAKE_DO:-}" ]; then eval "$FAKE_DO"; fi
exit "${FAKE_EXIT:-0}"
EOF
  chmod +x "$W/bin/claude"

  mkdir "$REPO" && cd "$REPO"
  git init -q && git checkout -q -b main
  printf '/.claude/worktrees/\n.env\n' > .gitignore
  git add . && git commit -qm init
}

# Runs graft non-interactively. Sets OUT, ERR and STATUS; never trips set -e.
run_graft() {
  OUT=$("$GRAFT" "$@" </dev/null 2>"$W/err") && STATUS=0 || STATUS=$?
  ERR=$(cat "$W/err")
}

# Runs graft on a pseudo-terminal so the exit prompt fires, answering $1.
# The answer is typed late and the pipe held open, because BSD script(1)
# turns end-of-input into a ^D straight away, which would beat the prompt.
# util-linux and BSD script take their arguments differently.
run_graft_tty() {
  local input=$1; shift
  typed() { sleep 2; printf '%s\n' "$input"; sleep 1; }
  if script --version 2>/dev/null | grep -q util-linux; then
    OUT=$(typed | script -qec "$(printf '%q ' "$GRAFT" "$@")" /dev/null 2>&1) && STATUS=0 || STATUS=$?
  else
    OUT=$(typed | script -q /dev/null "$GRAFT" "$@" 2>&1) && STATUS=0 || STATUS=$?
  fi
}

# Creates a worktree and sets MADE to its name, failing the test if that
# fails. Not a $(...) helper, so the run's OUT and ERR stay visible.
mk() {
  run_graft --new "$@"
  assert_status 0
  MADE=$(created)
}

# The name from the last run's "Created worktree <name>" line.
created() { printf '%s\n' "$OUT" | sed -n 's/^Created worktree //p'; }

wt_path() { printf '%s' "$REPO/.claude/worktrees/$1"; }
slug() { printf '%s' "${1//[^A-Za-z0-9]/-}"; }
project_dir() { printf '%s' "$CLAUDE_CONFIG_DIR/projects/$(slug "$1")"; }
stamp() { date +%m%d-%H%M; }
log_has() { grep -qxF -- "$1" "$FAKE_LOG"; }

fail() { echo "  $*" >&2; exit 1; }

assert_status() {
  [ "$STATUS" -eq "$1" ] || fail "expected exit $1, got $STATUS
  stdout: $OUT
  stderr: ${ERR:-}"
}
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
assert_match() { [[ $1 =~ $2 ]] || fail "'$1' does not match /$2/"; }
assert_contains() {
  case $1 in *"$2"*) ;; *) fail "expected to find '$2' in:
$1" ;; esac
}
assert_not_contains() {
  case $1 in *"$2"*) fail "did not expect '$2' in:
$1" ;; esac
}
assert_dir() { [ -d "$1" ] || fail "missing directory $1"; }
assert_no_dir() { [ ! -d "$1" ] || fail "directory should not exist: $1"; }
assert_branch() { git -C "$REPO" show-ref --verify --quiet "refs/heads/$1" || fail "missing branch $1"; }
assert_no_branch() { ! git -C "$REPO" show-ref --verify --quiet "refs/heads/$1" || fail "branch should not exist: $1"; }
