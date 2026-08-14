#!/bin/bash

# Refresh reviewed installer versions, commits and checksums in versions.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSIONS_FILE=${VERSIONS_FILE:-"$ROOT/scripts/versions.sh"}
WORK=$(mktemp -d)
OUTPUT=$(mktemp "$VERSIONS_FILE.tmp.XXXXXX")
trap 'rm -rf "$WORK"; rm -f "$OUTPUT"' EXIT

latest_tag() {
  local repo="$1" resolved
  resolved=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")
  basename "$resolved"
}

remote_ref() {
  local repo="$1" ref="$2" commit
  commit=$(git ls-remote "https://github.com/$repo.git" "$ref" | awk 'NR == 1 {print $1}')
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'Could not resolve %s %s\n' "$repo" "$ref" >&2
    return 1
  }
  printf '%s\n' "$commit"
}

tag_commit() {
  local repo="$1" tag="$2" commit
  commit=$(git ls-remote "https://github.com/$repo.git" "refs/tags/$tag^{}" | awk 'NR == 1 {print $1}')
  if [ -z "$commit" ]; then
    commit=$(remote_ref "$repo" "refs/tags/$tag")
  fi
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'Could not resolve %s tag %s\n' "$repo" "$tag" >&2
    return 1
  }
  printf '%s\n' "$commit"
}

url_sha256() {
  local url="$1" file="$WORK/download" hash
  curl -fsSL "$url" -o "$file"
  if command -v shasum >/dev/null 2>&1; then
    hash=$(shasum -a 256 "$file" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    hash=$(sha256sum "$file" | awk '{print $1}')
  else
    echo 'shasum or sha256sum is required' >&2
    return 1
  fi
  rm -f "$file"
  printf '%s\n' "$hash"
}

bun_tag=$(latest_tag oven-sh/bun)
bun_version=${bun_tag#bun-v}
volta_tag=$(latest_tag volta-cli/volta)
volta_version=${volta_tag#v}
volta_commit=$(tag_commit volta-cli/volta "$volta_tag")
oh_my_zsh_commit=$(remote_ref ohmyzsh/ohmyzsh refs/heads/master)
homebrew_commit=$(remote_ref Homebrew/install refs/heads/main)

bun_url=https://bun.com/install
volta_url="https://raw.githubusercontent.com/volta-cli/volta/$volta_commit/dev/unix/volta-install.sh"
homebrew_url="https://raw.githubusercontent.com/Homebrew/install/$homebrew_commit/install.sh"

bun_sha=$(url_sha256 "$bun_url")
volta_sha=$(url_sha256 "$volta_url")
homebrew_sha=$(url_sha256 "$homebrew_url")

cat >"$OUTPUT" <<EOF
# Reviewed bootstrap inputs. Update safely with \`make repin\`.
BUN_VERSION=$bun_version
BUN_INSTALL_URL=$bun_url
BUN_INSTALL_SHA256=$bun_sha

VOLTA_VERSION=$volta_version
VOLTA_INSTALL_URL=$volta_url
VOLTA_INSTALL_SHA256=$volta_sha

: "\${OH_MY_ZSH_REMOTE:=https://github.com/ohmyzsh/ohmyzsh.git}"
: "\${OH_MY_ZSH_COMMIT:=$oh_my_zsh_commit}"

HOMEBREW_INSTALL_URL=$homebrew_url
HOMEBREW_INSTALL_SHA256=$homebrew_sha
EOF

mv "$OUTPUT" "$VERSIONS_FILE"
printf 'Updated %s\n' "$VERSIONS_FILE"
