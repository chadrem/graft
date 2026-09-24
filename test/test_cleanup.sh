# What happens after claude exits. $FAKE_DO runs "during the session".

test_clean_worktree_prints_delete_command() {
  mk x; n=$MADE
  assert_contains "$OUT" "has no unlanded work"
  assert_contains "$OUT" "Delete:  git worktree remove --force"
  assert_dir "$(wt_path "$n")"
}

test_keeps_uncommitted_changes() {
  export FAKE_DO='echo x > new.txt'
  mk x
  assert_contains "$OUT" "(uncommitted changes)"
}

test_keeps_unlanded_commits() {
  export FAKE_DO='echo x > f && git add f && git commit -qm work'
  mk x
  assert_contains "$OUT" "(1 commit(s) not yet landed on main)"
}

test_keeps_during_merge() {
  export FAKE_DO='touch "$(git rev-parse --absolute-git-dir)/MERGE_HEAD"'
  mk x
  assert_contains "$OUT" "still in progress"
}

test_landed_work_is_offered_for_delete() {
  export FAKE_DO='echo x > f && git add f && git commit -qm work'
  mk x; n=$MADE
  git merge -q "graft/$n"
  unset FAKE_DO
  run_graft "$n"
  assert_status 0
  assert_contains "$OUT" "has no unlanded work"
}

test_worktree_removed_during_session() {
  export FAKE_DO='git -C "$REPO" worktree remove --force "$PWD"'
  run_graft
  assert_status 0
  assert_contains "$OUT" "is gone (removed during the session)"
}

test_prompt_yes_deletes() {
  mk x; n=$MADE
  run_graft_tty y "$n"
  assert_contains "$OUT" "Removed worktree '$n'"
  assert_no_dir "$(wt_path "$n")"
  assert_no_branch "graft/$n"
}

test_prompt_default_keeps() {
  mk x; n=$MADE
  run_graft_tty '' "$n"
  assert_contains "$OUT" "Kept. Reopen:"
  assert_dir "$(wt_path "$n")"
  assert_branch "graft/$n"
}
