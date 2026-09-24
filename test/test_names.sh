# Names are never reused: anything that ever claimed a name keeps it.

test_skips_name_with_old_conversations() {
  taken="x-$(stamp)"
  mkdir -p "$(project_dir "$(wt_path "$taken")")"
  mk x; n=$MADE
  [ "$n" != "$taken" ] || fail "reused '$taken', which has a transcript directory"
}

test_skips_name_with_local_branch() {
  taken="x-$(stamp)"
  git branch -q "graft/$taken"
  mk x; n=$MADE
  [ "$n" != "$taken" ] || fail "reused '$taken', which has a local branch"
}

test_skips_name_with_remote_branch() {
  taken="x-$(stamp)"
  git update-ref "refs/remotes/origin/graft/$taken" HEAD
  mk x; n=$MADE
  [ "$n" != "$taken" ] || fail "reused '$taken', which has a remote branch"
}

test_full_id_rebuilds_that_exact_path() {
  d=$(project_dir "$(wt_path old-0101-1200)")
  mkdir -p "$d" && echo '{}' > "$d/1.jsonl"
  run_graft old-0101-1200
  assert_status 0
  assert_eq "$(created)" old-0101-1200
  assert_contains "$ERR" "hosted Claude sessions before"
}

test_new_with_full_id_keeps_it() {
  mk spike-0101-1200; n=$MADE
  assert_eq "$n" spike-0101-1200
}
