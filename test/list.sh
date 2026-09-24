#!/usr/bin/env bash
# Smoke test for `graft --list`, meant to pass on both macOS (BSD stat) and
# Linux (GNU stat). Builds a throwaway repo with two worktrees, stands in a
# fake claude that just records a transcript, and checks what --list prints.
#
# Usage: test/list.sh        exits non-zero on the first failure
set -eu

GRAFT="$(cd "$(dirname "$0")/.." && pwd)/graft"
W=$(mktemp -d); W=$(cd "$W" && pwd -P)
trap 'rm -rf "$W"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# A stand-in for claude: write a transcript under this cwd's slug, then exit.
cat > "$W/fake-claude" <<'EOF'
#!/usr/bin/env bash
d="$CLAUDE_CONFIG_DIR/projects/${PWD//[^A-Za-z0-9]/-}"
mkdir -p "$d"
echo '{"type":"user"}' > "$d/$RANDOM.jsonl"
EOF
chmod +x "$W/fake-claude"

export CLAUDE_CONFIG_DIR="$W/claude" GRAFT_CLAUDE_BIN="$W/fake-claude"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset GRAFT_SUBDIR GRAFT_WORKTREE_DIR GRAFT_BRANCH_PREFIX GRAFT_BASE_BRANCH \
      GRAFT_SEED_FILES GRAFT_MAX_NAME

mkdir "$W/repo" && cd "$W/repo"
git init -q && git checkout -q -b main
echo '/.claude/worktrees/' > .gitignore
git add . && git commit -qm init

"$GRAFT" --new alpha </dev/null >/dev/null 2>&1 || fail "graft --new alpha"
"$GRAFT" --new beta  </dev/null >/dev/null 2>&1 || fail "graft --new beta"
alpha=$(ls .claude/worktrees | grep '^alpha-') || fail "no alpha worktree created"
(cd ".claude/worktrees/$alpha" && echo x > f && git add f && git commit -qm "Add alpha feature")

out=$("$GRAFT" --list </dev/null 2>"$W/err") || fail "--list exited non-zero: $(cat "$W/err")"
err=$(cat "$W/err")

[ -z "$err" ] || fail "--list wrote to stderr:
$err"
echo "$out" | grep -q '^  beta-' || fail "beta missing from --list:
$out"
# alpha: AHEAD 1, no dirty files, 1 session, WHAT from its commit.
echo "$out" | grep -Eq "^  $alpha +[0-9]+[mhd] +[0-9]+[mhd] +1 +- +1 +Add alpha feature\$" \
  || fail "alpha row wrong:
$out"

echo "ok: graft --list ($(uname -s))"
