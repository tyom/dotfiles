# repo-intel

Source for the `repo-intel` contributor-stats dashboard. The shipped
executable at `stow/bin/repo-intel` is built from the files here — the
HTML template is embedded into the script so the artifact is
single-file and depends only on Python 3 + `git`.

`repo-intel` reads commit history from either the current git repo or
a remote GitHub repo and writes a self-contained HTML dashboard
showing top contributors, weekly/daily activity, time-of-day patterns,
and per-author commit feeds. It also breaks down work by **language**
(per-commit file types in the timeline tooltip, a per-author language
bar in the contributor popover, and a repo-wide "Technologies" section)
and detects **frameworks** from dependency manifests grouped by language.

The per-file **language** breakdown needs file-level line stats that only
the local and bare-clone paths produce — the token-authenticated GraphQL
remote path omits it, so the Technologies section's language column shows a
short placeholder there instead. **Framework** detection works on every path
(on the remote path the dependency manifests are fetched over the API).

The [GitHub CLI (`gh`)](https://cli.github.com/) is optional but
recommended: when authenticated (`gh auth login`), `repo-intel` uses
its token to fetch remote repos via the GitHub GraphQL API and to
enrich author cards with GitHub profile data (avatar, bio, follower
counts, etc.). Without `gh`, the script falls back to `$GITHUB_TOKEN`
or a bare-clone of the remote, and author cards show git data only.

## Run without installing

Pipe the shipped artifact straight into Python — no clone, no install:

```bash
curl -sSL https://raw.githubusercontent.com/tyom/dotfiles/master/stow/bin/repo-intel \
  | python3 - <owner/repo>
```

Everything after `python3 -` is forwarded to the script. Replace
`<owner/repo>` with the GitHub repo you want stats for (e.g. `tyom/dotfiles`),
or drop it to run against the current directory's git repo. Append `--help`
(or `-h`) for the full flag reference:

```bash
curl -sSL https://raw.githubusercontent.com/tyom/dotfiles/master/stow/bin/repo-intel \
  | python3 - --help
```

The script is self-contained (Python 3 + `git`, optional `gh`). In this mode
stdin is the script body, so the interactive subset prompt for large remote
repos is auto-skipped and the script fetches all commits — pass
`--commits N` (or `--since` / `--until`) to trim the fetch on big repos.

## Usage

```
repo-intel [N] [REPO] [options]
```

- `N` — number of top contributors to include (default `10`).
- `REPO` — `owner/repo`, `https://github.com/owner/repo`, or
  `remote:owner/repo`. Omit to use the cwd's git repo.

Run `repo-intel --help` for the full flag reference.

### Modes

- **Local** — no `REPO`. Reads `git log` from the current working directory.
- **Remote (GraphQL)** — `REPO` plus a GitHub token from
  `gh auth token -h github.com` or `$GITHUB_TOKEN`. Fetches via the
  GitHub GraphQL API.
- **Remote (bare-clone fallback)** — `REPO` with no token. Clones to
  `/tmp/repo-intel-<owner>-<repo>.git` and reads locally. Subsequent
  runs `git fetch` the cached bare clone.

### Filtering commits

| Flag                  | Meaning                                                                  |
| --------------------- | ------------------------------------------------------------------------ |
| `--commits N`         | Last `N` commits (newest)                                                |
| `--commits A-B`       | Positions `[A, B)` counted from the oldest commit (0-indexed, half-open) |
| `--since YYYY-MM-DD`  | Commits on or after the date (inclusive)                                 |
| `--until YYYY-MM-DD`  | Commits on or before the date (inclusive)                                |

Filters compose: date bounds apply first, then the position slice. The
run prints `filtered: X/total commits` so you can see what was kept.

When a remote repo has more than 1000 commits and no filter flag was
passed, `repo-intel` prompts interactively for a subset (Last 500, Last
1000, Past year, or All). The prompt requires the GraphQL path
(token-authenticated), because that's where picking a subset actually
saves network — the bare-clone fallback downloads everything regardless,
so it skips the prompt and you can pass `--commits` / `--since` to trim
the display instead. Also skipped when stdin/stderr is not a TTY or when
any of `--commits` / `--since` / `--until` is given.

### Output

| Flag                  | Default                                                                                  |
| --------------------- | ---------------------------------------------------------------------------------------- |
| `-o, --output PATH`   | `/tmp/<owner>--<repo>.html` (or `/tmp/<repo>.html` for a local repo without a GitHub origin) |
| `--no-open`           | Opens the result in your default browser                                                 |

`--output` creates parent directories if they don't exist.

### Cache

Remote runs cache commit nodes per repo under
`$XDG_CACHE_HOME/repo-intel` (default `~/.cache/repo-intel`), one JSON
file per repo. The next run paginates from HEAD and stops at the first
already-cached SHA, so only new commits since the last fetch hit the
network.

- `--no-cache` — ignore the cache and re-fetch everything (also skips
  `git fetch` on the bare-clone fallback).
- Delete the relevant `<owner>-<repo>.json` to force a fresh fetch for
  one repo.

The cache assumes linear history extension; force-pushes that rewrite
history may leave orphan SHAs in the cache. Pass `--no-cache` after a
known force-push if precision matters.

### Examples

```bash
repo-intel                                            # cwd, top 10
repo-intel 20                                         # cwd, top 20
repo-intel tyom/dotfiles                              # remote, top 10
repo-intel --commits 100 tyom/dotfiles                # last 100 commits
repo-intel --commits 0-100 tyom/dotfiles              # first 100 commits
repo-intel --commits 400-800 facebook/react           # 400 commits at positions 400..799
repo-intel --since 2024-01-01 --until 2024-12-31 .    # all of 2024 in cwd
repo-intel --no-open -o ./stats.html tyom/dotfiles    # save without opening
repo-intel --no-cache tyom/dotfiles                   # bypass cache
```

## Files

| File              | Purpose                                                                      |
| ----------------- | ---------------------------------------------------------------------------- |
| `repo-intel.py`   | The script. Holds `TEMPLATE` + `TECHDATA` placeholders until bundled         |
| `template.html`   | Dashboard HTML, with `/*__DATA_INJECTION__*/` for runtime data               |
| `techdata.json`   | Generated language + framework detection data (committed; embedded at build) |
| `gen_techdata.py` | Regenerates `techdata.json` from GitHub Linguist + a curated framework map   |
| `build.py`        | Substitutes the `TEMPLATE` / `TECHDATA` lines with their data as a `repr()`   |

### Detection data (`techdata.json`)

Language detection (extension/filename → language, colors, vendored-path noise
filter) is generated from [GitHub Linguist](https://github.com/github-linguist/linguist)
— `languages.yml` (with fine-grained languages folded into their `group`, e.g.
`TSX`→`TypeScript`) and `vendor.yml`. Frameworks are a small curated
dependency → framework map maintained in `gen_techdata.py` (Vercel/Netlify's
lists target deploy presets, not the libraries a repo uses, so they're a poor
fit). `techdata.json` is committed and embedded into the artifact, so the
shipped tool stays offline and single-file.

## Workflows

**Build the shipped artifact** (run after editing source or template):

```bash
make repo-intel-build
```

Writes `stow/bin/repo-intel` (chmod 0755). Commit both source and
artifact — the artifact is checked in so a fresh clone + `make install`
works without a build step. `repo-intel-build` reads the committed
`techdata.json`; it is **not** regenerated on every build (that would need
network), so builds stay offline and reproducible.

**Refresh detection data** (only when bumping Linguist or editing the
framework map — needs network):

```bash
make repo-intel-techdata   # rewrites techdata.json; then commit it + rebuild
```

**Develop against the source live** (no rebuild needed between edits):

```bash
make repo-intel-dev                          # uses cwd, top 10
make repo-intel-dev ARGS="3 facebook/react"  # top 3 of a remote repo
```

The source script auto-detects that `TEMPLATE` is still the placeholder
and falls back to reading `template.html` (and `techdata.json`) from disk.
The built artifact never hits that branch — it carries both embedded.

## How the embedding works

`build.py` looks for exactly one occurrence each of:

```python
TEMPLATE = "__TEMPLATE_PLACEHOLDER__"
TECHDATA = "__TECHDATA_PLACEHOLDER__"
```

and replaces them with `TEMPLATE = <repr(template_html)>` and
`TECHDATA = <repr(techdata_json)>`. The result is a valid Python file
carrying both as string literals. Templating happens at build time; the
runtime substitution of `/*__DATA_INJECTION__*/` with
`window.__DATA__ = {...}` still happens inside `main()` as before. When
unbuilt, the script detects the placeholders and reads `template.html`
and `techdata.json` from disk instead.
