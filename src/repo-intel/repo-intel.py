#!/usr/bin/env python3
"""repo-intel — generate a contributor stats dashboard for a git repo."""

HELP = """\
repo-intel — generate a contributor stats dashboard for a git repo.

Usage:
  repo-intel [N] [REPO]
  repo-intel -h | --help

Arguments:
  N       Number of top contributors to include (default: 10)
  REPO    A GitHub repository, in any of these forms:
            owner/repo
            https://github.com/owner/repo
            remote:owner/repo
          When omitted, the current working directory is used as a local git repo.

Options:
  -h, --help    Show this help message and exit.

Examples:
  repo-intel                       # local repo (cwd), top 10
  repo-intel 20                    # local repo, top 20
  repo-intel facebook/react        # remote, top 10
  repo-intel 15 facebook/react     # remote, top 15

Remote auth:
  Uses `gh auth token -h github.com`, then $GITHUB_TOKEN.
  Falls back to `git clone --bare` into /tmp if neither is available.

Output:
  /tmp/<repo-name>.html (opened in default browser).
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
ORIGIN_RE = re.compile(r"^(?:https?://github\.com/|git@github\.com:)([^/]+)/(.+?)(?:\.git)?/?$")


def parse_args(argv):
    if any(tok in ("-h", "--help") for tok in argv):
        sys.stdout.write(HELP)
        sys.exit(0)
    top_n, remote = 10, None
    for tok in argv:
        if tok.isdigit():
            top_n = int(tok)
            continue
        t = tok.removeprefix("remote:")
        t = t.removeprefix("https://github.com/").removeprefix("http://github.com/")
        parts = t.rstrip("/").split("/")
        if len(parts) >= 2 and re.fullmatch(r"[\w.-]+", parts[0]) and re.fullmatch(r"[\w.-]+", parts[1]):
            remote = f"{parts[0]}/{parts[1]}"
            continue
        sys.stderr.write(f"repo-intel: unrecognized argument: {tok!r}\n")
        sys.stderr.write("Try 'repo-intel --help' for usage.\n")
        sys.exit(2)
    return top_n, remote


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
        ref = git("symbolic-ref", "--short", "refs/remotes/origin/HEAD", cwd=cwd).strip()
        if ref.startswith("origin/"):
            return ref[len("origin/"):]
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

    log = git("log", "--no-merges", "--format=%H\x1f%s\x1f%aE\x1f%aN\x1f%aI", cwd=cwd)
    commits_meta = {}
    for line in log.splitlines():
        parts = line.split("\x1f")
        if len(parts) != 5:
            continue
        h, s, email, name, dt_iso = parts
        commits_meta[h] = {"subject": s, "email": email.lower(), "name": name, "iso": dt_iso}

    ns = git("log", "--no-merges", "--pretty=format:%H", "--numstat", cwd=cwd)
    line_stats = {}
    cur = None
    for line in ns.splitlines():
        if not line:
            continue
        if re.fullmatch(r"[0-9a-f]{40}", line):
            cur = line
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
    return repo_name, github_base, current_email, commits_meta, line_stats, {}, default_branch


def collect_remote(slug):
    owner, repo = slug.split("/", 1)
    token = None
    try:
        token = subprocess.check_output(
            ["gh", "auth", "token", "-h", "github.com"],
            text=True, stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        token = os.environ.get("GITHUB_TOKEN")

    if not token:
        print("No GitHub token — falling back to bare clone.", file=sys.stderr)
        clone_dir = f"/tmp/repo-intel-{owner}-{repo}.git"
        if not os.path.isdir(clone_dir):
            subprocess.check_call(
                ["git", "clone", "--bare", f"https://github.com/{owner}/{repo}.git", clone_dir]
            )
        repo_name, github_base, _, commits_meta, line_stats, _, default_branch = collect_local(
            cwd=clone_dir, suppress_current_user=True
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
          history(first: 250, after: $cursor) {
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

    cursor = None
    nodes = []
    repo_name = repo
    repo_url = f"https://github.com/{owner}/{repo}"
    default_branch = "main"
    while True:
        payload = json.dumps({
            "query": query,
            "variables": {"owner": owner, "repo": repo, "cursor": cursor},
        }).encode()
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
        nodes.extend(history["nodes"])
        if not history["pageInfo"]["hasNextPage"]:
            break
        cursor = history["pageInfo"]["endCursor"]
        print(f"  fetched {len(nodes)} commits…", file=sys.stderr)

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


def build_data(top_n, repo_name, github_base, current_email, commits_meta, line_stats, avatars, default_branch):
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

        rec = authors.setdefault(email, {
            "name": name, "email": email,
            "commits": 0, "added": 0, "deleted": 0,
            "dates": set(), "daily_counts": defaultdict(int),
            "first": d_key, "last": d_key,
        })
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
        contributors.append({
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
        })

    weeks_sorted = sorted(all_weeks)
    weekly_data = {r["email"]: [weekly_by_author[r["email"]].get(w, 0) for w in weeks_sorted] for r in top}
    daily_data = {r["email"]: dict(daily_by_author[r["email"]]) for r in top}
    hourly_data = {r["email"]: hourly_by_author[r["email"]] for r in top}
    dow_data = {r["email"]: dow_by_author[r["email"]] for r in top}

    commits_list = []
    for h, meta in commits_meta.items():
        if meta["email"] not in top_emails:
            continue
        a, d = line_stats.get(h, [0, 0])
        commits_list.append({
            "h": h[:7],
            "s": (meta["subject"] or "")[:120],
            "e": meta["email"],
            "d": (meta.get("iso") or "")[:19],
            "a": a,
            "l": d,
        })

    date_range = (
        {"start": min(all_dates), "end": max(all_dates)} if all_dates else {"start": "", "end": ""}
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
    top_n, remote = parse_args(sys.argv[1:])

    if remote:
        print(f"Fetching {remote} via GitHub GraphQL…", file=sys.stderr)
        repo_name, github_base, current_email, commits_meta, line_stats, avatars, default_branch = collect_remote(remote)
    else:
        try:
            subprocess.check_output(["git", "rev-parse", "--git-dir"], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            sys.exit("error: not in a git repository (and no owner/repo argument given)")
        repo_name, github_base, current_email, commits_meta, line_stats, avatars, default_branch = collect_local()

    if not commits_meta:
        sys.exit("error: no commits found")

    data = build_data(top_n, repo_name, github_base, current_email, commits_meta, line_stats, avatars, default_branch)

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

    safe_name = re.sub(r"[^\w.-]+", "-", data["repoName"]).strip("-") or "repo"
    out_path = Path("/tmp") / f"{safe_name}.html"
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

    opener = "open" if sys.platform == "darwin" else "xdg-open"
    try:
        subprocess.run([opener, str(out_path)], check=False)
    except FileNotFoundError:
        webbrowser.open(out_path.as_uri())


if __name__ == "__main__":
    main()
