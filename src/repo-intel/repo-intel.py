#!/usr/bin/env python3
"""repo-intel — generate a contributor stats dashboard for a git repo."""

HELP = """\
repo-intel — generate a contributor stats dashboard for a git repo.

Usage:
  repo-intel [N] [REPO] [-o PATH] [--no-open]
  repo-intel -h | --help

Arguments:
  N       Number of top contributors to include (default: 10)
  REPO    A GitHub repository, in any of these forms:
            owner/repo
            https://github.com/owner/repo
            remote:owner/repo
          When omitted, the current working directory is used as a local git repo.

Options:
  -o, --output PATH   Write the dashboard to PATH instead of /tmp/<repo-name>.html.
  --no-open           Don't open the result in a browser.
  --no-cache          Ignore the local cache and re-fetch all commits.
  --commits SPEC      Filter commits by position. SPEC is either N (last N
                      commits, newest) or A-B (positions [A, B), 0-indexed
                      from oldest, half-open like Python slicing).
  --since DATE        Only include commits on or after DATE (YYYY-MM-DD, inclusive).
  --until DATE        Only include commits on or before DATE (YYYY-MM-DD, inclusive).
  -h, --help          Show this help message and exit.

Examples:
  repo-intel                       # local repo (cwd), top 10
  repo-intel 20                    # local repo, top 20
  repo-intel facebook/react        # remote, top 10
  repo-intel 15 facebook/react     # remote, top 15
  repo-intel -o ./stats.html       # write to a specific path
  repo-intel --no-open             # generate without launching browser
  repo-intel --commits 100         # only the last 100 commits
  repo-intel --commits 0-100       # the first 100 commits
  repo-intel --commits 400-800     # commits at positions 400..799 (oldest-first)
  repo-intel --since 2024-01-01    # commits since 2024-01-01
  repo-intel --since 2024-01-01 --until 2024-06-30  # H1 2024

Remote auth:
  Uses `gh auth token -h github.com`, then $GITHUB_TOKEN.
  Falls back to `git clone --bare` into /tmp if neither is available.

Output:
  /tmp/<owner>--<repo>.html (or --output PATH), opened in default browser
  unless --no-open is given. Falls back to /tmp/<repo>.html for local
  repos without a github.com origin.

Cache:
  Remote commit nodes are cached under
  $XDG_CACHE_HOME/repo-intel (default ~/.cache/repo-intel) as one JSON
  file per repo. Re-runs only fetch new commits.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
import webbrowser
from collections import defaultdict
from datetime import datetime
from pathlib import Path

TEMPLATE = "__TEMPLATE_PLACEHOLDER__"
PLACEHOLDER = "/*__DATA_INJECTION__*/"
NOREPLY_RE = re.compile(r"(?:\d+\+)?(.+)@users\.noreply\.github\.com")
ORIGIN_RE = re.compile(
    r"^(?:https?://github\.com/|git@github\.com:)([^/]+)/(.+?)(?:\.git)?/?$"
)
CACHE_DIR = (
    Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "repo-intel"
)


def cache_path(slug):
    safe = re.sub(r"[^\w.-]+", "-", slug.lower()).strip("-") or "repo"
    return CACHE_DIR / f"{safe}.json"


def load_cache(slug):
    p = cache_path(slug)
    if not p.exists():
        return [], False
    try:
        data = json.loads(p.read_text())
        return data.get("nodes", []), bool(data.get("complete", False))
    except (json.JSONDecodeError, OSError):
        return [], False


def save_cache(slug, nodes, complete):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path(slug).write_text(json.dumps({"nodes": nodes, "complete": complete}))


def cache_covers_request(loaded_nodes, loaded_complete, commits_filter, since, until):
    """True if the cache contains enough to answer the current request."""
    if loaded_complete:
        return True
    if not loaded_nodes:
        return False
    if until:
        return False
    if commits_filter:
        if commits_filter[0] == "last":
            return len(loaded_nodes) >= commits_filter[1]
        return False
    if since:
        oldest = ((loaded_nodes[-1].get("author") or {}).get("date") or "")[:10]
        return bool(oldest) and oldest <= since
    return False


def parse_commits_spec(val):
    if re.fullmatch(r"\d+", val):
        n = int(val)
        if n <= 0:
            raise ValueError("--commits N requires a positive integer")
        return ("last", n)
    m = re.fullmatch(r"(\d+)-(\d+)", val)
    if m:
        a, b = int(m.group(1)), int(m.group(2))
        if a >= b:
            raise ValueError(f"--commits A-B requires A < B (got {a}-{b})")
        return ("range", a, b)
    raise ValueError(f"--commits must be N or A-B (got {val!r})")


def parse_date(val, flag):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", val):
        raise ValueError(f"{flag} requires YYYY-MM-DD (got {val!r})")
    return val


def parse_args(argv):
    if any(tok in ("-h", "--help") for tok in argv):
        sys.stdout.write(HELP)
        sys.exit(0)
    top_n, remote, output, no_open, no_cache = 10, None, None, False, False
    commits_filter, since, until = None, None, None
    i = 0

    def take_value(name):
        tok = argv[i]
        if tok == name:
            if i + 1 >= len(argv):
                sys.stderr.write(f"repo-intel: {name} requires a value\n")
                sys.exit(2)
            return argv[i + 1], 2
        if tok.startswith(name + "="):
            return tok[len(name) + 1:], 1
        return None, 0

    while i < len(argv):
        tok = argv[i]
        try:
            if tok == "--no-open":
                no_open = True
                i += 1
                continue
            if tok == "--no-cache":
                no_cache = True
                i += 1
                continue
            if tok == "-o":
                if i + 1 >= len(argv):
                    sys.stderr.write("repo-intel: -o requires a value\n")
                    sys.exit(2)
                output = argv[i + 1]
                i += 2
                continue
            val, step = take_value("--output")
            if step:
                output = val
                i += step
                continue
            val, step = take_value("--commits")
            if step:
                commits_filter = parse_commits_spec(val)
                i += step
                continue
            val, step = take_value("--since")
            if step:
                since = parse_date(val, "--since")
                i += step
                continue
            val, step = take_value("--until")
            if step:
                until = parse_date(val, "--until")
                i += step
                continue
        except ValueError as exc:
            sys.stderr.write(f"repo-intel: {exc}\n")
            sys.exit(2)
        if tok.isdigit():
            top_n = int(tok)
            i += 1
            continue
        t = tok.removeprefix("remote:")
        t = t.removeprefix("https://github.com/").removeprefix("http://github.com/")
        parts = t.rstrip("/").split("/")
        if (
            len(parts) >= 2
            and re.fullmatch(r"[\w.-]+", parts[0])
            and re.fullmatch(r"[\w.-]+", parts[1])
        ):
            remote = f"{parts[0]}/{parts[1]}"
            i += 1
            continue
        sys.stderr.write(f"repo-intel: unrecognized argument: {tok!r}\n")
        sys.stderr.write("Try 'repo-intel --help' for usage.\n")
        sys.exit(2)
    if since and until and since > until:
        sys.stderr.write(f"repo-intel: --since {since} is after --until {until}\n")
        sys.exit(2)
    return top_n, remote, output, no_open, no_cache, commits_filter, since, until


def avatar_url(email, override=None):
    if override:
        return override
    m = NOREPLY_RE.fullmatch(email)
    if m:
        return f"https://github.com/{m.group(1)}.png?size=64"
    h = hashlib.md5(email.strip().lower().encode()).hexdigest()
    return f"https://www.gravatar.com/avatar/{h}?d=mp&s=64"


def iso_week_label(dt):
    y, w, _ = dt.isocalendar()
    return f"{y}-W{w:02d}"


def git(*args, cwd=None):
    return subprocess.check_output(["git", *args], text=True, cwd=cwd)


def detect_default_branch(cwd=None):
    try:
        ref = git(
            "symbolic-ref", "--short", "refs/remotes/origin/HEAD", cwd=cwd
        ).strip()
        if ref.startswith("origin/"):
            return ref[len("origin/") :]
    except subprocess.CalledProcessError:
        pass
    try:
        ref = git("symbolic-ref", "--short", "HEAD", cwd=cwd).strip()
        if ref:
            return ref
    except subprocess.CalledProcessError:
        pass
    return "main"


def collect_local(cwd=None, suppress_current_user=False):
    repo_root = git("rev-parse", "--show-toplevel", cwd=cwd).strip()
    repo_name = os.path.basename(repo_root)
    github_base = ""
    try:
        url = git("remote", "get-url", "origin", cwd=cwd).strip()
        m = ORIGIN_RE.match(url)
        if m:
            github_base = f"https://github.com/{m.group(1)}/{m.group(2)}"
            repo_name = m.group(2)
    except subprocess.CalledProcessError:
        pass

    current_email = ""
    if not suppress_current_user:
        try:
            current_email = git("config", "user.email", cwd=cwd).strip().lower()
        except subprocess.CalledProcessError:
            pass

    log = git(
        "log", "--no-merges",
        "--format=%H\x1f%s\x1f%aE\x1f%aN\x1f%aI",
        "--numstat",
        cwd=cwd,
    )
    commits_meta, line_stats = {}, {}
    cur = None
    for line in log.splitlines():
        if not line:
            continue
        if "\x1f" in line:
            parts = line.split("\x1f")
            if len(parts) != 5:
                continue
            h, s, email, name, dt_iso = parts
            commits_meta[h] = {
                "subject": s,
                "email": email.lower(),
                "name": name,
                "iso": dt_iso,
            }
            cur = h
            line_stats[cur] = [0, 0]
            continue
        if cur is None:
            continue
        cols = line.split("\t")
        if len(cols) < 2 or cols[0] == "-" or cols[1] == "-":
            continue
        try:
            line_stats[cur][0] += int(cols[0])
            line_stats[cur][1] += int(cols[1])
        except ValueError:
            pass

    default_branch = detect_default_branch(cwd=cwd)
    return (
        repo_name,
        github_base,
        current_email,
        commits_meta,
        line_stats,
        {},
        default_branch,
    )


def collect_remote(slug, no_cache=False, commits_filter=None, since=None, until=None):
    owner, repo = slug.split("/", 1)
    token = None
    try:
        token = subprocess.check_output(
            ["gh", "auth", "token", "-h", "github.com"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        token = os.environ.get("GITHUB_TOKEN")

    if not token:
        print("No GitHub token — falling back to bare clone.", file=sys.stderr)
        clone_dir = f"/tmp/repo-intel-{owner}-{repo}.git"
        if not os.path.isdir(clone_dir):
            subprocess.check_call(
                [
                    "git",
                    "clone",
                    "--bare",
                    f"https://github.com/{owner}/{repo}.git",
                    clone_dir,
                ]
            )
        elif not no_cache:
            print("  updating cached bare clone…", file=sys.stderr)
            subprocess.run(
                ["git", "fetch", "--quiet", "origin"], cwd=clone_dir, check=False
            )
        repo_name, github_base, _, commits_meta, line_stats, _, default_branch = (
            collect_local(cwd=clone_dir, suppress_current_user=True)
        )
        if not github_base:
            github_base = f"https://github.com/{owner}/{repo}"
        return repo_name, github_base, "", commits_meta, line_stats, {}, default_branch

    query = """
query($owner: String!, $repo: String!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    name url
    defaultBranchRef {
      name
      target {
        ... on Commit {
          history(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              oid messageHeadline
              author { name email date user { avatarUrl(size: 64) login } }
              additions deletions
            }
          }
        }
      }
    }
  }
}
""".strip()

    loaded_nodes, loaded_complete = ([], False) if no_cache else load_cache(slug)
    if loaded_nodes and not cache_covers_request(
        loaded_nodes, loaded_complete, commits_filter, since, until
    ):
        print(
            f"  cache: {len(loaded_nodes)} commits (partial — request needs more, re-fetching)",
            file=sys.stderr,
        )
        cached_nodes = []
    else:
        cached_nodes = loaded_nodes
        if cached_nodes:
            label = "complete" if loaded_complete else "partial"
            print(f"  cache: {len(cached_nodes)} commits ({label})", file=sys.stderr)
    cached_oids = {n["oid"] for n in cached_nodes}

    last_n = commits_filter[1] if commits_filter and commits_filter[0] == "last" else None

    cursor = None
    new_nodes = []
    repo_name = repo
    repo_url = f"https://github.com/{owner}/{repo}"
    default_branch = "main"
    hit_cache = False
    hit_end = False
    short_circuited = False
    while True:
        payload = json.dumps(
            {
                "query": query,
                "variables": {"owner": owner, "repo": repo, "cursor": cursor},
            }
        ).encode()
        req = urllib.request.Request(
            "https://api.github.com/graphql",
            data=payload,
            headers={
                "Authorization": f"bearer {token}",
                "Content-Type": "application/json",
                "User-Agent": "repo-intel",
            },
        )
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read())
        if "errors" in body:
            sys.exit(f"GraphQL error: {body['errors']}")
        repo_node = body["data"]["repository"]
        if not repo_node:
            sys.exit(f"Repository not found or inaccessible: {slug}")
        repo_name = repo_node["name"]
        repo_url = repo_node["url"]
        default_branch = repo_node["defaultBranchRef"].get("name") or default_branch
        history = repo_node["defaultBranchRef"]["target"]["history"]
        for n in history["nodes"]:
            if n["oid"] in cached_oids:
                hit_cache = True
                break
            new_nodes.append(n)
            if last_n is not None and len(new_nodes) + len(cached_nodes) >= last_n:
                short_circuited = True
                break
            if since:
                d = ((n.get("author") or {}).get("date") or "")[:10]
                if d and d < since:
                    short_circuited = True
                    break
        if hit_cache or short_circuited:
            break
        if not history["pageInfo"]["hasNextPage"]:
            hit_end = True
            break
        cursor = history["pageInfo"]["endCursor"]
        print(f"  fetched {len(new_nodes)} new commits…", file=sys.stderr)

    if new_nodes:
        print(f"  fetched {len(new_nodes)} new commits", file=sys.stderr)
    nodes = new_nodes + cached_nodes
    new_complete = hit_end or (hit_cache and loaded_complete)
    if not no_cache and nodes:
        save_cache(slug, nodes, new_complete)

    commits_meta, line_stats, avatars = {}, {}, {}
    for n in nodes:
        author = n.get("author") or {}
        email = (author.get("email") or "").lower()
        commits_meta[n["oid"]] = {
            "subject": n.get("messageHeadline") or "",
            "email": email,
            "name": author.get("name") or email or "unknown",
            "iso": author.get("date"),
        }
        line_stats[n["oid"]] = [n.get("additions") or 0, n.get("deletions") or 0]
        user = author.get("user")
        if user and user.get("avatarUrl") and email and email not in avatars:
            avatars[email] = user["avatarUrl"]

    return repo_name, repo_url, "", commits_meta, line_stats, avatars, default_branch


def apply_filters(commits_meta, line_stats, commits_filter, since, until):
    if since or until:
        def in_range(m):
            d = (m.get("iso") or "")[:10]
            return bool(d) and (not since or d >= since) and (not until or d <= until)
        commits_meta = {h: m for h, m in commits_meta.items() if in_range(m)}
    if commits_filter:
        ordered = sorted(commits_meta, key=lambda h: commits_meta[h].get("iso") or "")
        if commits_filter[0] == "last":
            keep = set(ordered[-commits_filter[1]:])
        else:
            keep = set(ordered[commits_filter[1]:commits_filter[2]])
        commits_meta = {h: m for h, m in commits_meta.items() if h in keep}
    line_stats = {h: line_stats[h] for h in commits_meta if h in line_stats}
    return commits_meta, line_stats


def build_data(
    top_n,
    repo_name,
    github_base,
    current_email,
    commits_meta,
    line_stats,
    avatars,
    default_branch,
):
    authors = {}
    daily_by_author = defaultdict(lambda: defaultdict(int))
    hourly_by_author = defaultdict(lambda: [0] * 24)
    dow_by_author = defaultdict(lambda: [0] * 7)
    weekly_by_author = defaultdict(lambda: defaultdict(int))
    all_dates, all_weeks = set(), set()
    total_added = total_deleted = 0

    for h, meta in commits_meta.items():
        iso = meta.get("iso")
        if not iso:
            continue
        try:
            dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        except ValueError:
            continue
        d_key = dt.strftime("%Y-%m-%d")
        wk, hr, dow = iso_week_label(dt), dt.hour, dt.weekday()
        email, name = meta["email"], meta["name"]
        a, d = line_stats.get(h, [0, 0])
        total_added += a
        total_deleted += d

        rec = authors.setdefault(
            email,
            {
                "name": name,
                "email": email,
                "commits": 0,
                "added": 0,
                "deleted": 0,
                "dates": set(),
                "daily_counts": defaultdict(int),
                "first": d_key,
                "last": d_key,
            },
        )
        rec["commits"] += 1
        rec["added"] += a
        rec["deleted"] += d
        rec["dates"].add(d_key)
        rec["daily_counts"][d_key] += 1
        if d_key < rec["first"]:
            rec["first"] = d_key
        if d_key > rec["last"]:
            rec["last"] = d_key

        daily_by_author[email][d_key] += 1
        hourly_by_author[email][hr] += 1
        dow_by_author[email][dow] += 1
        weekly_by_author[email][wk] += 1
        all_dates.add(d_key)
        all_weeks.add(wk)

    total_contributors = len(authors)
    ranked = sorted(authors.values(), key=lambda r: r["commits"], reverse=True)
    top = ranked[:top_n]
    top_emails = {r["email"] for r in top}

    contributors = []
    for r in top:
        busiest_day, busiest_count = "", 0
        for k, v in r["daily_counts"].items():
            if v > busiest_count:
                busiest_day, busiest_count = k, v
        contributors.append(
            {
                "name": r["name"],
                "email": r["email"],
                "commits": r["commits"],
                "added": r["added"],
                "deleted": r["deleted"],
                "activeDays": len(r["dates"]),
                "first": r["first"],
                "last": r["last"],
                "busiestDay": busiest_day,
                "busiestCount": busiest_count,
                "avatarUrl": avatar_url(r["email"], override=avatars.get(r["email"])),
                "highlight": bool(current_email) and r["email"] == current_email,
            }
        )

    weeks_sorted = sorted(all_weeks)
    weekly_data = {
        r["email"]: [weekly_by_author[r["email"]].get(w, 0) for w in weeks_sorted]
        for r in top
    }
    daily_data = {r["email"]: dict(daily_by_author[r["email"]]) for r in top}
    hourly_data = {r["email"]: hourly_by_author[r["email"]] for r in top}
    dow_data = {r["email"]: dow_by_author[r["email"]] for r in top}

    commits_list = []
    for h, meta in commits_meta.items():
        if meta["email"] not in top_emails:
            continue
        a, d = line_stats.get(h, [0, 0])
        commits_list.append(
            {
                "h": h[:7],
                "s": (meta["subject"] or "")[:120],
                "e": meta["email"],
                "d": (meta.get("iso") or "")[:19],
                "a": a,
                "l": d,
            }
        )

    date_range = (
        {"start": min(all_dates), "end": max(all_dates)}
        if all_dates
        else {"start": "", "end": ""}
    )
    return {
        "repoName": repo_name,
        "githubBaseUrl": github_base,
        "defaultBranch": default_branch,
        "dateRange": date_range,
        "totals": {
            "commits": len(commits_meta),
            "added": total_added,
            "deleted": total_deleted,
            "contributors": total_contributors,
        },
        "contributors": contributors,
        "weeks": weeks_sorted,
        "weeklyData": weekly_data,
        "dailyData": daily_data,
        "hourlyData": hourly_data,
        "dowData": dow_data,
        "commits": commits_list,
    }


def main():
    top_n, remote, output, no_open, no_cache, commits_filter, since, until = parse_args(
        sys.argv[1:]
    )

    if remote:
        print(f"Fetching {remote} via GitHub GraphQL…", file=sys.stderr)
        (
            repo_name,
            github_base,
            current_email,
            commits_meta,
            line_stats,
            avatars,
            default_branch,
        ) = collect_remote(
            remote,
            no_cache=no_cache,
            commits_filter=commits_filter,
            since=since,
            until=until,
        )
    else:
        try:
            subprocess.check_output(
                ["git", "rev-parse", "--git-dir"], stderr=subprocess.DEVNULL
            )
        except subprocess.CalledProcessError:
            sys.exit(
                "error: not in a git repository (and no owner/repo argument given)"
            )
        (
            repo_name,
            github_base,
            current_email,
            commits_meta,
            line_stats,
            avatars,
            default_branch,
        ) = collect_local()

    if not commits_meta:
        sys.exit("error: no commits found")

    if commits_filter or since or until:
        total_before = len(commits_meta)
        commits_meta, line_stats = apply_filters(
            commits_meta, line_stats, commits_filter, since, until
        )
        print(
            f"  filtered: {len(commits_meta)}/{total_before} commits", file=sys.stderr
        )
        if not commits_meta:
            sys.exit("error: no commits match the given filters")

    data = build_data(
        top_n,
        repo_name,
        github_base,
        current_email,
        commits_meta,
        line_stats,
        avatars,
        default_branch,
    )

    payload = f"window.__DATA__ = {json.dumps(data, ensure_ascii=False, separators=(',', ':'))};"
    template = TEMPLATE
    if template == "__TEMPLATE_PLACEHOLDER__":
        sibling = Path(__file__).resolve().parent / "template.html"
        if not sibling.exists():
            sys.exit(f"error: unbuilt script and template.html not found at {sibling}")
        template = sibling.read_text()
    if PLACEHOLDER not in template:
        sys.exit(f"error: placeholder {PLACEHOLDER!r} not found in template")
    html = template.replace(PLACEHOLDER, payload)

    if output:
        out_path = Path(output).expanduser()
    else:
        safe_name = re.sub(r"[^\w.-]+", "-", data["repoName"]).strip("-") or "repo"
        owner = ""
        if data["githubBaseUrl"]:
            m = ORIGIN_RE.match(data["githubBaseUrl"])
            if m:
                owner = re.sub(r"[^\w.-]+", "-", m.group(1)).strip("-")
        stem = f"{owner}--{safe_name}" if owner else safe_name
        out_path = Path("/tmp") / f"{stem}.html"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(html)

    print(f"Wrote {out_path}")
    print(
        f"  {data['totals']['commits']} commits · "
        f"{data['dateRange']['start']} — {data['dateRange']['end']} · "
        f"{data['totals']['contributors']} contributor"
        f"{'' if data['totals']['contributors'] == 1 else 's'}"
    )
    print("  top 3:")
    for c in data["contributors"][:3]:
        print(f"    {c['commits']:>5}  {c['name']} <{c['email']}>")

    if no_open:
        return
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    try:
        subprocess.run([opener, str(out_path)], check=False)
    except FileNotFoundError:
        webbrowser.open(out_path.as_uri())


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        sys.exit(130)
