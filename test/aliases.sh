#!/bin/bash

# Exercise shell helpers through a clean Zsh process and controlled Docker CLI.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/docker" <<'EOF'
#!/bin/bash
if [ "$1" = images ]; then
  [ "${NO_DANGLING:-}" = 1 ] && exit 0
  if [[ " $* " == *' --quiet '* ]]; then
    printf '%s\n' sha256:first sha256:second
  else
    printf '%s\n' '<none> <none> sha256:first 1MB' '<none> <none> sha256:second 2MB'
  fi
  exit 0
fi
printf '%s\n' "$*" >>"$DOCKER_LOG"
EOF
chmod +x "$TMP/bin/docker"

DOCKER_LOG="$TMP/docker.log"
DOCKER_LOG="$DOCKER_LOG" PATH="$TMP/bin:/usr/bin:/bin" \
  zsh -c 'source "$1"; eval docker-rm-unused-images' _ "$ROOT/shell/aliases.sh"

actual=$(cat "$TMP/docker.log")
expected=$(printf '%s\n' 'rmi sha256:first' 'rmi sha256:second')
if [ "$actual" != "$expected" ]; then
  printf ' ✖ Docker cleanup passed unexpected arguments:\n%s\n' "$actual"
  exit 1
fi

echo ' ✔ Docker cleanup passes only dangling image IDs to docker rmi'

: >"$DOCKER_LOG"
DOCKER_LOG="$DOCKER_LOG" NO_DANGLING=1 PATH="$TMP/bin:/usr/bin:/bin" \
  zsh -c 'source "$1"; docker-rm-unused-images' _ "$ROOT/shell/aliases.sh"

if [ -s "$DOCKER_LOG" ]; then
  echo ' ✖ Docker cleanup invokes docker rmi when there are no dangling images'
  exit 1
fi

echo ' ✔ Docker cleanup is quiet when there are no dangling images'
