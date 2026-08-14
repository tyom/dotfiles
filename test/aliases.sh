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
  [ "${DOCKER_IMAGES_FAIL:-}" = 1 ] && exit 23
  [ "${NO_DANGLING:-}" = 1 ] && exit 0
  if [[ " $* " == *' --quiet '* ]]; then
    printf '%s\n' sha256:first sha256:second
  else
    printf '%s\n' '<none> <none> sha256:first 1MB' '<none> <none> sha256:second 2MB'
  fi
  exit 0
fi
printf '%s\n' "$*" >>"$DOCKER_LOG"
if [ "${DOCKER_RMI_FAIL:-}" = 1 ] && [ "$2" = sha256:first ]; then
  exit 24
fi
exit 0
EOF
chmod +x "$TMP/bin/docker"

DOCKER_LOG="$TMP/docker.log"
DOCKER_LOG="$DOCKER_LOG" DOCKER_IMAGES_FAIL=0 NO_DANGLING=0 DOCKER_RMI_FAIL=0 \
  PATH="$TMP/bin:/usr/bin:/bin" \
  zsh -c 'source "$1"; eval docker-rm-unused-images' _ "$ROOT/shell/aliases.sh"

actual=$(cat "$TMP/docker.log")
expected=$(printf '%s\n' 'rmi sha256:first' 'rmi sha256:second')
if [ "$actual" != "$expected" ]; then
  printf ' ✖ Docker cleanup passed unexpected arguments:\n%s\n' "$actual"
  exit 1
fi

echo ' ✔ Docker cleanup passes only dangling image IDs to docker rmi'

: >"$DOCKER_LOG"
if ! DOCKER_LOG="$DOCKER_LOG" DOCKER_IMAGES_FAIL=0 NO_DANGLING=1 DOCKER_RMI_FAIL=0 \
  PATH="$TMP/bin:/usr/bin:/bin" \
  zsh -c 'source "$1"; docker-rm-unused-images' _ "$ROOT/shell/aliases.sh"; then
  echo ' ✖ Docker cleanup fails when there are no dangling images'
  exit 1
fi

if [ -s "$DOCKER_LOG" ]; then
  echo ' ✖ Docker cleanup invokes docker rmi when there are no dangling images'
  exit 1
fi

echo ' ✔ Docker cleanup is quiet when there are no dangling images'

: >"$DOCKER_LOG"
if DOCKER_LOG="$DOCKER_LOG" DOCKER_IMAGES_FAIL=1 NO_DANGLING=0 DOCKER_RMI_FAIL=0 \
  PATH="$TMP/bin:/usr/bin:/bin" \
  zsh -c 'source "$1"; docker-rm-unused-images' _ "$ROOT/shell/aliases.sh"; then
  images_status=0
else
  images_status=$?
fi

if [ "$images_status" -ne 23 ]; then
  echo ' ✖ Docker cleanup succeeds when listing images fails'
  exit 1
fi

if [ -s "$DOCKER_LOG" ]; then
  echo ' ✖ Docker cleanup invokes docker rmi after listing images fails'
  exit 1
fi

echo ' ✔ Docker cleanup propagates image-list failures'

: >"$DOCKER_LOG"
if DOCKER_LOG="$DOCKER_LOG" DOCKER_IMAGES_FAIL=0 NO_DANGLING=0 DOCKER_RMI_FAIL=1 \
  PATH="$TMP/bin:/usr/bin:/bin" \
  zsh -c 'source "$1"; docker-rm-unused-images' _ "$ROOT/shell/aliases.sh"; then
  echo ' ✖ Docker cleanup succeeds when removing an image fails'
  exit 1
fi

actual=$(cat "$DOCKER_LOG")
if [ "$actual" != "$expected" ]; then
  printf ' ✖ Docker cleanup used an unexpected removal sequence:\n%s\n' "$actual"
  exit 1
fi

echo ' ✔ Docker cleanup preserves removal failures and continues cleaning'
