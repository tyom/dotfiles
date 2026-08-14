#!/bin/bash

# Exercise setup failures against a throwaway HOME and controlled commands.

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/home"
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/bash
exit 22
EOF
chmod +x "$TMP/bin/curl"

if HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" \
  bash "$DOTFILES_DIR/scripts/setup.sh" --select node >/dev/null 2>&1; then
  echo ' ✖ setup succeeds when the Volta download fails'
  exit 1
fi

echo ' ✔ setup fails when the Volta download fails'

if HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" \
  bash "$DOTFILES_DIR/scripts/setup.sh" --select bun >/dev/null 2>&1; then
  echo ' ✖ setup succeeds when the Bun download fails'
  exit 1
fi

echo ' ✔ setup fails when the Bun download fails'

cat >"$TMP/fake-volta-installer" <<'EOF'
#!/bin/bash
touch "$INSTALLER_SENTINEL"
mkdir -p "$HOME/.volta/bin"
cat >"$HOME/.volta/bin/volta" <<'SCRIPT'
#!/bin/bash
case "$1" in
which | install) exit 0 ;;
--version) echo '2.0.2' ;;
esac
SCRIPT
chmod +x "$HOME/.volta/bin/volta"
EOF
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/bash
output=
while [ $# -gt 0 ]; do
  if [ "$1" = -o ]; then
    output=$2
    shift
  fi
  shift
done
[ -n "$output" ] || exit 2
cp "$FAKE_INSTALLER" "$output"
EOF
chmod +x "$TMP/bin/curl"

if HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" \
  FAKE_INSTALLER="$TMP/fake-volta-installer" \
  INSTALLER_SENTINEL="$TMP/installer-ran" \
  bash "$DOTFILES_DIR/scripts/setup.sh" --select node >/dev/null 2>&1; then
  echo ' ✖ setup executes a Volta installer whose checksum does not match'
  exit 1
fi

if [ -e "$TMP/installer-ran" ]; then
  echo ' ✖ setup runs a Volta installer before rejecting its checksum'
  exit 1
fi

echo ' ✔ setup rejects a Volta installer whose checksum does not match'
