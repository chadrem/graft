# graft

**One git worktree per task, for [Claude Code](https://claude.com/claude-code).**

`graft` creates a throwaway worktree, seeds the gitignored files a fresh
checkout needs, starts `claude` in it, and offers to clean up when you exit. Run
as many in parallel as you have attention for, and pick any of them back up
later — with its conversation history intact.

```console
$ graft
Preparing worktree (new branch 'graft/wt-0826-0910')
HEAD is now at 548a61c Initial commit
Created worktree wt-0826-0910
  path    ~/code/myapp/.claude/worktrees/wt-0826-0910
  branch  graft/wt-0826-0910 (from main)
  reopen  graft wt-0826-0910
  resume  graft wt-0826-0910 -c
  list    graft --list
  (3 other worktree(s) — graft --list)
```

You are now in a `claude` session in a clean checkout of `main`. Nothing you do
touches your primary working tree, so the other three worktrees — and whatever
you had half-finished in your main checkout — carry on undisturbed.

## Why not `claude --worktree`?

Claude Code's built-in worktrees are good, and need nothing installed. graft
adds a few things on top:

- **Names are never reused.** Claude Code reopens a worktree if you reuse its
  name, and `--continue` picks the latest chat in that folder, which may be a
  different task. graft makes every name unique. See
  [How names work](#how-names-work).
- **Monorepo support.** Claude Code always starts at the git root, so a
  `CLAUDE.md` or `.claude/skills/` in a subfolder is never found. Set
  [`GRAFT_SUBDIR`](#configuration) and graft starts there instead.
- **Ignored files with no setup.** graft copies `.env`, `config/master.key`,
  `.mcp.json` and friends on create and on every reopen. Claude Code needs a
  `.worktreeinclude` file first, and copies only on create.
- **A status list.** `graft --list` shows every worktree: whether claude is
  running, commits ahead, uncommitted changes, saved chats, and what it's for.
- **Easy reopen.** Type any unique part of a name, or `graft -c` for the last
  one. Claude Code needs the exact name.
- **Safer cleanup.** graft only offers to delete a worktree once its work is
  on the base branch, and tells you why it kept one.
- **Chats come back.** If you delete a worktree, graft can rebuild its path so
  its old chats work again.

Use the built-in feature if you want worktrees in the desktop app, for
subagents, or with no extra tool.

## Install

A single bash script, no dependencies beyond `git` and the `claude` CLI:

```sh
git clone https://github.com/chadrem/graft.git ~/src/graft
ln -s ~/src/graft/graft ~/bin/graft     # anywhere on your PATH
```

Then, in each repo you use it from, gitignore the worktree directory:

```sh
echo '/.claude/worktrees/' >> .gitignore
```

That is the whole setup for a standard single-app repo. Monorepos and unusual
layouts want a [`.graftrc`](#configuration).

## Commands

```
graft                    create a worktree (unique generated name)
graft --new <label>      create one named after what you're doing
graft <name> [args...]   reopen (exact, unique prefix, or substring)
graft -c                 reopen the most recently active worktree
graft --list             what exists, what's live, what to type
graft --help             full help
```

Anything after the name is passed straight through to `claude`, so
`graft fix-login -c` reopens that worktree *and* continues its last
conversation, and `graft --new perf -p "profile the slow query"` works too.

### Naming a worktree after the work

```console
$ graft --new fix-login
Created worktree fix-login-0826-0911
  branch  graft/fix-login-0826-0911 (from main)
```

The `-MMDD-HHMM` stamp is appended for you — that is what keeps names unique.

### Reopening

Because a bare argument means *reopen*, it matches loosely: exact name first,
then unique prefix, then unique substring.

```console
$ graft fix -c
'fix' -> fix-login-0823-0912
Reopening fix-login-0823-0912 (2 stored conversation(s); add -c to continue the last one)
```

If it is ambiguous, graft says so rather than guessing:

```console
$ graft wt
error: 'wt' matches more than one worktree: wt-0826-0853 wt-0826-0853b wt-0826-0853c
Type more of the name, or: graft --list
```

## Seeing what you have

```console
$ graft --list
  WORKTREE             AGE  LAST AHEAD DIRTY SESS  WHAT
* fix-login-0823-0912   2d   13m     4    11    2  Fix the login redirect loop
  wt-0826-0803         66m   57m     0     -    3  why is the nightly digest job skippi..
  webhooks-0825-1710   15h    5h     1     -    1  Rework the webhook retry backoff

  * = claude running now.  AHEAD = commits not on main.  SESS = stored conversations.
  Branch of <name> is always graft/<name>.
  Reopen: graft <name>   (any unique prefix works)
```

| Column | Means |
| --- | --- |
| `*` | a `claude` process is running in that worktree right now |
| `AGE` | how long ago the worktree was created |
| `LAST` | when its most recent conversation was last written to |
| `AHEAD` | commits on its branch that are not on the base branch |
| `DIRTY` | uncommitted changes (`-` for none) |
| `SESS` | stored conversations you could `-c` back into |
| `WHAT` | the first commit not on the base branch — or, before anything is committed, your first prompt in that worktree |

Rows are sorted by most recently active. `WHAT` is the column that makes a
screen full of date-stamped names legible again three days later.

## Finishing up

graft does not merge, push, or open PRs — that stays yours. Land the branch the
way you normally would (`git merge graft/fix-login-0823-0912`, push and open a
PR, whatever your project does). Once its commits are on the base branch, the
next exit offers cleanup.

On exit it mirrors `claude --worktree`'s prompt, but only offers to delete when
all three are true: no uncommitted changes, no rebase/merge/bisect in progress,
and no commits missing from the base branch. Otherwise it keeps the worktree and
tells you which one stopped it:

```console
Keeping worktree 'tokens-0826-0910' (1 commit(s) not yet landed on main).
Reopen: graft tokens-0826-0910   Land: merge or push graft/tokens-0826-0910, then rerun this.
```

```console
Keeping worktree 'fix-login-0823-0912' (uncommitted changes). Reopen: graft fix-login-0823-0912
```

When it is genuinely finished, it asks — and tells you what deleting costs,
because conversations are keyed to the path rather than the branch:

```console
Worktree 'spike-0826-0910' has no unlanded work.
Its 2 stored conversation(s) are keyed to this exact path, not to the branch.
Deleting puts them out of reach until the path exists again — `graft --new spike-0826-0910`
rebuilds it from main and --continue works there again (the branch's commits do
not come back).
Delete worktree 'spike-0826-0910' and branch graft/spike-0826-0910? [y/N]
```

Answer `n` and it is kept. Non-interactive runs never prompt; they print the
`git worktree remove` command instead.

## How names work

**A name is never reused.** A name counts as taken if a directory, a local
branch or a remote branch uses it — *or* if a Claude Code session was ever
recorded under that path. That last check is the load-bearing one: the
transcript directory outlives the worktree, so it is a permanent ledger of every
name that has ever hosted a session.

This is why the date stamp exists, and why `graft --new fix-login` quietly
becomes `fix-login-0826-0911`. The cost of a collision is not a git error, it is
`--continue` silently resuming somebody else's feature.

**Deleting a worktree does not delete its conversations.** They stay on disk,
keyed to the path. If the branch still exists but the directory is gone, graft
re-attaches the worktree at the same path automatically. If both are gone,
`graft --new <full-name>` rebuilds the path from the base branch so `--continue`
reaches them again — the branch's commits do not come back, but the transcript
does. `graft --list` reminds you which ones are in that state:

```console
  Deleted worktrees that still hold conversations: spike-0826-0910 (2).
  Recreate the path to reach them: graft --new <name>
```

## Seeded files

A fresh worktree is a clean checkout, so anything gitignored is missing from it
— which is how you end up with a worktree that cannot boot (no credentials key)
or that runs with no MCP tools at all. MCP servers connect at session *startup*,
so copying `.mcp.json` in halfway through does not help.

graft copies these from your primary checkout on both create and reopen, never
overwriting a file that is already there:

```
config/master.key   .env   .claude/settings.local.json   .mcp.json
```

Override the list with [`GRAFT_SEED_FILES`](#configuration). Missing sources are
skipped silently, so the default list is safe in a repo that has none of them.

## Configuration

Optional. Set these in `<repo root>/.graftrc` (sourced as shell) or as
environment variables, which win over the file. See
[`.graftrc.example`](.graftrc.example) for a commented copy.

| Variable | Default | What it does |
| --- | --- | --- |
| `GRAFT_SUBDIR` | *empty* (worktree root) | Subdirectory of the worktree to start the session in. Set this for monorepos where `CLAUDE.md` and `.claude/` live below the git root. |
| `GRAFT_WORKTREE_DIR` | `.claude/worktrees` | Where worktrees are created, relative to the repo root. Gitignore it. |
| `GRAFT_BRANCH_PREFIX` | `graft/` | Branch names are `<prefix><worktree name>`. |
| `GRAFT_BASE_BRANCH` | `origin/HEAD`, else `main`/`master`/`trunk` | Branch new worktrees fork from, and the one `AHEAD` is measured against. |
| `GRAFT_SEED_FILES` | see [Seeded files](#seeded-files) | Space-separated gitignored files to copy in, relative to the repo root. Each default entry moves under `GRAFT_SUBDIR` when that is set. |
| `GRAFT_MAX_NAME` | `24` | Longest permitted worktree name. |
| `GRAFT_CLAUDE_BIN` | `claude` | The CLI to launch. |

`CLAUDE_CONFIG_DIR` is honoured when locating Claude Code's own state.

### Monorepo example

For a repo laid out as `myrepo/{web,worker}`, where the Rails app and all its
Claude config live in `web/`:

```sh
# myrepo/.graftrc
GRAFT_SUBDIR=web
```

That is enough — the seed-file defaults follow `GRAFT_SUBDIR`, so they become
`web/config/master.key`, `web/.env` and so on. Sessions start in
`<worktree>/web`, where your `CLAUDE.md` and skills actually are.

### Why the 24-character name limit

Worktree paths end up inside unix domain socket paths — a Rails parallel-test
DRb socket, for one — and macOS allows those only 104 bytes total. A short cap
here is much cheaper than debugging "path too long" from a test runner an hour
later. Raise `GRAFT_MAX_NAME` if your toolchain does not care.

## Troubleshooting

**Worktrees show up as untracked files.** The worktree directory is not
gitignored. graft warns about this on create; add `/.claude/worktrees/` to
`.gitignore`.

**`error: GRAFT_SUBDIR is 'web', but …/web does not exist`.** Either a typo, or
you are running from a checkout where that directory genuinely is not present.
graft checks before creating anything, so nothing is left behind.

**`error: could not work out this repo's default branch`.** No `origin/HEAD` and
no local `main`, `master` or `trunk`. Set `GRAFT_BASE_BRANCH`.

**A worktree is stuck being kept.** Something in it is unfinished. `graft --list`
shows which — `DIRTY` for uncommitted changes, `AHEAD` for unlanded commits — and
an in-progress rebase or merge is reported on exit.

## Requirements

- bash 3.2+ (the version macOS ships) — tested on macOS and Linux
- git 2.5+, for worktree support
- the `claude` CLI on your `PATH`

## Testing

`test/list.sh` smoke-tests `graft --list` in a throwaway repo. CI runs it on
Linux and macOS.

## License

AGPL-3.0. See [LICENSE](LICENSE).

Not affiliated with Anthropic.
