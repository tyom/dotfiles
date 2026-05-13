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
  -o, --output PATH   Write the dashboard to PATH instead of /tmp/<owner>--<repo>.html.
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
  The GitHub CLI (`gh`, https://cli.github.com/) is optional but
  recommended — when authenticated it unlocks GraphQL remote fetching
  and author hovercard enrichment (avatar, bio, follower counts).
  Lookup order: `gh auth token -h github.com`, then $GITHUB_TOKEN.
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
from datetime import datetime, timedelta, timezone
from pathlib import Path

TEMPLATE = "__TEMPLATE_PLACEHOLDER__"
PLACEHOLDER = "/*__DATA_INJECTION__*/"
NOREPLY_RE = re.compile(r"(?:\d+\+)?(.+)@users\.noreply\.github\.com")
ORIGIN_RE = re.compile(
    r"^(?:https?://(?P<https_host>[^/]+)/|git@(?P<ssh_host>[^:]+):)"
    r"(?P<owner>[^/]+)/(?P<repo>.+?)(?:\.git)?/?$"
)
CACHE_DIR = (
    Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "repo-intel"
)


def parse_iso_instant(s):
    """Parse an ISO 8601 timestamp to a UTC-aware datetime; epoch on failure.

    Tags mix `Z`-suffixed UTC (GraphQL) with offset-suffixed local time
    (`git for-each-ref iso8601-strict`), so lex-sorting can misorder them.
    """
    if not s:
        return datetime(1970, 1, 1, tzinfo=timezone.utc)
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return datetime(1970, 1, 1, tzinfo=timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _slugify(s):
    return re.sub(r"[^\w.-]+", "-", s).strip("-")


def cache_path(slug):
    safe = _slugify(slug.lower()) or "repo"
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


def needs_older_fetch(have_count, cached_oldest_date, prev_complete,
                      commits_filter, since, until):
    """Should we paginate below the oldest cached commit after top-fetch?

    have_count: len(new_nodes) + len(cached_nodes) after the top-fetch.
    cached_oldest_date: YYYY-MM-DD of the oldest cached commit, "" if empty.
    """
    if prev_complete:
        return False
    if not cached_oldest_date:
        return False
    if until:
        return True
    if commits_filter:
        if commits_filter[0] == "last":
            return have_count < commits_filter[1]
        return True  # range — slice is anchored at oldest, must walk full history
    if since:
        return cached_oldest_date > since
    return True


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
            n = int(tok)
            if n <= 0:
                sys.stderr.write(f"repo-intel: N must be a positive integer (got {tok!r})\n")
                sys.exit(2)
            top_n = n
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


def login_from_email(email):
    m = NOREPLY_RE.fullmatch(email or "")
    return m.group(1) if m else ""


def avatar_url(email, override=None):
    if override:
        return override
    login = login_from_email(email)
    if login:
        return f"https://github.com/{login}.png?size=64"
    h = hashlib.md5(email.strip().lower().encode()).hexdigest()
    return f"https://www.gravatar.com/avatar/{h}?d=mp&s=64"


def iso_week_label(dt):
    y, w, _ = dt.isocalendar()
    return f"{y}-W{w:02d}"


def git(*args, cwd=None):
    return subprocess.check_output(["git", *args], text=True, cwd=cwd)


_CLONE_REFRESHED = set()


def ensure_bare_clone(owner, repo, no_cache):
    """Clone or fetch-update a bare repo under /tmp; idempotent within a run."""
    clone_dir = f"/tmp/repo-intel-{owner}-{repo}.git"
    if clone_dir in _CLONE_REFRESHED:
        return clone_dir
    if not os.path.isdir(clone_dir):
        subprocess.check_call(
            ["git", "clone", "--bare", f"https://github.com/{owner}/{repo}.git", clone_dir]
        )
    elif not no_cache:
        print("  updating cached bare clone…", file=sys.stderr)
        subprocess.run(
            ["git", "fetch", "--quiet", "origin"], cwd=clone_dir, check=False
        )
    _CLONE_REFRESHED.add(clone_dir)
    return clone_dir


def prompt_subset(total):
    """Ask which subset to fetch when a repo has many commits.

    Returns (commits_filter, since, until). All-None means "fetch all".
    """
    today = datetime.now(timezone.utc).date()
    one_year_ago = (today - timedelta(days=365)).isoformat()
    sys.stderr.write(
        f"\nRepository has {total:,} commits. Choose a subset to fetch:\n"
        f"  [1] Last 500\n"
        f"  [2] Last 1000\n"
        f"  [3] Past year (since {one_year_ago})\n"
        f"  [4] All\n"
    )
    while True:
        sys.stderr.write("Choice [4]: ")
        sys.stderr.flush()
        try:
            line = sys.stdin.readline()
        except KeyboardInterrupt:
            sys.stderr.write("\nAborted.\n")
            sys.exit(130)
        if not line:
            return None, None, None
        choice = line.strip() or "4"
        if choice == "1":
            return ("last", 500), None, None
        if choice == "2":
            return ("last", 1000), None, None
        if choice == "3":
            return None, one_year_ago, None
        if choice == "4":
            return None, None, None
        sys.stderr.write(f"  invalid choice {choice!r}\n")


def repo_disk_kb(cwd=None):
    """Total on-disk size of git objects (loose + packed) in KB."""
    try:
        out = git("count-objects", "-v", cwd=cwd)
    except subprocess.CalledProcessError:
        return 0
    size = size_pack = 0
    for line in out.splitlines():
        key, _, val = line.partition(":")
        try:
            n = int(val.strip())
        except ValueError:
            continue
        if key == "size":
            size = n
        elif key == "size-pack":
            size_pack = n
    return size + size_pack


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


def collect_local_tags(cwd=None):
    """Return list of {name, oid, date, message} for git tags, by commit date."""
    fmt = (
        "%(refname:short)\x1f"
        "%(*objectname)\x1f%(objectname)\x1f"
        "%(*committerdate:iso8601-strict)\x1f%(committerdate:iso8601-strict)\x1f"
        "%(contents:subject)"
    )
    try:
        out = git("tag", "-l", f"--format={fmt}", cwd=cwd)
    except subprocess.CalledProcessError:
        return []
    tags = []
    for line in out.splitlines():
        if not line:
            continue
        parts = line.split("\x1f")
        if len(parts) < 6:
            continue
        name, peel_oid, obj_oid, peel_date, obj_date = parts[:5]
        subject = "\x1f".join(parts[5:])
        oid = peel_oid or obj_oid
        date = peel_date or obj_date
        if not oid or not date:
            continue
        tags.append({"name": name, "oid": oid, "date": date, "message": subject})
    tags.sort(key=lambda t: parse_iso_instant(t.get("date")))
    return tags


def collect_local(cwd=None, suppress_current_user=False):
    repo_root = git("rev-parse", "--show-toplevel", cwd=cwd).strip()
    repo_name = os.path.basename(repo_root)
    github_base = ""
    try:
        url = git("remote", "get-url", "origin", cwd=cwd).strip()
        m = ORIGIN_RE.match(url)
        if m:
            host = m.group("https_host") or m.group("ssh_host")
            host_lc = (host or "").lower()
            if host_lc == "github.com" or host_lc.endswith(".github.com"):
                github_base = f"https://{host}/{m.group('owner')}/{m.group('repo')}"
                repo_name = m.group("repo")
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
        {},
        default_branch,
        repo_disk_kb(cwd=cwd),
        collect_local_tags(cwd=cwd),
    )


def gh_graphql(query, variables, token):
    """POST a GraphQL query to api.github.com. Returns the parsed JSON body."""
    payload = json.dumps({"query": query, "variables": variables}).encode()
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
        return json.loads(resp.read())


def gh_repository(body):
    """Extract data.repository defensively — GraphQL returns null on errors."""
    return (body.get("data") or {}).get("repository") or {}


def probe_remote_total(owner, repo, token):
    """Total commits on the default branch via GraphQL; None on error."""
    query = """
query($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    defaultBranchRef {
      target { ... on Commit { history(first: 1) { totalCount } } }
    }
  }
}
""".strip()
    try:
        body = gh_graphql(query, {"owner": owner, "repo": repo}, token)
    except urllib.error.URLError:
        return None
    if "errors" in body:
        return None
    repo_node = gh_repository(body)
    branch = repo_node.get("defaultBranchRef") or {}
    target = branch.get("target") or {}
    history = target.get("history") or {}
    total = history.get("totalCount")
    return total if isinstance(total, int) else None


def get_github_token():
    try:
        token = subprocess.check_output(
            ["gh", "auth", "token", "-h", "github.com"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        token = ""
    return token or os.environ.get("GITHUB_TOKEN") or None


def fetch_logins_for_commits(owner, repo, oids_by_email, token):
    """Look up GitHub author login for each email using a few sample oids.

    Used in the local-repo path where the commit walk doesn't know logins.
    Local commits not yet pushed return null, so multiple oids per email are
    queried in one batched GraphQL call; the first that resolves wins.
    Returns {email: login}.
    """
    if not oids_by_email or not token:
        return {}
    aliases = []
    oid_values = []
    for email, oids in oids_by_email.items():
        for oid in oids:
            aliases.append((len(oid_values), email))
            oid_values.append(oid)
    if not aliases:
        return {}
    var_decls = ", ".join(f"$oid{i}: GitObjectID!" for i in range(len(oid_values)))
    fragments = " ".join(
        f"c{i}: object(oid: $oid{i}) {{ ... on Commit {{ author {{ user {{ login }} }} }} }}"
        for i in range(len(oid_values))
    )
    query = (
        f"query($owner: String!, $repo: String!, {var_decls}) "
        f"{{ repository(owner: $owner, name: $repo) {{ {fragments} }} }}"
    )
    variables = {"owner": owner, "repo": repo}
    for i, oid in enumerate(oid_values):
        variables[f"oid{i}"] = oid

    try:
        body = gh_graphql(query, variables, token)
    except urllib.error.URLError as exc:
        print(f"  warning: login lookup failed: {exc}", file=sys.stderr)
        return {}
    if "errors" in body:
        print(f"  warning: login lookup errors: {body['errors']}", file=sys.stderr)
    repo_node = gh_repository(body)
    out = {}
    for i, email in aliases:
        if email in out:
            continue
        node = repo_node.get(f"c{i}") or {}
        user = ((node.get("author") or {}).get("user")) or {}
        login = user.get("login")
        if login:
            out[email] = login
    return out


def fetch_user_profiles(logins, token):
    """Fetch GitHub profile fields for `logins` in one aliased GraphQL query.

    Returns {login: {login,name,bio,location,websiteUrl,followers,following,publicRepos}}.
    Missing/renamed users are silently skipped.
    """
    if not logins or not token:
        return {}
    unique = []
    seen = set()
    for login in logins:
        if login and login not in seen:
            seen.add(login)
            unique.append(login)
    if not unique:
        return {}

    fields = (
        "login name bio location websiteUrl "
        "followers { totalCount } following { totalCount } "
        "repositories(privacy: PUBLIC, ownerAffiliations: OWNER) { totalCount }"
    )
    var_decls = ", ".join(f"$l{i}: String!" for i in range(len(unique)))
    fragments = " ".join(
        f"u{i}: user(login: $l{i}) {{ {fields} }}" for i in range(len(unique))
    )
    query = f"query({var_decls}) {{ {fragments} }}"
    variables = {f"l{i}": login for i, login in enumerate(unique)}

    try:
        body = gh_graphql(query, variables, token)
    except urllib.error.URLError as exc:
        print(f"  warning: profile fetch failed: {exc}", file=sys.stderr)
        return {}
    if "errors" in body:
        print(f"  warning: profile fetch errors: {body['errors']}", file=sys.stderr)
    data = body.get("data") or {}
    out = {}
    for i, login in enumerate(unique):
        node = data.get(f"u{i}")
        if not node:
            continue
        out[login] = {
            "login": node.get("login") or login,
            "name": node.get("name") or "",
            "bio": node.get("bio") or "",
            "location": node.get("location") or "",
            "websiteUrl": node.get("websiteUrl") or "",
            "followers": (node.get("followers") or {}).get("totalCount") or 0,
            "following": (node.get("following") or {}).get("totalCount") or 0,
            "publicRepos": (node.get("repositories") or {}).get("totalCount") or 0,
        }
    return out


def fetch_remote_tags(owner, repo, token):
    """Fetch all tag refs via GraphQL. Returns list of {name, oid, date, message}."""
    query = """
query($owner: String!, $repo: String!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    refs(refPrefix: "refs/tags/", first: 100, after: $cursor, orderBy: {field: TAG_COMMIT_DATE, direction: ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name
        target {
          __typename
          ... on Tag {
            message
            target { ... on Commit { oid committedDate } }
          }
          ... on Commit { oid committedDate }
        }
      }
    }
  }
}
""".strip()
    cursor = None
    tags = []
    while True:
        try:
            body = gh_graphql(query, {"owner": owner, "repo": repo, "cursor": cursor}, token)
        except urllib.error.URLError as exc:
            print(f"  warning: tag fetch failed: {exc}", file=sys.stderr)
            return tags
        if "errors" in body:
            print(f"  warning: tag fetch GraphQL error: {body['errors']}", file=sys.stderr)
            return tags
        refs = gh_repository(body).get("refs") or {}
        for node in refs.get("nodes") or []:
            tgt = node.get("target") or {}
            kind = tgt.get("__typename")
            if kind == "Tag":
                inner = tgt.get("target") or {}
                oid = inner.get("oid") or ""
                date = inner.get("committedDate") or ""
                message = tgt.get("message") or ""
            elif kind == "Commit":
                oid = tgt.get("oid") or ""
                date = tgt.get("committedDate") or ""
                message = ""
            else:
                continue
            if not oid or not date:
                continue
            tags.append({
                "name": node.get("name") or "",
                "oid": oid,
                "date": date,
                "message": (message.splitlines() or [""])[0],
            })
        page = refs.get("pageInfo") or {}
        if not page.get("hasNextPage"):
            break
        cursor = page.get("endCursor")
    tags.sort(key=lambda t: parse_iso_instant(t.get("date")))
    return tags


def _paginate_history(fetch_page, cached_oids, last_n, since,
                      have_count_baseline, label, skip_first=False):
    """Walk a Commit.history connection page by page.

    fetch_page(cursor) -> history dict, or None when the anchor object is gone.
    Returns (nodes, reason) where reason ∈
        "hit_cache" | "short_circuit" | "page_end" | "anchor_null"
    """
    nodes = []
    cursor = None
    dropped_anchor = not skip_first
    while True:
        history = fetch_page(cursor)
        if history is None:
            return nodes, "anchor_null"
        for n in history.get("nodes") or []:
            if not dropped_anchor:
                dropped_anchor = True
                continue
            if n["oid"] in cached_oids:
                return nodes, "hit_cache"
            nodes.append(n)
            if last_n is not None and len(nodes) + have_count_baseline >= last_n:
                return nodes, "short_circuit"
            if since:
                d = ((n.get("author") or {}).get("date") or "")[:10]
                if d and d < since:
                    return nodes, "short_circuit"
        page = history.get("pageInfo") or {}
        if not page.get("hasNextPage"):
            return nodes, "page_end"
        cursor = page.get("endCursor")
        print(f"  fetched {len(nodes)} {label} commits…", file=sys.stderr)


def collect_remote(slug, token, no_cache=False, commits_filter=None, since=None, until=None):
    owner, repo = slug.split("/", 1)

    if not token:
        clone_dir = ensure_bare_clone(owner, repo, no_cache)
        (
            repo_name,
            github_base,
            _,
            commits_meta,
            line_stats,
            _,
            _,
            default_branch,
            repo_size_kb,
            tags,
        ) = collect_local(cwd=clone_dir, suppress_current_user=True)
        if not github_base:
            github_base = f"https://github.com/{owner}/{repo}"
        return (
            repo_name,
            github_base,
            "",
            commits_meta,
            line_stats,
            {},
            {},
            default_branch,
            repo_size_kb,
            tags,
        )

    history_block = """
history(first: 100, after: $cursor) {
  pageInfo { hasNextPage endCursor }
  nodes {
    oid messageHeadline
    author { name email date user { avatarUrl(size: 64) login } }
    additions deletions
  }
}""".strip()

    top_query = f"""
query($owner: String!, $repo: String!, $cursor: String) {{
  repository(owner: $owner, name: $repo) {{
    name url diskUsage
    defaultBranchRef {{
      name
      target {{ ... on Commit {{ {history_block} }} }}
    }}
  }}
}}""".strip()

    bottom_query = f"""
query($owner: String!, $repo: String!, $oid: GitObjectID!, $cursor: String) {{
  repository(owner: $owner, name: $repo) {{
    object(oid: $oid) {{ ... on Commit {{ {history_block} }} }}
  }}
}}""".strip()

    loaded_nodes, loaded_complete = ([], False) if no_cache else load_cache(slug)
    cached_nodes = loaded_nodes
    cached_oids = {n["oid"] for n in cached_nodes}
    if cached_nodes:
        label = "complete" if loaded_complete else "partial"
        print(f"  cache: {len(cached_nodes)} commits ({label})", file=sys.stderr)

    last_n = commits_filter[1] if commits_filter and commits_filter[0] == "last" else None

    repo_meta = {
        "name": repo,
        "url": f"https://github.com/{owner}/{repo}",
        "branch": "main",
        "disk_kb": 0,
    }

    def top_fetch_page(cursor):
        body = gh_graphql(top_query, {"owner": owner, "repo": repo, "cursor": cursor}, token)
        if "errors" in body:
            sys.exit(f"GraphQL error: {body['errors']}")
        repo_node = gh_repository(body)
        if not repo_node:
            sys.exit(f"Repository not found or inaccessible: {slug}")
        repo_meta["name"] = repo_node["name"]
        repo_meta["url"] = repo_node["url"]
        repo_meta["disk_kb"] = repo_node.get("diskUsage") or 0
        branch_ref = repo_node.get("defaultBranchRef")
        if not branch_ref or not branch_ref.get("target"):
            sys.exit(f"error: {slug} has no commits on its default branch")
        repo_meta["branch"] = branch_ref.get("name") or repo_meta["branch"]
        return branch_ref["target"]["history"]

    new_nodes, top_reason = _paginate_history(
        top_fetch_page, cached_oids, last_n, since,
        have_count_baseline=len(cached_nodes), label="new",
    )

    if top_reason == "page_end" and cached_oids:
        print(
            f"  cache: orphaned by force-push/rewrite, discarded ({len(cached_nodes)} commits)",
            file=sys.stderr,
        )
        cached_nodes = []
        cached_oids = set()
        loaded_complete = False
    if new_nodes:
        print(f"  fetched {len(new_nodes)} new commits", file=sys.stderr)

    older_nodes = []
    bottom_reason = None
    have_count = len(new_nodes) + len(cached_nodes)
    cached_oldest_date = (
        ((cached_nodes[-1].get("author") or {}).get("date") or "")[:10]
        if cached_nodes else ""
    )
    if needs_older_fetch(
        have_count, cached_oldest_date, loaded_complete,
        commits_filter, since, until,
    ):
        anchor_oid = cached_nodes[-1]["oid"]

        def bottom_fetch_page(cursor):
            body = gh_graphql(
                bottom_query,
                {"owner": owner, "repo": repo, "oid": anchor_oid, "cursor": cursor},
                token,
            )
            if "errors" in body:
                sys.exit(f"GraphQL error: {body['errors']}")
            obj = gh_repository(body).get("object")
            if not obj:
                return None
            return obj.get("history") or {"nodes": [], "pageInfo": {}}

        older_nodes, bottom_reason = _paginate_history(
            bottom_fetch_page, cached_oids, last_n, since,
            have_count_baseline=have_count, label="older", skip_first=True,
        )
        if bottom_reason == "anchor_null":
            print(
                "  warning: cache anchor commit no longer exists; keeping what we have",
                file=sys.stderr,
            )
        elif older_nodes:
            print(f"  fetched {len(older_nodes)} older commits", file=sys.stderr)

    repo_name = repo_meta["name"]
    repo_url = repo_meta["url"]
    default_branch = repo_meta["branch"]
    repo_size_kb = repo_meta["disk_kb"]

    nodes = new_nodes + cached_nodes + older_nodes
    if bottom_reason is None:
        new_complete = top_reason == "page_end" or loaded_complete
    else:
        new_complete = bottom_reason == "page_end"
    if not no_cache and nodes:
        save_cache(slug, nodes, new_complete)

    commits_meta, line_stats, avatars, logins = {}, {}, {}, {}
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
        if user and email:
            if user.get("avatarUrl") and email not in avatars:
                avatars[email] = user["avatarUrl"]
            if user.get("login") and email not in logins:
                logins[email] = user["login"]

    tags = fetch_remote_tags(owner, repo, token)
    return (
        repo_name,
        repo_url,
        "",
        commits_meta,
        line_stats,
        avatars,
        logins,
        default_branch,
        repo_size_kb,
        tags,
    )


def apply_filters(commits_meta, line_stats, commits_filter, since, until):
    if since or until:
        def in_range(m):
            d = (m.get("iso") or "")[:10]
            return bool(d) and (not since or d >= since) and (not until or d <= until)
        commits_meta = {h: m for h, m in commits_meta.items() if in_range(m)}
    if commits_filter:
        epoch = datetime(1970, 1, 1, tzinfo=timezone.utc)
        def _ts(h):
            iso = commits_meta[h].get("iso") or ""
            if not iso:
                return epoch
            try:
                return datetime.fromisoformat(iso.replace("Z", "+00:00"))
            except ValueError:
                return epoch
        ordered = sorted(commits_meta, key=_ts)
        if commits_filter[0] == "last":
            keep = set(ordered[-commits_filter[1]:])
        else:
            keep = set(ordered[commits_filter[1]:commits_filter[2]])
        commits_meta = {h: m for h, m in commits_meta.items() if h in keep}
    line_stats = {h: line_stats[h] for h in commits_meta if h in line_stats}
    return commits_meta, line_stats


def filter_tags_to_range(tags, commits_meta):
    if not tags or not commits_meta:
        return []
    dates = [(m.get("iso") or "")[:10] for m in commits_meta.values()]
    dates = [d for d in dates if d]
    if not dates:
        return list(tags)
    lo, hi = min(dates), max(dates)
    return [t for t in tags if lo <= (t.get("date") or "")[:10] <= hi]


def build_data(
    top_n,
    repo_name,
    github_base,
    current_email,
    commits_meta,
    line_stats,
    avatars,
    logins,
    default_branch,
    repo_size_kb,
    tags,
):
    authors = {}
    daily_by_author = defaultdict(lambda: defaultdict(int))
    hourly_by_author = defaultdict(lambda: [0] * 24)
    dow_by_author = defaultdict(lambda: [0] * 7)
    weekly_by_author = defaultdict(lambda: defaultdict(int))
    all_dates, all_weeks = set(), set()
    total_added = total_deleted = total_commits = 0

    for h, meta in commits_meta.items():
        iso = meta.get("iso")
        if not iso:
            continue
        try:
            dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        except ValueError:
            continue
        total_commits += 1
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
        login = logins.get(r["email"]) or login_from_email(r["email"])
        contributors.append(
            {
                "name": r["name"],
                "email": r["email"],
                "login": login,
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
                "d": meta.get("iso") or "",
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
        "repoSizeKb": repo_size_kb,
        "dateRange": date_range,
        "totals": {
            "commits": total_commits,
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
        "tags": tags or [],
    }


def _sample_oids_per_email(commits_meta, target_emails, per_email=3):
    """Up to `per_email` oldest oids per email. Unknown-date commits sort last."""
    by_email = defaultdict(list)
    for h, meta in commits_meta.items():
        if meta["email"] in target_emails:
            by_email[meta["email"]].append((meta.get("iso") or "", h))
    sample = {}
    for email, items in by_email.items():
        items.sort(key=lambda x: (not x[0], x[0]))
        sample[email] = [h for _, h in items[:per_email]]
    return sample


def enrich_contributor_profiles(contributors, commits_meta, github_base, token=None):
    """In-place: attach `profile` dict to contributors using GitHub GraphQL."""
    if not github_base:
        return
    if token is None:
        token = get_github_token()
    if not token:
        return
    origin = ORIGIN_RE.match(github_base)
    if not origin:
        return
    # gh_graphql is hardcoded to api.github.com; skip Enterprise hosts so we
    # don't issue lookups against the wrong API.
    if (origin.group("https_host") or "").lower() != "github.com":
        return

    missing = [c for c in contributors if not c.get("login")]
    if missing:
        sample = _sample_oids_per_email(
            commits_meta, {c["email"] for c in missing}
        )
        resolved = fetch_logins_for_commits(
            origin.group("owner"), origin.group("repo"), sample, token
        )
        for c in missing:
            login = resolved.get(c["email"])
            if login:
                c["login"] = login

    top_logins = [c["login"] for c in contributors if c.get("login")]
    profiles = fetch_user_profiles(top_logins, token)
    for c in contributors:
        p = profiles.get(c.get("login") or "")
        if p:
            c["profile"] = p


def main():
    top_n, remote, output, no_open, no_cache, commits_filter, since, until = parse_args(
        sys.argv[1:]
    )

    token = None
    if remote:
        owner, repo = remote.split("/", 1)
        token = get_github_token()

        if not token:
            print("No GitHub token — falling back to bare clone.", file=sys.stderr)

        # Subset prompt only in the GraphQL path: probing total via the API is
        # cheap, and skipping `--commits N` actually saves network. In the
        # bare-clone path the full clone runs regardless, so the prompt would
        # only trim local display — pass `--commits` / `--since` for that.
        if (
            token
            and not (commits_filter or since or until)
            and sys.stdin.isatty()
            and sys.stderr.isatty()
        ):
            has_any_cache = not no_cache and cache_path(remote).exists()
            total = None if has_any_cache else probe_remote_total(owner, repo, token)
            if total and total > 1000:
                commits_filter, since, until = prompt_subset(total)

        if token:
            print(f"Fetching {remote} via GitHub GraphQL…", file=sys.stderr)
        (
            repo_name,
            github_base,
            current_email,
            commits_meta,
            line_stats,
            avatars,
            logins,
            default_branch,
            repo_size_kb,
            tags,
        ) = collect_remote(
            remote,
            token,
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
            logins,
            default_branch,
            repo_size_kb,
            tags,
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

    tags = filter_tags_to_range(tags, commits_meta)

    data = build_data(
        top_n,
        repo_name,
        github_base,
        current_email,
        commits_meta,
        line_stats,
        avatars,
        logins,
        default_branch,
        repo_size_kb,
        tags,
    )

    enrich_contributor_profiles(data["contributors"], commits_meta, github_base, token=token)

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
        safe_name = _slugify(data["repoName"]) or "repo"
        owner = ""
        if data["githubBaseUrl"]:
            m = ORIGIN_RE.match(data["githubBaseUrl"])
            if m:
                owner = _slugify(m.group("owner"))
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
