# Help, startup checks and base-branch detection.

test_help_exits_zero() {
  run_graft --help
  assert_status 0
  assert_contains "$OUT" "Usage:"
  run_graft -h
  assert_status 0
}

test_help_works_outside_a_repo() {
  cd "$W"
  run_graft --help
  assert_status 0
}

test_outside_a_repo_errors() {
  cd "$W"
  run_graft --list
  assert_status 1
  assert_contains "$ERR" "not inside a git repository"
}

test_missing_claude_errors() {
  export GRAFT_CLAUDE_BIN=no-such-claude-bin
  run_graft
  assert_status 1
  assert_contains "$ERR" "'no-such-claude-bin' is not on PATH"
}

test_unknown_base_branch_errors() {
  export GRAFT_BASE_BRANCH=nope
  run_graft
  assert_status 1
  assert_contains "$ERR" "GRAFT_BASE_BRANCH is 'nope'"
}

test_no_default_branch_errors() {
  git branch -q -m main dev
  run_graft
  assert_status 1
  assert_contains "$ERR" "could not work out this repo's default branch"
}

test_falls_back_to_master() {
  git branch -q -m main master
  run_graft
  assert_status 0
  assert_contains "$OUT" "(from master)"
}

test_origin_head_beats_main() {
  git branch -q develop
  git update-ref refs/remotes/origin/develop HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  run_graft
  assert_status 0
  assert_contains "$OUT" "(from develop)"
}
