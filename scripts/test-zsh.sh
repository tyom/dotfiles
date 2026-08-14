#!/bin/bash

# Exercise the Oh My Zsh bootstrap against a local Git remote.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/upstream"
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/bash
exit 22
EOF
cat >"$TMP/bin/zsh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMP/bin/curl" "$TMP/bin/zsh"

git -C "$TMP/upstream" init -q
echo 'pinned' >"$TMP/upstream/README"
git -C "$TMP/upstream" add README
git -C "$TMP/upstream" -c user.name=test -c user.email=test@example.com \
  commit -qm 'initial' --no-gpg-sign
commit=$(git -C "$TMP/upstream" rev-parse HEAD)

HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" DOTFILES_DIR="$ROOT" \
  OH_MY_ZSH_REMOTE="$TMP/upstream" OH_MY_ZSH_COMMIT="$commit" \
  bash "$ROOT/scripts/zsh.sh" >/dev/null 2>&1

actual=$(git -C "$TMP/home/.oh-my-zsh" rev-parse HEAD)
if [ "$actual" != "$commit" ]; then
  printf ' ✖ Oh My Zsh is at %s, expected pinned commit %s\n' "$actual" "$commit"
  exit 1
fi

echo ' ✔ Oh My Zsh installs the pinned commit'
