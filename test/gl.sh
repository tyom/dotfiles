#!/bin/bash

# Exercise gl through a real throwaway repository.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo " ✖ $1"; exit 1; }

mkdir -p "$TMP/bin" "$TMP/repo"
cat >"$TMP/bin/less" <<'EOF'
#!/bin/bash
cat
if [[ -n "$GL_TEST_QUIT" && "$*" == *'q quit x'* ]]; then
  exit 120
fi
EOF
chmod +x "$TMP/bin/less"

git -C "$TMP/repo" init -q -b topic
echo 'base' >"$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" -c user.name=test -c user.email=test@example.com \
  commit -qm 'base' --no-gpg-sign
git -C "$TMP/repo" tag v1
git -C "$TMP/repo" branch merged
git -C "$TMP/repo" update-ref refs/remotes/origin/topic HEAD
git -C "$TMP/repo" switch -qc pending
echo 'pending' >>"$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" -c user.name=test -c user.email=test@example.com \
  commit -qm 'pending' --no-gpg-sign
git -C "$TMP/repo" switch -q topic

output=$(cd "$TMP/repo" && PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/home/bin/gl" --all --max-count=2)
current_block=$'\033[7m topic \033[m'
merged_branch=$'\033[32m✓ merged\033[37m'
unmerged_branch=$'\033[32m✓ pending\033[37m'
remote_branch=$'\033[32morigin/topic\033[37m'

[[ "$output" == *"$current_block"* && "$output" != *HEAD* && \
  "$output" == *'tag: v1'* && "$output" == *"$merged_branch"* && \
  "$output" != *"$unmerged_branch"* && "$output" == *"$remote_branch"* ]] ||
  fail 'gl branch decorations are wrong'

# The refs of the newest commit head the output, so they sit above it
marker=$(sed -n "s/^marker='\(.*\)'$/\1/p" "$ROOT/home/bin/gl")
[[ "${output%%$'\n'*}" == "$marker "* ]] || fail 'gl refs are not above their commit'

# The commit right below the current branch carries the bright sha
[[ "$(printf '%s\n' "$output" | grep -A1 -F "$current_block" | sed -n 2p)" == $'\033[1m'* ]] ||
  fail 'gl does not brighten the current commit'

git -C "$TMP/repo" checkout -q --detach
output=$(cd "$TMP/repo" && PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/home/bin/gl" --max-count=1)
detached_head=$'\033[32mHEAD\033[37m'

[[ "$output" == *"$detached_head"* && "$output" != *$'\033[7m HEAD '* ]] ||
  fail 'gl changes the detached HEAD decoration'

output=$(cd "$TMP/repo" && GL_TEST_QUIT=1 PATH="$TMP/bin:/usr/bin:/bin" \
  "$ROOT/home/bin/gl" --max-count=1)
reserved_rows=$'\033[2A\r\033[J'

[[ "$output" == *"$reserved_rows" ]] || fail 'gl leaves no prompt room after q'

echo ' ✔ gl formats refs and leaves prompt room after q'
