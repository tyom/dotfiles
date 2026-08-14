#!/bin/bash

# Exercise gw through a real throwaway repository and worktree.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/repo"
cat >"$TMP/bin/less" <<'EOF'
#!/bin/bash
cat
EOF
chmod +x "$TMP/bin/less"

git -C "$TMP/repo" init -q -b develop
echo 'base' >"$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" -c user.name=test -c user.email=test@example.com \
  commit -qm 'base' --no-gpg-sign
git -C "$TMP/repo" branch feature
git -C "$TMP/repo" worktree add -q "$TMP/feature" feature
echo 'feature' >>"$TMP/feature/file"
git -C "$TMP/feature" add file
git -C "$TMP/feature" -c user.name=test -c user.email=test@example.com \
  commit -qm 'feature' --no-gpg-sign
git -C "$TMP/repo" merge -q --ff-only feature

# This is the local state made by `git remote set-head origin -a`.
git -C "$TMP/repo" update-ref refs/remotes/origin/develop refs/heads/develop
git -C "$TMP/repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop

set +e
output=$(cd "$TMP/repo" && COLUMNS=120 PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/home/bin/gw")
result=$?
set -e
if [ "$result" -ne 0 ] || [[ "$output" != *'✓'*feature* ]]; then
  echo ' ✖ gw does not mark a feature merged into the develop default branch'
  exit 1
fi

echo ' ✔ gw uses the repository default branch when classifying worktrees'
