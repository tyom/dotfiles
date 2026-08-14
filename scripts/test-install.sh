#!/bin/bash

# Exercise the piped remote installer without touching a real checkout or network.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/not-dotfiles/.git" "$TMP/not-dotfiles/scripts" "$TMP/run"
cat >"$TMP/bin/git" <<'EOF'
#!/bin/bash
if [ "$3 $4 $5" = 'remote get-url origin' ] && [ -n "$FAKE_REMOTE" ]; then
  printf '%s\n' "$FAKE_REMOTE"
fi
exit 0
EOF
cat >"$TMP/not-dotfiles/scripts/setup.sh" <<EOF
#!/bin/bash
touch "$TMP/wrong-setup-ran"
EOF
chmod +x "$TMP/bin/git" "$TMP/not-dotfiles/scripts/setup.sh"

if (cd "$TMP/run" && DOTFILES_DIR="$TMP/not-dotfiles" PATH="$TMP/bin:/usr/bin:/bin" \
  bash <"$ROOT/docs/install.sh" >/dev/null 2>&1); then
  echo ' ✖ remote install accepts an unrelated existing Git checkout'
  exit 1
fi

if [ -e "$TMP/wrong-setup-ran" ]; then
  echo ' ✖ remote install ran setup from an unrelated existing Git checkout'
  exit 1
fi

echo ' ✔ remote install rejects an unrelated existing Git checkout'

mkdir -p "$TMP/dotfiles/.git" "$TMP/dotfiles/scripts"
cat >"$TMP/dotfiles/scripts/setup.sh" <<EOF
#!/bin/bash
touch "$TMP/right-setup-ran"
EOF
chmod +x "$TMP/dotfiles/scripts/setup.sh"

if ! (cd "$TMP/run" && FAKE_REMOTE='git@github.com:tyom/dotfiles.git' \
  DOTFILES_DIR="$TMP/dotfiles" PATH="$TMP/bin:/usr/bin:/bin" \
  bash <"$ROOT/docs/install.sh" >/dev/null 2>&1); then
  echo ' ✖ remote install rejects the expected existing Git checkout'
  exit 1
fi

if [ ! -e "$TMP/right-setup-ran" ]; then
  echo ' ✖ remote install does not run setup from the expected checkout'
  exit 1
fi

echo ' ✔ remote install accepts the expected existing Git checkout'
