#!/bin/bash

# Docker entrypoint for remote install testing. Both modes do the same thing —
# pipe install.sh straight into bash, which is the path a real user takes and
# the one that differs from running the file. Only the URL changes:
#
#   docker run <image> remote-test        the deployed script
#   docker run <image> remote-test-local  the script in this checkout, served
#                                         locally, so a change to install.sh can
#                                         be tested before it ships
#
# Either way install.sh clones dotfiles from GitHub, so the local mode tests
# install.sh itself, not the rest of the working tree.

set -e

export YES_OVERRIDE=true

case "${1:-remote-test}" in
remote-test)
  URL=https://tyom.github.io/dotfiles/install.sh
  ;;
remote-test-local)
  URL=http://localhost:8080/install.sh
  (cd /tmp/docs && exec python3 -m http.server 8080) &>/dev/null &
  trap 'kill %1 2>/dev/null' EXIT
  # Poll rather than sleep a fixed amount: the server is usually up immediately.
  for _ in $(seq 20); do
    curl -fsS --max-time 1 "$URL" >/dev/null 2>&1 && break
    sleep 0.25
  done
  ;;
*)
  exec "$@"
  ;;
esac

echo "Installing from $URL"
echo ""
curl -fsSL "$URL" | bash
echo ""
echo "Remote install test completed successfully!"
