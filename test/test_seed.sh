# Seeding gitignored files, and GRAFT_SUBDIR.

test_seeds_env_on_create() {
  echo secret > .env
  mk x; n=$MADE
  assert_contains "$OUT" "Seeded .env"
  assert_eq "$(cat "$(wt_path "$n")/.env")" secret
}

test_seeds_nested_files() {
  mkdir config && echo key > config/master.key
  mk x; n=$MADE
  assert_eq "$(cat "$(wt_path "$n")/config/master.key")" key
}

test_never_overwrites_a_seeded_file() {
  echo secret > .env
  mk x; n=$MADE
  echo local > "$(wt_path "$n")/.env"
  run_graft "$n"
  assert_status 0
  assert_eq "$(cat "$(wt_path "$n")/.env")" local
  assert_not_contains "$OUT" "Seeded"
}

test_seeds_on_reopen_when_missing() {
  mk x; n=$MADE
  echo '{}' > .mcp.json
  run_graft "$n"
  assert_status 0
  assert_contains "$OUT" "Seeded .mcp.json"
}

test_seed_list_is_configurable() {
  echo secret > .env
  echo custom > custom.txt
  export GRAFT_SEED_FILES=custom.txt
  mk x; n=$MADE
  assert_eq "$(cat "$(wt_path "$n")/custom.txt")" custom
  [ ! -e "$(wt_path "$n")/.env" ] || fail ".env seeded despite override"
}

test_subdir_starts_session_there() {
  mkdir web && echo '# web' > web/CLAUDE.md
  git add web && git commit -qm web
  echo secret > web/.env
  echo root > .env
  export GRAFT_SUBDIR=web
  mk x; n=$MADE
  log_has "cwd=$(wt_path "$n")/web" || fail "claude not started in web/"
  assert_eq "$(cat "$(wt_path "$n")/web/.env")" secret
  [ ! -e "$(wt_path "$n")/.env" ] || fail "root .env seeded; defaults should follow GRAFT_SUBDIR"
}

test_missing_subdir_errors_before_creating() {
  export GRAFT_SUBDIR=nope
  run_graft
  assert_status 1
  assert_contains "$ERR" "GRAFT_SUBDIR is 'nope'"
  [ -z "$(git branch --list 'graft/*')" ] || fail "a branch was left behind"
}

test_uncommitted_subdir_errors() {
  mkdir web
  export GRAFT_SUBDIR=web
  run_graft
  assert_status 1
  assert_contains "$ERR" "does not exist in this worktree"
}
