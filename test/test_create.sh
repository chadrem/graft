# Creating worktrees: names, branches, what claude is launched with.

test_bare_graft_creates_a_worktree() {
  run_graft
  assert_status 0
  n=$(created)
  assert_match "$n" '^wt-[0-9]{4}-[0-9]{4}[a-z]?$'
  assert_dir "$(wt_path "$n")"
  assert_branch "graft/$n"
  log_has "cwd=$(wt_path "$n")" || fail "claude did not start in the worktree"
}

test_new_label_gets_a_stamp() {
  mk fix-login; n=$MADE
  assert_match "$n" '^fix-login-[0-9]{4}-[0-9]{4}[a-z]?$'
}

test_same_label_twice_gets_two_names() {
  mk x; a=$MADE
  mk x; b=$MADE
  [ "$a" != "$b" ] || fail "both runs got '$a'"
  assert_contains "$OUT" "(1 other worktree(s)"
}

test_forks_from_base_not_current_branch() {
  git checkout -q -b other
  git commit -q --allow-empty -m "on other"
  mk x; n=$MADE
  assert_eq "$(git -C "$(wt_path "$n")" rev-parse HEAD)" "$(git rev-parse main)"
}

test_passes_args_through_to_claude() {
  run_graft --new x -p "hello world"
  assert_status 0
  log_has "arg=-p" || fail "missing -p"
  log_has "arg=hello world" || fail "missing prompt arg"
}

test_returns_claudes_exit_status() {
  export FAKE_EXIT=3
  run_graft
  assert_status 3
}

test_label_too_long_errors() {
  run_graft --new abcdefghijklmnopqrst
  assert_status 1
  assert_contains "$ERR" "no free name for label"
  assert_no_dir "$REPO/.claude/worktrees/abcdefghijklmnopqrst"
}

test_max_name_is_configurable() {
  export GRAFT_MAX_NAME=40
  mk abcdefghijklmnopqrst; n=$MADE
  assert_match "$n" '^abcdefghijklmnopqrst-'
}

test_rejects_bad_names() {
  for bad in 'a/b' '.hidden' '..' 'a b' 'semi;colon'; do
    run_graft --new "$bad"
    [ "$STATUS" -eq 1 ] || fail "'$bad' was accepted"
  done
  [ -z "$(git branch --list 'graft/*')" ] || fail "a branch was created"
}

test_warns_when_worktree_dir_not_ignored() {
  echo '.env' > .gitignore
  git commit -qam "stop ignoring worktrees"
  run_graft
  assert_status 0
  assert_contains "$ERR" "is not gitignored"
}

test_no_warning_when_ignored() {
  run_graft
  assert_not_contains "$ERR" "is not gitignored"
}
