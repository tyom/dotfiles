#!/bin/bash

# Exercise dependency repinning with deterministic upstream responses.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/bash
args="$*"
case "$args" in
*oven-sh/bun/releases/latest*) printf '%s' "https://github.com/oven-sh/bun/releases/tag/${FAKE_BUN_TAG:-bun-v9.8.7}"; exit 0 ;;
*volta-cli/volta/releases/latest*) printf '%s' "https://github.com/volta-cli/volta/releases/tag/${FAKE_VOLTA_TAG:-v6.5.4}"; exit 0 ;;
esac

output=
url=
while [ $# -gt 0 ]; do
  case "$1" in
  -o) output=$2; shift ;;
  http*) url=$1 ;;
  esac
  shift
done
case "$url" in
https://bun.com/install) printf 'bun installer\n' >"$output" ;;
*volta-cli/volta/2222222222222222222222222222222222222222/*) printf 'volta installer\n' >"$output" ;;
*Homebrew/install/4444444444444444444444444444444444444444/*) printf 'homebrew installer\n' >"$output" ;;
*) exit 22 ;;
esac
EOF
cat >"$TMP/bin/git" <<'EOF'
#!/bin/bash
case "$2 $3" in
*volta-cli/volta.git*'refs/tags/v6.5.4^{}') printf '%s\t%s\n' 2222222222222222222222222222222222222222 'refs/tags/v6.5.4^{}' ;;
*ohmyzsh/ohmyzsh.git*refs/heads/master) printf '%s\t%s\n' 3333333333333333333333333333333333333333 refs/heads/master ;;
*Homebrew/install.git*refs/heads/main) printf '%s\t%s\n' 4444444444444444444444444444444444444444 refs/heads/main ;;
*) exit 1 ;;
esac
EOF
chmod +x "$TMP/bin/curl" "$TMP/bin/git"

PATH="$TMP/bin:/usr/bin:/bin" VERSIONS_FILE="$TMP/versions.sh" \
  bash "$ROOT/scripts/repin.sh" >/dev/null

assert_line() {
  if ! grep -qxF "$1" "$TMP/versions.sh"; then
    printf ' ✖ repinned file is missing: %s\n' "$1"
    exit 1
  fi
}

assert_line 'BUN_VERSION=9.8.7'
assert_line 'BUN_INSTALL_SHA256=fe408834856dae38ed3c8e84f13fede38f2ff103af194fd666545207458f163d'
assert_line 'VOLTA_VERSION=6.5.4'
assert_line 'VOLTA_INSTALL_SHA256=7b6223760a0ab34f9cee039db6cc773c7d7342a32c133f9f12009ad6079523a1'
assert_line ': "${OH_MY_ZSH_COMMIT:=3333333333333333333333333333333333333333}"'
assert_line 'HOMEBREW_INSTALL_SHA256=fbaa11d4ed7378e0c699a5546061e7b12d3ed6d7c5db8c2c07a5d96fcadcd957'

echo ' ✔ repin writes complete version, commit and checksum pins'

cp "$TMP/versions.sh" "$TMP/versions.before"
if PATH="$TMP/bin:/usr/bin:/bin" VERSIONS_FILE="$TMP/versions.sh" \
  FAKE_BUN_TAG='bun-v9.8.7;echo unsafe' \
  bash "$ROOT/scripts/repin.sh" >/dev/null 2>&1; then
  echo ' ✖ repin accepts a malformed Bun release tag'
  exit 1
fi

if ! cmp -s "$TMP/versions.before" "$TMP/versions.sh"; then
  echo ' ✖ repin changes versions.sh after a malformed Bun release tag'
  exit 1
fi

echo ' ✔ repin rejects a malformed Bun release tag without changing versions.sh'

if PATH="$TMP/bin:/usr/bin:/bin" VERSIONS_FILE="$TMP/versions.sh" \
  FAKE_VOLTA_TAG='v6.5.4$(echo unsafe)' \
  bash "$ROOT/scripts/repin.sh" >/dev/null 2>&1; then
  echo ' ✖ repin accepts a malformed Volta release tag'
  exit 1
fi

if ! cmp -s "$TMP/versions.before" "$TMP/versions.sh"; then
  echo ' ✖ repin changes versions.sh after a malformed Volta release tag'
  exit 1
fi

echo ' ✔ repin rejects a malformed Volta release tag without changing versions.sh'
