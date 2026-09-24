# .graftrc and environment variables.

test_graftrc_is_read() {
  echo 'GRAFT_BRANCH_PREFIX=me/' > .graftrc
  mk x; n=$MADE
  assert_branch "me/$n"
}

test_env_beats_graftrc() {
  echo 'GRAFT_BRANCH_PREFIX=me/' > .graftrc
  export GRAFT_BRANCH_PREFIX=env/
  mk x; n=$MADE
  assert_branch "env/$n"
  assert_no_branch "me/$n"
}

test_worktree_dir_is_configurable() {
  echo '/wts/' >> .gitignore && git commit -qam "ignore wts"
  export GRAFT_WORKTREE_DIR=wts
  mk x; n=$MADE
  assert_dir "$REPO/wts/$n"
  assert_not_contains "$ERR" "is not gitignored"
}

test_base_branch_is_configurable() {
  git branch -q release
  git commit -q --allow-empty -m "main moves on"
  export GRAFT_BASE_BRANCH=release
  mk x; n=$MADE
  assert_contains "$OUT" "(from release)"
  assert_eq "$(git -C "$(wt_path "$n")" rev-parse HEAD)" "$(git rev-parse release)"
}
