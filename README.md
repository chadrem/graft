# graft

Launch a [Claude Code](https://claude.com/claude-code) session in a throwaway
git worktree — one worktree per task, run as many in parallel as you like, and
never lose track of which conversation belongs to which branch.

```
$ graft
Created worktree wt-0826-0853
  path    /repo/.claude/worktrees/wt-0826-0853
  branch  graft/wt-0826-0853 (from main)
  reopen  graft wt-0826-0853
  resume  graft wt-0826-0853 -c
  list    graft --list
```

```
$ graft --list
  WORKTREE             AGE  LAST AHEAD DIRTY SESS  WHAT
* fix-login-0826-0853   3h    2m     4    11    2  Fix the login redirect loop
  api-0825-1710         1d    5h     1     -    1  Rework the webhook retry
  wt-0825-0902          2d    2d     0     -    3  (nothing recorded yet)

  * = claude running now.  AHEAD = commits not on main.  SESS = stored conversations.
  Branch of <name> is always graft/<name>.
  Reopen: graft <name>   (any unique prefix works)
```

## Why not `claude --worktree`?

Two reasons.

**It recycles names.** Claude Code binds a session to its literal working
directory: transcripts live in `~/.claude/projects/<cwd-slug>/`, and
`--continue` means "the most recent conversation in *this directory*". Reuse a
worktree name and you pool unrelated features under one path — `--continue`
then resumes whichever one happened to be last. graft never reuses a name.
Generated names carry an `<MMDD>-<HHMM>` stamp, and a bare label gets one
appended (`fix-login` → `fix-login-0826-0853`). A name counts as taken if a
directory, a local branch or a remote branch uses it, *or* if a session was
ever recorded under that path — the transcript directory outlives the worktree,
so it is a permanent ledger.

**It starts at the git root.** In a monorepo where `CLAUDE.md`, `.claude/skills/`
and `.claude/settings.local.json` live in a subdirectory, none of that is
discovered from the root, so your project skills silently vanish. Set
`GRAFT_SUBDIR` and the session starts in the right place, with full parity with
a normal `claude` run.

It also seeds the gitignored files a fresh checkout needs (`config/master.key`,
`.env`, `.mcp.json`, …), which otherwise leave you with a worktree that can't
boot or has no MCP servers.

## Install

`graft` is a single bash script with no dependencies beyond `git` and the
`claude` CLI. Clone it and put it on your `PATH`:

```sh
git clone https://github.com/chadrem/graft.git ~/src/graft
ln -s ~/src/graft/graft ~/bin/graft
```

Then, in each repo you use it from, gitignore the worktree directory:

```sh
echo '/.claude/worktrees/' >> .gitignore
```

## Usage

```
graft                    create a worktree (unique generated name)
graft --list             what exists, what's live, what to type
graft <name> [args]      reopen (exact, unique prefix, or substring)
graft --new <name>       create with an explicit name, or rebuild a
                         deleted path so its sessions resume
graft -c                 reopen the most recently active worktree
graft --help             full help
```

Anything after the name is passed straight through to `claude`, so
`graft fix-login -c` reopens that worktree and continues its last conversation.

Because a bare argument means *reopen*, it matches loosely: exact name first,
then unique prefix, then unique substring. `graft fix` finds
`fix-login-0826-0853`. Use `--new` to force creation.

If the branch still exists but the directory is gone, graft re-attaches the
worktree at the same path — which is exactly what an old session needs in order
to resume, since its transcripts are keyed to that path. `graft --new <name>`
on a name that once held sessions rebuilds the path so `--continue` reaches
them again (the branch's commits do not come back).

## On exit

When the session ends, graft mirrors `claude --worktree`'s cleanup. It offers
to delete the worktree and its branch only when all three are true: no
uncommitted changes, no rebase/merge/bisect in progress, and no commits missing
from the base branch. Otherwise it keeps the worktree and says which of those
stopped it. Non-interactive runs never prompt; they print the commands instead.

## Configuration

Set these in `<repo root>/.graftrc` (sourced as shell) or as environment
variables, which win over the file. See [`.graftrc.example`](.graftrc.example).

| Variable | Default | What it does |
| --- | --- | --- |
| `GRAFT_SUBDIR` | `''` (worktree root) | Subdirectory of the worktree to start the session in. Set this for monorepos where `CLAUDE.md` and `.claude/` live below the git root. |
| `GRAFT_WORKTREE_DIR` | `.claude/worktrees` | Where worktrees are created, relative to the repo root. Gitignore it. |
| `GRAFT_BRANCH_PREFIX` | `graft/` | Branch name prefix. `<prefix><name>`. |
| `GRAFT_BASE_BRANCH` | `origin/HEAD`, else `main`/`master`/`trunk` | Branch new worktrees fork from, and the one "unlanded commits" is measured against. |
| `GRAFT_SEED_FILES` | `config/master.key .env .claude/settings.local.json .mcp.json` (each under `GRAFT_SUBDIR` when set) | Space-separated gitignored files copied from the primary checkout into a new worktree. Missing sources and existing destinations are skipped. |
| `GRAFT_MAX_NAME` | `24` | Longest permitted worktree name. Worktree paths end up inside unix domain socket paths (a Rails parallel-test DRb socket, for one) and macOS allows those only 104 bytes, so a short cap is cheaper than debugging "path too long" from a test runner. |
| `GRAFT_CLAUDE_BIN` | `claude` | The CLI to launch. |

`CLAUDE_CONFIG_DIR` is honoured for locating Claude Code's own state.

### Rails monorepo example

For a repo laid out as `myrepo/{web,worker}` where the Rails app is in `web/`:

```sh
# myrepo/.graftrc
GRAFT_SUBDIR=web
GRAFT_SEED_FILES='web/config/master.key web/.env web/.claude/settings.local.json web/.mcp.json'
```

## Requirements

- bash 3.2+ (ships with macOS) — tested on macOS and Linux
- git 2.5+ (worktree support)
- the `claude` CLI on your `PATH`

## License

AGPL-3.0. See [LICENSE](LICENSE).
