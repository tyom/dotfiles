#!/bin/bash

# Exercise the first-run Homebrew branch for the host OS with controlled tools.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

case "${TEST_PLATFORM:-$(uname -s)}" in
Darwin | macos) platform=macos; fake_uname=Darwin ;;
Linux | linux) platform=linux; fake_uname=Linux ;;
*) echo 'Homebrew bootstrap test supports only macOS and Linux'; exit 1 ;;
esac

mkdir -p "$TMP/repo/scripts/install" "$TMP/repo/shell" "$TMP/bin" \
  "$TMP/fixtures" "$TMP/home"
cp "$ROOT/scripts/install/brew.sh" "$TMP/repo/scripts/install/brew.sh"
cp "$ROOT/scripts/vars.sh" "$TMP/repo/scripts/vars.sh"
cp "$ROOT/shell/utils.sh" "$TMP/repo/shell/utils.sh"

cat >"$TMP/fixtures/brew" <<'EOF'
#!/bin/bash
case "$1" in
shellenv) printf 'export PATH="%s:$PATH"\n' "$(dirname "$0")" ;;
--prefix) dirname "$(dirname "$0")" ;;
*) printf '%s\n' "$*" >>"$BREW_LOG" ;;
esac
EOF
chmod +x "$TMP/fixtures/brew"

cat >"$TMP/fixtures/install.sh" <<'EOF'
#!/bin/bash
cp "$FAKE_BREW" "$FAKE_BIN/brew"
chmod +x "$FAKE_BIN/brew"
touch "$INSTALLER_RAN"
EOF

if command -v shasum >/dev/null 2>&1; then
  installer_sha=$(shasum -a 256 "$TMP/fixtures/install.sh" | awk '{print $1}')
else
  installer_sha=$(sha256sum "$TMP/fixtures/install.sh" | awk '{print $1}')
fi
cat >"$TMP/repo/scripts/versions.sh" <<EOF
HOMEBREW_INSTALL_URL=https://example.invalid/install.sh
HOMEBREW_INSTALL_SHA256=$installer_sha
EOF

cat >"$TMP/bin/curl" <<'EOF'
#!/bin/bash
output=
url=
while [ $# -gt 0 ]; do
  case "$1" in
  -o) output=$2; shift ;;
  http*) url=$1 ;;
  esac
  shift
done
[ -n "$output" ] && [ -n "$url" ] || exit 2
printf '%s\n' "$url" >>"$CURL_LOG"
cp "$FAKE_INSTALLER" "$output"
EOF

cat >"$TMP/bin/uname" <<EOF
#!/bin/bash
printf '%s\n' '$fake_uname'
EOF

cat >"$TMP/bin/git" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$GIT_LOG"
if [ "$1" = clone ]; then
  destination=${!#}
  mkdir -p "$destination/bin"
  cp "$FAKE_BREW" "$destination/bin/brew"
  chmod +x "$destination/bin/brew"
fi
EOF
chmod +x "$TMP/bin/curl" "$TMP/bin/git" "$TMP/bin/uname"

BREW_LOG="$TMP/brew.log"
CURL_LOG="$TMP/curl.log"
GIT_LOG="$TMP/git.log"
INSTALLER_RAN="$TMP/installer-ran"

(cd "$TMP/repo" && \
  HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" \
  BREW_LOG="$BREW_LOG" CURL_LOG="$CURL_LOG" GIT_LOG="$GIT_LOG" \
  FAKE_BREW="$TMP/fixtures/brew" FAKE_BIN="$TMP/bin" \
  FAKE_INSTALLER="$TMP/fixtures/install.sh" INSTALLER_RAN="$INSTALLER_RAN" \
  bash scripts/install/brew.sh >/dev/null)

if [ ! -e "$INSTALLER_RAN" ]; then
  printf ' ✖ %s did not run the verified Homebrew installer\n' "$platform"
  exit 1
fi

if ! grep -qxF 'https://example.invalid/install.sh' "$CURL_LOG"; then
  printf ' ✖ %s did not download the configured Homebrew installer URL\n' "$platform"
  exit 1
fi

if [ "$platform" = macos ]; then
  grep -qxF "eval \"\$($TMP/bin/brew shellenv)\"" "$TMP/home/.zprofile"
  package_command='install bat fzf git-delta herdr jq scmpuff tree wget tyom/tap/ungit tyom/tap/agent-ctx tyom/tap/git-owns coreutils findutils tyom/tap/kcm'
else
  if [ -s "$GIT_LOG" ]; then
    echo ' ✖ Linux used an unverified Git clone for Homebrew'
    exit 1
  fi
  package_command='install bat fzf git-delta herdr jq scmpuff tree wget tyom/tap/ungit tyom/tap/agent-ctx tyom/tap/git-owns'
fi

for command in update "$package_command" cleanup; do
  if ! grep -qxF "$command" "$BREW_LOG"; then
    printf ' ✖ %s bootstrap did not run brew %s\n' "$platform" "$command"
    exit 1
  fi
done

rm -f "$TMP/bin/brew" "$INSTALLER_RAN"
cat >"$TMP/repo/scripts/versions.sh" <<'EOF'
HOMEBREW_INSTALL_URL=https://example.invalid/install.sh
HOMEBREW_INSTALL_SHA256=0000000000000000000000000000000000000000000000000000000000000000
EOF

if (cd "$TMP/repo" && \
  HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" \
  BREW_LOG="$BREW_LOG" CURL_LOG="$CURL_LOG" GIT_LOG="$GIT_LOG" \
  FAKE_BREW="$TMP/fixtures/brew" FAKE_BIN="$TMP/bin" \
  FAKE_INSTALLER="$TMP/fixtures/install.sh" INSTALLER_RAN="$INSTALLER_RAN" \
  bash scripts/install/brew.sh >/dev/null 2>&1); then
  printf ' ✖ %s accepts a Homebrew installer with the wrong checksum\n' "$platform"
  exit 1
fi

if [ -e "$INSTALLER_RAN" ]; then
  printf ' ✖ %s runs Homebrew before rejecting the wrong checksum\n' "$platform"
  exit 1
fi

printf ' ✔ %s bootstraps Homebrew only from the configured verified installer\n' "$platform"
