# Reopening: how a bare name is matched, re-attaching, and -c.

test_reopen_exact_name() {
  mk alpha-0101-1200
  run_graft alpha-0101-1200
  assert_status 0
  assert_contains "$OUT" "Reopening alpha-0101-1200"
  log_has "cwd=$(wt_path alpha-0101-1200)" || fail "claude not started in the worktree"
  assert_eq "$(ls .claude/worktrees | wc -l | tr -d ' ')" 1
}

test_reopen_by_prefix() {
  mk alpha-0101-1200
  run_graft alp
  assert_status 0
  assert_contains "$OUT" "'alp' -> alpha-0101-1200"
}

test_reopen_by_substring() {
  mk alpha-0101-1200
  run_graft pha
  assert_status 0
  assert_contains "$OUT" "'pha' -> alpha-0101-1200"
}

test_reopen_ignores_case() {
  mk alpha-0101-1200
  run_graft ALPHA
  assert_status 0
  assert_contains "$OUT" "Reopening alpha-0101-1200"
}

test_ambiguous_name_errors() {
  mk alpha-0101-1200
  mk alpha-0102-1200
  run_graft alpha
  assert_status 1
  assert_contains "$ERR" "matches more than one worktree"
}

test_exact_match_beats_prefix() {
  mk a-0101-1200
  mk a-0101-1200b
  run_graft a-0101-1200
  assert_status 0
  assert_contains "$OUT" "Reopening a-0101-1200 "
}

test_unmatched_label_creates_new() {
  mk alpha-0101-1200
  run_graft zeta
  assert_status 0
  assert_match "$(created)" '^zeta-'
}

test_reopen_counts_conversations() {
  mk alpha-0101-1200
  run_graft alpha-0101-1200
  assert_contains "$OUT" "(1 stored conversation(s)"
}

test_reopen_passes_args_through() {
  mk alpha-0101-1200
  run_graft alpha -c
  assert_status 0
  log_has "arg=-c" || fail "-c not passed to claude"
}

test_reattaches_when_directory_is_gone() {
  mk alpha-0101-1200
  git worktree remove --force "$(wt_path alpha-0101-1200)"
  run_graft alpha-0101-1200
  assert_status 0
  assert_contains "$OUT" "re-attaching it"
  assert_dir "$(wt_path alpha-0101-1200)"
}

test_continue_without_name_picks_most_recent() {
  mk a-0101-1200
  mk b-0101-1200
  touch -t 202001010000 "$(project_dir "$(wt_path b-0101-1200)")"/*.jsonl
  run_graft -c
  assert_status 0
  assert_contains "$OUT" "most recently active worktree: a-0101-1200"
  log_has "arg=-c" || fail "-c not passed to claude"
}

test_continue_without_conversations_errors() {
  export FAKE_NO_TRANSCRIPT=1
  mk a-0101-1200
  run_graft -c
  assert_status 1
  assert_contains "$ERR" "no worktree has a stored conversation"
}
