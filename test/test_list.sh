# graft --list, and the stat helper it depends on.

test_list_with_no_worktrees() {
  run_graft --list
  assert_status 0
  assert_contains "$OUT" "No worktrees."
}

test_list_shows_each_worktree() {
  export FAKE_DO='echo x > f && git add f && git commit -qm "Add alpha feature"'
  mk alpha; a=$MADE
  unset FAKE_DO
  mk beta
  run_graft --list
  assert_status 0
  assert_eq "$ERR" ""
  assert_contains "$OUT" "  beta-"
  # AHEAD 1, not dirty, 1 session, WHAT from its first commit.
  printf '%s\n' "$OUT" | grep -Eq "^  $a +[0-9]+[mhd] +[0-9]+[mhd] +1 +- +1 +Add alpha feature\$" \
    || fail "alpha row wrong:
$OUT"
}

test_list_counts_dirty_files() {
  export FAKE_DO='touch one two'
  mk x; n=$MADE
  run_graft --list
  printf '%s\n' "$OUT" | grep -Eq "^  $n +[0-9]+[mhd] +[0-9]+[mhd] +0 +2 +1 " \
    || fail "expected DIRTY 2:
$OUT"
}

test_list_what_falls_back_to_first_prompt() {
  mk x; n=$MADE
  printf '{"display":"/clear","project":"%s"}\n{"display":"fix the flaky test","project":"%s"}\n' \
    "$(wt_path "$n")" "$(wt_path "$n")" > "$CLAUDE_CONFIG_DIR/history.jsonl"
  run_graft --list
  assert_contains "$OUT" "fix the flaky test"
}

test_list_sorts_most_recent_first() {
  mk a-0101-1200
  mk b-0101-1200
  touch -t 202001010000 "$(project_dir "$(wt_path b-0101-1200)")"/*.jsonl
  run_graft --list
  first=$(printf '%s\n' "$OUT" | sed -n 2p)
  assert_contains "$first" "a-0101-1200"
}

test_list_notes_deleted_worktrees_with_conversations() {
  mk gone-0101-1200
  git worktree remove --force "$(wt_path gone-0101-1200)"
  git branch -q -D graft/gone-0101-1200
  run_graft --list
  assert_contains "$OUT" "Deleted worktrees that still hold conversations: gone-0101-1200 (1)."
}

test_list_marks_live_sessions() {
  mk x; n=$MADE
  # A process ps reports as "claude". A symlink, not a copy: macOS kills a
  # copied system binary for its broken code signature.
  mkdir -p "$W/live" && ln -s "$(command -v sleep)" "$W/live/claude"
  "$W/live/claude" 30 &
  pid=$!
  mkdir -p "$CLAUDE_CONFIG_DIR/sessions"
  printf '{"pid":%s,"cwd":"%s"}\n' "$pid" "$(wt_path "$n")" > "$CLAUDE_CONFIG_DIR/sessions/$pid.json"
  run_graft --list
  kill "$pid"
  assert_contains "$OUT" "* $n"
}

test_list_ignores_stale_session_files() {
  mk x; n=$MADE
  mkdir -p "$CLAUDE_CONFIG_DIR/sessions"
  printf '{"cwd":"%s"}\n' "$(wt_path "$n")" > "$CLAUDE_CONFIG_DIR/sessions/999999.json"
  run_graft --list
  assert_not_contains "$OUT" "* $n"
}

# The GNU stat fix: BSD's `stat -f` means something else on Linux, and GNU
# prints "-" for a missing birth time. Only all-digit answers may get through.
test_stat_helpers_only_return_numbers() {
  eval "$(sed -n '/^stat_num()/,/^mtime_of/p' "$GRAFT")"
  stat() {
    case $1 in
      -f) echo "  File: noise"; return 1 ;;
      -c) if [ "$2" = %W ]; then echo -; else echo 1790208442; fi ;;
    esac
  }
  assert_eq "$(birth_of x)" 0
  assert_eq "$(mtime_of x)" 1790208442
  stat() { return 1; }
  assert_eq "$(mtime_of x)" 0
}
